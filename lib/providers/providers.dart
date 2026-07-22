import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../state/active_workout.dart';
import 'db_provider.dart';

export 'db_provider.dart' show databaseProvider;

/// All routine templates with their exercise counts (Today + Routines tabs).
final routinesProvider = StreamProvider<List<RoutineWithCount>>((ref) {
  return ref.watch(databaseProvider).watchRoutines();
});

/// The exercises inside one routine, kept live so the detail screen and the
/// builder both reflect edits immediately.
final routineItemsProvider =
    StreamProvider.family<List<RoutineItemView>, int>((ref, id) {
  return ref.watch(databaseProvider).watchItemsForRoutine(id);
});

/// The whole exercise library (Library screen + routine builder picker).
final exerciseLibraryProvider = StreamProvider<List<Exercise>>((ref) {
  return ref.watch(databaseProvider).watchExercises();
});

/// Completed sessions, newest first (History tab).
final historyProvider = StreamProvider<List<Workout>>((ref) {
  return ref.watch(databaseProvider).watchHistory();
});

/// Number of completed workouts (Today + Profile).
final workoutCountProvider = StreamProvider<int>((ref) {
  return ref.watch(databaseProvider).watchWorkoutCount();
});

/// The user's chosen weight unit ('kg' or 'lb').
final weightUnitProvider = StreamProvider<String>((ref) {
  return ref.watch(databaseProvider).watchWeightUnit();
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
