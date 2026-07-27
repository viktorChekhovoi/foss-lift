import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_theme.dart';
import '../util/qr_capacity.dart';

/// The chrome every "share this thing" screen is built from.
///
/// Themes and routines share a transport — a QR and a link — so they share the
/// buttons, the QR card and the paste dialog too. One copy means the two
/// screens cannot drift into looking like different apps, and the QR advice
/// below only has to be got right once.

/// Something shareable as a QR someone else can point a phone at.
///
/// Holds the full `fosslift://…` link rather than the bare code, so one image
/// serves both routes: a system camera recognises the scheme and offers to open
/// Foss Lift, while our own scanner strips the prefix and imports directly.
///
/// Deliberately **not** painted in the current theme. A QR code is read by a
/// machine looking for dark modules on a light field with a quiet margin around
/// them; rendering it in a dark theme's colours would make it pretty and
/// unscannable. So it is always black on white, on a white card, whatever the
/// app looks like around it.
class ShareQr extends StatelessWidget {
  const ShareQr({
    super.key,
    required this.data,
    required this.caption,
    this.maxSize = 340,
  });

  /// The link the symbol carries.
  final String data;

  /// One line under the symbol saying what to do with it.
  final String caption;

  /// The largest the symbol will be drawn. It otherwise takes whatever width it
  /// is given: a long payload is a denser grid, and every logical pixel per
  /// module is one the scanning camera does not have to guess at. Capped so it
  /// does not become a billboard on a tablet.
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    // How much redundancy this payload can afford — medium while it fits, low
    // when only low will hold it. See `util/qr_capacity.dart`.
    final ecc = qrEccFor(data.length);
    if (ecc == null) return _tooBig();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 24 is the white card's padding; the symbol gets the rest.
        final available = constraints.hasBoundedWidth
            ? constraints.maxWidth - 24
            : maxSize;
        final size = available.clamp(160.0, maxSize);

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
                data: data,
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
                errorCorrectionLevel: switch (ecc) {
                  QrEcc.medium => QrErrorCorrectLevel.M,
                  QrEcc.low => QrErrorCorrectLevel.L,
                },
                // The capacity check above should make this unreachable; it is
                // here because a QR library refusing to encode must show the
                // honest card, never throw into a build.
                errorStateBuilder: (_, _) => _tooBig(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              caption,
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
            ),
          ],
        );
      },
    );
  }

  /// What a payload past every error-correction level gets instead of a symbol
  /// nothing could read.
  Widget _tooBig() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(
          'Too big for a QR code. Send it as a link instead — same thing, '
          'no camera needed.',
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
        ),
      );
}

/// A small all-caps section heading, matching the theme picker's group labels.
Widget shareSectionLabel(String text) => Text(text,
    style: kMono.copyWith(
        fontSize: 11, letterSpacing: 1.2, color: AppColors.faint));

/// A row of equal-width outlined actions. Two per row keeps the labels legible
/// at large font scales, where a four-across row would truncate. A null
/// callback disables that action — used when a payload is too big for a QR.
Widget shareActionRow(List<(IconData, String, VoidCallback?)> actions) => Row(
      children: [
        for (final (i, action) in actions.indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: action.$3,
              icon: Icon(action.$1, size: 18),
              label: Text(action.$2, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ],
    );

/// Prompts for a pasted code or link and returns the trimmed text, or null if
/// the dialog was dismissed or left empty.
Future<String?> promptForCode(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final controller = TextEditingController();
  final pasted = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title),
      content: TextField(
        controller: controller,
        maxLines: 4,
        autofocus: true,
        style: kMono.copyWith(fontSize: 12, color: AppColors.text),
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  controller.dispose();
  final text = pasted?.trim() ?? '';
  return text.isEmpty ? null : text;
}

/// Leaves a screen that may have been pushed onto a stack (the in-app paths) or
/// opened cold by a link, where there is nothing to pop back to and popping
/// would close the app.
///
/// [fallback] is where the cold case lands — somewhere the user who just
/// imported something would want to be anyway.
void leaveShareScreen(BuildContext context, void Function() fallback) {
  final navigator = Navigator.maybeOf(context);
  if (navigator != null && navigator.canPop()) {
    navigator.pop();
    return;
  }
  fallback();
}
