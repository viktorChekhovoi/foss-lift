import 'dart:typed_data';

import 'package:zxing2/qrcode.dart';

/// Finds a QR code in a camera frame, in pure Dart.
///
/// Decoding runs here rather than through `mobile_scanner` on purpose: that
/// package wraps Google's ML Kit, a proprietary binary that would disqualify
/// the app from F-Droid and sit oddly inside an app whose whole pitch is that
/// nothing leaves the device. The cost is this file — the frame plumbing ML Kit
/// would have hidden.
///
/// Split out from the camera screen so the awkward part is reachable from a
/// test: [decodeLuminance] takes plain bytes and needs no camera, no
/// permission and no device.
abstract final class QrDecoder {
  /// Reads a QR code from an 8-bit greyscale image, or null if there isn't one
  /// in frame.
  ///
  /// [luminance] is row-major, one byte per pixel, `width * height` long.
  /// Never throws: a frame with no code in it is the normal case, arriving
  /// thirty times a second, not an error.
  static String? decodeLuminance(Uint8List luminance, int width, int height) {
    if (width <= 0 || height <= 0 || luminance.length < width * height) {
      return null;
    }
    try {
      // zxing2 wants ARGB ints. The source is greyscale, so each channel takes
      // the same value; only the luma matters to the binarizer.
      final pixels = Int32List(width * height);
      for (var i = 0; i < pixels.length; i++) {
        final v = luminance[i];
        pixels[i] = 0xFF000000 | (v << 16) | (v << 8) | v;
      }
      final source = RGBLuminanceSource(width, height, pixels);
      final bitmap = BinaryBitmap(HybridBinarizer(source));
      return QRCodeReader().decode(bitmap).text;
    } catch (_) {
      // NotFoundException, ChecksumException, FormatException — all of which
      // just mean "not this frame".
      return null;
    }
  }

  /// Pulls the luminance plane out of a camera frame's planes.
  ///
  /// Both formats the plugin gives us on Android put luma first: YUV420 has it
  /// as plane 0, and NV21 is a single interleaved plane that begins with the
  /// full luma image. Either way the first `width * height` bytes of plane 0
  /// are what we want, so the rest is ignored rather than converted.
  ///
  /// [bytesPerRow] is honoured because the camera pads rows to a stride that is
  /// often wider than the image; reading straight through without accounting
  /// for it shears the picture and nothing ever decodes.
  static Uint8List? lumaFromPlane(
    Uint8List plane0,
    int width,
    int height,
    int bytesPerRow,
  ) {
    if (width <= 0 || height <= 0) return null;
    if (bytesPerRow <= 0) bytesPerRow = width;
    if (plane0.length < bytesPerRow * (height - 1) + width) return null;
    if (bytesPerRow == width) {
      return Uint8List.sublistView(plane0, 0, width * height);
    }
    final out = Uint8List(width * height);
    for (var row = 0; row < height; row++) {
      out.setRange(
        row * width,
        row * width + width,
        plane0,
        row * bytesPerRow,
      );
    }
    return out;
  }
}
