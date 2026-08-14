import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../data/superset.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/seed_names.dart';
import '../util/target_label.dart';
import '../widgets/plate_line.dart';
import '../widgets/start_workout.dart';
import '../widgets/workout_estimate.dart';

/// One training day: the exercises it contains, and the button that starts it.
class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});
  final int workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workout = ref.watch(workoutProvider(workoutId)).value;
    final items = ref.watch(workoutItemsProvider(workoutId));
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final plates = ref.watch(plateSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(workout == null
            ? l10n.workoutDetailTitle
            : seededName(l10n, workout.seedKey, workout.name)),
        actions: [
          IconButton(
            tooltip: l10n.commonEdit,
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(
                          value: '${list.length}',
                          label: l10n.workoutDetailExerciseCount(list.length),
                        ),
                        WorkoutEstimate(
                          workoutId: workoutId,
                          builder: (_, label) => _Pill(label: label),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          l10n.workoutDetailEmpty,
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
                            for (final group in supersetGroups(normaliseJoins([
                              for (final v in list) v.item.supersetWithPrevious,
                            ])))
                              // A group of one is an ordinary exercise and says
                              // nothing about itself; a real group is tagged
                              // once, above the rows it holds.
                              for (final i in group) ...[
                                if (group.length > 1 && i == group.first)
                                  _SupersetTag(),
                                _ExerciseRow(
                                  index: i + 1,
                                  view: list[i],
                                  unit: unit,
                                  plates: plates,
                                  grouped: group.length > 1,
                                  last: i == list.length - 1,
                                ),
                              ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _StartBar(
              enabled: workout != null && (items.value ?? const []).isNotEmpty,
              // The *stored* name, not the one in the app bar: it is written to
              // history as the session's name, and history holds English plus a
              // key so a logged session follows the language like everything
              // else. The key rides along so the dialogs on the way in can
              // still say the day's name in the language on screen.
              onStart: () => startWorkout(context, ref, workoutId,
                  workout!.name, seedKey: workout.seedKey),
            ),
          ],
        ),
      ),
    );
  }
}

/// One small rounded fact about the day — how many exercises, how long it will
/// take. [value] is the number picked out from the [label] beside it; a pill
/// that is all label leaves it out.
class _Pill extends StatelessWidget {
  const _Pill({this.value, required this.label});
  final String? value;
  final String label;
  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return Container(
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
            if (value != null)
              TextSpan(
                text: '$value ',
                style: TextStyle(
                    color: AppColors.text, fontWeight: FontWeight.w600),
              ),
            TextSpan(text: label),
          ],
        ),
      ),
    );
  }
}

/// Says that the rows under it are trained back to back. One line, above the
/// group — the rows themselves keep their own targets, because a group is a way
/// of performing exercises rather than an exercise of its own.
class _SupersetTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context).commonSuperset,
            style: kMono.copyWith(
              fontSize: 10,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ],
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
    this.grouped = false,
  });
  final int index;
  final WorkoutItemView view;
  final String unit;
  final PlateSettings plates;
  final bool last;

  /// Whether this row belongs to a superset, which draws the accent down its
  /// left edge so the group reads as a block.
  final bool grouped;

  /// "31.25/side" beside the muscle group, so a barbell day can be read as the
  /// bars it will be. The full breakdown waits for the session — this screen is
  /// a glance at the day, not a loading chart.
  String? _perSide(AppLocalizations l10n) {
    final w = view.item.suggestedWeight;
    if (w == null || w <= 0) return null;
    return perSideLabel(
      l10n: l10n,
      weightKg: w,
      type: view.exercise.weightType,
      settings: plates,
      unit: unit,
      barKg: view.exercise.barWeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final perSide = _perSide(l10n);
    final muscle = muscleGroupLabel(l10n, view.exercise.muscleGroup);
    return Container(
      padding: EdgeInsets.fromLTRB(grouped ? 10 : 0, 14, 0, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: last
              ? BorderSide.none
              : BorderSide(color: AppColors.line),
          left: grouped
              ? BorderSide(color: AppColors.accent.withValues(alpha: 0.5))
              : BorderSide.none,
        ),
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
                Text(
                    seededName(
                        l10n, view.exercise.seedKey, view.exercise.name),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  perSide == null ? muscle : '$muscle · $perSide',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                // Which week of its cycle the next session of this slot is, on
                // the day that offers it — the same line the live board shows,
                // and for the same reason.
                if (view.item.runsCycle)
                  Text(
                    l10n.sessionCycleWeek(
                        view.item.cycleWeekNumber, view.item.cycleWeeks.length),
                    style: kMono.copyWith(fontSize: 11, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          Text(
            // A cycle's week is written out a set at a time, so it is listed
            // rather than multiplied — see [rowsTargetLabel].
            view.item.runsCycle
                ? rowsTargetLabel(l10n, view.item.cycleRows)
                : setsTargetLabel(
                    l10n,
                    sets: view.item.targetSets,
                    progression: view.item.progression,
                    toFailure: view.item.toFailure,
                    holdSeconds: view.item.holdSeconds,
                    // What the next session will actually ask for: a slot
                    // climbing its range is aiming at one number, not at the
                    // whole range.
                    repsMin: view.item.goalReps,
                    repsMax: view.item.climbsRange ? null : view.item.repsMax,
                  ),
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
          label: Text(AppLocalizations.of(context).workoutDetailStart),
        ),
      ),
    );
  }
}
