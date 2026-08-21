import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/warmup.dart';
import '../data/workout_estimate.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';

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
    final routine = routines
        .where((r) => r.routine.id == routineId)
        .map((r) => r.routine)
        .firstOrNull;
    if (routine == null) return const SizedBox.shrink();

    final minutes = estimateMinutes(
      estimateWorkoutDuration(
        items: [for (final v in items) v.item],
        routineRestSeconds: routine.restSeconds,
        warmupSets: workout!.warmupsEnabled
            ? ref.watch(defaultWarmupSetsProvider).value ?? kDefaultWarmupSets
            : 0,
        exerciseWarmupSets: {
          for (final v in items) v.exercise.id: ?v.exercise.warmupSets,
        },
      ),
    );
    if (minutes <= 0) return const SizedBox.shrink();
    return builder(context, AppLocalizations.of(context)
        .commonEstimatedMinutes(minutes));
  }
}
