import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_theme.dart';
import '../theme/theme_code.dart';

/// The active theme as a QR code, for someone else to point a phone at.
///
/// It holds the full `fosslift://theme/…` link rather than the bare code, so
/// one image serves both routes: a system camera recognises the scheme and
/// offers to open Foss Lift, while our own scanner strips the prefix and
/// imports directly.
///
/// Deliberately **not** painted in the current theme. A QR code is read by a
/// machine looking for dark modules on a light field with a quiet margin around
/// them; rendering it in a dark theme's colours would make it pretty and
/// unscannable. So it is always black on white, on a white card, whatever the
/// app looks like around it.
class ThemeQr extends StatelessWidget {
  const ThemeQr({super.key, required this.palette, this.size = 220});

  final AppPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: QrImageView(
            data: ThemeCode.link(palette),
            size: size,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
            // The margin is the quiet zone every scanner needs to find the
            // symbol at all.
            padding: const EdgeInsets.all(8),
            // Error correction buys back readability on a scuffed screen at an
            // angle, which is how these are actually scanned. The codes are
            // short enough that the extra density costs nothing legible.
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Point another phone at this. Foss Lift will ask before changing '
          'anything.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}
