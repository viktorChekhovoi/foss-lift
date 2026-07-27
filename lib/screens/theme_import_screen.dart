import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../theme/theme_code.dart';
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
    final result = ThemeCode.decode(code);
    return Scaffold(
      appBar: AppBar(title: const Text('Shared theme')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: switch (result) {
            ThemeCodeOk(:final palette) => _offer(context, ref, palette),
            ThemeCodeFailure(:final message) => _refuse(context, message),
          },
        ),
      ),
    );
  }

  List<Widget> _offer(BuildContext context, WidgetRef ref, AppPalette palette) {
    return [
      Text(palette.name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(
        'Someone shared this theme with you. Here is what it looks like.',
        style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
      ),
      const SizedBox(height: 18),
      ThemePreview(palette: palette),
      const SizedBox(height: 22),
      FilledButton(
        onPressed: () async {
          // Arrives as *your* custom theme: a shared code carries a palette,
          // not a claim on one of the shipped preset slots.
          await ref
              .read(databaseProvider)
              .setCustomTheme(palette.copyWith(id: kCustomThemeId).toJson());
          if (context.mounted) _leave(context);
        },
        child: const Text('Use this theme'),
      ),
      const SizedBox(height: 10),
      OutlinedButton(
        onPressed: () => _leave(context),
        child: const Text('Cancel'),
      ),
      const SizedBox(height: 14),
      Text(
        'This replaces your custom theme. The preset themes are untouched, so '
        'you can switch back at any time.',
        style: TextStyle(color: AppColors.faint, fontSize: 12, height: 1.5),
      ),
    ];
  }

  List<Widget> _refuse(BuildContext context, String message) {
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
        child: const Text('Back'),
      ),
    ];
  }

  /// Leaves the screen whether we were pushed onto an existing stack (the
  /// in-app paths) or opened cold by a link, where there is nothing to pop back
  /// to and popping would close the app — so that case lands on the theme
  /// screen instead, which is where someone who just imported a theme wants to
  /// be anyway.
  void _leave(BuildContext context) {
    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return;
    }
    GoRouter.maybeOf(context)?.go('/settings/theme');
  }
}
