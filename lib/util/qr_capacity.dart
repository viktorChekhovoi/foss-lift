/// How much a QR code can actually hold, and how much of it we can afford to
/// spend on error correction.
///
/// Deliberately free of Flutter: the widget layer paints the symbol, the data
/// layer decides whether to offer one at all, and both have to agree about
/// where the line is. That line is a property of the standard, not of either.
library;

/// Byte-mode capacity of the largest symbol (version 40, 177×177 modules) at
/// each error-correction level, in bytes — ISO/IEC 18004.
///
/// Byte mode is the one that applies: a share code is base64url and the link
/// prefix is lowercase, and alphanumeric mode covers neither. Our payloads are
/// all ASCII, so one character is one byte and a length in characters can be
/// compared against these directly.
const int kQrBytesLowEcc = 2953;
const int kQrBytesMediumEcc = 2331;

/// How much error correction a payload of [bytes] can afford.
///
/// Medium while it fits: a QR is read off a screen at an angle, often with a
/// reflection across it, and the redundancy is what survives that. Only when
/// medium will not hold the payload does it drop to low — a worse symbol is
/// still better than no symbol, and the alternative on offer is a link.
///
/// Null means it does not fit at any level, and the caller should say so rather
/// than paint something unscannable.
QrEcc? qrEccFor(int bytes) => switch (bytes) {
      <= kQrBytesMediumEcc => QrEcc.medium,
      <= kQrBytesLowEcc => QrEcc.low,
      _ => null,
    };

/// Whether a payload of [bytes] fits in a QR code at all.
bool qrHolds(int bytes) => qrEccFor(bytes) != null;

/// The error-correction levels this app paints at, kept as our own enum so the
/// data layer can reason about capacity without importing a QR library.
enum QrEcc { low, medium }
