import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../theme/theme_code.dart';
import '../widgets/share_widgets.dart';
import '../widgets/theme_preview.dart';

class ThemeImportScreen extends ConsumerWidget {
  const ThemeImportScreen({super.key, required this.code});

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
          final db = ref.read(databaseProvider);
          // Imported colors are user-controlled and have not been audited.
          final json = palette.copyWith(accessible: false).toJson();
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

  void _leave(BuildContext context) => leaveShareScreen(
      context, () => GoRouter.maybeOf(context)?.go('/settings/appearance'));
}
