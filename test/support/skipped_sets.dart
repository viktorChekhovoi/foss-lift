// Fixtures shared by the skipped-set progression and timed-deload regressions.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';

import 'seeded.dart';

const normalProgressions = [
  (name: 'Weight', mode: ProgressionMode.weight, weightAndReps: false),
  (name: 'Reps', mode: ProgressionMode.reps, weightAndReps: false),
  (name: 'Weight + Reps', mode: ProgressionMode.weight, weightAndReps: true),
];

typedef SkippedSetWorkout = ({
  Workout workout,
  WorkoutItem squat,
  WorkoutItem bench,
});

/// Three sets each of squats and bench, with an independently configured bench.
Future<SkippedSetWorkout> skippedSetWorkout(
  AppDatabase db, {
  ProgressionMode mode = ProgressionMode.weight,
  bool weightAndReps = false,
  int successes = 0,
  int failures = 0,
  int? repsTarget = 7,
}) async {
  final squat = await exerciseNamed(db, 'Back Squat');
  final bench = await exerciseNamed(db, 'Bench Press');
  final workout = await workoutNamed(db, 'Push');
  await db.replaceWorkoutItems(workout.id, [
    WorkoutItemsCompanion.insert(
      workoutId: workout.id,
      exerciseId: squat.id,
      targetSets: const Value(3),
      repsMin: const Value(5),
      suggestedWeight: const Value(100),
    ),
    WorkoutItemsCompanion.insert(
      workoutId: workout.id,
      exerciseId: bench.id,
      position: const Value(1),
      targetSets: const Value(3),
      repsMin: const Value(6),
      repsMax: const Value(8),
      suggestedWeight: const Value(80),
      progression: Value(mode),
      addWeightAtTopOfRange: Value(weightAndReps),
      repsTarget: Value(weightAndReps ? repsTarget : null),
      increment: Value(mode == ProgressionMode.reps ? 1 : 2.5),
      deload: Value(mode == ProgressionMode.reps ? 2 : 5),
      repsIncrement: const Value(1),
      repsDeload: const Value(2),
      successThreshold: const Value(2),
      failureThreshold: const Value(2),
      successStreak: Value(successes),
      failStreak: Value(failures),
    ),
  ]);
  final items = await db.itemsForWorkout(workout.id);
  return (workout: workout, squat: items[0].item, bench: items[1].item);
}

/// Finishes through the real controller; null means the set was never logged.
Future<int> finishSkippedSetWorkout(
  ProviderContainer container,
  SkippedSetWorkout fixture, {
  List<int?> benchReps = const [null, null, null],
  bool trainSquat = false,
  double? benchWeight,
}) async {
  final ctrl = container.read(activeWorkoutProvider.notifier);
  await ctrl.start(workoutId: fixture.workout.id, name: fixture.workout.name);
  if (benchWeight != null) ctrl.setWorkingWeight(1, benchWeight);
  if (trainSquat) {
    final squat = container.read(activeWorkoutProvider)!.exercises[0];
    for (var si = 0; si < squat.sets.length; si++) {
      ctrl.setLogged(0, si, squat.sets[si].goal);
    }
  }
  for (var si = 0; si < benchReps.length; si++) {
    final reps = benchReps[si];
    if (reps != null) ctrl.setLogged(1, si, reps);
  }
  return (await ctrl.finish())!;
}
