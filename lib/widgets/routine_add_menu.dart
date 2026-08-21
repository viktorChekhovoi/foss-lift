import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'share_widgets.dart';

const kRoutinesAddKey = ValueKey('routines-add');

enum RoutineAddChoice { library, build, import }

class AddRoutineButton extends ConsumerWidget {
  const AddRoutineButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      key: kRoutinesAddKey,
      tooltip: l10n.routinesAdd,
      icon: const Icon(Icons.add),
      color: AppColors.accent,
      onPressed: () => addRoutine(context, ref),
    );
  }
}

Future<void> addRoutine(BuildContext context, WidgetRef ref) async {
  final choice = await _sheet<RoutineAddChoice>(
    context,
    (sheet) => [
      for (final c in RoutineAddChoice.values)
        RoutineAddRow(choice: c, onTap: () => Navigator.pop(sheet, c)),
    ],
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case RoutineAddChoice.library:
      await context.push('/routines/library');
    case RoutineAddChoice.build:
      await context.push('/routine/new');
    case RoutineAddChoice.import:
      await _import(context, ref);
  }
}

Future<void> _import(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  if (!ref.read(capabilitiesProvider).scanning) {
    await _paste(context);
    return;
  }
  final scan = await _sheet<bool>(
    context,
    (sheet) => [
      _SheetRow(
        icon: Icons.qr_code_scanner,
        label: l10n.themeScanQr,
        onTap: () => Navigator.pop(sheet, true),
      ),
      _SheetRow(
        icon: Icons.content_paste,
        label: l10n.themePasteCode,
        onTap: () => Navigator.pop(sheet, false),
      ),
    ],
  );
  if (scan == null || !context.mounted) return;
  if (scan) {
    await context.push('/scan?for=routine');
  } else {
    await _paste(context);
  }
}

Future<void> _paste(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final text = await promptForCode(context,
      title: l10n.routinesPasteTitle, hint: l10n.routinesPasteHint);
  if (text == null || !context.mounted) return;
  await context.push('/routine/import?code=${Uri.encodeQueryComponent(text)}');
}

class RoutineAddRow extends StatelessWidget {
  const RoutineAddRow({super.key, required this.choice, this.onTap});

  final RoutineAddChoice choice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, label) = switch (choice) {
      RoutineAddChoice.library => (
          Icons.auto_stories_outlined,
          l10n.routineLibraryTitle
        ),
      RoutineAddChoice.build => (Icons.add, l10n.routinesNewRoutine),
      RoutineAddChoice.import => (Icons.download_outlined, l10n.routinesImport),
    };
    return _SheetRow(icon: icon, label: label, onTap: onTap);
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.accent),
        title: Text(label),
        onTap: onTap,
      );
}

Future<T?> _sheet<T>(
  BuildContext context,
  List<Widget> Function(BuildContext sheet) rows,
) =>
    showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: rows(sheet)),
      ),
    );
