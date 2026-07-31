import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/share_code.dart';
import 'app_theme.dart';

/// A palette squeezed into something a person can paste into a chat message or
/// a QR code can hold comfortably.
///
/// The JSON export is fine for a file and hopeless for either of those: pretty
/// printed it runs to roughly 600 characters. A theme code is about 75.
///
/// ```
/// FLT1.AA8SGBcbJB8lMCcuOyoxPeru9YuVp1pkdP9qPeBSHz7VmP_CSwhJZ25pdGlvbvd1
/// ```
///
/// The shipped presets encode to between 65 and 84 characters.
///
/// ## The wire format
///
/// `FLT1` is a **format** version, not an app version. It is the first thing
/// read and everything else is dispatched on it, so a future `FLT2` may change
/// the layout wholesale and this reader will decline it with "made by a newer
/// version" rather than mangling it.
///
/// The envelope — the tag, the base64, the checksum, the link unwrapping and
/// the three failure cases — is [ShareCodec], shared with the routine format.
/// What is written *inside* it is this file's business:
///
/// After the dot, base64url (unpadded) of:
///
/// | Offset | Bytes | Meaning |
/// |---|---|---|
/// | 0 | 1 | flags — bit 0 is [AppPalette.accessible] |
/// | 1 | 36 | the twelve roles, 3 bytes of RGB each, in [_roleOrder] |
/// | 37 | 1 | length of the name in UTF-8 bytes |
/// | 38 | n | the name |
/// | 38+n | … | fields a later writer added; skipped by this reader |
/// | end-2 | 2 | CRC-16/CCITT over everything before it |
///
/// **The role order is frozen.** It is a wire format now: reordering
/// [_roleOrder] silently changes the meaning of every code already shared.
///
/// Forward compatibility is the reason the checksum sits at the end rather than
/// after the name. Anything between the name and those last two bytes is
/// ignored here but still covered by the checksum, so a later additive field
/// neither breaks this reader nor escapes damage detection.
abstract final class ThemeCode {
  /// The current format tag. Bump only for a layout change this reader could
  /// not otherwise survive — additive fields do not need it.
  static const String version = 'FLT1';

  /// The URL a shared theme travels as *inside a QR symbol*. A custom scheme
  /// rather than an https App Link: it needs no domain, no hosting and no
  /// network, and so cannot rot when nobody is paying for a server. See issue
  /// #29.
  static const String scheme = kShareScheme;

  /// The link host a theme lives under, so `fosslift://theme/…` and
  /// `fosslift://routine/…` route to different screens.
  static const String host = 'theme';

  /// The twelve roles, in the order their bytes appear. **Frozen** — see the
  /// class docs.
  static const List<Color Function(AppPalette)> _roleOrder = [
    _ground, _surface, _surface2, _surface3,
    _line, _text, _muted, _faint,
    _accent, _accentPress, _good, _gold,
  ];

  static Color _ground(AppPalette p) => p.ground;
  static Color _surface(AppPalette p) => p.surface;
  static Color _surface2(AppPalette p) => p.surface2;
  static Color _surface3(AppPalette p) => p.surface3;
  static Color _line(AppPalette p) => p.line;
  static Color _text(AppPalette p) => p.text;
  static Color _muted(AppPalette p) => p.muted;
  static Color _faint(AppPalette p) => p.faint;
  static Color _accent(AppPalette p) => p.accent;
  static Color _accentPress(AppPalette p) => p.accentPress;
  static Color _good(AppPalette p) => p.good;
  static Color _gold(AppPalette p) => p.gold;

  static const int _colorBytes = 3;
  static const int _flagsAt = 0;
  static const int _colorsAt = 1;
  static const int _nameLenAt = _colorsAt + 12 * _colorBytes; // 37
  static const int _nameAt = _nameLenAt + 1; // 38

  /// The longest name a code can carry, in UTF-8 bytes — one length byte.
  static const int maxNameBytes = 255;

  /// Encodes [palette] as a shareable code.
  static String encode(AppPalette palette) =>
      encodeWithExtraFields(palette, const []);

  /// [encode], with [extra] bytes appended where a later format version's
  /// additional fields would sit. Exists so the forward-compatibility promise
  /// in the class docs is something the tests can actually exercise rather than
  /// a comment nobody checks.
  static String encodeWithExtraFields(AppPalette palette, List<int> extra) {
    var name = utf8.encode(palette.name);
    if (name.length > maxNameBytes) {
      // Truncate on a byte boundary that still decodes; a silly-long name is
      // not worth failing an export over.
      name = utf8.encode(
          utf8.decode(name.sublist(0, maxNameBytes), allowMalformed: true));
    }

    final body = BytesBuilder();
    body.addByte(palette.accessible ? 0x01 : 0x00);
    for (final role in _roleOrder) {
      final c = role(palette);
      body.add([_channel(c.r), _channel(c.g), _channel(c.b)]);
    }
    body.addByte(name.length);
    body.add(name);
    body.add(extra);

    return ShareCodec.pack(version, body.takeBytes());
  }

  /// The full share link for [palette] — what a **QR code** holds, so one image
  /// serves both routes: a system camera recognises the scheme and offers to
  /// open Foss Lift, while our own scanner strips the prefix and imports
  /// directly.
  ///
  /// The share *sheet* sends [encode] instead. A chat app does not linkify a
  /// custom scheme, so a link pasted into a message is unclickable text with a
  /// prefix the reader then has to strip; a camera has no such trouble with one.
  static String link(AppPalette palette) =>
      '${ShareCodec.linkPrefix(host)}${encode(palette)}';

  /// Reads a code, a share link, or either with whitespace through it.
  ///
  /// Never throws and never returns a half-read palette: the result is either
  /// [ThemeCodeOk] with a complete theme or a [ThemeCodeFailure] saying which
  /// of the three things went wrong.
  ///
  /// [unnamed] is what a palette that arrived without a name is called. It is a
  /// translated string, so it comes from the screen showing the result rather
  /// than from here; a caller that only asks whether the code reads at all can
  /// leave it out and get the empty name the sender sent.
  static ThemeCodeResult decode(String source, {String? unnamed}) {
    // Long enough for the fixed header and an empty name.
    final read = ShareCodec.unpack(source,
        version: version, host: host, minBody: _nameAt);
    if (read.problem != null) return ThemeCodeFailure(read.problem!);
    final bytes = read.body!;
    final bodyEnd = bytes.length;

    final nameLen = bytes[_nameLenAt];
    if (_nameAt + nameLen > bodyEnd) {
      return const ThemeCodeFailure(ThemeCodeProblem.damaged);
    }
    final String name;
    try {
      name = utf8.decode(bytes.sublist(_nameAt, _nameAt + nameLen));
    } catch (_) {
      return const ThemeCodeFailure(ThemeCodeProblem.damaged);
    }
    // Bytes between the name and the checksum belong to a later format
    // revision. Ignored on purpose — see the class docs.

    Color role(int index) {
      final at = _colorsAt + index * _colorBytes;
      return Color.fromARGB(0xFF, bytes[at], bytes[at + 1], bytes[at + 2]);
    }

    return ThemeCodeOk(AppPalette(
      // A code carries a theme, not a claim to be one of ours: it always
      // arrives as the recipient's custom palette.
      id: kCustomThemeId,
      name: name.trim().isEmpty ? (unnamed ?? '') : name,
      accessible: bytes[_flagsAt] & 0x01 != 0,
      ground: role(0),
      surface: role(1),
      surface2: role(2),
      surface3: role(3),
      line: role(4),
      text: role(5),
      muted: role(6),
      faint: role(7),
      accent: role(8),
      accentPress: role(9),
      good: role(10),
      gold: role(11),
    ));
  }

  static int _channel(double v) => (v * 255).round().clamp(0, 255);
}

/// What came of reading a theme code.
sealed class ThemeCodeResult {
  const ThemeCodeResult();
}

/// A code that read cleanly. [palette] is complete and safe to preview.
final class ThemeCodeOk extends ThemeCodeResult {
  const ThemeCodeOk(this.palette);
  final AppPalette palette;
}

/// A code that did not read, and why.
final class ThemeCodeFailure extends ThemeCodeResult {
  const ThemeCodeFailure(this.problem);
  final ThemeCodeProblem problem;
}

/// The three ways reading a theme code can fail. The same three as every other
/// share code, so the wording and the handling stay in step — see
/// [ShareCodeProblem].
typedef ThemeCodeProblem = ShareCodeProblem;
