import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../state/active_workout.dart';
import 'db_provider.dart';

export 'db_provider.dart' show databaseProvider;

/// All routine templates with their exercise counts (Today + Routines tabs).
final routinesProvider = StreamProvider<List<RoutineWithCount>>((ref) {
  return ref.watch(databaseProvider).watchRoutines();
});

/// The exercises inside one routine (Routine detail screen).
final routineItemsProvider =
    FutureProvider.family<List<RoutineItemView>, int>((ref, id) {
  return ref.watch(databaseProvider).itemsForRoutine(id);
});

/// Completed sessions, newest first (History tab).
final historyProvider = StreamProvider<List<Workout>>((ref) {
  return ref.watch(databaseProvider).watchHistory();
});

/// Lifetime totals (Profile tab).
final totalsProvider = StreamProvider<({int workouts, double volume})>((ref) {
  return ref.watch(databaseProvider).watchTotals();
});

/// The live session (null when not training).
final activeWorkoutProvider =
    NotifierProvider<ActiveWorkoutController, ActiveWorkout?>(
  ActiveWorkoutController.new,
);

/// A finished session (+ its sets) for the summary screen.
final workoutSummaryProvider = FutureProvider.family<
    ({Workout workout, List<WorkoutSet> sets}), int>((ref, id) async {
  final db = ref.watch(databaseProvider);
  final workout =
      await (db.select(db.workouts)..where((t) => t.id.equals(id))).getSingle();
  final sets = await db.setsForWorkout(id);
  return (workout: workout, sets: sets);
});
