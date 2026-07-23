import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../services/reminders.dart';
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

/// Everything ever lifted: volume (kg), reps and sets (Today's Lifetime card).
final lifetimeTotalsProvider = StreamProvider<LifetimeTotals>((ref) {
  return ref.watch(databaseProvider).watchLifetimeTotals();
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

/// When each routine's next reminder is due, and when it was last trained.
final routineRemindersProvider =
    StreamProvider<List<RoutineReminder>>((ref) {
  return ref.watch(databaseProvider).watchRoutineReminders();
});

/// The one notification scheduler.
final reminderServiceProvider =
    Provider<ReminderService>((ref) => ReminderService());

/// Keeps the pending notifications in step with the routines and the history.
///
/// A provider rather than a call site, because the things that invalidate a
/// reminder are scattered: editing a schedule, finishing a session, deleting a
/// routine. All of them move [routineRemindersProvider], and re-laying every
/// reminder from that one signal is cheaper than remembering to do it in three
/// places and forgetting in a fourth. Watch it once, high up — see `main.dart`.
final reminderSyncProvider = Provider<void>((ref) {
  final reminders = ref.watch(routineRemindersProvider).value;
  if (reminders != null) ref.watch(reminderServiceProvider).sync(reminders);
});

/// The layoff rules: the gap that earns a back-off and how deep it cuts.
final layoffSettingsProvider = StreamProvider<LayoffSettings>((ref) {
  return ref.watch(databaseProvider).watchLayoffSettings();
});

/// The user's chosen weight unit ('kg' or 'lb').
final weightUnitProvider = StreamProvider<String>((ref) {
  return ref.watch(databaseProvider).watchWeightUnit();
});

/// The bar and plate rack as stored — read [plateSettingsProvider] instead
/// unless you specifically need to know whether the user has configured them.
final storedPlateSetupProvider = StreamProvider<StoredPlateSetup>((ref) {
  return ref.watch(databaseProvider).watchPlateSetup();
});

/// The bar and the plates to work with, resolved against the chosen unit.
///
/// Synchronous rather than a stream: every screen that draws a plate breakdown
/// wants an answer on the first frame, and "the standard rack" is a correct
/// answer to give while the settings row is still being read.
final plateSettingsProvider = Provider<PlateSettings>((ref) {
  final unit = ref.watch(weightUnitProvider).value ?? 'kg';
  final stored = ref.watch(storedPlateSetupProvider).value;
  return resolvePlateSettings(
    unit: unit,
    inventory: stored?.inventory,
    barKg: stored?.barKg,
  );
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
