// Integration tests for the half of feature 04 that happens while nobody is
// looking at the board: the rest ending audibly with the phone away, the shade's
// buttons, the resume bar keeping its place on the way back to a tab, and a
// session outliving the process it was started in.
//
// Everything is driven through the real public surface — the
// `activeWorkoutProvider` controller, `applyShadeAction`, `shadeButtons`, the
// `AppDatabase`, and the two widgets that mount the resume bar. The notification
// and the tone are recorded rather than played, because a test runner has neither
// an audio route nor a notification channel; what a phone has to be checked for
// by hand is written up in the report, not asserted here.
//
// Timer discipline (see the harness): starting a session hits real SQLite and is
// wrapped in `tester.runAsync`, which makes the session's own 1-second timer a
// *real* one. The rest countdown is created in the test body and so runs on the
// fake clock, which is what `pump(Duration(...))` advances.
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/home_shell.dart';
import 'package:foss_lift/services/notifications.dart';
import 'package:foss_lift/services/rest_alarm.dart';
import 'package:foss_lift/services/rest_tone.dart';
import 'package:foss_lift/services/workout_shade.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/state/workout_cue.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/util/locales.dart';
import 'package:foss_lift/widgets/resume_workout_bar.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

/// Lets the work behind a call land: the alarm is handed over asynchronously,
/// and so is every snapshot write.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

/// The same snapshot as a build that never recorded the order of logging wrote
/// it: every set stripped of its stamp, nothing else touched.
String _withoutLogOrder(String payload) {
  final m = jsonDecode(payload) as Map<String, dynamic>;
  for (final e in m['exercises'] as List) {
    for (final key in ['sets', 'warmups']) {
      for (final s in (e as Map<String, dynamic>)[key] as List) {
        (s as Map<String, dynamic>).remove('loggedOrder');
      }
    }
  }
  return jsonEncode(m);
}

/// Waits out a two-second rest, and the tick that ends it.
Future<void> _restRunsOut() =>
    Future<void>.delayed(const Duration(milliseconds: 2400));

/// The English catalogue: the shade's buttons are named from it, so the
/// assertions read them from the same place rather than re-typing them.
final _l10n = l10nFor();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  ProviderContainer? container;

  setUp(() => db = memoryDb());

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  ActiveWorkout session() => container!.read(activeWorkoutProvider)!;

  /// A live Push session, with the phone [onScreen] or not, and its ding routed
  /// to [alarm] and [tone] instead of to a platform that is not there.
  Future<ActiveWorkoutController> startPush({
    bool onScreen = true,
    RestAlarm? alarm,
    RestTone? tone,
    PendingShadeActions? pending,
  }) async {
    container = containerFor(
      db,
      mirrorSession: true,
      overrides: [
        if (alarm != null) restAlarmProvider.overrideWithValue(alarm),
        if (tone != null) restToneProvider.overrideWithValue(tone),
        if (pending != null)
          pendingShadeActionsProvider.overrideWithValue(pending),
        appOnScreenProvider.overrideWithValue(() => onScreen),
      ],
    );
    final ctl = container!.read(activeWorkoutProvider.notifier);
    await ctl.start(workoutId: await workoutIdNamed(db, 'Push'), name: 'Push');
    return ctl;
  }

  /// The cue the shade would be drawing for the session as it stands.
  WorkoutCue cue() => nextUp(session(), restLeft: session().restLeft)!;

  /// The set entry [at] points at, read out of the session as it stands now — a
  /// warm-up rung and a working set are both sets a press can land on.
  SetEntry entryAt(WorkoutCue at) {
    final e = session().exercises[at.exerciseIndex];
    return at.warmup ? e.warmups[at.setIndex] : e.sets[at.setIndex];
  }

  /// How many sets in the session carry a number, warm-up rungs included. One
  /// press logs one of them.
  int logged() => session().exercises
      .expand((e) => [...e.warmups, ...e.sets])
      .where((s) => s.logged != null)
      .length;

  /// The snapshot on disk, once the write behind the last mutation has landed.
  Future<LiveSession> snapshot() async {
    for (var i = 0; i < 50; i++) {
      final row = await db.loadLiveSession();
      if (row != null) return row;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw StateError('nothing was ever written down');
  }

  /// The session a fresh launch over the same database comes back to — the
  /// isolate that held the old one is gone, exactly as after Android reclaims
  /// the app.
  Future<ActiveWorkout?> relaunch({
    DateTime? savedAt,
    List<Override> overrides = const [],
  }) async {
    if (savedAt != null) {
      // Every queued write has to have landed before the row is aged, or the
      // last of them puts today's timestamp back on it.
      await snapshot();
      await _settle();
      final row = await snapshot();
      await db.saveLiveSession(row.payload, at: savedAt);
    }
    container?.dispose();
    container = containerFor(db, mirrorSession: true, overrides: overrides);
    // The launch path, not `restore()` by hand: what a launch does is the thing
    // under test, and part of it is applying the presses that were made while
    // there was nobody to hear them.
    await container!.read(liveSessionRestoreProvider.future);
    return container!.read(activeWorkoutProvider);
  }

  group('A rest ending is audible with the phone away', () {
    // The user's report: "i still get no notification sound about a rest being
    // done when i'm not in the app", and no sound even with the alarm volume at
    // maximum. The countdown is a timer in this process and Android is free to
    // kill the process the moment the app is backgrounded, so the ding cannot be
    // this isolate's to make. It is handed to Android in advance.
    late _RecordingAlarm alarm;
    late _RecordingTone tone;

    Future<ActiveWorkoutController> pushWithPhone({
      required bool onScreen,
    }) async {
      alarm = _RecordingAlarm();
      tone = _RecordingTone();
      return startPush(onScreen: onScreen, alarm: alarm, tone: tone);
    }

    test('starting a rest with the app away schedules nothing', () async {
      // It used to hand the ding to Android for the instant the rest would end,
      // against the app being killed before then. That needed an alarm
      // permission Play will not grant a workout tracker, and an inexact one
      // lands late — see `no-alarm-privilege-asked-for`. What replaced it is the
      // foreground service keeping this isolate alive to ring for itself.
      final ctl = await pushWithPhone(onScreen: false);

      ctl.startRest(90, null);
      await _settle();

      expect(alarm.rung, isEmpty, reason: 'the rest has not ended yet');
      expect(
        alarm.cleared,
        greaterThan(0),
        reason: 'anything left from the last rest is for a rest that is over',
      );

      ctl.discard();
    });

    test('the app rings at the moment the rest ends', () async {
      // `ding-posted-when-rest-ends`. Nothing was handed over in advance, so
      // this is the only thing that makes a rest audible from a pocket — and it
      // happens because the session's foreground service is still holding this
      // isolate open when its own countdown reaches zero.
      final ctl = await pushWithPhone(onScreen: false);

      // A real two-second rest, run out for real: the point of the test is what
      // happens at the moment the countdown reaches zero.
      ctl.startRest(2, null);
      await _restRunsOut();

      expect(session().restLeft, 0, reason: 'the rest is over');
      expect(
        alarm.rung,
        hasLength(1),
        reason: 'off screen the notification is posted now, not scheduled',
      );
      expect(
        alarm.rung.single,
        contains('Bench Press'),
        reason: '"rest done" makes you open the app to find out what for',
      );
      // `volume-is-a-gain-because-app-plays-it`: the notification is the
      // picture, the player is the noise — including from a pocket, which is
      // the only reason the volume setting means anything.
      expect(tone.played, 1, reason: 'the sound is the tone either way');

      ctl.discard();
    });

    test(
      'with the app on screen the tone plays and nothing is posted',
      () async {
        final ctl = await pushWithPhone(onScreen: true);

        ctl.startRest(2, null);
        await _settle();

        await _restRunsOut();

        expect(tone.played, 1);
        expect(alarm.rung, isEmpty, reason: 'one ding, not two');

        ctl.discard();
      },
    );

    test('skipping a rest by hand from the shade sounds', () async {
      // It used to be silent, on the argument that whoever pressed Skip knows.
      // That left the one button that is only ever pressed from a pocket with no
      // feedback at all.
      final ctl = await pushWithPhone(onScreen: false);
      ctl.startRest(90, null);

      applyShadeAction(ctl, WorkoutShade.restSkipAction);

      expect(session().restLeft, 0);
      expect(alarm.rung, hasLength(1));
      expect(alarm.rung.single, contains('Bench Press'));

      ctl.discard();
    });
  });

  group('The shade drives the rest and the log', () {
    test('a running rest offers Skip, −15s and +15s', () async {
      final ctl = await startPush();
      ctl.startRest(90, null);

      final buttons = shadeButtons(_l10n, cue());

      // Skip leads: Android fills the row from the left and clips it from the
      // right, and Skip is the one a rest is reached for.
      expect(buttons.map((b) => b.text), [
        _l10n.sessionRestSkip,
        _l10n.sessionRestMinus,
        _l10n.sessionRestPlus,
      ]);
      expect(buttons.map((b) => b.id), [
        WorkoutShade.restSkipAction,
        WorkoutShade.restSubAction,
        WorkoutShade.restAddAction,
      ]);

      ctl.discard();
    });

    test('and the two nudges move it by the screen\'s own step', () async {
      final ctl = await startPush();
      ctl.startRest(90, null);

      applyShadeAction(ctl, WorkoutShade.restAddAction);
      expect(session().restLeft, 105);

      applyShadeAction(ctl, WorkoutShade.restSubAction);
      expect(session().restLeft, 90);

      ctl.discard();
    });

    test(
      'Done logs the set at its goal, starts the rest and comes forward',
      () async {
        final ctl = await startPush();
        var opened = 0;
        final at = cue();

        applyShadeAction(ctl, WorkoutShade.doneAction, open: () => opened++);

        expect(entryAt(at).logged, at.reps);
        expect(
          session().restLeft,
          greaterThan(0),
          reason: 'a set was just finished, so the rest is on',
        );
        expect(
          opened,
          1,
          reason: 'the next thing after a logged set is the board',
        );

        ctl.discard();
      },
    );

    test(
      'Missed logs one short, comes forward, and starts the rest too',
      () async {
        final ctl = await startPush();
        var opened = 0;
        final at = cue();

        applyShadeAction(ctl, WorkoutShade.missedAction, open: () => opened++);

        final set = entryAt(at);
        expect(
          set.logged,
          at.reps! - 1,
          reason: 'one short lands gold, not green',
        );
        expect(set.missedGoal, isTrue);
        expect(opened, 1, reason: 'the number is one you are meant to correct');
        expect(
          session().restLeft,
          greaterThan(0),
          reason: 'you just finished a set; correcting a number is not a rest',
        );

        ctl.discard();
      },
    );

    group('a held set', () {
      Future<ActiveWorkoutController> startPlank() async {
        final plank = await exerciseNamed(db, 'Plank');
        final rid = await db.createRoutine(
          name: 'Timed',
          color: 'FF0000',
          restSeconds: 90,
        );
        final wid = await db.createWorkout(rid, 'Plank Day');
        await db.replaceWorkoutItems(wid, [
          WorkoutItemsCompanion.insert(
            workoutId: wid,
            exerciseId: plank.id,
            targetSets: const Value(2),
            holdSeconds: const Value(45),
            progression: Value(ProgressionMode.time),
          ),
        ]);
        container = containerFor(db);
        final ctl = container!.read(activeWorkoutProvider.notifier);
        await ctl.start(workoutId: wid, name: 'Plank Day');
        return ctl;
      }

      test('offers one button, Start', () async {
        final ctl = await startPlank();

        final buttons = shadeButtons(_l10n, cue());

        expect(buttons.map((b) => b.text), [_l10n.shadeStart]);
        expect(buttons.single.id, WorkoutShade.startAction);

        ctl.discard();
      });

      test('and Start opens the app without logging anything', () async {
        final ctl = await startPlank();
        var opened = 0;

        applyShadeAction(ctl, WorkoutShade.startAction, open: () => opened++);

        expect(opened, 1, reason: 'how long you held it is the measurement');
        expect(session().doneSets, 0);
        expect(session().restLeft, 0);

        ctl.discard();
      });
    });
  });

  group('A session survives the process being killed', () {
    test('the sets logged, the weights and the clock all come back', () async {
      final ctl = await startPush();
      ctl.cycleSet(0, 0); // Bench, first set, at its goal
      ctl.cycleSet(0, 1);
      ctl.cycleSet(0, 1); // and the second one rep short
      ctl.setWorkingWeight(1, 47.5);
      final owed = nextUp(session())!;
      await snapshot();

      final back = (await relaunch(
        savedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      ))!;

      expect(back.name, 'Push');
      expect(back.exercises, hasLength(5));
      expect(back.exercises[0].sets[0].logged, 8);
      expect(back.exercises[0].sets[1].logged, 7);
      expect(back.exercises[0].sets[1].missedGoal, isTrue);
      expect(back.doneSets, 2);
      expect(back.exercises[1].workingKg, 47.5);
      expect(
        back.elapsed,
        greaterThanOrEqualTo(180),
        reason: 'a workout that started at nine is an hour old at ten',
      );
      final back0wed = nextUp(back)!;
      expect(
        (back0wed.exerciseIndex, back0wed.setIndex, back0wed.warmup),
        (owed.exerciseIndex, owed.setIndex, owed.warmup),
        reason: 'the set you owe is the one you owed',
      );

      container!.read(activeWorkoutProvider.notifier).discard();
    });

    test('a back-off slot comes back a back-off, not flattened', () async {
      // Push reduced to one bench slot whose sets step down 10% each.
      final ex = await exerciseNamed(db, 'Bench Press');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          targetSets: const Value(3),
          repsMin: const Value(8),
          suggestedWeight: const Value(100),
          scheme: const Value(SetScheme.backOff),
          schemePercent: const Value(10),
          progression: const Value(ProgressionMode.weight),
        ),
      ]);
      await startPush();
      expect(session().exercises.single.sets.map((s) => s.weight).toList(),
          [100.0, 90.0, 80.0]);
      await snapshot();

      final back = (await relaunch())!;
      expect(back.exercises.single.sets.map((s) => s.weight).toList(),
          [100.0, 90.0, 80.0], reason: 'the ladder is not a flat 100');

      final ctl = container!.read(activeWorkoutProvider.notifier);
      ctl.setWorkingWeight(0, 110);
      expect(session().exercises.single.sets.map((s) => s.weight).toList(),
          [110.0, 100.0, 87.5], reason: 'moving the top moves the rungs');

      // And the bar is still the floor under the ladder: every rung of a 20 kg
      // bench sits on the bar rather than under it.
      ctl.setWorkingWeight(0, 20);
      expect(session().exercises.single.sets.map((s) => s.weight).toList(),
          [20.0, 20.0, 20.0]);

      ctl.discard();
    });

    test('and the mark is still on the movement you were working', () async {
      // Logged on the fourth exercise, then went back up to the second. The
      // order those two happened in is what says where you are, and template
      // order disagrees with it — so a snapshot that dropped it would put the
      // mark back on the fourth.
      final ctl = await startPush();
      ctl.cycleSet(3, 0);
      ctl.cycleSet(1, 0);
      expect(nextUp(session())!.exerciseIndex, 1);
      await snapshot();

      final back = (await relaunch())!;
      expect(nextUp(back)!.exerciseIndex, 1);

      container!.read(activeWorkoutProvider.notifier).discard();
    });

    test('a snapshot from a build that never wrote that order still reads',
        () async {
      // What the shipped build left behind: logged sets and no record of the
      // order. Absent is taken as list order — the behaviour that build had —
      // rather than as a session that will not load.
      final ctl = await startPush();
      ctl.cycleSet(3, 0);
      ctl.cycleSet(1, 0);
      await snapshot();
      await _settle();
      await db.saveLiveSession(_withoutLogOrder((await snapshot()).payload));

      final back = (await relaunch())!;
      expect(nextUp(back)!.exerciseIndex, 3,
          reason: 'the last logged in list order, as it was before');

      container!.read(activeWorkoutProvider.notifier).discard();
    });

    test('and so does a rest, minus the time the app was dead', () async {
      final ctl = await startPush();
      ctl.startRest(120, (
        purpose: RestPurpose.anotherSet,
        weightKg: null,
        exercise: null,
        exerciseSeedKey: null,
      ));
      await snapshot();

      final back = (await relaunch(
        savedAt: DateTime.now().subtract(const Duration(seconds: 90)),
      ))!;

      expect(back.restLeft, closeTo(30, 2));
      expect(back.restPrompt?.purpose, RestPurpose.anotherSet);

      container!.read(activeWorkoutProvider.notifier).discard();
    });

    test('and the rest still knows which set it belongs to', () async {
      final ctl = await startPush();
      ctl.cycleSet(0, 1);
      ctl.startRest(120, session().restAfterSet(0, 1),
          forSet: (exercise: 0, set: 1, warmup: false));
      await snapshot();

      final back = (await relaunch())!;
      expect(back.restFor, (exercise: 0, set: 1, warmup: false));

      container!.read(activeWorkoutProvider.notifier).discard();
    });

    test('a rest that ran out while the app was dead is simply over', () async {
      final ctl = await startPush();
      ctl.startRest(30, null);
      await snapshot();

      final back = (await relaunch(
        savedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ))!;

      expect(back.restLeft, 0);
      expect(back.restPrompt, isNull);

      container!.read(activeWorkoutProvider.notifier).discard();
    });

    test('finishing leaves nothing to come back to', () async {
      final ctl = await startPush();
      ctl.cycleSet(0, 0);
      await snapshot();

      await ctl.finish();

      expect(await relaunch(), isNull);
      expect(await db.loadLiveSession(), isNull);
    });

    test('and neither does throwing the session away', () async {
      final ctl = await startPush();
      ctl.cycleSet(0, 0);
      await snapshot();

      await ctl.discard();
      // The delete is queued behind the write it follows.
      await _settle();

      expect(await relaunch(), isNull);
    });

    test('a snapshot that cannot be read is dropped, not crashed on', () async {
      await db.saveLiveSession('{not json at all');

      expect(await relaunch(), isNull);
      await _settle();
      expect(
        await db.loadLiveSession(),
        isNull,
        reason: 'it would only fail again on the next launch',
      );
    });
  });

  group('A press waits for the app rather than being lost with it', () {
    // Every button on the shade is applied by the isolate that holds the
    // session, and Android is free to kill that isolate with the workout in a
    // pocket. The press used to be announced down a port and nothing else: with
    // nobody listening it went nowhere, so Missed raised the app and logged
    // nothing.

    /// The record a press is written into. A cell in this test, SharedPreferences
    /// on a phone — the point is that it outlives the isolate either way.
    String? written;
    PendingShadeActions record() => PendingShadeActions(
      read: () async => written,
      write: (value) async => written = value,
    );

    setUp(() => written = null);

    test('a press made with nothing listening lands on the way back', () async {
      final pending = record();
      await startPush(pending: pending);
      final at = cue();
      await snapshot();

      // The service's own isolate, writing the press down. The app's isolate is
      // then gone before it could hear anything about it.
      await pending.add(WorkoutShade.missedAction);

      final back = (await relaunch(
        overrides: [pendingShadeActionsProvider.overrideWithValue(pending)],
      ))!;

      final set = entryAt(at);
      expect(
        set.logged,
        at.reps! - 1,
        reason: 'the press was made; the app being dead is not an answer',
      );
      expect(set.missedGoal, isTrue);
      expect(
        back.restLeft,
        greaterThan(0),
        reason: 'a set was logged, so its rest is on',
      );

      container!.read(activeWorkoutProvider.notifier).discard();
    });

    test('and it is applied once, not once per launch', () async {
      final pending = record();
      await startPush(pending: pending);
      final at = cue();
      await snapshot();

      await pending.add(WorkoutShade.doneAction);

      await relaunch(
        overrides: [pendingShadeActionsProvider.overrideWithValue(pending)],
      );
      await relaunch(
        overrides: [pendingShadeActionsProvider.overrideWithValue(pending)],
      );

      expect(entryAt(at).logged, at.reps);
      expect(
        logged(),
        1,
        reason: 'claiming the record is what taking it means',
      );

      container!.read(activeWorkoutProvider.notifier).discard();
    });

    test('several presses are applied in the order they were made', () async {
      // The rest nudges are the ones pressed twice in a row: they do not raise
      // the app, so nothing interrupts a second press.
      final pending = record();
      final ctl = await startPush(pending: pending);
      ctl.startRest(90, null);
      await snapshot();

      await pending.add(WorkoutShade.restAddAction);
      await pending.add(WorkoutShade.restAddAction);
      await pending.add(WorkoutShade.restSubAction);

      await drainShadeActions(ctl, pending);

      expect(session().restLeft, 105, reason: '90 + 15 + 15 − 15');

      ctl.discard();
    });

    test('a press outlives no session it was not made in', () async {
      // Finishing takes the record with it. Otherwise a Missed pressed as the
      // last set went in would land on tomorrow's first set instead.
      final pending = record();
      final ctl = await startPush(pending: pending);
      await snapshot();

      await pending.add(WorkoutShade.missedAction);
      await ctl.finish();
      await _settle();

      expect(
        written,
        anyOf(isNull, ''),
        reason: 'the session it belonged to is history now',
      );

      final next = await startPush(pending: pending);
      await drainShadeActions(next, pending);

      expect(logged(), 0, reason: 'yesterday\'s press, today\'s board');

      next.discard();
    });
  });

  group('The resume bar stays above the navigation bar', () {
    // The user's report: going to Settings and coming back left the bar
    // *underneath* the four tabs. Two mount points draw the bar — the shell's,
    // above the navigation bar, and the app's last row everywhere else — and the
    // hand-off back to the shell is what was missed, because a pop is the one
    // navigation the route-information provider does not announce.

    /// The app as it really is: the tab shell under the overlay, plus a screen
    /// outside the shell to push and come back from.
    Future<GoRouter> pumpShell(WidgetTester tester) async {
      await tester.runAsync(() async {
        container = containerFor(db);
        await container!
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: await workoutIdNamed(db, 'Push'), name: 'Push');
      });
      final router = GoRouter(
        initialLocation: '/today',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => HomeShell(shell: shell),
            branches: [
              for (final p in const [
                '/today',
                '/routines',
                '/history',
                '/profile',
              ])
                StatefulShellBranch(
                  routes: [GoRoute(path: p, builder: (_, _) => const _Tab())],
                ),
            ],
          ),
          GoRoute(path: '/settings', builder: (_, _) => const _Pushed()),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container!,
          child: MaterialApp.router(
            theme: AppTheme.build(kDefaultPalette),
            supportedLocales: kSupportedLocales,
            localizationsDelegates: kTestDelegates,
            routerConfig: router,
            builder: (context, child) =>
                ResumeWorkoutOverlay(router: router, child: child!),
          ),
        ),
      );
      await frames(tester);
      return router;
    }

    /// Fails unless there is exactly one bar and the navigation bar is below it.
    void expectBarAboveTheTabs(WidgetTester tester, String when) {
      expect(find.byKey(resumeWorkoutBarKey), findsOneWidget, reason: when);
      final bar = tester.getRect(find.byKey(resumeWorkoutBarKey));
      final nav = tester.getRect(find.byType(NavigationBar));
      expect(bar.bottom, lessThanOrEqualTo(nav.top + 0.5), reason: when);
    }

    testWidgets('on a tab root, and again after coming back from a push', (
      tester,
    ) async {
      final router = await pumpShell(tester);
      expectBarAboveTheTabs(tester, 'at rest on a tab root');

      router.push('/settings');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byKey(resumeWorkoutBarKey),
        findsOneWidget,
        reason: 'the pushed screen ends above the bar, not under it',
      );
      expect(
        find.byType(NavigationBar),
        findsNothing,
        reason: 'a pushed screen has no tabs, so the bar is the last row',
      );
      expect(
        tester.getRect(find.byKey(resumeWorkoutBarKey)).bottom,
        closeTo(tester.getSize(find.byType(MaterialApp)).height, 1.0),
        reason: 'the overlay owns it here — nothing is underneath it',
      );

      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expectBarAboveTheTabs(tester, 'back on the tab root the shell owns it');

      container!.read(activeWorkoutProvider.notifier).discard();
      await stop(tester);
    });

    testWidgets('and switching tabs does not lose it either', (tester) async {
      final router = await pumpShell(tester);

      router.go('/profile');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expectBarAboveTheTabs(tester, 'on another tab');

      container!.read(activeWorkoutProvider.notifier).discard();
      await stop(tester);
    });
  });
}

/// A tab screen with something scrollable on it, so the bar has room to be in
/// the wrong place.
class _Tab extends StatelessWidget {
  const _Tab();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      children: [for (var i = 0; i < 30; i++) ListTile(title: Text('row $i'))],
    ),
  );
}

/// A screen outside the shell, of the shape everything pushed over a tab has:
/// its own scaffold, and no navigation bar.
class _Pushed extends StatelessWidget {
  const _Pushed();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('pushed')));
}

/// A [RestTone] that counts rather than playing. Built over [_NoPlayer], so
/// constructing it cannot reach the audio plugin a test runner does not have.
class _RecordingTone extends RestTone {
  _RecordingTone() : super(player: _NoPlayer());

  int played = 0;

  @override
  Future<void> play() async => played++;
}

/// A [RestAlarm] that records rather than posting.
class _RecordingAlarm extends RestAlarm {
  _RecordingAlarm() : super(platformSupported: true);

  final List<String> rung = [];
  int cleared = 0;

  @override
  Future<void> ring({
    required NotificationChannelCopy channel,
    required String title,
    required String body,
  }) async =>
      rung.add(body);

  @override
  Future<void> clear() async => cleared++;
}

/// An [AudioPlayer] that would throw if the tone ever reached it.
class _NoPlayer implements AudioPlayer {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('the tone reached the player');
}
