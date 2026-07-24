import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/plate_line.dart';

/// One training day: the exercises it contains, and the button that starts it.
class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});
  final int workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(workoutProvider(workoutId)).value;
    final items = ref.watch(workoutItemsProvider(workoutId));
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final plates = ref.watch(plateSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(workout?.name ?? 'Workout'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/workout/$workoutId/edit'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: items.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (e, _) => Center(
                  child:
                      Text('$e', style: TextStyle(color: AppColors.muted)),
                ),
                data: (list) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    _CountChip(count: list.length),
                    const SizedBox(height: 14),
                    if (list.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No exercises yet. Tap the edit icon to add some.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.line),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            for (var i = 0; i < list.length; i++)
                              _ExerciseRow(
                                index: i + 1,
                                view: list[i],
                                unit: unit,
                                plates: plates,
                                last: i == list.length - 1,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _StartBar(
              enabled: (items.value ?? const []).isNotEmpty,
              onStart: () => _start(context, ref, workoutId,
                  workout?.name ?? 'Workout'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Starts the session, offering a back-off first if the workout has been left
/// alone long enough to earn one.
///
/// The offer comes *before* the session is hydrated, so accepting it moves the
/// template and the first set row is drawn at the new weight — there is no
/// moment where the screen shows one number and the programme holds another.
/// Declining is not remembered anywhere: training today resets the gap on its
/// own, so the question cannot come back to nag.
Future<void> _start(
  BuildContext context,
  WidgetRef ref,
  int workoutId,
  String name,
) async {
  final db = ref.read(databaseProvider);
  final layoff = await db.layoffFor(workoutId);

  String? notice;
  if (layoff != null && context.mounted) {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => _LayoffDialog(layoff: layoff, workoutName: name),
    );
    if (accepted == true) {
      final moved = await db.applyLayoffDeload(workoutId, layoff.percent);
      // Nothing moved means nothing here had a target to cut. Announcing a
      // deload that did not happen is worse than saying nothing.
      if (moved > 0) {
        notice = 'Targets cut ${layoff.percent}% — '
            '${layoff.gapDays} days since you last trained this.';
      }
    }
  }

  await ref
      .read(activeWorkoutProvider.notifier)
      .start(workoutId: workoutId, name: name, notice: notice);
  if (context.mounted) context.push('/session');
}

/// The one place the user is asked about a layoff: what it noticed, what it
/// proposes, and the option to say no.
class _LayoffDialog extends StatelessWidget {
  const _LayoffDialog({required this.layoff, required this.workoutName});
  final LayoffDeload layoff;
  final String workoutName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Been a while'),
      content: Text(
        'You last trained $workoutName ${layoff.gapDays} days ago. Coming back '
        'at the same load is how people get hurt.\n\n'
        'Foss Lift can drop every target in this workout by ${layoff.percent}% '
        'to ease you back in. Your logged history is not touched.',
        style: TextStyle(color: AppColors.muted, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep weights'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Deload ${layoff.percent}%'),
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.line),
        ),
        child: Text.rich(
          TextSpan(
            style: kMono.copyWith(fontSize: 12, color: AppColors.muted),
            children: [
              TextSpan(
                text: '$count',
                style: TextStyle(
                    color: AppColors.text, fontWeight: FontWeight.w600),
              ),
              TextSpan(text: count == 1 ? ' exercise' : ' exercises'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.index,
    required this.view,
    required this.unit,
    required this.plates,
    required this.last,
  });
  final int index;
  final WorkoutItemView view;
  final String unit;
  final PlateSettings plates;
  final bool last;

  /// "31.25/side" beside the muscle group, so a barbell day can be read as the
  /// bars it will be. The full breakdown waits for the session — this screen is
  /// a glance at the day, not a loading chart.
  String? get _perSide {
    final w = view.item.suggestedWeight;
    if (w == null || w <= 0) return null;
    return perSideLabel(
      weightKg: w,
      type: view.exercise.weightType,
      settings: plates,
      unit: unit,
      barKg: view.exercise.barWeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final perSide = _perSide;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text('$index',
                textAlign: TextAlign.center,
                style: kMono.copyWith(fontSize: 13, color: AppColors.faint)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(view.exercise.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  perSide == null
                      ? view.exercise.muscleGroup
                      : '${view.exercise.muscleGroup} · $perSide',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            '${view.item.targetSets} × ${repsLabel(view.item)}',
            style: kMono.copyWith(
              fontSize: 13,
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartBar extends StatelessWidget {
  const _StartBar({required this.onStart, required this.enabled});
  final VoidCallback onStart;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: enabled ? onStart : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start workout'),
        ),
      ),
    );
  }
}
