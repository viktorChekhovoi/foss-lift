import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/warmup.dart';
import '../data/workout_estimate.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';

/// How long one training day will take, ready to draw.
///
/// The figure is derived — see `data/workout_estimate.dart` — so it needs the
/// day's slots and the routine's default rest, and it follows an edit to either.
/// [builder] is handed the finished string ("~45 min"); the widget renders
/// **nothing at all** when there is no estimate to give, so an empty day and a
/// day whose template has not arrived yet both show no figure rather than a
/// zero.
///
/// A builder rather than a fixed presentation because the two places it appears
/// dress it differently: a pill on the training day, a suffix on the Today card.
class WorkoutEstimate extends ConsumerWidget {
  const WorkoutEstimate({
    super.key,
    required this.workoutId,
    required this.builder,
  });

  final int workoutId;
  final Widget Function(BuildContext context, String label) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(workoutItemsProvider(workoutId)).value;
    final workout = ref.watch(workoutProvider(workoutId)).value;
    final routineId = workout?.routineId;
    final routines = ref.watch(routinesProvider).value;
    if (items == null || items.isEmpty || routineId == null ||
        routines == null) {
      return const SizedBox.shrink();
    }
    // The routine only for its default rest. A dangling id resolves to nothing
    // here for the same reason it does on Today: better no figure than one
    // built on a rest time nobody set.
    final routine = routines
        .where((r) => r.routine.id == routineId)
        .map((r) => r.routine)
        .firstOrNull;
    if (routine == null) return const SizedBox.shrink();

    final minutes = estimateMinutes(
      estimateWorkoutDuration(
        items: [for (final v in items) v.item],
        routineRestSeconds: routine.restSeconds,
        // The same count a session would open every ramp with, so the figure on
        // the card is the day the lifter will actually train — which is none on
        // a day that has switched its ramps off, exactly as [start] resolves it.
        warmupSets: workout!.warmupsEnabled
            ? ref.watch(defaultWarmupSetsProvider).value ?? kDefaultWarmupSets
            : 0,
      ),
    );
    if (minutes <= 0) return const SizedBox.shrink();
    return builder(context, AppLocalizations.of(context)
        .commonEstimatedMinutes(minutes));
  }
}
