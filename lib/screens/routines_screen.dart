import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/routine_card.dart';

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
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text(
              'A routine is a programme — "Push / Pull / Legs" — and it holds '
              'the workouts you actually train. Tap a circle to choose which '
              'routine the Today tab shows.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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
