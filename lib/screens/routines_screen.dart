import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/routine_card.dart';
import '../widgets/share_widgets.dart';

class RoutinesScreen extends ConsumerWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routinesProvider);
    final currentId = ref.watch(currentRoutineProvider)?.routine.id;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const ScreenHeader(eyebrow: 'Your programmes', title: 'Routines'),
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
                      onTap: () => context.push('/routine/${r.routine.id}'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 4),
                  _NewRoutineButton(),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: shareSectionLabel('IMPORT A ROUTINE'),
                  ),
                  const SizedBox(height: 10),
                  shareActionRow([
                    (
                      Icons.qr_code_scanner,
                      'Scan QR',
                      () => context.push('/scan?for=routine')
                    ),
                    (
                      Icons.content_paste,
                      'Paste code',
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
  final text = await promptForCode(context,
      title: 'Paste a routine', hint: 'FLR1.… or a fosslift:// link');
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
        child: const Text('+ New routine'),
      ),
    );
  }
}
