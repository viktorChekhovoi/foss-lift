import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../state/active_workout.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../util/seed_names.dart';

Future<void> startWorkout(
  BuildContext context,
  WidgetRef ref,
  int workoutId,
  String name, {
  String? seedKey,
}) async {
  final l10n = AppLocalizations.of(context);
  final shown = seededName(l10n, seedKey, name);
  final live = ref.read(activeWorkoutProvider);
  if (live != null) {
    if (live.workoutId == workoutId) {
      context.push('/session');
      return;
    }
    final swap = await showDialog<bool>(
      context: context,
      builder: (_) => _SwitchDialog(live: live, starting: shown),
    );
    if (swap != true || !context.mounted) return;
    ref.read(activeWorkoutProvider.notifier).discard();
  }

  final db = ref.read(databaseProvider);
  final items = await db.itemsForWorkout(workoutId);

  LayoffNotice? notice;
  final byExercise = <int, List<WorkoutItemView>>{};
  for (final view in items) {
    (byExercise[view.item.exerciseId] ??= []).add(view);
  }
  for (final slots in byExercise.values) {
    final view = slots.first;
    final item = view.item;
    final normalProgression = slots.any((slot) =>
        !slot.item.progression.timed &&
        !slot.item.runsCycle &&
        slot.item.gzclTier == null &&
        slot.item.targetRpe == null);
    final layoff = await db.layoffFor(
      workoutId,
      exerciseId: normalProgression ? item.exerciseId : null,
    );
    if (!context.mounted) return;
    if (layoff == null) continue;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => _LayoffDialog(
        layoff: layoff,
        exerciseName:
            seededName(l10n, view.exercise.seedKey, view.exercise.name),
      ),
    );
    if (accepted == true) {
      final moved = await db.applyLayoffDeload(
        workoutId,
        layoff.percent,
        exerciseId: item.exerciseId,
      );
      if (moved > 0) {
        notice = (percent: layoff.percent, days: layoff.gapDays);
      }
    }
  }

  await ref
      .read(activeWorkoutProvider.notifier)
      .start(workoutId: workoutId, name: name, notice: notice);
  if (context.mounted) context.push('/session');
}

class _SwitchDialog extends StatelessWidget {
  const _SwitchDialog({required this.live, required this.starting});
  final ActiveWorkout live;
  final String starting;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final running = seededName(l10n, live.seedKey, live.name);
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(l10n.startWorkoutSwitchTitle(starting)),
      content: Text(
        l10n.startWorkoutSwitchBody(
            running, live.doneSets, live.totalSets, fmtDuration(live.elapsed)),
        style: TextStyle(color: AppColors.muted, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.startWorkoutKeepRunning(running)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.gold),
          child: Text(l10n.startWorkoutDiscardRunning(running)),
        ),
      ],
    );
  }
}

class _LayoffDialog extends StatelessWidget {
  const _LayoffDialog({required this.layoff, required this.exerciseName});
  final LayoffDeload layoff;
  final String exerciseName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(l10n.startWorkoutLayoffTitle),
      content: Text(
        l10n.startWorkoutLayoffBody(
            exerciseName, layoff.gapDays, layoff.percent),
        style: TextStyle(color: AppColors.muted, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.startWorkoutKeepWeights),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.startWorkoutDeload(layoff.percent)),
        ),
      ],
    );
  }
}
