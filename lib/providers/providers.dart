import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../data/database.dart';
import '../data/routine_code.dart';
import '../data/routine_import.dart';
import '../services/reminders.dart';
import '../services/workout_shade.dart';
import '../state/active_workout.dart';
import '../state/workout_cue.dart';
import '../theme/app_theme.dart';
import 'db_provider.dart';

export 'db_provider.dart' show databaseProvider;
// The rest clock lives on the session controller, so the two providers it needs
// live beside it — see the note on db_provider.dart for why that shape exists.
export '../state/active_workout.dart' show restSoundProvider, restToneProvider;

/// All routines with their workout counts (Today + Routines tabs).
final routinesProvider = StreamProvider<List<RoutineWithCount>>((ref) {
  return ref.watch(databaseProvider).watchRoutines();
});

/// The workouts (training days) inside one routine, with exercise counts.
final routineWorkoutsProvider =
    StreamProvider.family<List<WorkoutWithCount>, int>((ref, routineId) {
  return ref.watch(databaseProvider).watchWorkoutsForRoutine(routineId);
});

/// One routine gathered into the shape it travels in — see `routine_code.dart`.
///
/// Watches the routine's workouts as well as reading it, so the code on the
/// share screen re-gathers if the programme is edited underneath it rather than
/// handing someone a QR of a routine that no longer exists.
final sharedRoutineProvider =
    FutureProvider.family<SharedRoutine, int>((ref, routineId) async {
  ref.watch(routineWorkoutsProvider(routineId));
  return ref.watch(databaseProvider).sharedRoutine(routineId);
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

/// One movement's personal note, live.
///
/// A note is a fact about the movement, not session state, so the live workout
/// board watches this instead of reading the copy it hydrated with: a note
/// written from the library halfway through a session belongs on that session's
/// board, and one written *on* the board belongs in the library. It is the one
/// thing the board reads through — everything else about a session is a
/// deliberate snapshot of the template.
///
/// It rides the library stream that is already in memory, so watching it costs
/// no further query.
final exerciseNoteProvider = Provider.family<String?, int>((ref, id) {
  final library = ref.watch(exerciseLibraryProvider).value;
  if (library == null) return null;
  for (final e in library) {
    if (e.id == id) return e.notes;
  }
  return null;
});

/// Completed sessions, newest first (History tab).
final historyProvider = StreamProvider<List<Session>>((ref) {
  return ref.watch(databaseProvider).watchHistory();
});

/// Every logged set of one exercise across finished sessions, oldest first —
/// the source for its progress chart.
final exerciseHistoryProvider =
    StreamProvider.family<List<ExerciseSetEntry>, int>((ref, exerciseId) {
  return ref.watch(databaseProvider).watchExerciseSetHistory(exerciseId);
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

/// Whether the first-run tutorial has already been shown. False triggers the
/// coach marks once on a genuine first run; see `widgets/tutorial.dart`.
final tutorialSeenProvider = StreamProvider<bool>((ref) {
  return ref.watch(databaseProvider).watchTutorialSeen();
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

/// The live workout in the notification shade.
final workoutShadeProvider = Provider<WorkoutShade>((ref) => WorkoutShade());

/// Keeps the shade in step with the session, and routes its two buttons back.
///
/// A provider rather than a call site for the same reason the reminder sync is
/// one: what changes the shade is scattered — a set logged, a rest ticking, a
/// weight edited, the session ending — and they all move
/// [activeWorkoutProvider]. Watching that once is cheaper than remembering to
/// update the notification in nine places and forgetting in a tenth.
///
/// Watch it somewhere permanent; see `main.dart`.
final workoutShadeSyncProvider = Provider<void>((ref) {
  final shade = ref.watch(workoutShadeProvider);
  final unit = ref.watch(weightUnitProvider).value ?? 'kg';

  // The buttons come back from the service's own isolate, which holds no
  // session — this is where they land, in the isolate that does.
  ref.watch(shadeActionsProvider);

  final session = ref.watch(activeWorkoutProvider);
  if (session == null) {
    shade.hide();
    return;
  }
  final cue = nextUp(session, restLeft: session.restLeft);
  if (cue != null) shade.show(cue, unit: unit);
});

/// Subscribes to the shade's button presses for as long as anything watches.
final shadeActionsProvider = Provider<void>((ref) {
  final shade = ref.watch(workoutShadeProvider);
  if (!shade.supported) return;

  void onData(Object data) {
    final controller = ref.read(activeWorkoutProvider.notifier);
    switch (data) {
      case WorkoutShade.doneAction:
        controller.logNextAtGoal();
      case WorkoutShade.missedAction:
        controller.logNextAsMissed();
    }
  }

  FlutterForegroundTask.initCommunicationPort();
  FlutterForegroundTask.addTaskDataCallback(onData);
  ref.onDispose(() => FlutterForegroundTask.removeTaskDataCallback(onData));
});

/// The user's text-size nudge on top of the phone's own setting. Read as
/// `.value ?? 1.0` — following the phone is the default.
final textScaleProvider = StreamProvider<double>((ref) {
  return ref.watch(databaseProvider).watchTextScale();
});

/// The layoff rules: the gap that earns a back-off and how deep it cuts.
final layoffSettingsProvider = StreamProvider<LayoffSettings>((ref) {
  return ref.watch(databaseProvider).watchLayoffSettings();
});

/// The user's chosen weight unit ('kg' or 'lb').
final weightUnitProvider = StreamProvider<String>((ref) {
  return ref.watch(databaseProvider).watchWeightUnit();
});

/// The stored theme choice: the selected id and the custom palette JSON.
/// Read [activePaletteProvider] unless you need the raw choice (the picker
/// does, to mark which preset is selected).
final themeSettingProvider = StreamProvider<ThemeSetting>((ref) {
  return ref.watch(databaseProvider).watchThemeSetting();
});

/// The phone's own light/dark setting, kept current as it changes.
///
/// It decides only what an untouched install opens as — picking any theme
/// stores that choice, and a stored choice outranks the system. Watched rather
/// than read once so a phone that flips at sunset flips the app with it.
class PlatformBrightness extends Notifier<Brightness>
    with WidgetsBindingObserver {
  @override
  Brightness build() {
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    ref.onDispose(() => binding.removeObserver(this));
    return binding.platformDispatcher.platformBrightness;
  }

  @override
  void didChangePlatformBrightness() {
    state = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }
}

final platformBrightnessProvider =
    NotifierProvider<PlatformBrightness, Brightness>(PlatformBrightness.new);

/// The palette to paint with, resolved against the shipped presets and any
/// custom theme. Synchronous with a sensible default, so the very first frame
/// is painted with the default preset rather than an unthemed flash while the
/// settings row is read.
final activePaletteProvider = Provider<AppPalette>((ref) {
  final setting = ref.watch(themeSettingProvider).value;
  return resolvePalette(
    setting?.presetId,
    setting?.customJson,
    system: ref.watch(platformBrightnessProvider),
  );
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
    kgRack: stored?.kgRack,
    lbRack: stored?.lbRack,
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
