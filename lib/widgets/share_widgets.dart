import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import '../util/qr_capacity.dart';


class ShareQr extends StatelessWidget {
  const ShareQr({
    super.key,
    required this.data,
    required this.caption,
    this.maxSize = 340,
  });

  final String data;

  final String caption;

  final double maxSize;

  double _sideFor(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return math
        .min(screen.width - _chromeAcross, screen.height - _chromeDown)
        .clamp(160.0, maxSize);
  }

  static const _chromeAcross = 96.0;

  static const _chromeDown = 320.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ecc = qrEccFor(data.length);
    if (ecc == null) return _tooBig(l10n);
    final side = _sideFor(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            width: side,
            height: side,
            child: QrImageView(
              data: data,
              size: side,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
              padding: const EdgeInsets.all(8),
              errorCorrectionLevel: switch (ecc) {
                QrEcc.medium => QrErrorCorrectLevel.M,
                QrEcc.low => QrErrorCorrectLevel.L,
              },
              errorStateBuilder: (_, _) => _tooBig(l10n),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }

  Widget _tooBig(AppLocalizations l10n) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(
          l10n.shareQrTooBig,
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
        ),
      );
}

Widget shareSectionLabel(String text) => Text(text, style: sectionLabelStyle());

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

Future<String?> promptForCode(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final pasted = await showAppDialog<String>(
    context,
    keyboard: TextInputType.multiline,
    builder: (_) => _PasteDialog(title: title, hint: hint),
  );
  final text = pasted?.trim() ?? '';
  return text.isEmpty ? null : text;
}

class _PasteDialog extends StatefulWidget {
  const _PasteDialog({required this.title, required this.hint});
  final String title;
  final String hint;

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: widget.title,
      content: TextField(
        controller: _controller,
        maxLines: 4,
        autofocus: true,
        style: kMono.copyWith(fontSize: 12, color: AppColors.text),
        decoration: InputDecoration(
          hintText: widget.hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.shareContinue),
        ),
      ],
    );
  }
}

void leaveShareScreen(BuildContext context, void Function() fallback) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (router.canPop()) {
      router.pop();
    } else {
      fallback();
    }
    return;
  }
  final navigator = Navigator.maybeOf(context);
  if (navigator != null && navigator.canPop()) {
    navigator.pop();
    return;
  }
  fallback();
}
