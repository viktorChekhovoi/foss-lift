import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

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

  /// The URL a shared theme travels as. A custom scheme rather than an https
  /// App Link: it needs no domain, no hosting and no network, and so cannot rot
  /// when nobody is paying for a server. See issue #29.
  static const String scheme = 'fosslift';
  static const String _linkPrefix = '$scheme://theme/';

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
  static const int _checksumBytes = 2;

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

    final bytes = body.takeBytes();
    final sum = _crc16(bytes);
    final full = Uint8List(bytes.length + _checksumBytes)
      ..setAll(0, bytes)
      ..[bytes.length] = (sum >> 8) & 0xFF
      ..[bytes.length + 1] = sum & 0xFF;

    return '$version.${base64Url.encode(full).replaceAll('=', '')}';
  }

  /// The full share link for [palette] — what a QR code holds, so one image
  /// serves both a system camera (which routes the scheme to the app) and the
  /// in-app scanner (which strips the prefix and imports directly).
  static String link(AppPalette palette) => '$_linkPrefix${encode(palette)}';

  /// Reads a code, a share link, or either with whitespace through it.
  ///
  /// Never throws and never returns a half-read palette: the result is either
  /// [ThemeCodeOk] with a complete theme or a [ThemeCodeFailure] saying which
  /// of the three things went wrong.
  static ThemeCodeResult decode(String source) {
    // Pasted text arrives wrapped, indented, or with a trailing newline; a QR
    // scan arrives as the whole link.
    var s = source.replaceAll(RegExp(r'\s+'), '');
    final at = s.indexOf(_linkPrefix);
    if (at >= 0) s = s.substring(at + _linkPrefix.length);

    final dot = s.indexOf('.');
    if (dot <= 0) return const ThemeCodeFailure(ThemeCodeProblem.notACode);
    final tag = s.substring(0, dot);
    if (!RegExp(r'^FLT\d+$').hasMatch(tag)) {
      return const ThemeCodeFailure(ThemeCodeProblem.notACode);
    }
    if (tag != version) {
      return const ThemeCodeFailure(ThemeCodeProblem.futureVersion);
    }

    final payload = s.substring(dot + 1);
    Uint8List bytes;
    try {
      bytes = base64Url.decode(payload.padRight(
          payload.length + ((4 - payload.length % 4) % 4), '='));
    } catch (_) {
      return const ThemeCodeFailure(ThemeCodeProblem.damaged);
    }

    // Long enough for the fixed header, an empty name and the checksum.
    if (bytes.length < _nameAt + _checksumBytes) {
      return const ThemeCodeFailure(ThemeCodeProblem.damaged);
    }
    final bodyEnd = bytes.length - _checksumBytes;
    final expected = (bytes[bodyEnd] << 8) | bytes[bodyEnd + 1];
    if (_crc16(bytes.sublist(0, bodyEnd)) != expected) {
      return const ThemeCodeFailure(ThemeCodeProblem.damaged);
    }

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
      name: name.trim().isEmpty ? 'Shared theme' : name,
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

  /// CRC-16/CCITT-FALSE. Enough to catch the damage a code actually suffers —
  /// a truncated copy-paste, a mistyped character — without the weight of a
  /// real hash, which would cost QR density for no gain against an attacker
  /// who could simply share a different theme.
  static int _crc16(List<int> bytes) {
    var crc = 0xFFFF;
    for (final byte in bytes) {
      crc ^= byte << 8;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
        crc &= 0xFFFF;
      }
    }
    return crc;
  }
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

  /// Wording for the user. Each case gets its own advice, because what to do
  /// about it differs: retype it, update the app, or check what you scanned.
  String get message => switch (problem) {
        ThemeCodeProblem.notACode =>
          "That doesn't look like a theme code.",
        ThemeCodeProblem.futureVersion =>
          'That theme was made by a newer version of Foss Lift. Update the app '
              'to use it.',
        ThemeCodeProblem.damaged =>
          'That theme code looks damaged — some of it may be missing. Try '
              'copying it again.',
      };
}

/// The three ways reading a code can fail, kept apart because the user can act
/// on the difference.
enum ThemeCodeProblem {
  /// Not a theme code at all — a URL, a stray paste, empty text.
  notACode,

  /// A theme code, but in a format this build predates.
  futureVersion,

  /// The right format, but the bytes did not survive the trip.
  damaged,
}
