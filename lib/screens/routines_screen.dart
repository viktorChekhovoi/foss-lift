import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/routine_card.dart';
import '../widgets/share_widgets.dart';

class RoutinesScreen extends ConsumerWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final routines = ref.watch(routinesProvider);
    final currentId = ref.watch(currentRoutineProvider)?.routine.id;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ScreenHeader(
              eyebrow: l10n.routinesEyebrow, title: l10n.routinesTitle),
          const SizedBox(height: 4),
          routines.when(
            loading: () => Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text('$e', style: TextStyle(color: AppColors.muted)),
            ),
            data: (list) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (final r in list) ...[
                    RoutineCard(
                      data: r,
                      isCurrent: r.routine.id == currentId,
                      onSetCurrent: () => ref
                          .read(databaseProvider)
                          .setActiveRoutineId(r.routine.id),
                      onTap: () => context.push(
                          '${branchRoot(context)}/routine/${r.routine.id}'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 4),
                  _NewRoutineButton(),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: shareSectionLabel(l10n.routinesImportSection),
                  ),
                  const SizedBox(height: 10),
                  shareActionRow([
                    // Scanning needs camera frames one at a time, which a
                    // browser does not offer. Pasting is the way in that never
                    // needed a permission, so it is the only one left there.
                    if (ref.watch(capabilitiesProvider).scanning)
                      (
                        Icons.qr_code_scanner,
                        l10n.themeScanQr,
                        () => context.push('/scan?for=routine')
                      ),
                    (
                      Icons.content_paste,
                      l10n.themePasteCode,
                      () => _pasteRoutine(context)
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Takes a pasted routine code or link to the import screen — the only place a
/// shared routine is ever added.
Future<void> _pasteRoutine(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final text = await promptForCode(context,
      title: l10n.routinesPasteTitle, hint: l10n.routinesPasteHint);
  if (text == null || !context.mounted) return;
  context.push('/routine/import?code=${Uri.encodeQueryComponent(text)}');
}

class _NewRoutineButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: BorderSide(color: AppColors.line),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () => context.push('/routine/new'),
        child: Text(AppLocalizations.of(context).routinesNewRoutine),
      ),
    );
  }
}
