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

/// The most recent finished session of a routine, or null if never trained.
final lastSessionProvider =
    StreamProvider.family<Session?, int>((ref, routineId) {
  return ref.watch(databaseProvider).watchLastSessionForRoutine(routineId);
});

/// The workout a routine suggests next — the one after whatever was trained
/// most recently, wrapping around. Null while loading or if there are none.
final nextWorkoutIdProvider = Provider.family<int?, int>((ref, routineId) {
  final workouts = ref.watch(routineWorkoutsProvider(routineId)).value;
  if (workouts == null) return null;
  final last = ref.watch(lastSessionProvider(routineId)).value;
  return nextWorkoutId(
    workouts.map((w) => w.workout.id).toList(),
    last?.workoutId,
  );
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

/// The routine the Today tab is about, as stored. May point at a routine that
/// has since been deleted — prefer [currentRoutineProvider], which resolves it.
final activeRoutineIdProvider = StreamProvider<int?>((ref) {
  return ref.watch(databaseProvider).watchActiveRoutineId();
});

/// The current routine, or null if none is chosen (or the chosen one is gone).
final currentRoutineProvider = Provider<RoutineWithCount?>((ref) {
  final id = ref.watch(activeRoutineIdProvider).value;
  final routines = ref.watch(routinesProvider).value;
  if (id == null || routines == null) return null;
  for (final r in routines) {
    if (r.routine.id == id) return r;
  }
  return null;
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
