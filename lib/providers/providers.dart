import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../data/database.dart';
import '../data/routine_code.dart';
import '../data/routine_import.dart';
import '../l10n/app_localizations.dart';
import '../services/reminders.dart';
import '../services/set_video_store.dart';
import '../services/set_video_thumbnails.dart';
import '../services/workout_shade.dart';
import '../state/active_workout.dart';
import '../state/workout_cue.dart';
import '../theme/app_theme.dart';
import '../util/capabilities.dart';
import '../util/locales.dart';
import '../util/seed_names.dart';
import '../util/units.dart';
import 'db_provider.dart';

export 'db_provider.dart' show databaseProvider;
// The rest clock lives on the session controller, so the two providers it needs
// live beside it — see the note on db_provider.dart for why that shape exists.
export '../state/active_workout.dart' show restToneProvider;
// The live session's crash snapshot, for the same reason: it is the session's
// own, and the controller above is what drives it.
export '../state/session_mirror.dart';
export '../services/set_video_store.dart';
export '../services/set_video_thumbnails.dart';

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
/// share screen re-gathers if the program is edited underneath it rather than
/// handing someone a QR of a routine that no longer exists.
final sharedRoutineProvider = FutureProvider.family<SharedRoutine, int>((
  ref,
  routineId,
) async {
  ref.watch(routineWorkoutsProvider(routineId));
  return ref.watch(databaseProvider).sharedRoutine(routineId);
});

/// The most recent finished session of a routine, or null if never trained.
final lastSessionProvider = StreamProvider.family<Session?, int>((
  ref,
  routineId,
) {
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
final workoutItemsProvider = StreamProvider.family<List<WorkoutItemView>, int>((
  ref,
  id,
) {
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

/// What this build can do — see `util/capabilities.dart`.
///
/// A provider rather than a bare constant so a test can mount a screen as the
/// browser build would draw it without being in a browser.
final capabilitiesProvider =
    Provider<Capabilities>((ref) => currentCapabilities);

/// When each routine's next reminder is due, and when it was last trained.
final routineRemindersProvider = StreamProvider<List<RoutineReminder>>((ref) {
  return ref.watch(databaseProvider).watchRoutineReminders();
});

/// The one notification scheduler.
final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(),
);

/// Keeps the pending notifications in step with the routines and the history.
///
/// A provider rather than a call site, because the things that invalidate a
/// reminder are scattered: editing a schedule, finishing a session, deleting a
/// routine. All of them move [routineRemindersProvider], and re-laying every
/// reminder from that one signal is cheaper than remembering to do it in three
/// places and forgetting in a fourth. Watch it once, high up — see `main.dart`.
///
/// The language is one of those things: a switch has to re-lay every pending
/// reminder, or the next training day is announced in the language the phone
/// was in when the schedule was last edited.
final reminderSyncProvider = Provider<void>((ref) {
  final reminders = ref.watch(routineRemindersProvider).value;
  if (reminders == null) return;
  final l10n = ref.watch(appLocalizationsProvider);
  ref.watch(reminderServiceProvider).sync(
        [
          for (final r in reminders)
            (
              reminder: r,
              title: seededName(l10n, r.seedKey, r.name),
              body: l10n.reminderBody,
            ),
        ],
        channel: (
          name: l10n.reminderChannelName,
          description: l10n.reminderChannelDescription,
        ),
      );
});

/// The live workout in the notification shade.
final workoutShadeProvider = Provider<WorkoutShade>((ref) => WorkoutShade());

/// How the shade's set buttons raise the live board once the press has reached
/// this isolate.
///
/// Overridden in `main.dart`, which is where the router is; the default does
/// nothing, so nothing in the provider layer has to know a router exists and a
/// screen pumped on its own in a test is never navigated out from under.
final openSessionProvider = Provider<void Function()>((ref) => () {});

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
  final cue =
      session == null ? null : nextUp(session, restLeft: session.restLeft);
  // The one place that pushes state into the shade, so the one place that has
  // to know what language it is in — the service takes finished text.
  final copy = cue == null
      ? null
      : shadeCopy(ref.watch(appLocalizationsProvider), cue, unit);
  if (copy == null) {
    shade.hide();
    return;
  }
  shade.show(copy);
});

/// Raising the board, as the shade's set buttons ask for.
///
/// The service's isolate can raise the *app* but cannot steer it: the route it
/// passes is an intent extra only a cold start reads. So the screen is chosen on
/// this side — and only when the board is not already the thing on screen, or a
/// press would stack a second copy of it.
final shadeOpenProvider = Provider<void Function()>(
  (ref) => () {
    if (!ref.read(workoutScreenVisibleProvider)) {
      ref.read(openSessionProvider)();
    }
  },
);

/// Subscribes to the shade's button presses for as long as anything watches.
final shadeActionsProvider = Provider<void>((ref) {
  final shade = ref.watch(workoutShadeProvider);
  if (!shade.supported) return;

  void onData(Object data) {
    // The press itself is in the record; this is only the news that there is one
    // — see [PendingShadeActions]. A bare id is the fallback for a press the
    // record would not take, and is applied here and now.
    if (data == WorkoutShade.drainPoke) {
      drainShadeActions(
        ref.read(activeWorkoutProvider.notifier),
        ref.read(pendingShadeActionsProvider),
        open: ref.read(shadeOpenProvider),
      );
      return;
    }
    applyShadeAction(
      ref.read(activeWorkoutProvider.notifier),
      data,
      open: ref.read(shadeOpenProvider),
    );
  }

  FlutterForegroundTask.initCommunicationPort();
  FlutterForegroundTask.addTaskDataCallback(onData);
  ref.onDispose(() => FlutterForegroundTask.removeTaskDataCallback(onData));
});

/// Applies every press waiting in [pending], oldest first.
///
/// Called from the two places a session can be ready for one: the poke that
/// follows a press made with the app alive, and the end of a launch, for the
/// press made when it was not — see [liveSessionRestoreProvider]. Taking the
/// record is what claims it, so calling this twice over is safe and the second
/// call does nothing.
Future<void> drainShadeActions(
  ActiveWorkoutController controller,
  PendingShadeActions pending, {
  void Function()? open,
}) async {
  for (final id in await pending.take()) {
    applyShadeAction(controller, id, open: open);
  }
}

/// One notification button press, applied to the live session.
///
/// A function rather than a closure inside [shadeActionsProvider] so it can be
/// tested: what arrives from the service's isolate is a bare string, and which
/// string does what is the part worth pinning down. Anything unrecognised is
/// ignored — a press from a notification the system kept across an upgrade is
/// not a reason to do something arbitrary to a workout.
///
/// [open] raises the board, and is called by the presses that log a set — see
/// [WorkoutShade.bringsAppForward]. It is a callback rather than a navigation
/// here so this stays testable without a router.
void applyShadeAction(
  ActiveWorkoutController controller,
  Object data, {
  void Function()? open,
}) {
  switch (data) {
    case WorkoutShade.doneAction:
      controller.logNextAtGoal();
      open?.call();
    case WorkoutShade.missedAction:
      controller.logNextAsMissed();
      open?.call();
    // A hold logs nothing from a pocket: how long you held it is the whole
    // measurement, so the button's only job is to put the stopwatch in front of
    // you.
    case WorkoutShade.startAction:
      open?.call();
    case WorkoutShade.restAddAction:
      controller.nudgeRest(WorkoutShade.restStepSeconds);
    case WorkoutShade.restSubAction:
      controller.nudgeRest(-WorkoutShade.restStepSeconds);
    case WorkoutShade.restSkipAction:
      controller.stopRest();
  }
}

/// The user's text-size nudge on top of the phone's own setting. Read as
/// `.value ?? 1.0` — following the phone is the default.
final textScaleProvider = StreamProvider<double>((ref) {
  return ref.watch(databaseProvider).watchTextScale();
});

/// The language the app renders in, as a stored tag (`uk`, `pt_BR`).
///
/// **The phone is consulted once, not for ever.** An install that has not
/// chosen yet emits null exactly once; that null is answered by resolving the
/// phone's preference list against the catalogues we ship and writing the
/// answer to `Settings.localeTag`. So there is no "follow the phone" state to
/// be in — the picker always has one of the five selected, and changing the
/// phone's language afterwards leaves the app where the user left it.
final localeTagProvider = StreamProvider<String?>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchLocaleTag().asyncMap((tag) async {
    if (tag != null) return tag;
    final resolved = localeTag(resolveLocale(
      null,
      WidgetsBinding.instance.platformDispatcher.locales,
    ));
    await db.setLocaleTag(resolved);
    return resolved;
  });
});

/// The language to render in.
///
/// Synchronous, and deliberately: the app root needs a locale for the very
/// first frame, and the stored choice has not arrived yet. Until it does — and
/// on the first launch, until the write above lands — this is the phone's own
/// answer, which is what first run is about to store anyway. See
/// [localeReadyProvider] for the gate that keeps that guess off the screen.
final activeLocaleProvider = Provider<Locale>((ref) {
  return resolveLocale(
    ref.watch(localeTagProvider).value,
    WidgetsBinding.instance.platformDispatcher.locales,
  );
});

/// The string catalogue for [activeLocaleProvider].
///
/// **For the parts of the app that render text with no widget tree under
/// them** — the notification shade, the rest alarm, the scheduled reminders.
/// Everywhere there is a `BuildContext`, `AppLocalizations.of(context)` is the
/// answer and this is not.
///
/// Derived rather than remembered, and read at the moment the text is built:
/// switching language rebuilds it in the same pass that rebuilds the screens,
/// so nothing can post yesterday's language.
final appLocalizationsProvider = Provider<AppLocalizations>(
  (ref) => lookupAppLocalizations(ref.watch(activeLocaleProvider)),
);

/// Whether the stored language has arrived. Joined with [themeReadyProvider]
/// at the app root, for the same reason: painting a frame in the wrong
/// language and correcting it is a flicker on every cold launch.
final localeReadyProvider = Provider<bool>((ref) {
  return ref.watch(localeTagProvider).hasValue;
});

/// The layoff rules: the gap that earns a back-off and how deep it cuts.
final layoffSettingsProvider = StreamProvider<LayoffSettings>((ref) {
  return ref.watch(databaseProvider).watchLayoffSettings();
});

/// The user's chosen weight unit ('kg' or 'lb'). Kilograms until they say
/// otherwise, including while the first-run question is still on screen.
final weightUnitProvider = StreamProvider<String>((ref) {
  return ref.watch(databaseProvider).watchWeightUnit();
});

/// Whether the unit has been stored yet. The app root holds a blank frame until
/// it is true, so no screen ever opens in kilograms and corrects itself to
/// pounds a frame later.
final unitChosenProvider = StreamProvider<bool>((ref) {
  return ref.watch(databaseProvider).watchUnitChosen();
});

/// Writes the phone's region into the weight unit, once, on a fresh install.
///
/// Watched by the app root and nothing else. The unit is not something a
/// tracker needs to open with a question about: a country weighs a barbell one
/// way, the phone already says which country it is in, and anybody the guess is
/// wrong for is one tap away from Profile → Exercise settings. See
/// [AppDatabase.seedWeightUnit] for why the guess is only ever made once.
final unitSeedProvider = Provider<void>((ref) {
  final unit =
      localeDefaultUnit(WidgetsBinding.instance.platformDispatcher.locales);
  unawaited(ref.watch(databaseProvider).seedWeightUnit(unit));
});

/// The selected theme's stored id — a preset slug, `custom:<n>`, or null for
/// "nothing chosen". Read [activePaletteProvider] unless you need the raw
/// choice (the picker does, to mark which row is selected).
final themePresetIdProvider = StreamProvider<String?>((ref) {
  return ref.watch(databaseProvider).watchThemePresetId();
});

/// The user's own themes, in the order they were built or imported, already
/// parsed and stamped with the ids that name them.
///
/// A row whose JSON will not parse is dropped rather than listed as a palette
/// of default colours: there is nothing useful to show for it and nothing the
/// user could do about it if there were.
final customThemesProvider = StreamProvider<List<AppPalette>>((ref) {
  return ref
      .watch(databaseProvider)
      .watchCustomThemes()
      .map(
        (rows) => [
          for (final row in rows) ?customThemeFromRow(row.id, row.palette),
        ],
      );
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
  return resolvePalette(
    ref.watch(themePresetIdProvider).value,
    ref.watch(customThemesProvider).value ?? const [],
    system: ref.watch(platformBrightnessProvider),
  );
});

/// Whether the stored theme has arrived yet. The app root holds a bare frame
/// until it has — see the note on the first paint in `main.dart`. Both halves
/// have to be in: the selected id says *which* theme, the list says what it
/// looks like, and painting on one without the other is the same flicker.
final themeReadyProvider = Provider<bool>((ref) {
  return ref.watch(themePresetIdProvider).hasValue &&
      ref.watch(customThemesProvider).hasValue;
});

/// The bars the gym racks, for the unit in use — the list every bar picker
/// offers. See the `Bars` table for why there is one list per unit.
final barsProvider = StreamProvider<List<Bar>>((ref) {
  final unit = ref.watch(weightUnitProvider).value ?? 'kg';
  return ref.watch(databaseProvider).watchBars(unit);
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

/// Rebuilds the live session the last run left behind — see
/// `ActiveWorkoutController.restore`. Watched once, high up, so a process
/// Android killed mid-workout comes back to the workout. Nothing reads its value.
/// The launch: the session Android killed the process out from under, and then
/// any press that was made on the shade while there was nobody to receive it.
///
/// In that order, and both here rather than in `main.dart`, because the order is
/// the point — a press applied before the session is back has nothing to apply
/// itself to, and would be dropped for the second time.
final liveSessionRestoreProvider = FutureProvider<void>((ref) async {
  await ref.read(activeWorkoutProvider.notifier).restore();
  await drainShadeActions(
    ref.read(activeWorkoutProvider.notifier),
    ref.read(pendingShadeActionsProvider),
    open: ref.read(shadeOpenProvider),
  );
});

/// A finished session (+ its sets) for the summary screen.
final sessionSummaryProvider =
    FutureProvider.family<({Session session, List<SessionSet> sets}), int>((
      ref,
      id,
    ) async {
      final db = ref.watch(databaseProvider);
      final session = await (db.select(
        db.sessions,
      )..where((t) => t.id.equals(id))).getSingle();
      final sets = await db.setsForSession(id);
      return (session: session, sets: sets);
    });

// ---------------------------------------------------------------------------
// Set clips
// ---------------------------------------------------------------------------

/// How a clip is filmed: the height, and the hard stop on its length.
final videoSettingProvider = StreamProvider<VideoSetting>((ref) {
  return ref.watch(databaseProvider).watchVideoSetting();
});

/// Every clip path a set points at, kept current.
final videoPathsProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(databaseProvider).watchVideoPaths();
});

/// Bytes held by clips on disk.
///
/// Recomputed whenever the set of referenced paths changes, so deleting a clip
/// moves the number without a reload. It measures the *folder*, not the rows —
/// a stranded file is space the user has lost, and a storage screen that did
/// not count it would be lying about the thing it exists to report.
final videoUsageProvider = FutureProvider<int>((ref) async {
  ref.watch(videoPathsProvider);
  return ref.watch(setVideoStoreProvider).bytesUsed();
});

/// Sweeps clip files that nothing points at, once per launch.
///
/// A provider rather than a call in `main()` so it runs inside the same scope
/// as the database it has to ask, and so a test can await it. Watched high up —
/// see `main.dart`. Files younger than [kOrphanGrace] are left alone, which is
/// what keeps it from deleting the set somebody is filming right now.
final orphanSweepProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  return ref
      .watch(setVideoStoreProvider)
      .sweepOrphans(await db.allVideoPaths());
});

/// The frame a reel row shows, or null when there is not going to be one.
///
/// The work behind it is memoised per clip in [SetVideoThumbnails], so a row
/// rebuilding — or the screen being opened again — costs a map lookup rather
/// than a decode.
final clipStillProvider = FutureProvider.family<File?, String>(
    (ref, clipRelative) =>
        ref.watch(setVideoThumbnailsProvider).stillFor(clipRelative));

/// Every clip of one exercise, newest first — the film reel for that movement.
final exerciseClipsProvider =
    StreamProvider.family<List<ExerciseSetEntry>, int>((ref, exerciseId) {
      return ref.watch(databaseProvider).watchExerciseClips(exerciseId);
    });
