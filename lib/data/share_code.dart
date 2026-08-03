/// The plumbing every Foss Lift share code is built on.
///
/// Two things travel between phones as a pasteable line of text — a theme
/// (`FLT1`, see `theme/theme_code.dart`) and a routine (`FLR1`, see
/// `routine_code.dart`). They carry completely different payloads and share
/// everything else: the version tag, the base64 envelope, the checksum, the way
/// a link is unwrapped, and the three ways reading one can fail. That common
/// half lives here so the two formats cannot drift apart in how they *fail*,
/// which is the part a user actually sees.
///
/// Deliberately free of drift, and free of Flutter but for the string
/// catalogue: this is bytes in, bytes out, plus the sentences a failure is
/// reported with.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../l10n/app_localizations.dart';

/// The URL scheme a shared anything travels as. A custom scheme rather than an
/// https App Link: it needs no domain, no hosting and no network, and so cannot
/// rot when nobody is paying for a server.
const String kShareScheme = 'fosslift';

/// The two ways reading a code can fail, kept apart because the user can act on
/// the difference: one is the wrong text entirely, the other is our text with a
/// piece knocked out of it.
///
/// Each way out is a whole sentence per kind of code, rather than one sentence
/// with "theme" or "routine" dropped into a hole in it. English gets away with
/// the hole; a language that inflects the noun — Ukrainian declines it, Spanish
/// and Portuguese put an article and a gender on it — cannot be handed a bare
/// dictionary form and asked to make it fit. Four messages is the price of the
/// two the user ever sees being sentences somebody wrote.
enum ShareCodeProblem {
  /// Not one of our codes at all — a URL, a stray paste, empty text, a code of
  /// the *other* kind, or one tagged with a version this build does not know.
  notACode,

  /// The right format, but the bytes did not survive the trip.
  damaged;

  /// What a routine code that would not read says on the import screen.
  String routineMessage(AppLocalizations l10n) => switch (this) {
        ShareCodeProblem.notACode => l10n.shareRoutineNotACode,
        ShareCodeProblem.damaged => l10n.shareRoutineDamaged,
      };

  /// The same for a theme code.
  String themeMessage(AppLocalizations l10n) => switch (this) {
        ShareCodeProblem.notACode => l10n.shareThemeNotACode,
        ShareCodeProblem.damaged => l10n.shareThemeDamaged,
      };
}

/// Thrown by [ByteReader] when the bytes run out — or turn out to be nonsense —
/// part way through a field. Always caught by a decoder and turned into
/// [ShareCodeProblem.damaged]; it never escapes to a caller.
class ShareCodeDamaged implements Exception {
  const ShareCodeDamaged();
}

/// A code that was read out of its envelope: either the body bytes or the
/// reason there are none.
typedef ShareCodeBody = ({Uint8List? body, ShareCodeProblem? problem});

/// The envelope: `TAG.base64url(body + checksum)`, and the reverse.
abstract final class ShareCodec {
  /// Wraps [body] as a shareable code under [version] (`FLT1`, `FLR1`, …).
  ///
  /// [checksumBytes] picks the guard: two bytes of CRC-16 for a payload of a
  /// few dozen bytes, four of CRC-32 where the code runs to hundreds and a
  /// one-in-65536 chance of a corruption slipping through stops being small
  /// enough.
  static String pack(String version, List<int> body,
      {int checksumBytes = 2}) {
    final sum = checksumBytes == 4 ? _crc32(body) : _crc16(body);
    final full = Uint8List(body.length + checksumBytes)..setAll(0, body);
    for (var i = 0; i < checksumBytes; i++) {
      full[body.length + i] = (sum >> (8 * (checksumBytes - 1 - i))) & 0xFF;
    }
    return '$version.${base64Url.encode(full).replaceAll('=', '')}';
  }

  /// Reads a code, a `fosslift://<host>/` link, or either with whitespace
  /// through it, and hands back the body [pack] was given.
  ///
  /// Never throws. Any tag that is not exactly [version] — another family's, or
  /// the same family at a number this build does not know — is
  /// [ShareCodeProblem.notACode]. There is only one version of each family so
  /// far; the day a second exists, this is where the older one has to keep being
  /// accepted, because the codes written against it are in messages people can
  /// still open.
  ///
  /// [minBody] is the shortest body the caller's format can possibly have; a
  /// code below it is damaged rather than parsed into a half-read anything.
  static ShareCodeBody unpack(
    String source, {
    required String version,
    required String host,
    int minBody = 1,
    int checksumBytes = 2,
  }) {
    // Pasted text arrives wrapped, indented, or with a trailing newline; a QR
    // scan arrives as the whole link.
    var s = source.replaceAll(RegExp(r'\s+'), '');
    final prefix = linkPrefix(host);
    final at = s.indexOf(prefix);
    if (at >= 0) s = s.substring(at + prefix.length);

    const notACode = (body: null, problem: ShareCodeProblem.notACode);
    const damaged = (body: null, problem: ShareCodeProblem.damaged);

    final dot = s.indexOf('.');
    if (dot <= 0) return notACode;
    if (s.substring(0, dot) != version) return notACode;

    final payload = s.substring(dot + 1);
    Uint8List bytes;
    try {
      bytes = base64Url.decode(
          payload.padRight(payload.length + ((4 - payload.length % 4) % 4), '='));
    } catch (_) {
      return damaged;
    }

    if (bytes.length < minBody + checksumBytes) return damaged;
    final end = bytes.length - checksumBytes;
    var expected = 0;
    for (var i = 0; i < checksumBytes; i++) {
      expected = (expected << 8) | bytes[end + i];
    }
    final body = bytes.sublist(0, end);
    final actual = checksumBytes == 4 ? _crc32(body) : _crc16(body);
    if (actual != expected) return damaged;

    return (body: body, problem: null);
  }

  /// The prefix a shared [host] travels under: `fosslift://theme/`, and so on.
  static String linkPrefix(String host) => '$kShareScheme://$host/';

  /// CRC-16/CCITT-FALSE. Enough to catch the damage a short code actually
  /// suffers — a truncated copy-paste, a mistyped character — without the
  /// weight of a real hash, which would cost QR density for no gain against an
  /// attacker who could simply share a different theme.
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

  /// CRC-32 (the zip/PNG polynomial), for payloads long enough that CRC-16's
  /// odds stop being comfortable: a routine code is hundreds of characters, and
  /// every one of them is a chance for a bad copy to land on a colliding sum.
  static int _crc32(List<int> bytes) {
    var crc = 0xFFFFFFFF;
    for (final byte in bytes) {
      crc ^= byte;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? ((crc >> 1) ^ 0xEDB88320) : (crc >> 1);
      }
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }
}

/// Builds a body byte by byte. Numbers go out as LEB128 varints, so the small
/// values that make up almost every field cost one byte rather than four.
class ByteWriter {
  final BytesBuilder _out = BytesBuilder();

  void byte(int value) => _out.addByte(value & 0xFF);

  void bytes(List<int> value) => _out.add(value);

  /// An unsigned LEB128 varint. Negatives are not a thing any share format
  /// carries; one arriving would be a bug upstream, so it is clamped rather
  /// than encoded into seven wasted bytes.
  void varint(int value) {
    var v = value < 0 ? 0 : value;
    while (v >= 0x80) {
      _out.addByte((v & 0x7F) | 0x80);
      v >>= 7;
    }
    _out.addByte(v);
  }

  /// A number to two decimal places, as hundredths. Every quantity the app
  /// stores as a real — kilograms, an increment, a bar weight — is meaningful
  /// to 0.01 and no further, so this is lossless in practice and a great deal
  /// smaller than eight bytes of IEEE754.
  void fixed2(double value) => varint((value * 100).round());

  /// A length-prefixed UTF-8 string.
  void string(String value) {
    final utf = utf8.encode(value);
    varint(utf.length);
    _out.add(utf);
  }

  Uint8List take() => _out.takeBytes();
}

/// Reads back what [ByteWriter] wrote. Every method throws [ShareCodeDamaged]
/// rather than returning something half-read, so a decoder can wrap the whole
/// parse in one try/catch instead of checking after every field.
class ByteReader {
  ByteReader(this._bytes);
  final List<int> _bytes;
  int _at = 0;

  bool get atEnd => _at >= _bytes.length;

  int byte() {
    if (atEnd) throw const ShareCodeDamaged();
    return _bytes[_at++];
  }

  int varint() {
    var result = 0;
    var shift = 0;
    while (true) {
      final b = byte();
      result |= (b & 0x7F) << shift;
      if (b & 0x80 == 0) return result;
      shift += 7;
      // Well past any field this app writes: a run of continuation bytes is
      // corruption, not a very large number.
      if (shift > 42) throw const ShareCodeDamaged();
    }
  }

  double fixed2() => varint() / 100.0;

  String string() {
    final length = varint();
    if (_at + length > _bytes.length) throw const ShareCodeDamaged();
    final slice = _bytes.sublist(_at, _at + length);
    _at += length;
    try {
      return utf8.decode(slice);
    } catch (_) {
      throw const ShareCodeDamaged();
    }
  }
}
