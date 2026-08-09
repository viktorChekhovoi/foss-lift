import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import '../util/qr_capacity.dart';

/// The chrome every "share this thing" screen is built from.
///
/// Themes and routines share a transport — a QR and a share-sheet code — so
/// they share the buttons, the QR card and the paste dialog too. One copy means
/// the two screens cannot drift into looking like different apps, and the QR
/// advice below only has to be got right once.

/// Something shareable as a QR someone else can point a phone at.
///
/// Holds the full `fosslift://…` link rather than the bare code, so one image
/// serves both routes: a system camera recognises the scheme and offers to open
/// Foss Lift, while our own scanner strips the prefix and imports directly. (The
/// share *sheet* sends the bare code — a chat app would leave a link as
/// unclickable text.)
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

  /// The largest the symbol will be drawn. It is otherwise sized off the
  /// screen: a long payload is a denser grid, and every logical pixel per
  /// module is one the scanning camera does not have to guess at. Capped so it
  /// does not become a billboard on a tablet.
  final double maxSize;

  /// The side of the symbol, in logical pixels.
  ///
  /// Measured from the **screen**, not from the parent's constraints, and then
  /// nailed down with a tight [SizedBox]. Both halves of that matter, and the
  /// blank QR dialog needed both.
  ///
  /// `AlertDialog` sizes its content through `IntrinsicWidth`, and a
  /// `LayoutBuilder` cannot answer an intrinsic-width query — it would have to
  /// run its layout callback speculatively. `QrImageView` *is* a
  /// `LayoutBuilder` inside, whatever size it is handed, so every QR in a
  /// dialog threw during layout and left a barrier dimming the screen over
  /// nothing at all. A `SizedBox` with a tight width and height answers the
  /// intrinsic query out of its own constraints without ever descending into
  /// the child, which is what keeps the question away from the builder.
  ///
  /// Both dimensions are consulted because a dialog is short as well as narrow.
  /// [_chromeAcross] and [_chromeDown] are what surrounds a symbol at its most
  /// cramped. On any real phone the width is what binds, so the generous
  /// vertical allowance costs nothing where it matters and keeps a short screen
  /// from overflowing its own dialog.
  ///
  /// Below 160 a symbol stops being worth pointing a camera at, so it stops
  /// shrinking there rather than degrading into an unreadable one.
  double _sideFor(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return math
        .min(screen.width - _chromeAcross, screen.height - _chromeDown)
        .clamp(160.0, maxSize);
  }

  /// A dialog's own side insets, plus its content padding, plus the white
  /// card's.
  static const _chromeAcross = 96.0;

  /// A dialog's top and bottom insets, its title, its buttons, the white card's
  /// padding and the caption under the symbol — which wraps to three lines at a
  /// large font scale, so this is rounded up rather than measured.
  static const _chromeDown = 320.0;

  @override
  Widget build(BuildContext context) {
    // How much redundancy this payload can afford — medium while it fits, low
    // when only low will hold it. See `util/qr_capacity.dart`.
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

  /// What a payload past every error-correction level gets instead of a symbol
  /// nothing could read.
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

/// A small all-caps section heading, at the app's own heading size and colour.
///
/// Bare text rather than a [SectionLabel]: these sit inside layouts that supply
/// their own spacing, and the widget's padding would double it.
Widget shareSectionLabel(String text) => Text(text, style: sectionLabelStyle());

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
  final pasted = await showAppDialog<String>(
    context,
    keyboard: TextInputType.multiline,
    builder: (_) => _PasteDialog(title: title, hint: hint),
  );
  final text = pasted?.trim() ?? '';
  return text.isEmpty ? null : text;
}

/// The paste dialog, owning its own controller.
///
/// The controller has to belong to a `State` that lives and dies with the
/// dialog, and not to [promptForCode]. `showDialog`'s future completes when the
/// route is *popped*, which is the start of the dismissal and not the end of
/// it: the field is still mounted, still painting and still about to unsubscribe
/// from its controller. Disposing it at the await threw
/// "A TextEditingController was used after being disposed" for the length of
/// the fade — the red frames that looked like an invalid code crashing the app,
/// though it happened just as much on a good one, and on Cancel.
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

/// Leaves a screen that may have been pushed onto a stack (the in-app paths) or
/// opened cold by a link, where there is nothing to pop back to and popping
/// would close the app.
///
/// [fallback] is where the cold case lands — somewhere the user who just
/// imported something would want to be anyway.
///
/// The router is asked before the navigator, and that order matters. A
/// `Navigator.pop` leaves go_router's match list untouched until the page has
/// finished animating out; applying a theme in the meantime re-keys
/// `MaterialApp` at the root, and the fresh `Router` rebuilds its pages from
/// that stale list — putting the screen straight back. `GoRouter.pop` drops the
/// match there and then, so there is nothing left to restore. The navigator is
/// still the path for a screen pumped without a router under it.
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
