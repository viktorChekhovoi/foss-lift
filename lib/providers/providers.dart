import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../state/active_workout.dart';
import 'db_provider.dart';

export 'db_provider.dart' show databaseProvider;

/// All routines with their workout counts (Today + Routines tabs).
final routinesProvider = StreamProvider<List<RoutineWithCount>>((ref) {
  return ref.watch(databaseProvider).watchRoutines();
});

/// The workouts (training days) inside one routine, with exercise counts.
final routineWorkoutsProvider =
    StreamProvider.family<List<WorkoutWithCount>, int>((ref, routineId) {
  return ref.watch(databaseProvider).watchWorkoutsForRoutine(routineId);
});

/// One workout template, kept live so a rename shows up immediately.
final workoutProvider = StreamProvider.family<Workout?, int>((ref, id) {
  return ref.watch(databaseProvider).watchWorkout(id);
});

/// The exercises inside one workout, kept live so the detail screen and the
/// builder both reflect edits immediately.
final workoutItemsProvider =
    StreamProvider.family<List<WorkoutItemView>, int>((ref, id) {
  return ref.watch(databaseProvider).watchItemsForWorkout(id);
});

/// The whole exercise library (Library screen + routine builder picker).
final exerciseLibraryProvider = StreamProvider<List<Exercise>>((ref) {
  return ref.watch(databaseProvider).watchExercises();
});

/// Completed sessions, newest first (History tab).
final historyProvider = StreamProvider<List<Session>>((ref) {
  return ref.watch(databaseProvider).watchHistory();
});

/// Number of completed sessions (Today + Profile).
final sessionCountProvider = StreamProvider<int>((ref) {
  return ref.watch(databaseProvider).watchSessionCount();
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
final sessionSummaryProvider = FutureProvider.family<
    ({Session session, List<SessionSet> sets}), int>((ref, id) async {
  final db = ref.watch(databaseProvider);
  final session =
      await (db.select(db.sessions)..where((t) => t.id.equals(id))).getSingle();
  final sets = await db.setsForSession(id);
  return (session: session, sets: sets);
});
