import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../theme/theme_code.dart';
import '../widgets/share_widgets.dart';
import '../widgets/theme_preview.dart';

/// Confirms a theme that arrived from outside the app before applying it.
///
/// Every inbound path lands here — a scanned QR, a tapped `fosslift://` link, a
/// pasted code — so the rule holds everywhere it needs to: **a theme is
/// previewed and accepted, never applied on arrival.** A code from a stranger's
/// screen is untrusted input, and silently repainting someone's app because
/// they pointed a camera at something would be a poor trade for saving one tap.
///
/// A code that will not read is a dead end by design: there is no button to
/// apply something we could not fully decode.
class ThemeImportScreen extends ConsumerWidget {
  const ThemeImportScreen({super.key, required this.code});

  /// The raw scanned/pasted/linked text. Decoding happens here rather than at
  /// the call sites so every entry point reports failures identically.
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final result = ThemeCode.decode(code, unnamed: l10n.shareThemeFallbackName);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.themeSharedTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: switch (result) {
            ThemeCodeOk(:final palette) => _offer(context, ref, l10n, palette),
            ThemeCodeFailure(:final problem) =>
              _refuse(context, l10n, problem.themeMessage(l10n)),
          },
        ),
      ),
    );
  }

  List<Widget> _offer(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, AppPalette palette) {
    return [
      Text(palette.name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(
        l10n.themeSharedWithYou,
        style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
      ),
      const SizedBox(height: 18),
      ThemePreview(palette: palette),
      const SizedBox(height: 22),
      FilledButton(
        onPressed: () async {
          // Joins *your* themes rather than replacing one: a code carries a
          // palette, not a claim on a slot. Importing four leaves you holding
          // four, and a theme you built is never overwritten by post.
          //
          // Not the AAA badge either. The claim means "designed and checked
          // against WCAG", which is a fact about the two shipped presets, not
          // about a palette whose colours you can edit freely afterwards.
          // Building your own from a high-contrast preset drops it for the
          // same reason; arriving with one is the same situation by post.
          final db = ref.read(databaseProvider);
          final json = palette.copyWith(accessible: false).toJson();
          // Leaving happens *before* the write is awaited, and that ordering is
          // the whole fix. Applying a theme repaints the app: the root re-keys
          // `MaterialApp` on a palette change, which unmounts this screen's
          // element mid-await, so waiting for the write left this holding a dead
          // `BuildContext` and dismissing nothing — the freshly rebuilt import
          // screen sat back on top of the stack with only Back out of it.
          _leave(context);
          await db.addCustomTheme(json);
        },
        child: Text(l10n.themeUseThis),
      ),
      const SizedBox(height: 10),
      OutlinedButton(
        onPressed: () => _leave(context),
        child: Text(l10n.commonCancel),
      ),
    ];
  }

  List<Widget> _refuse(
      BuildContext context, AppLocalizations l10n, String message) {
    return [
      const SizedBox(height: 24),
      Icon(Icons.error_outline, size: 40, color: AppColors.muted),
      const SizedBox(height: 14),
      Text(message,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.text, fontSize: 15, height: 1.5)),
      const SizedBox(height: 24),
      OutlinedButton(
        onPressed: () => _leave(context),
        child: Text(l10n.commonBack),
      ),
    ];
  }

  /// Leaves the screen. Opened cold by a link there is nothing to pop back to,
  /// so that case lands on the theme screen — where someone who just imported a
  /// theme wants to be anyway.
  void _leave(BuildContext context) => leaveShareScreen(
      context, () => GoRouter.maybeOf(context)?.go('/settings/appearance'));
}
