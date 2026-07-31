// Integration tests for features/index.html#sec04 — the in-memory live
// workout: starting a day, logging sets by tapping, the rest timer, the warm-up
// ramp, surviving a collapse, and what Finish writes.
//
// The session is driven through its real public surface: the
// `activeWorkoutProvider` controller, the `AppDatabase`, and the `WorkoutScreen`
// widget. Nothing here asserts on generated code or private internals.
//
// Timer discipline (see the harness): starting and finishing hit real SQLite
// and are wrapped in `tester.runAsync`; a live tree is never quiet, so widget
// tests use plain `pump()`s and end with `stop(tester)`. The session's 1-second
// duration timer is a *real* timer (created inside runAsync), so it does not
// advance under a widget test's fake clock — duration ticks are covered by a
// controller test instead. The rest banner's countdown *is* a fake-zone timer,
// so it advances with `pump(Duration(...))`.
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/data/warmup.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/home_shell.dart';
import 'package:foss_lift/screens/library_screen.dart';
import 'package:foss_lift/screens/today_screen.dart';
import 'package:foss_lift/screens/workout_detail_screen.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/services/notifications.dart';
import 'package:foss_lift/services/rest_alarm.dart';
import 'package:foss_lift/services/rest_tone.dart';
import 'package:foss_lift/services/workout_shade.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/state/workout_cue.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/util/text_scale.dart';
import 'package:foss_lift/util/units.dart';
import 'package:foss_lift/widgets/resume_workout_bar.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

import 'support/harness.dart';
import 'support/seeded.dart';
import 'package:foss_lift/util/format.dart';
import 'package:foss_lift/util/locales.dart';

// The seeded PPL Push day, in template order.
const kPushSize = 5; // Bench, Overhead, Incline DB, Lateral, Triceps
const kPushTotalSets = 17; // 4 + 4 + 3 + 3 + 3
const benchGoal = 8; // 6–8 range → top of range
const benchWeight = 80.0;

/// A one-day routine with a single barbell slot at [weightKg]. The warm-up
/// reproduction in issue #35 is a squat at 227.5 kg — a weight no seeded slot
/// uses, and the point of it is the awkward number. Returns the workout id.
Future<int> buildBarbellWorkout(
  AppDatabase db, {
  String exercise = 'Back Squat',
  double weightKg = 227.5,
  int sets = 3,
}) async {
  final ex = await exerciseNamed(db, exercise);
  final rid = await db.createRoutine(
    name: 'Heavy',
    color: 'FF0000',
    restSeconds: 120,
  );
  final wid = await db.createWorkout(rid, 'Squat Day');
  final draft = ItemDraft.forExercise(ex)
    ..sets = sets
    ..repsMin = 5
    ..weightKg = weightKg;
  await db.replaceWorkoutItems(wid, itemCompanions([draft], workoutId: wid));
  return wid;
}

/// A one-day routine with a single timed slot: Plank, [sets] × [holdSeconds].
/// The library's Plank is the only held movement, so it is what a timed session
/// is built from. Returns the workout id.
Future<int> buildPlankWorkout(
  AppDatabase db, {
  int holdSeconds = 45,
  int sets = 2,
}) async {
  final plank = await exerciseNamed(db, 'Plank');
  final rid = await db.createRoutine(
    name: 'Timed',
    color: 'FF0000',
    restSeconds: 90,
  );
  final wid = await db.createWorkout(rid, 'Plank Day');
  final draft = ItemDraft.forExercise(plank)
    ..sets = sets
    ..holdSeconds = holdSeconds;
  await db.replaceWorkoutItems(wid, itemCompanions([draft], workoutId: wid));
  return wid;
}

/// A one-day routine of two movements, the second called [second].
///
/// The first is a single machine set, so logging it finishes that exercise —
/// and the rest that follows is the "between exercises" one, the only caption
/// that names a movement and so the only one with an exercise name's worth of
/// length in it. Returns the workout id.
Future<int> buildTwoExerciseWorkout(
  AppDatabase db, {
  required String second,
  required String routine,
}) async {
  final first = await exerciseNamed(db, 'Triceps Pushdown');
  final secondId = await db.createExercise(
    name: second,
    muscle: 'Back',
    equipment: 'Machine',
  );
  final rid = await db.createRoutine(
    name: routine,
    color: 'FF0000',
    restSeconds: 120,
  );
  final wid = await db.createWorkout(rid, 'Two Day');
  final drafts = [
    ItemDraft.forExercise(first)..sets = 1,
    ItemDraft.forExercise(await db.exerciseById(secondId))..sets = 3,
  ];
  await db.replaceWorkoutItems(wid, itemCompanions(drafts, workoutId: wid));
  return wid;
}

/// What a rest bar measures: the bar itself, its caption and its three
/// controls.
typedef BannerGeometry = ({Rect banner, Rect caption, Map<String, Rect> pills});

void main() {
  late AppDatabase db;
  ProviderContainer? container;

  setUp(() => db = memoryDb());
  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  // The controller under a plain `test` — the periodic timer keeps ticking on
  // the real event loop until the container is disposed in tearDown.
  Future<ActiveWorkoutController> startPush() async {
    container = containerFor(db);
    final wid = await workoutIdNamed(db, 'Push');
    final ctl = container!.read(activeWorkoutProvider.notifier);
    await ctl.start(workoutId: wid, name: 'Push');
    return ctl;
  }

  ActiveWorkout session() => container!.read(activeWorkoutProvider)!;

  // A set row has two tap targets — the reps cell logs the set, the weight cell
  // opens that one set's own weight — so each is found by its own key rather
  // than by being the row's only gesture.
  Finder repsCell(String row) => find.descendant(
        of: find.byKey(ValueKey(row)),
        matching: find.byKey(const ValueKey('set-result')),
      );
  Finder weightCell(String row) => find.descendant(
        of: find.byKey(ValueKey(row)),
        matching: find.byKey(const ValueKey('set-weight')),
      );

  /// Puts the session down, then the tree.
  ///
  /// The rest clock belongs to the session rather than the logging screen now —
  /// that is what lets it keep running with the phone away — so unmounting the
  /// screen no longer stops it, and a test has to end the session itself.
  Future<void> stopAll(WidgetTester tester) async {
    container?.read(activeWorkoutProvider.notifier).discard();
    await stop(tester);
  }

  // Starts the Push day and mounts WorkoutScreen, ready to pump.
  Future<void> pumpPushScreen(WidgetTester tester) async {
    await tester.runAsync(() async {
      final wid = await workoutIdNamed(db, 'Push');
      container = containerFor(db);
      await container!
          .read(activeWorkoutProvider.notifier)
          .start(workoutId: wid, name: 'Push');
    });
    await tester.pumpWidget(appUnder(container!, const WorkoutScreen()));
    await tester.pump();
  }

  group('Start hydrates set rows from the template', () {
    test(
      'every slot becomes an exercise with its planned sets and goals',
      () async {
        await startPush();
        final ex = session().exercises;
        expect(ex.length, kPushSize);

        final bench = ex[0];
        expect(bench.name, 'Bench Press');
        expect(bench.sets.length, 4);
        expect(bench.sets.every((s) => s.goal == benchGoal), isTrue);
        expect(bench.sets.every((s) => s.goalWeight == benchWeight), isTrue);
        expect(bench.sets.every((s) => !s.timed), isTrue);
        // Nothing is logged on the way in.
        expect(bench.sets.every((s) => s.logged == null && !s.done), isTrue);

        // Overhead Press: fixed 8 (no upper bound) @50.
        expect(ex[1].sets.length, 4);
        expect(ex[1].sets.first.goal, 8);
        expect(ex[1].sets.first.goalWeight, 50);
        // Incline DB Press: 10–12 → goal 12, three sets.
        expect(ex[2].sets.length, 3);
        expect(ex[2].sets.first.goal, 12);
        // Triceps Pushdown: 12–15 → goal 15, at the bottom of the list.
        expect(ex.last.name, 'Triceps Pushdown');
        expect(ex.last.sets.first.goal, 15);

        expect(session().totalSets, kPushTotalSets);
        expect(session().doneSets, 0);
      },
    );
  });

  group('Tapping logs a set through its cycle', () {
    test(
      'a working set: untouched → goal → one fewer → … → 0 → untouched',
      () async {
        final ctl = await startPush();
        int? logged() => session().exercises[0].sets[0].logged;

        expect(logged(), isNull);
        ctl.cycleSet(0, 0);
        expect(logged(), benchGoal); // first tap claims the goal
        // Every tap after counts one rep short, down to zero.
        for (var i = 0; i < benchGoal; i++) {
          ctl.cycleSet(0, 0);
        }
        expect(logged(), 0);
        ctl.cycleSet(0, 0); // 0 → untouched, the set never happened
        expect(logged(), isNull);
        expect(session().exercises[0].sets[0].done, isFalse);
      },
    );

    testWidgets('one tap on the row logs at goal and the set counter updates', (
      tester,
    ) async {
      await pumpPushScreen(tester);
      expect(find.text('0/$kPushTotalSets'), findsOneWidget);
      expect(find.text('0:00'), findsOneWidget); // duration stat

      await tester.tap(repsCell('0-0-Bench Press'));
      await tester.pump();

      expect(find.text('1/$kPushTotalSets'), findsOneWidget);
      await stopAll(tester);
    });
  });

  group('Duration and set count track live', () {
    test('the elapsed timer ticks up while the session runs', () async {
      await startPush();
      expect(session().elapsed, 0);
      // Real 1-second timer: wait past one tick and confirm it advanced.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(session().elapsed, greaterThanOrEqualTo(1));
    });

    test('doneSets rises as sets are logged, across exercises', () async {
      final ctl = await startPush();
      ctl.cycleSet(0, 0);
      ctl.cycleSet(0, 1);
      ctl.cycleSet(2, 0); // a different exercise
      expect(session().doneSets, 3);
      ctl.cycleSet(0, 0); // untoggling one back off
      // 8 → 7, still done; counter unchanged.
      expect(session().doneSets, 3);
    });
  });

  group('The rest timer runs with shorter / longer / skip', () {
    testWidgets('logging a set opens the banner; controls adjust and skip it', (
      tester,
    ) async {
      await pumpPushScreen(tester);
      await tester.tap(repsCell('0-0-Bench Press'));
      await tester.pump();

      // The banner opens at the slot's configured rest (routine default 120s).
      expect(find.byKey(kRestBannerKey), findsOneWidget);
      expect(find.text('2:00'), findsOneWidget);

      // It counts down a second at a time (fake-zone timer).
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1:59'), findsOneWidget);

      // Longer: +15s.
      await tester.tap(find.text('+15s'));
      await tester.pump();
      expect(find.text('2:14'), findsOneWidget);

      // Shorter: −15s (the label uses a Unicode minus).
      await tester.tap(find.text('−15s'));
      await tester.pump();
      expect(find.text('1:59'), findsOneWidget);

      // Skip clears it entirely.
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(find.byKey(kRestBannerKey), findsNothing);

      await stopAll(tester);
    });

    testWidgets('−15s ends a rest with less than 15s left, rather than doing '
        'nothing', (tester) async {
      await pumpPushScreen(tester);
      await tester.tap(repsCell('0-0-Bench Press'));
      await tester.pump();

      // Run the 120s rest down to single figures.
      await tester.pump(const Duration(seconds: 112));
      expect(find.text('0:08'), findsOneWidget);

      // Taking 15 off eight would be a negative rest; the only useful reading
      // of the button here is "skip".
      await tester.tap(find.text('−15s'));
      await tester.pump();
      expect(find.byKey(kRestBannerKey), findsNothing);

      await stopAll(tester);
    });
  });

  group('A workout can be abandoned outright', () {
    // Aborting leaves for Today, so this one needs a router over it.
    Future<void> pumpRouted(WidgetTester tester) async {
      await tester.runAsync(() async {
        final wid = await workoutIdNamed(db, 'Push');
        container = containerFor(db);
        await container!
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: wid, name: 'Push');
      });
      await tester
          .pumpWidget(routedAppUnder(container!, const WorkoutScreen()));
      await tester.pump();
    }

    testWidgets('abort asks first, and a refusal keeps the session',
        (tester) async {
      await pumpRouted(tester);

      await tester.tap(find.byTooltip('Abort workout'));
      await frames(tester);
      expect(find.text('Abort this workout?'), findsOneWidget);

      await tester.tap(find.text('Keep going'));
      await frames(tester);
      expect(container!.read(activeWorkoutProvider), isNotNull);
      expect(find.text('0/$kPushTotalSets'), findsOneWidget);

      await stopAll(tester);
    });

    testWidgets('confirming throws the session away without writing it',
        (tester) async {
      await pumpRouted(tester);
      // Log something, so the discarded session is one that had work in it.
      await tester.tap(repsCell('0-0-Bench Press'));
      await tester.pump();
      expect(find.text('1/$kPushTotalSets'), findsOneWidget);

      await tester.tap(find.byTooltip('Abort workout'));
      await frames(tester);
      await tester.tap(find.text('Abort'));
      await frames(tester);

      expect(container!.read(activeWorkoutProvider), isNull);
      final sessions = await tester.runAsync(() => db.watchHistory().first);
      expect(sessions, isEmpty,
          reason: 'an aborted workout is never written to history');

      await stop(tester);
    });
  });

  group('Starting a workout while one is already live', () {
    /// The detail screen for [wid], with a `/session` to land on.
    Future<void> pumpDetail(WidgetTester tester, int wid) async {
      await tester.pumpWidget(routedAppUnder(
        container!,
        WorkoutDetailScreen(workoutId: wid),
        alsoRoutes: const ['session'],
      ));
      await frames(tester);
    }

    /// Starts Push for real and returns the id of the day named [other].
    Future<int> livePushThen(WidgetTester tester, String other) async {
      late int id;
      await tester.runAsync(() async {
        container = containerFor(db);
        id = await workoutIdNamed(db, other);
        await container!.read(activeWorkoutProvider.notifier).start(
              workoutId: await workoutIdNamed(db, 'Push'),
              name: 'Push',
            );
      });
      container!.read(activeWorkoutProvider.notifier).cycleSet(0, 0);
      return id;
    }

    testWidgets('the one already running opens instead of restarting',
        (tester) async {
      final push = await livePushThen(tester, 'Push');
      final startedAt = session().startedAt;

      await pumpDetail(tester, push);
      await tester.tap(find.text('Start workout'));
      await frames(tester);

      expect(find.text('at /session'), findsOneWidget);
      // The same session, not a fresh one wearing its name.
      expect(session().startedAt, startedAt);
      expect(session().doneSets, 1);

      await stopAll(tester);
    });

    testWidgets('a different one asks first, naming what would be lost',
        (tester) async {
      final pull = await livePushThen(tester, 'Pull');
      await pumpDetail(tester, pull);
      await tester.tap(find.text('Start workout'));
      await frames(tester);

      expect(find.text('Switch to Pull?'), findsOneWidget);
      expect(
        find.textContaining('Push is still running — 1 of $kPushTotalSets '
            'sets logged'),
        findsOneWidget,
      );
      // Nothing has happened yet.
      expect(find.text('at /session'), findsNothing);

      await tester.tap(find.text('Keep Push'));
      await frames(tester);

      expect(session().name, 'Push');
      expect(session().doneSets, 1);
      expect(find.text('at /session'), findsNothing);

      await stopAll(tester);
    });

    testWidgets('confirming discards the live session and starts the new one',
        (tester) async {
      final pull = await livePushThen(tester, 'Pull');
      await pumpDetail(tester, pull);
      await tester.tap(find.text('Start workout'));
      await frames(tester);

      // Starting the new day reads the template, so it crosses the real loop.
      await tester.tap(find.text('Discard Push'));
      await pumpThroughDatabase(tester);

      expect(session().name, 'Pull');
      expect(session().workoutId, pull);
      expect(session().doneSets, 0, reason: 'a fresh session logs nothing');
      expect(find.text('at /session'), findsOneWidget);

      // This session's duration timer was created under the fake clock (the
      // start ran inside a pump), so it has to be cancelled before the tree
      // goes or the binding sees a timer outliving it.
      container!.read(activeWorkoutProvider.notifier).discard();
      await stopAll(tester);
    });
  });

  group('Warm-ups: an ascending ramp kept apart from the working sets', () {
    test(
      'a barbell lift gets a rising ramp below the working weight',
      () async {
        await startPush();
        final bench = session().exercises[0];
        expect(bench.hasWarmups, isTrue);
        expect(bench.warmupCount, kDefaultWarmupSets);
        expect(bench.warmups, isNotEmpty);

        final weights = bench.warmups.map((s) => s.weight).toList();
        // Strictly ascending, and every rung sits below the work.
        for (var i = 1; i < weights.length; i++) {
          expect(weights[i], greaterThan(weights[i - 1]));
        }
        expect(weights.every((w) => w < benchWeight), isTrue);
      },
    );

    test('a timed/unloaded slot offers no warm-ups', () async {
      container = containerFor(db);
      final wid = await buildPlankWorkout(db);
      await container!
          .read(activeWorkoutProvider.notifier)
          .start(workoutId: wid, name: 'Plank Day');
      expect(session().exercises.single.hasWarmups, isFalse);
      expect(session().exercises.single.warmups, isEmpty);
    });

    test('warm-up rest is its own shorter interval', () async {
      await startPush();
      final bench = session().exercises[0];
      expect(bench.warmupRestSeconds, kWarmupRestSeconds);
      expect(bench.warmupRestSeconds, lessThan(bench.restSeconds));
    });

    test('the rest after the last rung is the working rest', () async {
      // Between warm-ups you are catching your breath; after the heaviest one
      // you are about to do the actual set, and that earns the full rest.
      await startPush();
      final bench = session().exercises[0];
      final last = bench.warmups.length - 1;
      expect(bench.restAfterWarmup(last), bench.restSeconds);
      for (var wi = 0; wi < last; wi++) {
        expect(bench.restAfterWarmup(wi), kWarmupRestSeconds);
      }
    });

    testWidgets('tapping the last rung starts the full rest', (tester) async {
      await pumpPushScreen(tester);
      await tester.tap(find.text('WARM-UP').first);
      await tester.pump();

      // The first rung: the short warm-up rest.
      await tester.tap(repsCell('w0-0-Bench Press'));
      await tester.pump();
      expect(find.text('0:45'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pump();

      // The last rung: the routine's own 2:00, because the work is next.
      final last = session().exercises[0].warmups.length - 1;
      await tester.tap(repsCell('w0-$last-Bench Press'));
      await tester.pump();
      expect(find.text('2:00'), findsOneWidget);

      await stopAll(tester);
    });

    test('the count is adjustable and clamped to 0..max', () async {
      final ctl = await startPush();
      ctl.setWarmupCount(0, 5);
      expect(session().exercises[0].warmupCount, 5);
      final w = session().exercises[0].warmups.map((s) => s.weight).toList();
      expect(w.length, lessThanOrEqualTo(5));
      for (var i = 1; i < w.length; i++) {
        expect(w[i], greaterThan(w[i - 1]));
      }

      ctl.setWarmupCount(0, 0);
      expect(session().exercises[0].warmupCount, 0);
      expect(session().exercises[0].warmups, isEmpty);

      ctl.setWarmupCount(0, 99); // clamped up
      expect(session().exercises[0].warmupCount, kMaxWarmupSets);
      ctl.setWarmupCount(0, -3); // clamped down
      expect(session().exercises[0].warmupCount, 0);
    });

    test('warm-ups are excluded from every working aggregate', () async {
      final ctl = await startPush();
      // Log every warm-up on Bench and nothing else.
      for (var wi = 0; wi < session().exercises[0].warmups.length; wi++) {
        ctl.cycleWarmup(0, wi);
      }
      expect(session().exercises[0].warmups.every((s) => s.done), isTrue);

      // None of it counts: not toward the set counter, the totals or the volume,
      // and it cannot make the exercise's verdict succeed on its own.
      expect(session().doneSets, 0);
      expect(session().totalSets, kPushTotalSets);
      expect(session().volume, 0);
      expect(session().exercises[0].succeeded, isFalse);
    });

    test('warm-ups are never persisted on Finish', () async {
      final ctl = await startPush();
      // Log the warm-ups (heavier-than-nothing weights like 20/45/…) and the
      // four working sets at 80.
      for (var wi = 0; wi < session().exercises[0].warmups.length; wi++) {
        ctl.cycleWarmup(0, wi);
      }
      for (var si = 0; si < 4; si++) {
        ctl.cycleSet(0, si);
      }
      final id = await ctl.finish();

      final saved = await db.setsForSession(id!);
      final bench = saved
          .where((s) => s.exerciseName == 'Bench Press')
          .toList();
      // Only the four working sets, all at the working weight — no warm-up rung.
      expect(bench.length, 4);
      expect(bench.every((s) => s.weight == benchWeight), isTrue);
    });

    testWidgets(
      'the ramp is collapsed until expanded, then shows its disclaimer',
      (tester) async {
        await pumpPushScreen(tester);
        // Collapsed: the header is drawn but no warm-up rows and no disclaimer.
        expect(find.text('WARM-UP'), findsWidgets);
        expect(find.byKey(const ValueKey('w0-0-Bench Press')), findsNothing);
        expect(find.textContaining('not medical advice'), findsNothing);

        await tester.tap(find.text('WARM-UP').first);
        await tester.pump();

        expect(find.byKey(const ValueKey('w0-0-Bench Press')), findsOneWidget);
        expect(find.textContaining('not medical advice'), findsWidgets);

        await stopAll(tester);
      },
    );
  });

  group('One working weight for the exercise, not one box per set', () {
    test('setting it moves every set that has not been logged yet', () async {
      final ctl = await startPush();
      // Bench: four sets at 80. Two are in the bag when today turns out to be
      // an 85 day.
      ctl.cycleSet(0, 0);
      ctl.cycleSet(0, 1);
      ctl.setWorkingWeight(0, 85);

      final bench = session().exercises[0];
      expect(bench.workingKg, 85);
      // What is logged is what happened, and stays at the weight it happened at.
      expect(bench.sets[0].weight, benchWeight);
      expect(bench.sets[1].weight, benchWeight);
      // Everything still to come follows the new goal.
      expect(bench.sets[2].weight, 85);
      expect(bench.sets[3].weight, 85);
    });

    test('a single set can still be dropped to finish it', () async {
      final ctl = await startPush();
      ctl.setWeight(0, 3, 70);

      final bench = session().exercises[0];
      expect(bench.sets[3].weight, 70);
      expect(bench.sets.take(3).every((s) => s.weight == benchWeight), isTrue);
      // Deloading one set does not restate what the exercise is being done at.
      expect(bench.workingKg, benchWeight);
    });

    test('changing the working weight recomputes the warm-up ramp', () async {
      final ctl = await startPush();
      final before =
          session().exercises[0].warmups.map((s) => s.weight).toList();

      ctl.setWorkingWeight(0, benchWeight + 40);
      final after =
          session().exercises[0].warmups.map((s) => s.weight).toList();

      expect(after, isNot(before), reason: 'the ramp primed the old weight');
      expect(after.last, greaterThan(before.last));
      // Still a ramp: ascending, and still under the work.
      expect(after.every((w) => w < benchWeight + 40), isTrue);
      for (var i = 1; i < after.length; i++) {
        expect(after[i], greaterThan(after[i - 1]));
      }
    });

    test('a warm-up already logged is not rewritten by a recompute', () async {
      final ctl = await startPush();
      // The middle rung is the one that moves when the work gets heavier.
      ctl.cycleWarmup(0, 1);
      final done = session().exercises[0].warmups[1];
      final wasAt = done.weight;
      final didReps = done.logged;

      ctl.setWorkingWeight(0, benchWeight + 40);

      final now = session().exercises[0].warmups[1];
      expect(now.logged, didReps);
      expect(now.weight, wasAt,
          reason: 'the plates were already on the bar for that rung');
    });

    testWidgets('the weight is one control per exercise, not a box per set',
        (tester) async {
      await pumpPushScreen(tester);
      // Nothing on the board asks to be typed into.
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.byKey(const ValueKey('working-weight-0')));
      await frames(tester);
      await tester.enterText(find.byType(TextField), '85');
      await tester.tap(find.text('Save'));
      await frames(tester);

      final bench = session().exercises[0];
      expect(bench.workingKg, 85);
      expect(bench.sets.every((s) => s.weight == 85), isTrue);

      await stopAll(tester);
    });

    testWidgets('one set can still be overridden from its own row',
        (tester) async {
      await pumpPushScreen(tester);
      await tester.tap(weightCell('0-3-Bench Press'));
      await frames(tester);
      await tester.enterText(find.byType(TextField), '70');
      await tester.tap(find.text('Save'));
      await frames(tester);

      final bench = session().exercises[0];
      expect(bench.sets[3].weight, 70);
      expect(bench.sets[0].weight, benchWeight);

      await stopAll(tester);
    });

    testWidgets('changing the warm-up count moves the weights, not only the '
        'goals', (tester) async {
      // Issue #35: a 227.5 kg squat with three warm-ups reads 20×8, 110×8,
      // 190×2. Stepping to four moved the goals to 20/70/130/190 while the
      // weight boxes beside them still said 20/110/190/190 — so the number you
      // would load the bar from was the wrong one.
      await tester.runAsync(() async {
        final wid = await buildBarbellWorkout(db);
        container = containerFor(db);
        await container!
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: wid, name: 'Squat Day');
      });
      await tester.pumpWidget(appUnder(container!, const WorkoutScreen()));
      await tester.pump();
      await tester.tap(find.text('WARM-UP').first);
      await tester.pump();

      void expectRampOnScreen() {
        final ramp = session().exercises[0].warmups;
        expect(ramp, isNotEmpty);
        for (var wi = 0; wi < ramp.length; wi++) {
          expect(
            find.descendant(
              of: find.byKey(ValueKey('w0-$wi-Back Squat')),
              matching: find.text(fmtWeight(ramp[wi].weight)),
            ),
            findsOneWidget,
            reason: 'rung $wi should be loaded at ${ramp[wi].weight}',
          );
        }
      }

      expect(session().exercises[0].warmupCount, 3);
      expectRampOnScreen();

      await tester.tap(find.text('+'));
      await tester.pump();

      expect(session().exercises[0].warmupCount, 4);
      expectRampOnScreen();

      await stopAll(tester);
    });
  });

  group('Warm-up rungs land on loads the gym can actually set', () {
    // Every rung of a ramp has to be a weight you can walk up to the rack and
    // make — and the cheapest such weight near the step, so a warm-up costs one
    // pair of plates rather than four. See features/index.html#sec04.

    /// Whether [kg] sits on a [step]-sized grid (2.5 kg dumbbells, 5 lb stacks).
    bool onGrid(double kg, double step) {
      final n = kg / step;
      return (n - n.roundToDouble()).abs() < 1e-6;
    }

    /// The warm-up rungs of the exercise at [ei], in the display unit.
    List<double> rungsIn(String unit, int ei) => session()
        .exercises[ei]
        .warmups
        .map((s) => toDisplayWeight(s.weight, unit))
        .toList();

    test('a barbell ramp always starts on the empty bar', () async {
      await startPush();
      // Bench Press, 80 kg over the default 20 kg bar.
      expect(session().exercises[0].warmups.first.weight, 20.0);
      // And it still does after the count is dialled up or down. (A ramp of one
      // is not a ramp — see the lone-warm-up test below.)
      final ctl = container!.read(activeWorkoutProvider.notifier);
      for (final n in [2, 3, kMaxWarmupSets]) {
        ctl.setWarmupCount(0, n);
        expect(
          session().exercises[0].warmups.first.weight,
          20.0,
          reason: 'ramp of $n should still open on the empty bar',
        );
      }
    });

    test('every barbell rung is loadable, and cheap to load', () async {
      await startPush();
      final ctl = container!.read(activeWorkoutProvider.notifier);
      ctl.setWarmupCount(0, kMaxWarmupSets);
      final rack = defaultPlatesFor('kg');
      for (final s in session().exercises[0].warmups.skip(1)) {
        final sol = solvePlates(targetKg: s.weight, barKg: 20, inventory: rack);
        expect(sol.exact, isTrue, reason: '${s.weight} kg cannot be loaded');
        final perSide = sol.plates.fold<int>(0, (a, p) => a + p.count);
        expect(
          perSide,
          lessThanOrEqualTo(2),
          reason: '${s.weight} kg needs $perSide plates a side',
        );
      }
    });

    test('a pounds gym ramps 45 → 95 → 135, one pair at a time', () async {
      await db.setWeightUnit('lb');
      await startPush();
      expect(rungsIn('lb', 0).map((w) => w.round()).toList(), [45, 95, 135]);
    });

    test('a dumbbell ramp moves in the steps a gym stocks', () async {
      await startPush();
      // Incline DB Press, 30 kg a hand: metric racks go up in 2.5s.
      final kg = rungsIn('kg', 2);
      expect(kg, isNotEmpty);
      for (final w in kg) {
        expect(onGrid(w, 2.5), isTrue, reason: '$w kg is not a stocked bell');
      }

      // The same rack counted in pounds goes up in 5s.
      await db.setWeightUnit('lb');
      container!.dispose();
      await startPush();
      final lb = rungsIn('lb', 2);
      expect(lb, isNotEmpty);
      for (final w in lb) {
        expect(onGrid(w, 5), isTrue, reason: '$w lb is not a stocked bell');
      }
    });

    test('a machine ramp moves in multiples of five', () async {
      await startPush();
      // Triceps Pushdown, 35 kg on a stack.
      final kg = rungsIn('kg', 4);
      expect(kg, isNotEmpty);
      for (final w in kg) {
        expect(onGrid(w, 5), isTrue, reason: '$w kg is not a stack setting');
      }

      await db.setWeightUnit('lb');
      container!.dispose();
      await startPush();
      final lb = rungsIn('lb', 4);
      expect(lb, isNotEmpty);
      for (final w in lb) {
        expect(onGrid(w, 5), isTrue, reason: '$w lb is not a stack setting');
      }
    });

    test('a ramp of any length stays ascending and under the work', () async {
      final ctl = await startPush();
      for (var ei = 0; ei < kPushSize; ei++) {
        final working = session().exercises[ei].sets.first.goalWeight!;
        for (var n = 1; n <= kMaxWarmupSets; n++) {
          ctl.setWarmupCount(ei, n);
          final w = session().exercises[ei].warmups.map((s) => s.weight);
          expect(w.length, lessThanOrEqualTo(n));
          expect(w.every((x) => x > 0 && x < working), isTrue,
              reason: 'exercise $ei, $n sets: $w against $working');
          for (var i = 1; i < w.length; i++) {
            expect(w.elementAt(i), greaterThan(w.elementAt(i - 1)));
          }
        }
      }
    });

    test('no rung climbs past the top of the ramp, however many', () async {
      // Snapping to a loadable weight rounds *down* past the ceiling: a last
      // warm-up at 88% of a set you still owe four of is a working set.
      final ctl = await startPush();
      for (var ei = 0; ei < kPushSize; ei++) {
        final working = session().exercises[ei].sets.first.goalWeight!;
        for (var n = 1; n <= kMaxWarmupSets; n++) {
          ctl.setWarmupCount(ei, n);
          for (final s in session().exercises[ei].warmups.skip(1)) {
            expect(
              s.weight,
              lessThanOrEqualTo(working * kWarmupTopFraction + 0.01),
              reason: 'exercise $ei, $n sets: ${s.weight} of $working',
            );
          }
        }
      }
    });

    test('a lone warm-up is middle of the road, not the empty bar', () async {
      // One warm-up set is not the bottom of a ramp, it is the whole warm-up:
      // heavy enough to actually warm you up, light enough not to hurt you.
      final ctl = await startPush();
      for (var ei = 0; ei < kPushSize; ei++) {
        ctl.setWarmupCount(ei, 1);
        final e = session().exercises[ei];
        expect(e.warmups.length, 1);
        final frac = e.warmups.single.weight / e.sets.first.goalWeight!;
        expect(frac, greaterThanOrEqualTo(kWarmupStartFraction));
        expect(frac, lessThanOrEqualTo(kWarmupTopFraction + 0.01),
            reason: 'exercise $ei warmed up at ${(frac * 100).round()}%');
        // On a barbell lift that means plates on it, not the bar on its own.
        expect(e.warmups.single.weight, greaterThan(e.warmupBarKg));
      }
    });

    test('the heaviest rung is a warm-up, not another light set', () async {
      // Preferring cheap loads must not buy a saved plate with half the ramp:
      // 20 → 70 before a 140 kg squat is not a warm-up for it.
      final ctl = await startPush();
      for (var ei = 0; ei < kPushSize; ei++) {
        final working = session().exercises[ei].sets.first.goalWeight!;
        for (var n = 2; n <= kMaxWarmupSets; n++) {
          ctl.setWarmupCount(ei, n);
          expect(
            session().exercises[ei].warmups.last.weight,
            greaterThanOrEqualTo(0.6 * working),
            reason: 'exercise $ei, $n sets, working $working',
          );
        }
      }
    });

    test('reps fall off as the ramp gets heavier', () async {
      final ctl = await startPush();
      ctl.setWarmupCount(0, kMaxWarmupSets);
      final ramp = session().exercises[0].warmups;
      for (var i = 1; i < ramp.length; i++) {
        expect(ramp[i].goal, lessThanOrEqualTo(ramp[i - 1].goal),
            reason: 'rung $i of ${ramp.map((s) => '${s.weight}x${s.goal}')}');
      }
      // The top of the ramp is a couple of reps, not a set.
      expect(ramp.last.goal, lessThanOrEqualTo(3));
    });
  });

  group('The plate line describes the working bar', () {
    testWidgets('a barbell lift breaks its weight down per side', (
      tester,
    ) async {
      await pumpPushScreen(tester);
      // Bench 80 kg over a 20 kg bar → 30/side (25 + 5).
      expect(find.text('30 KG/SIDE · 25 + 5 · BAR 20'), findsOneWidget);
      await stopAll(tester);
    });
  });

  group('A bar cannot be loaded below its own weight', () {
    /// A one-exercise day at [weightKg], mounted and ready to tap.
    Future<void> pumpOne(
      WidgetTester tester, {
      required String exercise,
      required double weightKg,
    }) async {
      await tester.runAsync(() async {
        final wid = await buildBarbellWorkout(
          db,
          exercise: exercise,
          weightKg: weightKg,
        );
        container = containerFor(db);
        await container!
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: wid, name: 'Squat Day');
      });
      await tester.pumpWidget(appUnder(container!, const WorkoutScreen()));
      await tester.pump();
    }

    /// Types [typed] into whichever weight editor is open and saves it.
    Future<void> type(WidgetTester tester, String typed) async {
      await tester.enterText(find.byType(TextField), typed);
      await tester.tap(find.text('Save'));
      await frames(tester);
    }

    testWidgets('the exercise weight stops at the bar, and says so',
        (tester) async {
      // Back Squat over the standard 20 kg bar. Ten kilos is not a light day,
      // it is a load nobody can build.
      await pumpOne(tester, exercise: 'Back Squat', weightKg: 100);

      await tester.tap(find.byKey(const ValueKey('working-weight-0')));
      await frames(tester);
      expect(find.textContaining('no lighter than the 20 kg bar'),
          findsOneWidget);

      await type(tester, '10');

      final squat = session().exercises[0];
      expect(squat.workingKg, 20, reason: 'clamped to the bar, not accepted');
      expect(squat.sets.every((set) => set.weight == 20), isTrue);

      await stopAll(tester);
    });

    testWidgets('and so does one set of its own', (tester) async {
      await pumpOne(tester, exercise: 'Back Squat', weightKg: 100);

      await tester.tap(weightCell('0-2-Back Squat'));
      await frames(tester);
      await type(tester, '5');

      expect(session().exercises[0].sets[2].weight, 20);
      await stopAll(tester);
    });

    testWidgets('a machine has no bar under it, and no floor', (tester) async {
      // The number on a stack is the number; zero is a real answer there.
      await pumpOne(tester, exercise: 'Triceps Pushdown', weightKg: 35);

      await tester.tap(find.byKey(const ValueKey('working-weight-0')));
      await frames(tester);
      expect(find.textContaining('no lighter than'), findsNothing);

      await type(tester, '0');

      expect(session().exercises[0].workingKg, 0);
      await stopAll(tester);
    });
  });

  group('A movement with no load has no weight on the board', () {
    testWidgets('a plank shows no weight column, and no empty unit',
        (tester) async {
      await tester.runAsync(() async {
        final wid = await buildPlankWorkout(db);
        container = containerFor(db);
        await container!
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: wid, name: 'Plank Day');
      });
      await tester.pumpWidget(appUnder(container!, const WorkoutScreen()));
      await tester.pump();

      expect(find.text('KG'), findsNothing,
          reason: 'a column heading over nothing');
      expect(find.byKey(const ValueKey('set-weight')), findsNothing);
      expect(find.byKey(const ValueKey('working-weight-0')), findsNothing);

      // The set still logs — it is the weight that is absent, not the row.
      await tester.tap(repsCell('0-0-Plank'));
      await tester.pump(const Duration(seconds: 4));
      await tester.tap(repsCell('0-0-Plank'));
      await tester.pump();
      expect(session().exercises[0].sets[0].logged, 4);

      await stopAll(tester);
    });

    testWidgets('and a loaded lift still has one', (tester) async {
      await pumpPushScreen(tester);
      expect(find.text('KG'), findsWidgets);
      expect(find.byKey(const ValueKey('set-weight')), findsWidgets);
      await stopAll(tester);
    });
  });

  group('The rest bar takes room rather than covering the board', () {
    // The same rule the resume bar follows, for the same reason: a bar lying
    // over the rows hid whichever set you were trying to read, and the only way
    // to see underneath was to end the rest you were taking.

    testWidgets('the rows scroll clear of it', (tester) async {
      tester.view.physicalSize = const Size(390, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpPushScreen(tester);
      await tester.ensureVisible(repsCell('0-0-Bench Press'));
      await tester.pump();
      await tester.tap(repsCell('0-0-Bench Press'));
      await tester.pump();
      expect(find.byKey(kRestBannerKey), findsOneWidget);

      final bar = tester.getRect(find.byKey(kRestBannerKey));
      final list = tester.getRect(find.byType(ListView).first);
      expect(list.bottom, lessThanOrEqualTo(bar.top + 0.5),
          reason: 'the board ran on underneath the bar');

      // And the far end of the session can be reached with the bar up: the last
      // set of the last exercise comes to rest above it.
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('4-2-Triceps Pushdown')),
        find.byType(ListView).first,
        const Offset(0, -120),
        maxIteration: 60,
      );
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const ValueKey('4-2-Triceps Pushdown'))).bottom,
        lessThanOrEqualTo(bar.top + 0.5),
      );

      // And it is against the bottom edge, taking only the height it needs: a
      // bar handed a share of the column sat halfway up the screen with the
      // board squeezed above it and nothing at all underneath.
      expect(bar.bottom, closeTo(780, 0.5),
          reason: 'a blank strip opened up under the bar');
      expect(bar.height, lessThan(200),
          reason: 'the bar took room the board should have had');

      await stopAll(tester);
    });
  });

  group('A ramp with nothing to build says why', () {
    // Never "add some above": the stepper above is not what is wrong, and
    // adding rungs cannot conjure a load between the bar and a working weight
    // that is already the bar.

    Future<void> pumpEmptyBarSquat(WidgetTester tester) async {
      await tester.runAsync(() async {
        // An empty-bar squat: there is nothing under 20 kg to warm up with.
        final wid = await buildBarbellWorkout(db, weightKg: 20);
        container = containerFor(db);
        await container!
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: wid, name: 'Squat Day');
      });
      await tester.pumpWidget(appUnder(container!, const WorkoutScreen()));
      await tester.pump();
      await tester.tap(find.text('WARM-UP').first);
      await tester.pump();
    }

    testWidgets('it names the reason, and never asks for the impossible',
        (tester) async {
      await pumpEmptyBarSquat(tester);

      expect(session().exercises[0].warmupCount, greaterThan(0));
      expect(session().exercises[0].warmups, isEmpty);
      expect(find.textContaining('add some above'), findsNothing);
      expect(find.textContaining('Too light to ramp'), findsOneWidget);

      await stopAll(tester);
    });

    testWidgets('and asking for none says nothing at all', (tester) async {
      await pumpEmptyBarSquat(tester);

      for (var i = 0; i < kDefaultWarmupSets; i++) {
        await tester.tap(find.text('−'));
        await tester.pump();
      }

      expect(session().exercises[0].warmupCount, 0);
      expect(find.textContaining('Too light to ramp'), findsNothing,
          reason: 'the stepper beside it already reads 0');

      await stopAll(tester);
    });
  });

  group('The session lives in memory until Finish', () {
    test('logging sets writes nothing to the database', () async {
      final ctl = await startPush();
      for (var si = 0; si < 4; si++) {
        ctl.cycleSet(0, si);
      }
      // No finished session on disk yet.
      expect(await db.watchHistory().first, isEmpty);
    });

    testWidgets(
      'collapsing keeps the session alive and flips the visible flag',
      (tester) async {
        await pumpPushScreen(tester);
        // Mounting the screen marks it visible (post-frame), which hides the
        // resume pill.
        expect(container!.read(workoutScreenVisibleProvider), isTrue);

        // Collapse: unmount the screen and nothing else — the point of the
        // test is that the session outlives it, so it must not be put down.
        await stop(tester);
        await tester.pump();
        expect(container!.read(workoutScreenVisibleProvider), isFalse);
        expect(container!.read(activeWorkoutProvider), isNotNull);
      },
    );

    test(
      'a session only ends by finishing — an explicit discard aside',
      () async {
        final ctl = await startPush();
        expect(container!.read(activeWorkoutProvider), isNotNull);
        ctl.discard();
        expect(container!.read(activeWorkoutProvider), isNull);
      },
    );
  });

  group('Finish writes only completed working sets', () {
    test(
      'logged sets are saved with their goals; unlogged ones are dropped',
      () async {
        final ctl = await startPush();
        // Log Bench sets 1 and 3 only (indices 0 and 2), skip 2 and 4.
        ctl.cycleSet(0, 0);
        ctl.cycleSet(0, 2);
        final id = await ctl.finish();

        final saved = await db.setsForSession(id!);
        // Two rows, renumbered sequentially over the sets that happened.
        expect(saved.length, 2);
        expect(saved.map((s) => s.setNumber), [1, 2]);
        expect(saved.every((s) => s.exerciseName == 'Bench Press'), isTrue);
        final first = saved.first;
        expect(first.weight, benchWeight);
        expect(first.reps, benchGoal);
        expect(first.goalReps, benchGoal);
        expect(first.goalWeight, benchWeight);
        expect(first.seconds, isNull);

        // The live session is cleared once it is on disk.
        expect(container!.read(activeWorkoutProvider), isNull);
      },
    );

    test('a timed set is saved as seconds held, not reps', () async {
      container = containerFor(db);
      final wid = await buildPlankWorkout(db, holdSeconds: 45);
      final ctl = container!.read(activeWorkoutProvider.notifier);
      await ctl.start(workoutId: wid, name: 'Plank Day');
      ctl.cycleSet(0, 0); // hold the goal
      // A held set moves no load.
      expect(session().volume, 0);
      final id = await ctl.finish();

      final saved = await db.setsForSession(id!);
      expect(saved.length, 1);
      expect(saved.first.seconds, 45);
      expect(saved.first.reps, 0);
      expect(saved.first.goalSeconds, 45);
    });
  });

  group('Finishing with working sets unlogged asks first', () {
    // Finish is the one tap that turns a half-done session into history and
    // moves next session's targets with it. Leaving sets unlogged is sometimes
    // deliberate and sometimes a forgotten row, and the two look identical from
    // the outside — so it asks, and says what it would cost.

    /// The Push day on screen, with a `/summary/:id` to land on when it does
    /// finish.
    Future<void> pumpRouted(WidgetTester tester) async {
      await tester.runAsync(() async {
        final wid = await workoutIdNamed(db, 'Push');
        container = containerFor(db);
        await container!
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: wid, name: 'Push');
      });
      await tester.pumpWidget(routedAppUnder(
        container!,
        const WorkoutScreen(),
        alsoRoutes: const ['summary/:id'],
      ));
      await tester.pump();
    }

    /// Logs every working set of the running session.
    void logEverything() {
      final ctl = container!.read(activeWorkoutProvider.notifier);
      for (var ei = 0; ei < session().exercises.length; ei++) {
        for (var si = 0; si < session().exercises[ei].sets.length; si++) {
          ctl.cycleSet(ei, si);
        }
      }
    }

    testWidgets('it names the count and defaults to going back',
        (tester) async {
      await pumpRouted(tester);
      await tester.tap(repsCell('0-0-Bench Press'));
      await tester.pump();

      await tester.tap(find.text('Finish'));
      await frames(tester);

      expect(find.text('Finish with ${kPushTotalSets - 1} sets unlogged?'),
          findsOneWidget);

      await tester.tap(find.text('Back to the board'));
      await frames(tester);

      expect(container!.read(activeWorkoutProvider), isNotNull,
          reason: 'the default answer leaves the session running');
      final sessions = await tester.runAsync(() => db.watchHistory().first);
      expect(sessions, isEmpty, reason: 'nothing was written on the way past');

      await stopAll(tester);
    });

    testWidgets('confirming finishes it', (tester) async {
      await pumpRouted(tester);
      await tester.tap(repsCell('0-0-Bench Press'));
      await tester.pump();

      await tester.tap(find.text('Finish'));
      await frames(tester);
      await tester.tap(find.text('Finish anyway'));
      await frames(tester);

      expect(container!.read(activeWorkoutProvider), isNull);
      final sessions = await tester.runAsync(() => db.watchHistory().first);
      expect(sessions, hasLength(1),
          reason: 'the session it warned about is still the one it writes');

      await stop(tester);
    });

    testWidgets('a fully logged session finishes without asking',
        (tester) async {
      await pumpRouted(tester);
      logEverything();
      await tester.pump();

      await tester.tap(find.text('Finish'));
      await frames(tester);

      expect(find.textContaining('unlogged'), findsNothing,
          reason: 'there is nothing to warn about');
      expect(container!.read(activeWorkoutProvider), isNull);

      await stop(tester);
    });

    testWidgets('an unlogged warm-up rung never triggers it', (tester) async {
      // Skipping rungs of the ramp is ordinary: they are never written and
      // never decide whether a session was clean.
      await pumpRouted(tester);
      logEverything();
      await tester.pump();
      expect(
          session().exercises.any((e) => e.warmups.any((w) => !w.done)), isTrue,
          reason: 'this proves nothing unless a rung is left unlogged');

      await tester.tap(find.text('Finish'));
      await frames(tester);

      expect(find.textContaining('unlogged'), findsNothing);
      expect(container!.read(activeWorkoutProvider), isNull);

      await stop(tester);
    });
  });

  group('Finish advances progression, in the right order', () {
    test(
      'a clean session steps the slot up, with its sets on disk to justify it',
      () async {
        final ctl = await startPush();
        final benchItemId = (await db.itemsForWorkout(
          session().workoutId!,
        ))[0].item.id;
        for (var si = 0; si < 4; si++) {
          ctl.cycleSet(0, si); // all four at goal and weight → a clean bench
        }
        expect(session().exercises[0].succeeded, isTrue);
        final id = await ctl.finish();

        // The saved session exists...
        final saved = await db.setsForSession(id!);
        expect(saved.where((s) => s.exerciseName == 'Bench Press').length, 4);
        // ...and the slot advanced by one step (2.5 kg default).
        final item = await db.workoutItemById(benchItemId);
        expect(item!.suggestedWeight, benchWeight + 2.5);
      },
    );

    test(
      'the progression report is keyed to an already-persisted session',
      () async {
        // Sets are saved *before* progression advances, so the report the finish
        // publishes points at a session whose sets are already queryable.
        final ctl = await startPush();
        for (var si = 0; si < 4; si++) {
          ctl.cycleSet(0, si);
        }
        final id = await ctl.finish();
        final report = container!.read(lastProgressionProvider);
        expect(report, isNotNull);
        expect(report!.sessionId, id);
        expect(report.outcomes, isNotEmpty);
        // The session the report names already carries its sets.
        expect(await db.setsForSession(report.sessionId), isNotEmpty);
      },
    );

    test('a fresh start clears the previous session\'s report', () async {
      final ctl = await startPush();
      for (var si = 0; si < 4; si++) {
        ctl.cycleSet(0, si);
      }
      await ctl.finish();
      expect(container!.read(lastProgressionProvider), isNotNull);

      final wid = await workoutIdNamed(db, 'Push');
      await ctl.start(workoutId: wid, name: 'Push');
      expect(container!.read(lastProgressionProvider), isNull);
    });

    test('a session short on reps does not step the slot up', () async {
      final ctl = await startPush();
      final benchItemId = (await db.itemsForWorkout(
        session().workoutId!,
      ))[0].item.id;
      for (var si = 0; si < 4; si++) {
        ctl.cycleSet(0, si);
      }
      ctl.setLogged(0, 1, benchGoal - 2); // one set came up short
      expect(session().exercises[0].succeeded, isFalse);
      await ctl.finish();

      final item = await db.workoutItemById(benchItemId);
      expect(item!.suggestedWeight, benchWeight); // held, not raised
    });

    test(
      'deloading to finish a set counts as a miss and blocks a step up',
      () async {
        final ctl = await startPush();
        final benchItemId = (await db.itemsForWorkout(
          session().workoutId!,
        ))[0].item.id;
        for (var si = 0; si < 4; si++) {
          ctl.cycleSet(0, si); // reps at goal...
          ctl.setWeight(
            0,
            si,
            benchWeight - 2.5,
          ); // ...but under the suggested load
        }
        expect(session().exercises[0].succeeded, isFalse);
        await ctl.finish();

        final item = await db.workoutItemById(benchItemId);
        expect(item!.suggestedWeight, benchWeight); // a miss holds the target
      },
    );
  });

  group('The goal is stated once, beside the weight', () {
    // Issue #63. It used to be reprinted on every row, where the weight cell
    // and the greyed-out result cell beside it already said both halves of it.
    //
    // And it reads as a goal: sets × reps, joined to the load by an @, with the
    // load the only part of the line inside a box. "WORKING SETS × 8 [80]" read
    // as a label with a stray editable cell in the middle of it.

    testWidgets('no row carries a goal cell; the exercise states it once',
        (tester) async {
      await tester.runAsync(() async {
        final wid = await buildBarbellWorkout(db, weightKg: 100, sets: 3);
        container = containerFor(db);
        await container!
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: wid, name: 'Squat Day');
      });
      await tester.pumpWidget(appUnder(container!, const WorkoutScreen()));
      await tester.pump();

      expect(find.text('GOAL'), findsNothing);
      expect(find.byKey(kExerciseGoalKey), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(kExerciseGoalKey)).data, '3 × 5',
          reason: 'three sets of five, said the way a lifter says it');
      // Joined to the load, which is the control: "3 × 5 @ 100 kg".
      expect(find.text('@'), findsOneWidget);
      await stopAll(tester);
    });

    testWidgets('and a real session shows no per-row goal anywhere',
        (tester) async {
      await pumpPushScreen(tester);

      // One per exercise that is actually built — the list is lazy, so the
      // assertion is "at least one, and nothing in the old per-row form".
      expect(find.byKey(kExerciseGoalKey), findsWidgets);
      expect(find.text('80×8'), findsNothing,
          reason: 'the goal cell that used to sit on every row');
      await stopAll(tester);
    });

    testWidgets('a hold with nothing on it states the hold on its own',
        (tester) async {
      await tester.runAsync(() async {
        final wid = await buildPlankWorkout(db);
        container = containerFor(db);
        await container!
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: wid, name: 'Plank Day');
      });
      await tester.pumpWidget(appUnder(container!, const WorkoutScreen()));
      await tester.pump();

      expect(tester.widget<Text>(find.byKey(kExerciseGoalKey)).data, '2 × 45s',
          reason: 'two holds of forty-five seconds');
      expect(find.text('@'), findsNothing,
          reason: 'nothing to be at: the movement carries no load');
      await stopAll(tester);
    });
  });

  group('The board says which set you are on', () {
    // Issue #60. The shade already works out what is next; the board is the
    // thing you are actually looking at, so it marks the same answer rather
    // than leaving you to scan for the last row that went green.

    /// The mark, inside one named row.
    Finder markOn(String row) => find.descendant(
          of: find.byKey(ValueKey(row)),
          matching: find.byKey(kNextSetKey),
        );

    /// Ticks off Bench's whole warm-up ramp, so the work is what is next.
    void clearRamp(ActiveWorkoutController ctl) {
      for (var wi = 0; wi < session().exercises[0].warmups.length; wi++) {
        ctl.cycleWarmup(0, wi);
      }
      ctl.stopRest(tone: false);
    }

    testWidgets('the ramp is where you start, so the group carries the mark',
        (tester) async {
      await pumpPushScreen(tester);

      // The group is shut by default, so it is the only thing on screen that
      // can say the ramp is where you are.
      expect(find.byKey(kNextWarmupKey), findsOneWidget);
      expect(find.byKey(kNextSetKey), findsNothing);
      await stopAll(tester);
    });

    testWidgets('opening the group marks the rung itself', (tester) async {
      await pumpPushScreen(tester);
      await tester.tap(find.text('WARM-UP').first);
      await tester.pump();

      expect(markOn('w0-0-Bench Press'), findsOneWidget);
      expect(find.byKey(kNextSetKey), findsOneWidget,
          reason: 'one rung, not the whole ramp');
      await stopAll(tester);
    });

    testWidgets('with the ramp behind you it is the first working set',
        (tester) async {
      await pumpPushScreen(tester);
      clearRamp(container!.read(activeWorkoutProvider.notifier));
      await tester.pump();

      expect(markOn('0-0-Bench Press'), findsOneWidget);
      expect(find.byKey(kNextSetKey), findsOneWidget,
          reason: 'exactly one thing on the board is ever marked');
      expect(find.byKey(kNextWarmupKey), findsNothing);
      await stopAll(tester);
    });

    testWidgets('logging a set moves the mark down, rest or no rest',
        (tester) async {
      await pumpPushScreen(tester);
      clearRamp(container!.read(activeWorkoutProvider.notifier));
      await tester.pump();

      await tester.tap(repsCell('0-0-Bench Press'));
      await tester.pump();

      // A rest is running now; the set marked is still the one you are resting
      // *for*.
      expect(find.byKey(kRestBannerKey), findsOneWidget);
      expect(markOn('0-0-Bench Press'), findsNothing);
      expect(markOn('0-1-Bench Press'), findsOneWidget);
      await stopAll(tester);
    });

    testWidgets('and a finished session marks nothing at all', (tester) async {
      await pumpPushScreen(tester);
      final ctl = container!.read(activeWorkoutProvider.notifier);
      for (var ei = 0; ei < session().exercises.length; ei++) {
        for (var wi = 0; wi < session().exercises[ei].warmups.length; wi++) {
          ctl.cycleWarmup(ei, wi);
        }
        for (var si = 0; si < session().exercises[ei].sets.length; si++) {
          ctl.cycleSet(ei, si);
        }
      }
      ctl.stopRest(tone: false);
      await tester.pump();

      expect(find.byKey(kNextSetKey), findsNothing);
      expect(find.byKey(kNextWarmupKey), findsNothing);
      await stopAll(tester);
    });
  });

  group('Verdict and volume read only the working sets', () {
    test('missedGoal is true short on reps, and short on weight', () async {
      final ctl = await startPush();
      final set = session().exercises[0].sets[0];

      ctl.cycleSet(0, 0); // logged at goal, at weight → a hit
      expect(set.missedGoal, isFalse);

      ctl.setLogged(0, 0, benchGoal - 1); // short on reps
      expect(set.missedGoal, isTrue);

      ctl.setLogged(0, 0, benchGoal); // back to full reps...
      ctl.setWeight(0, 0, benchWeight - 5); // ...but under the suggested weight
      expect(set.missedGoal, isTrue);
    });

    test('succeeded needs every planned set logged and none short', () async {
      final ctl = await startPush();
      // Three of four logged, one skipped → not a clean exercise.
      ctl.cycleSet(0, 0);
      ctl.cycleSet(0, 1);
      ctl.cycleSet(0, 2);
      expect(session().exercises[0].succeeded, isFalse);
      ctl.cycleSet(0, 3);
      expect(session().exercises[0].succeeded, isTrue);
    });

    test('performedWeight is the lightest weight carried through', () async {
      final ctl = await startPush();
      for (var si = 0; si < 4; si++) {
        ctl.cycleSet(0, si);
      }
      ctl.setWeight(0, 3, benchWeight + 5); // one heavy set does not move it
      expect(session().exercises[0].performedWeight, benchWeight);
    });

    test('volume sums load moved and ignores held sets', () async {
      final ctl = await startPush();
      ctl.cycleSet(0, 0); // 8 reps @ 80 = 640
      expect(session().volume, benchGoal * benchWeight);
      expect(session().missedSets, 0);
      ctl.setLogged(0, 1, benchGoal - 3); // a short set is a miss...
      expect(session().missedSets, 1);
      // ...and still adds its own moved load.
      expect(
        session().volume,
        benchGoal * benchWeight + (benchGoal - 3) * benchWeight,
      );
    });
  });

  group('A timed set taps goal ⇄ untouched only', () {
    test('a plank never counts down a second at a time', () async {
      container = containerFor(db);
      final wid = await buildPlankWorkout(db, holdSeconds: 45);
      final ctl = container!.read(activeWorkoutProvider.notifier);
      await ctl.start(workoutId: wid, name: 'Plank Day');
      int? logged() => session().exercises[0].sets[0].logged;

      expect(logged(), isNull);
      ctl.cycleSet(0, 0);
      expect(logged(), 45); // claims the whole hold
      ctl.cycleSet(0, 0);
      expect(logged(), isNull); // straight back to untouched, not 44
      ctl.cycleSet(0, 0);
      expect(logged(), 45);
    });
  });

  group('What the session says to do next', () {
    // The board draws the whole session and lets your eye pick the row; one
    // line has to choose. That choice is the part most likely to be wrong, so
    // it is arithmetic with tests rather than something inside a notification.

    test('the ramp comes before the work of the same exercise', () async {
      await startPush();
      final cue = nextUp(session())!;

      expect(cue.kind, CueKind.lift);
      expect(cue.exercise, 'Bench Press');
      expect(cue.warmup, isTrue, reason: 'the first rung, not the first set');
      expect(cue.weightKg, session().exercises[0].warmups.first.weight);
    });

    test('the cue counts the list the set belongs to', () async {
      final ctl = await startPush();
      final ramp = session().exercises[0].warmups;

      expect(nextUp(session())!.setCount, ramp.length,
          reason: 'a rung counts the rungs');

      for (var wi = 0; wi < ramp.length; wi++) {
        ctl.cycleWarmup(0, wi);
      }
      expect(nextUp(session())!.setCount, session().exercises[0].sets.length,
          reason: 'a working set counts the working sets');
    });

    test('and the work follows once the ramp is ticked off', () async {
      final ctl = await startPush();
      for (var wi = 0; wi < session().exercises[0].warmups.length; wi++) {
        ctl.cycleWarmup(0, wi);
      }

      final cue = nextUp(session())!;
      expect(cue.warmup, isFalse);
      expect(cue.exercise, 'Bench Press');
      expect(cue.setIndex, 0);
      expect(cue.reps, benchGoal);
      expect(cue.weightKg, benchWeight);
    });

    test('a rung nobody went back for does not hold up the next exercise',
        () async {
      final ctl = await startPush();
      // Every working set of Bench done, one warm-up rung still unticked.
      for (var si = 0; si < 4; si++) {
        ctl.cycleSet(0, si);
      }

      final cue = nextUp(session())!;
      expect(cue.exercise, session().exercises[1].name,
          reason: 'the ramp of a finished exercise is behind you');
    });

    test('a warm-up rung of a later exercise is not what you owe now',
        () async {
      await startPush();
      final cue = nextUp(session())!;
      // Bench's ramp, not the ramp of anything further down the list.
      expect(cue.exerciseIndex, 0);
    });

    test('resting outranks whatever is next, and still names it', () async {
      final ctl = await startPush();
      for (var wi = 0; wi < session().exercises[0].warmups.length; wi++) {
        ctl.cycleWarmup(0, wi);
      }

      final cue = nextUp(session(), restLeft: 74)!;
      expect(cue.kind, CueKind.resting);
      expect(cue.restLeft, 74);
      // "Rest, then bench 80 for 8" is more use than "rest".
      expect(cue.exercise, 'Bench Press');
      expect(cue.reps, benchGoal);
    });

    test('a held movement is a hold, not a rep count', () async {
      container = containerFor(db);
      final wid = await buildPlankWorkout(db, holdSeconds: 45);
      await container!
          .read(activeWorkoutProvider.notifier)
          .start(workoutId: wid, name: 'Plank Day');

      final cue = nextUp(session())!;
      expect(cue.kind, CueKind.hold);
      expect(cue.seconds, 45);
      expect(cue.reps, isNull, reason: 'a plank is not forty-five of anything');
    });

    test('a bodyweight movement names no weight', () async {
      final ctl = await startPush();
      // Drop the bench to nothing, which is what a bodyweight slot looks like.
      ctl.setWorkingWeight(0, 0);

      final cue = nextUp(session())!;
      expect(cue.weightKg, isNull);
    });

    test('when everything is logged there is nothing left to say', () async {
      final ctl = await startPush();
      for (var ei = 0; ei < session().exercises.length; ei++) {
        for (var wi = 0; wi < session().exercises[ei].warmups.length; wi++) {
          ctl.cycleWarmup(ei, wi);
        }
        for (var si = 0; si < session().exercises[ei].sets.length; si++) {
          ctl.cycleSet(ei, si);
        }
      }

      expect(nextUp(session())!.kind, CueKind.finished);
    });

    test('missed seeds one short of the goal, never below nothing', () async {
      await startPush();
      final cue = nextUp(session(), restLeft: 0)!;

      // A counted set: most of it got done, which is why the button was
      // reached for rather than the app.
      expect(missedSeed((
        kind: CueKind.lift,
        exercise: 'Bench Press',
        exerciseSeedKey: null,
        warmup: false,
        exerciseIndex: 0,
        setIndex: 0,
        setCount: 4,
        weightKg: 80,
        reps: 8,
        seconds: null,
        restLeft: null,
      )), 7);

      // A goal of one has nowhere to go but zero.
      expect(missedSeed((
        kind: CueKind.lift,
        exercise: 'x',
        exerciseSeedKey: null,
        warmup: false,
        exerciseIndex: 0,
        setIndex: 0,
        setCount: 4,
        weightKg: null,
        reps: 1,
        seconds: null,
        restLeft: null,
      )), 0);

      // A hold is not guessable — how long you held it is not a number
      // anything can seed.
      expect(missedSeed((
        kind: CueKind.hold,
        exercise: 'Plank',
        exerciseSeedKey: null,
        warmup: false,
        exerciseIndex: 0,
        setIndex: 0,
        setCount: 2,
        weightKg: null,
        reps: null,
        seconds: 45,
        restLeft: null,
      )), isNull);

      expect(cue.exercise, isNotEmpty);
    });
  });

  group('The shade logs a set without the app being open', () {
    // The buttons act on nextUp rather than on a set they were told about: the
    // press comes from a notification that may be a moment out of date, and the
    // session is the only thing that knows what is actually outstanding.

    test('Done logs the outstanding set at its goal and starts the rest',
        () async {
      final ctl = await startPush();
      // Clear Bench's ramp so the working set is what is outstanding.
      for (var wi = 0; wi < session().exercises[0].warmups.length; wi++) {
        ctl.cycleWarmup(0, wi);
      }
      ctl.stopRest(tone: false);

      ctl.logNextAtGoal();

      expect(session().exercises[0].sets[0].logged, benchGoal);
      expect(session().exercises[0].sets[0].missedGoal, isFalse,
          reason: 'at the goal is a hit');
      expect(session().restLeft, greaterThan(0),
          reason: 'the rest starts without the app being touched');
    });

    test('Done walks the warm-up rungs first', () async {
      final ctl = await startPush();
      ctl.logNextAtGoal();

      final ramp = session().exercises[0].warmups;
      expect(ramp.first.logged, ramp.first.goal);
      expect(session().exercises[0].sets[0].done, isFalse,
          reason: 'the work waits for the ramp');
    });

    test('Done does nothing while a rest is running', () async {
      final ctl = await startPush();
      ctl.startRest(90, null);
      final before = session().doneSets;

      ctl.logNextAtGoal();

      expect(session().doneSets, before,
          reason: 'you are resting; there is nothing to claim yet');
    });

    test('Done refuses a hold, which is not a number it can invent', () async {
      container = containerFor(db);
      final wid = await buildPlankWorkout(db, holdSeconds: 45);
      final ctl = container!.read(activeWorkoutProvider.notifier);
      await ctl.start(workoutId: wid, name: 'Plank Day');

      ctl.logNextAtGoal();

      expect(session().exercises[0].sets[0].done, isFalse);
    });

    test('Missed logs one short, and starts the rest too', () async {
      final ctl = await startPush();
      for (var wi = 0; wi < session().exercises[0].warmups.length; wi++) {
        ctl.cycleWarmup(0, wi);
      }
      ctl.stopRest(tone: false);

      ctl.logNextAsMissed();

      expect(session().exercises[0].sets[0].logged, benchGoal - 1);
      expect(session().exercises[0].sets[0].missedGoal, isTrue,
          reason: 'it lands gold, which is the point of seeding it short');
      // You have just finished a set. That the number wants correcting does not
      // make the rest between sets any shorter, and a board you come back to
      // with no clock running is one where you have to start it by hand.
      expect(session().restLeft, greaterThan(0));
    });

    test('nothing reaches the database before Finish', () async {
      final ctl = await startPush();
      ctl.logNextAtGoal();
      ctl.logNextAsMissed();

      expect(await db.watchHistory().first, isEmpty);
      expect(await db.watchSessionCount().first, 0);
    });
  });

  group('What the shade says', () {
    // The words are the catalogue's, so the assertions ask it for them rather
    // than re-typing the English: what the shade has to get right is which
    // message it picks and what it fills in — the load in the unit on the
    // phone, which set of how many, and whether a rest is running.
    final l10n = l10nFor();
    String load(String amount, String unit) =>
        l10n.unitWeightShort(amount, unit);

    WorkoutCue cue({
      CueKind kind = CueKind.lift,
      String exercise = 'Bench Press',
      bool warmup = false,
      int setIndex = 0,
      int setCount = 4,
      double? weightKg,
      int? reps,
      int? seconds,
      int? restLeft,
    }) =>
        (
          kind: kind,
          exercise: exercise,
          exerciseSeedKey: null,
          warmup: warmup,
          exerciseIndex: 0,
          setIndex: setIndex,
          setCount: setCount,
          weightKg: weightKg,
          reps: reps,
          seconds: seconds,
          restLeft: restLeft,
        );

    test('a loaded set reads as a bar you could go and load', () {
      expect(describeCue(l10n, cue(weightKg: 80, reps: 8), 'kg'),
          l10n.shadeSetWeightReps(load('80', l10n.unitKgSuffix), 8));
    });

    test('and in the unit on the phone, not the one in the database', () {
      // 80 kg is 176.4 lb — the number you would set the bar to.
      expect(describeCue(l10n, cue(weightKg: 80, reps: 8), 'lb'),
          l10n.shadeSetWeightReps(load('176.4', l10n.unitLbSuffix), 8));
    });

    test('a bodyweight movement says so rather than saying nothing', () {
      expect(describeCue(l10n, cue(reps: 12), 'kg'),
          l10n.shadeSetBodyweightReps(12));
    });

    test('a hold is seconds, and a loaded hold is both', () {
      expect(describeCue(l10n, cue(kind: CueKind.hold, seconds: 45), 'kg'),
          l10n.unitSecondsShort('45'));
      expect(
        describeCue(
            l10n, cue(kind: CueKind.hold, weightKg: 20, seconds: 45), 'kg'),
        l10n.shadeSetWeightSeconds(load('20', l10n.unitKgSuffix), 45),
      );
    });

    test('a set to do is described, and nothing is called next', () {
      expect(shadeText(l10n, cue(weightKg: 80, reps: 8), 'kg'),
          l10n.shadeSetWeightReps(load('80', l10n.unitKgSuffix), 8));
    });

    test('and the bold line says which set of how many', () {
      // Four identical sets of bench read identically from a pocket without
      // it — see issue #65.
      expect(
        shadeTitle(l10n, cue(weightKg: 80, reps: 8, setIndex: 3, setCount: 5)),
        l10n.shadeWhereExerciseSet('Bench Press', 4, 5),
      );
    });

    test('a warm-up rung counts the rungs, not the working sets', () {
      expect(
        shadeTitle(l10n, cue(warmup: true, setIndex: 1, setCount: 3)),
        l10n.shadeWhereWarmupSet('Bench Press', 2, 3),
      );
    });

    test('resting, the line names the exercise as well as the load', () {
      // The bold line is the countdown while a rest runs, so this is the only
      // line the movement can be named on — and a weight and a rep count
      // belonging to nothing is not an instruction (issue #62).
      expect(
        shadeText(
            l10n,
            cue(
                kind: CueKind.resting,
                weightKg: 80,
                reps: 8,
                setIndex: 3,
                setCount: 5,
                restLeft: 40),
            'kg'),
        l10n.shadeNextLine(
          l10n.shadeWhereExerciseSet('Bench Press', 4, 5),
          l10n.shadeSetWeightReps(load('80', l10n.unitKgSuffix), 8),
        ),
      );
      expect(shadeTitle(l10n, cue(kind: CueKind.resting, restLeft: 40)),
          l10n.shadeRestTitle(fmtDuration(40)));
    });

    test('and says when what is next is a warm-up rung', () {
      expect(
        shadeText(
          l10n,
          cue(
              kind: CueKind.resting,
              warmup: true,
              weightKg: 60,
              reps: 5,
              setIndex: 0,
              setCount: 3,
              restLeft: 40),
          'kg',
        ),
        l10n.shadeNextLine(
          l10n.shadeWhereWarmupSet('Bench Press', 1, 3),
          l10n.shadeSetWeightReps(load('60', l10n.unitKgSuffix), 5),
        ),
      );
    });

    test('a rest offers the rest, not a set to log', () {
      // The same three controls the screen has, so the two places a rest can be
      // nudged from do not disagree about what a nudge is.
      expect(
        shadeButtons(l10n, cue(kind: CueKind.resting, restLeft: 40))
            .map((b) => b.id),
        [
          WorkoutShade.restSubAction,
          WorkoutShade.restAddAction,
          WorkoutShade.restSkipAction,
        ],
      );
    });

    test('a set to do offers Done and Missed', () {
      expect(
        shadeButtons(l10n, cue(weightKg: 80, reps: 8)).map((b) => b.id),
        [WorkoutShade.doneAction, WorkoutShade.missedAction],
      );
    });

    test('a hold offers the one button that opens the app', () {
      // Start, which logs nothing: how long you held it is the measurement, and
      // nothing in a pocket can invent it.
      expect(
        shadeButtons(l10n, cue(kind: CueKind.hold, seconds: 45)).map((b) => b.id),
        [WorkoutShade.startAction],
      );
    });

    test('and a finished session offers nothing', () {
      expect(shadeButtons(l10n, cue(kind: CueKind.finished)), isEmpty);
    });
  });

  group('The shade runs the rest', () {
    // The rest is the one stretch of a session the phone is certainly not in
    // your hand for — see issue #62.

    test('Skip ends it', () async {
      final ctl = await startPush();
      ctl.startRest(90, null);

      applyShadeAction(ctl, WorkoutShade.restSkipAction);

      expect(session().restLeft, 0);
    });

    test('+30s adds to what is left', () async {
      final ctl = await startPush();
      ctl.startRest(90, null);

      applyShadeAction(ctl, WorkoutShade.restAddAction);

      expect(session().restLeft, 90 + WorkoutShade.restStepSeconds);
    });

    test('and a press nobody recognises does nothing to the session', () async {
      final ctl = await startPush();
      ctl.startRest(90, null);

      applyShadeAction(ctl, 'something_else');

      expect(session().restLeft, 90);
      expect(session().doneSets, 0);
    });
  });

  group('The rest ding reaches you with the phone in a pocket', () {
    // Issue #61. A media player is the right instrument while you are looking
    // at the board and the wrong one with the screen off, so the two are a
    // pair: the tone on screen, a notification off it, never both.
    late _RecordingAlarm alarm;
    late _RecordingTone tone;

    Future<ActiveWorkoutController> startPushWithPhone(
        {required bool onScreen}) async {
      alarm = _RecordingAlarm();
      tone = _RecordingTone();
      container = containerFor(db, overrides: [
        restAlarmProvider.overrideWithValue(alarm),
        restToneProvider.overrideWithValue(tone),
        appOnScreenProvider.overrideWithValue(() => onScreen),
      ]);
      final wid = await workoutIdNamed(db, 'Push');
      final ctl = container!.read(activeWorkoutProvider.notifier);
      await ctl.start(workoutId: wid, name: 'Push');
      return ctl;
    }

    test('a rest running out off screen rings, and says what is next',
        () async {
      final ctl = await startPushWithPhone(onScreen: false);
      ctl.startRest(90, null);

      ctl.stopRest();

      expect(alarm.rung, hasLength(1));
      expect(alarm.rung.single, contains('Bench Press'),
          reason: '"rest over" makes you open the app to find out what for');
      expect(tone.played, 0, reason: 'one ding, not two');
    });

    test('with the app on screen it does not — the tone is enough', () async {
      final ctl = await startPushWithPhone(onScreen: true);
      ctl.startRest(90, null);

      ctl.stopRest();

      expect(alarm.rung, isEmpty);
      expect(tone.played, 1);
    });

    test('skipping from the shade sounds, like every other end of a rest',
        () async {
      // It used to be silent, on the argument that whoever pressed Skip knows.
      // What that produced was the one button in the app that is only ever
      // pressed from a pocket, with no feedback of any kind.
      final ctl = await startPushWithPhone(onScreen: false);
      ctl.startRest(90, null);

      applyShadeAction(ctl, WorkoutShade.restSkipAction);

      expect(alarm.rung, hasLength(1));
      expect(session().restLeft, 0);
    });

    test('and starting the next rest takes the old one down', () async {
      final ctl = await startPushWithPhone(onScreen: true);
      ctl.startRest(90, null);
      ctl.stopRest();

      ctl.startRest(90, null);

      expect(alarm.cleared, greaterThan(0));
    });
  });

  group('A rest says what to do with it', () {
    // The four cases from features/index.html#sec04: another rung, the work, another set, a
    // different movement. What differs between them is what you have to set up,
    // which is the only part worth a line of screen.

    test('between warm-up rungs it names the next rung', () async {
      await startPush();
      final ramp = session().exercises[0].warmups;
      expect(ramp.length, greaterThan(1));

      final p = session().restAfterWarmup(0, 0);
      expect(p.purpose, RestPurpose.anotherWarmup);
      expect(p.weightKg, ramp[1].weight,
          reason: 'the load about to go on the bar, not the one just lifted');
    });

    test('after the last rung it names the working weight', () async {
      await startPush();
      final last = session().exercises[0].warmups.length - 1;

      final p = session().restAfterWarmup(0, last);
      expect(p.purpose, RestPurpose.theWorkingSet);
      expect(p.weightKg, benchWeight);
    });

    test('between working sets there is nothing to set up', () async {
      final ctl = await startPush();
      ctl.cycleSet(0, 0);

      final p = session().restAfterSet(0, 0);
      expect(p.purpose, RestPurpose.anotherSet);
      expect(p.weightKg, isNull);
      expect(p.exercise, isNull);
    });

    test('the last set of an exercise points at the next movement', () async {
      final ctl = await startPush();
      // Bench has four sets; log all of them.
      for (var si = 0; si < 4; si++) {
        ctl.cycleSet(0, si);
      }

      final p = session().restAfterSet(0, 3);
      expect(p.purpose, RestPurpose.nextExercise);
      expect(p.exercise, session().exercises[1].name);
    });

    test('an exercise already finished is not what comes next', () async {
      final ctl = await startPush();
      for (var si = 0; si < 4; si++) {
        ctl.cycleSet(0, si); // Bench, done
      }
      for (var si = 0; si < 4; si++) {
        ctl.cycleSet(1, si); // Overhead Press, also done
      }

      // Walking to the machine you have already finished with is not advice.
      final p = session().restAfterSet(0, 3);
      expect(p.exercise, session().exercises[2].name);
    });

    testWidgets('and the banner says so, in the display unit', (tester) async {
      await pumpPushScreen(tester);

      // Between working sets: nothing to change.
      await tester.tap(repsCell('0-0-Bench Press'));
      await tester.pump();
      expect(find.text('Rest, then lift.'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pump();

      // After the last warm-up rung: the working weight is next.
      await tester.tap(find.text('WARM-UP').first);
      await tester.pump();
      final last = session().exercises[0].warmups.length - 1;
      await tester.tap(repsCell('w0-$last-Bench Press'));
      await tester.pump();
      expect(find.text('Set up 80 kg, rest, then lift.'), findsOneWidget);

      await stopAll(tester);
    });

    testWidgets('the weight is named in pounds when that is the unit',
        (tester) async {
      await tester.runAsync(() => db.setWeightUnit('lb'));
      await pumpPushScreen(tester);

      await tester.tap(find.text('WARM-UP').first);
      await tester.pump();
      final last = session().exercises[0].warmups.length - 1;
      await tester.tap(repsCell('w0-$last-Bench Press'));
      await tester.pump();

      // 80 kg is 176.4 lb — the number you would set the bar to, not the
      // number the database happens to hold.
      expect(find.textContaining('Set up 176.4 lb'), findsOneWidget);

      await stopAll(tester);
    });
  });

  group('A held set times itself', () {
    /// The Plank day, mounted and ready to tap. Two sets of a 45-second hold.
    Future<void> pumpPlank(WidgetTester tester) async {
      await tester.runAsync(() async {
        final wid = await buildPlankWorkout(db);
        container = containerFor(db);
        await container!
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: wid, name: 'Plank Day');
      });
      await tester.pumpWidget(appUnder(container!, const WorkoutScreen()));
      await tester.pump();
    }

    testWidgets('tap starts a count-up; tap again logs what it read',
        (tester) async {
      // A hold is a duration you measure, not a count you claim — so the cell
      // is a stopwatch rather than the rep cycle.
      await pumpPlank(tester);
      final cell = repsCell('0-0-Plank');

      // Untouched, it shows the goal.
      expect(find.descendant(of: cell, matching: find.text('45s')),
          findsOneWidget);

      await tester.tap(cell);
      await tester.pump();
      expect(find.descendant(of: cell, matching: find.text('0s')),
          findsOneWidget,
          reason: 'the stopwatch starts at zero, not at the goal');
      expect(session().exercises[0].sets[0].done, isFalse,
          reason: 'a hold in progress is not a logged set');

      // It counts up a second at a time.
      await tester.pump(const Duration(seconds: 12));
      expect(find.descendant(of: cell, matching: find.text('12s')),
          findsOneWidget);

      // And stopping logs exactly what it read.
      await tester.tap(cell);
      await tester.pump();
      expect(session().exercises[0].sets[0].logged, 12);

      await stopAll(tester);
    });

    testWidgets('stopping a hold starts the rest', (tester) async {
      await pumpPlank(tester);
      final cell = repsCell('0-0-Plank');

      await tester.tap(cell);
      await tester.pump();
      // No rest while the hold is running — you are still in the set.
      expect(find.byKey(kRestBannerKey), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await tester.tap(cell);
      await tester.pump();

      expect(find.byKey(kRestBannerKey), findsOneWidget);
      await stopAll(tester);
    });

    testWidgets('tapping a logged hold clears it, ready to run again',
        (tester) async {
      await pumpPlank(tester);
      final cell = repsCell('0-0-Plank');

      await tester.tap(cell);
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(cell);
      await tester.pump();
      expect(session().exercises[0].sets[0].logged, 3);

      // The same "undo by tapping" the rep cycle ends on.
      await tester.tap(cell);
      await tester.pump();
      expect(session().exercises[0].sets[0].logged, isNull);

      await stopAll(tester);
    });

    testWidgets('only one hold runs at a time', (tester) async {
      // You cannot be in two planks at once — and the one you were in did
      // happen, so it is logged rather than thrown away.
      await pumpPlank(tester);

      await tester.tap(repsCell('0-0-Plank'));
      await tester.pump(const Duration(seconds: 7));
      await tester.tap(repsCell('0-1-Plank'));
      await tester.pump();

      expect(session().exercises[0].sets[0].logged, 7,
          reason: 'the abandoned hold is logged, not lost');
      expect(session().exercises[0].sets[1].done, isFalse,
          reason: 'and the new one is running, not logged');

      await tester.pump(const Duration(seconds: 4));
      await tester.tap(repsCell('0-1-Plank'));
      await tester.pump();
      expect(session().exercises[0].sets[1].logged, 4);

      await stopAll(tester);
    });

    testWidgets('a duration can still be typed in by hand', (tester) async {
      // For the hold you timed on the clock on the wall.
      await pumpPlank(tester);

      await tester.longPress(repsCell('0-0-Plank'));
      await frames(tester);
      expect(find.text('Seconds held'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '52');
      await tester.tap(find.text('Save'));
      await frames(tester);

      expect(session().exercises[0].sets[0].logged, 52);
      await stopAll(tester);
    });

    testWidgets('the hint says how a hold is logged', (tester) async {
      await pumpPlank(tester);
      expect(find.textContaining('tap to start, tap to stop'), findsOneWidget);
      await stopAll(tester);
    });

    testWidgets('and does not offer it to a session with nothing held',
        (tester) async {
      await pumpPushScreen(tester);
      expect(find.textContaining('tap to start, tap to stop'), findsNothing);
      await stopAll(tester);
    });
  });

  group('And it makes a sound when it is over', () {
    test('there is no switch on it, and nothing to turn off', () async {
      // A rest timer that ends silently is a rest timer that does not work.
      // The phone's own volume keys, silent mode and Do Not Disturb are the
      // controls for this, and both routes follow them by being alarms.
      final tone = RestTone(player: _NoPlayer());
      addTearDown(tone.dispose);

      // Nothing to pass, and nothing thrown: on a runner with no audio channel
      // the platform check turns it into a no-op.
      await expectLater(tone.play(), completes);
    });
  });

  group('A short set says so without relying on its colour', () {
    testWidgets('a set that fell short carries a downward arrow; a hit does not',
        (tester) async {
      // Green and gold differing only in hue is the one pair a colour-blind
      // reader cannot separate, and this column is the app's most-read signal.
      await pumpPushScreen(tester);

      // Set 1 at the goal: a hit, and nothing but colour to say so.
      await tester.tap(repsCell('0-0-Bench Press'));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('0-0-Bench Press')),
          matching: find.byIcon(Icons.arrow_downward_rounded),
        ),
        findsNothing,
      );

      // Logging set 1 started a rest, and the bar it docked took the bottom of
      // the board with it. Scrolling to the next row is exactly what a lifter
      // does — and what the bar taking real room is for.
      await tester.ensureVisible(repsCell('0-1-Bench Press'));
      await tester.pump();

      // Set 2 tapped twice: one rep short.
      await tester.tap(repsCell('0-1-Bench Press'));
      await tester.pump();
      await tester.tap(repsCell('0-1-Bench Press'));
      await tester.pump();

      final row = session().exercises[0].sets[1];
      expect(row.missedGoal, isTrue);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('0-1-Bench Press')),
          matching: find.byIcon(Icons.arrow_downward_rounded),
        ),
        findsOneWidget,
        reason: 'nothing but the hue distinguishes a short set',
      );

      await stopAll(tester);
    });
  });

  group('The resume bar takes room rather than covering things', () {
    /// Mounts [routes] under the overlay, with the same router the overlay is
    /// told to read — the app's global one belongs to the app, not to a test.
    Future<GoRouter> pumpUnderOverlay(
      WidgetTester tester,
      String at,
      List<RouteBase> routes,
    ) async {
      final router = GoRouter(initialLocation: at, routes: routes);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container!,
        child: MaterialApp.router(
          theme: AppTheme.build(kDefaultPalette),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: kTestDelegates,
          routerConfig: router,
          builder: (context, child) =>
              ResumeWorkoutOverlay(router: router, child: child!),
        ),
      ));
      await frames(tester);
      return router;
    }

    testWidgets('a pushed screen ends above the bar, not under it',
        (tester) async {
      await tester.runAsync(() async {
        container = containerFor(db);
        await container!.read(activeWorkoutProvider.notifier).start(
              workoutId: await workoutIdNamed(db, 'Push'),
              name: 'Push',
            );
      });
      await pumpUnderOverlay(tester, '/library', [
        GoRoute(path: '/library', builder: (_, _) => const LibraryScreen()),
      ]);

      expect(find.byKey(resumeWorkoutBarKey), findsOneWidget);
      final bar = tester.getRect(find.byKey(resumeWorkoutBarKey));
      final list = tester.getRect(find.byType(ListView).first);
      expect(list.bottom, lessThanOrEqualTo(bar.top + 0.5),
          reason: 'the list runs on underneath the bar');

      await stopAll(tester);
    });

    testWidgets('a tab screen keeps it above the nav bar and clear of the list',
        (tester) async {
      // A tab screen on a small phone is the worst case there is: a navigation
      // bar and the resume bar out of 720 logical pixels.
      tester.view.physicalSize = const Size(390, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.runAsync(() async {
        container = containerFor(db);
        await container!.read(activeWorkoutProvider.notifier).start(
              workoutId: await workoutIdNamed(db, 'Push'),
              name: 'Push',
            );
      });
      await pumpUnderOverlay(tester, '/today', [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => HomeShell(shell: shell),
          branches: [
            for (final p in const ['/today', '/routines', '/history', '/profile'])
              StatefulShellBranch(
                routes: [GoRoute(path: p, builder: (_, _) => const TodayScreen())],
              ),
          ],
        ),
      ]);

      // One bar, not two: the shell owns it here and the overlay stands off.
      expect(find.byKey(resumeWorkoutBarKey), findsOneWidget);
      final bar = tester.getRect(find.byKey(resumeWorkoutBarKey));
      final nav = tester.getRect(find.byType(NavigationBar));
      final list = tester.getRect(find.byType(ListView).first);

      expect(bar.bottom, lessThanOrEqualTo(nav.top + 0.5),
          reason: 'the bar belongs above the navigation bar');
      expect(list.bottom, lessThanOrEqualTo(bar.top + 0.5),
          reason: "Today's list runs on underneath the bar");

      await stopAll(tester);
    });

    testWidgets('with no session live nothing is reserved at all',
        (tester) async {
      container = containerFor(db);
      await pumpUnderOverlay(tester, '/library', [
        GoRoute(path: '/library', builder: (_, _) => const LibraryScreen()),
      ]);

      expect(find.byKey(resumeWorkoutBarKey), findsNothing);
      final list = tester.getRect(find.byType(ListView).first);
      expect(list.bottom,
          closeTo(tester.getSize(find.byType(MaterialApp)).height, 1.0));

      await stopAll(tester);
    });
  });

  group('a personal note is read and written from the board', () {
    /// The note the library holds for [name] right now.
    Future<String?> storedNote(WidgetTester tester, String name) async =>
        (await tester.runAsync(() => exerciseNamed(db, name)))!.notes;

    Future<void> noteOn(WidgetTester tester, String name, String text) =>
        tester.runAsync(() async {
          final e = await exerciseNamed(db, name);
          await db.setExerciseNotes(e.id, text);
        });

    testWidgets('a note is readable without leaving the workout',
        (tester) async {
      await noteOn(tester, 'Bench Press', 'Rack pin 7, bench squeaks');
      await pumpPushScreen(tester);

      // One tap, on the screen you are already on.
      await tester.tap(find.byTooltip('My note').first);
      await frames(tester);

      expect(find.text('Rack pin 7, bench squeaks'), findsOneWidget);

      await stopAll(tester);
    });

    testWidgets('a movement with no note still offers somewhere to add one',
        (tester) async {
      await pumpPushScreen(tester);

      // Nothing to read, so nothing claims there is — but there is somewhere
      // to write the first one.
      expect(find.byTooltip('My note'), findsNothing);
      expect(find.byTooltip('Add a note'), findsWidgets);

      await tester.tap(find.byTooltip('Add a note').first);
      await frames(tester);
      await tester.enterText(find.byType(TextField), 'Seat 4, pin 7');
      await tester.tap(find.text('Save'));
      await pumpThroughDatabase(tester);

      // Written through to the library, without leaving the workout — and the
      // icon now says there is one to read.
      expect(await storedNote(tester, 'Bench Press'), 'Seat 4, pin 7');
      expect(find.byTooltip('My note'), findsOneWidget);

      await stopAll(tester);
    });

    testWidgets('one tap brings it up, and there is no second icon',
        (tester) async {
      // It used to take two: the first tap unfolded the note and grew a pencil,
      // and the pencil was the thing you were reaching for.
      await noteOn(tester, 'Bench Press', 'Rack pin 7');
      await pumpPushScreen(tester);
      expect(find.byTooltip('Edit note'), findsNothing);

      await tester.tap(find.byTooltip('My note').first);
      await frames(tester);

      // The note is up, and it is the thing you can change.
      expect(find.text('Rack pin 7'), findsOneWidget);
      expect(find.byTooltip('Edit note'), findsNothing,
          reason: 'one icon, one meaning');

      await tester.enterText(find.byType(TextField), 'Rack pin 8');
      await tester.tap(find.text('Save'));
      await pumpThroughDatabase(tester);

      expect(await storedNote(tester, 'Bench Press'), 'Rack pin 8');

      await stopAll(tester);
    });

    testWidgets('a note written elsewhere reaches a session already running',
        (tester) async {
      await pumpPushScreen(tester);
      expect(find.byTooltip('My note'), findsNothing);

      // Written from the library while the session runs.
      await noteOn(tester, 'Bench Press', 'Bench squeaks');
      await pumpThroughDatabase(tester);

      await tester.tap(find.byTooltip('My note').first);
      await frames(tester);
      expect(find.text('Bench squeaks'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await frames(tester);

      await stopAll(tester);
    });
  });

  group('There is only ever one resume bar on screen', () {
    // features/index.html#sec04: "Two mount points draw it and exactly one may be live at a
    // time — including *during* a navigation... the count is one whether the
    // app is settled or mid-transition."
    //
    // Every other resume-bar test asserts at rest, which is exactly how this
    // was missed: the route flips the instant the push begins, but the tab
    // screen keeps painting for the length of the slide, so both mount points
    // believe the bar is theirs for a few hundred milliseconds.

    /// The app as it really is: the tab shell (which mounts the bar above the
    /// navigation bar) underneath the overlay (which mounts it as the app's
    /// last row everywhere else), plus a screen outside the shell to push.
    Future<GoRouter> pumpShellWithSomewhereToGo(WidgetTester tester) async {
      await tester.runAsync(() async {
        container = containerFor(db);
        await container!.read(activeWorkoutProvider.notifier).start(
              workoutId: await workoutIdNamed(db, 'Push'),
              name: 'Push',
            );
      });
      final router = GoRouter(initialLocation: '/today', routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => HomeShell(shell: shell),
          branches: [
            for (final p in const ['/today', '/routines', '/history', '/profile'])
              StatefulShellBranch(
                routes: [GoRoute(path: p, builder: (_, _) => const TodayScreen())],
              ),
          ],
        ),
        GoRoute(path: '/library', builder: (_, _) => const LibraryScreen()),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container!,
        child: MaterialApp.router(
          theme: AppTheme.build(kDefaultPalette),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: kTestDelegates,
          routerConfig: router,
          builder: (context, child) =>
              ResumeWorkoutOverlay(router: router, child: child!),
        ),
      ));
      await frames(tester);
      return router;
    }

    /// Walks half a second of animation 50 ms at a time, failing on the first
    /// frame that draws a second bar. A settle would skip straight past the
    /// frames this is about.
    Future<void> everyFrameOf(WidgetTester tester, String what) async {
      for (var i = 1; i <= 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          find.byKey(resumeWorkoutBarKey),
          findsOneWidget,
          reason: '$what, ${i * 50} ms in — one bar, settled or mid-slide',
        );
      }
    }

    testWidgets('pushing a screen over a tab never draws two', (tester) async {
      final router = await pumpShellWithSomewhereToGo(tester);
      expect(find.byKey(resumeWorkoutBarKey), findsOneWidget,
          reason: 'at rest on a tab root the shell owns it');

      router.push('/library');
      await everyFrameOf(tester, 'pushing /library over /today');

      await stopAll(tester);
    });

    testWidgets('and neither does popping back to it', (tester) async {
      final router = await pumpShellWithSomewhereToGo(tester);
      router.push('/library');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      router.pop();
      await everyFrameOf(tester, 'popping back to /today');

      await stopAll(tester);
    });
  });

  group('The rest bar says its whole line', () {
    // The caption is the only thing on the bar with any length to it, and it is
    // the only thing on it worth reading — so it gets a line of its own, the
    // full width of a docked bar, and it is never cut off. "Rest, then lift."
    // was wrapping onto two lines on a 390-wide phone at ordinary text size.
    const longName = 'Barbell Romanian Deadlift';
    const shortName = 'Row';

    /// The caption's own line height at [scale].
    double captionLine(double scale) => 11 * 1.3 * scale;

    /// Starts a day whose second movement is [next], logs the first exercise's
    /// only set, and measures the rest banner that opens.
    ///
    /// Everything the screen does — mount, tap, unmount — happens inside the
    /// caller's overflow interception, so a banner that blows out reports one
    /// captured line rather than dumping a disposed render tree to the console.
    Future<BannerGeometry> bannerAfterLastSetOf(
      WidgetTester tester,
      String next,
      double scale,
    ) async {
      late int wid;
      await tester.runAsync(() async {
        wid = await buildTwoExerciseWorkout(db, second: next, routine: next);
      });
      final c = containerFor(db);
      // Torn down after the test rather than inside it: disposing a container
      // schedules drift's stream cleanup, and a timer left pending when the
      // body returns fails the test for the wrong reason.
      addTearDown(c.dispose);
      // Registered second, so it runs first: the tree comes down before the
      // container it reads from goes away, even when an expectation above has
      // already thrown.
      addTearDown(() => stop(tester));
      await tester.runAsync(
        () => c.read(activeWorkoutProvider.notifier).start(
              workoutId: wid,
              name: 'Two Day',
            ),
      );

      await tester.pumpWidget(
        appUnder(c, const WorkoutScreen(), textScale: scale),
      );
      await tester.pump();
      // At a large text scale the first set row sits below the fold; scrolling
      // to it is what a lifter would do, and the banner is what is under test.
      await tester.ensureVisible(repsCell('0-0-Triceps Pushdown'));
      await tester.pump();
      await tester.tap(repsCell('0-0-Triceps Pushdown'));
      await tester.pump();

      expect(find.byKey(kRestBannerKey), findsOneWidget);
      final geometry = (
        banner: tester.getRect(find.byKey(kRestBannerKey)),
        caption: tester.getRect(
          find.text('Set up $next, rest, then lift.'),
        ),
        pills: {
          for (final label in const ['−15s', '+15s', 'Skip'])
            label: tester.getRect(find.widgetWithText(OutlinedButton, label)),
        },
      );

      c.read(activeWorkoutProvider.notifier).discard();
      await stop(tester);
      return geometry;
    }

    Future<void> checkAtScale(WidgetTester tester, double scale) async {
      // A phone, not the 800×600 the test binding defaults to: a caption only
      // has a name's worth of length to it on the width it actually gets.
      tester.view.physicalSize = const Size(390, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late BannerGeometry short;
      late BannerGeometry long;
      final overflows = await overflowsDuring(() async {
        short = await bannerAfterLastSetOf(tester, shortName, scale);
        long = await bannerAfterLastSetOf(tester, longName, scale);
      });

      expect(overflows, isEmpty,
          reason: 'the rest bar overflowed at ${scale}x');

      // The bar is the board's last row, not something that runs off it.
      expect(long.banner.top, greaterThanOrEqualTo(0.0),
          reason: 'the bar grew off the top of the screen at ${scale}x');

      // At the size the phone ships with, a short caption is one line. That is
      // the whole complaint: "Rest, then lift." came back on two.
      //
      // Above 1.0 it is allowed to wrap — "Set up Row, rest, then lift." is 28
      // characters, and at 2× on a 390 px phone no font puts that on one line.
      // What must stay true at every scale is that it wraps rather than being
      // cut: the caption has no maxLines, so there is no ellipsis to find, and
      // the checks below hold the three buttons to their size while it grows.
      expect(short.caption.height,
          lessThan(captionLine(scale) * (scale <= 1.0 ? 1.9 : 3.9)),
          reason: 'the short caption ran past three lines at ${scale}x');

      for (final label in const ['−15s', '+15s', 'Skip']) {
        final a = short.pills[label]!;
        final b = long.pills[label]!;
        expect(b.size.width, closeTo(a.size.width, 0.5),
            reason: '$label was squeezed by the name above it at ${scale}x');
        expect(b.size.height, closeTo(a.size.height, 0.5),
            reason: '$label lost height to the caption at ${scale}x');
        expect(b.left, closeTo(a.left, 0.5),
            reason: '$label moved along the bar at ${scale}x');
      }
    }

    testWidgets('a long name pushes nothing about, at ordinary text size',
        (tester) async {
      await checkAtScale(tester, 1.0);
    });

    testWidgets('and at the largest text the app renders', (tester) async {
      // The caption takes however many lines it needs here, and the bar takes
      // the room from the board rather than from its own controls.
      await checkAtScale(tester, kMaxTextScale);
    });

    testWidgets('the whole line is on screen, uncut', (tester) async {
      // Cutting the caption off with an ellipsis defeats the only thing it is
      // there for: "Set up ..., rest, then lift" says nothing to set up.
      late int wid;
      await tester.runAsync(() async {
        wid = await buildTwoExerciseWorkout(
          db,
          second: longName,
          routine: longName,
        );
      });
      container = containerFor(db);
      await tester.runAsync(
        () => container!.read(activeWorkoutProvider.notifier).start(
              workoutId: wid,
              name: 'Two Day',
            ),
      );
      await tester.pumpWidget(appUnder(container!, const WorkoutScreen()));
      await tester.pump();
      await tester.tap(repsCell('0-0-Triceps Pushdown'));
      await tester.pump();

      final caption = tester.widget<Text>(
        find.text('Set up $longName, rest, then lift.'),
      );
      // Read first, torn down second: an expectation that throws must not take
      // the live session's tree with it.
      await stopAll(tester);

      expect(caption.maxLines, isNull, reason: 'it wraps as far as it needs to');
      expect(caption.overflow, isNot(TextOverflow.ellipsis));
    });

    testWidgets('"Rest, then lift." is one line on a 390-wide phone',
        (tester) async {
      // The reported case, at the phone's own text size: between two working
      // sets there is nothing to set up, and the caption is six words long.
      tester.view.physicalSize = const Size(390, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpPushScreen(tester);
      await tester.ensureVisible(repsCell('0-0-Bench Press'));
      await tester.pump();
      await tester.tap(repsCell('0-0-Bench Press'));
      await tester.pump();

      final line = tester.getSize(find.text('Rest, then lift.'));
      expect(line.height, lessThan(captionLine(1.0) * 1.9),
          reason: 'the caption wrapped onto a second line');

      await stopAll(tester);
    });
  });

  group('The rest tone is one note, not two', () {
    // features/index.html#sec04: "A rest ending is one event, so it gets one ding: a single
    // pitch with a fast attack and a short decay, done inside a third of a
    // second."
    //
    // Read straight off the shipped asset, because the asset *is* the design —
    // a wav is a binary nobody can review, so the only honest check is on the
    // samples themselves. Nothing here pins the frequency: the generator picks
    // that.

    /// The size of the two-note figure this replaces. Not a target — a ceiling:
    /// a shorter tone at the same format cannot be bigger than the one it is
    /// cut down from.
    const twoNoteBytes = 52964;

    /// The longest a ding may last, from `features/index.html#sec04`: "under half a second".
    /// It was a third of a second and was reported as too quiet — half of
    /// which is duration, not amplitude (issue #61).
    const maxSeconds = 0.5;

    final wav = _RestTone.read();

    test('it is a short, plain PCM ding', () {
      expect(wav.bitsPerSample, 16, reason: 'plain 16-bit PCM, or the maths '
          'below is reading something else');
      expect(wav.channels, 1);
      expect(wav.seconds, lessThan(maxSeconds),
          reason: 'a rest ending is one event; it does not need a melody');
      expect(wav.bytes, lessThan(twoNoteBytes),
          reason: 'shorter than the two-note figure it replaces');
    });

    test('and it is struck at the top of the scale', () {
      // The complaint that started issue #61: a ding you cannot hear over a
      // gym is a rest timer that does not work. Nothing is gained by leaving
      // headroom on the one sound the app makes.
      final peak = wav.envelope(const Duration(milliseconds: 10))
          .reduce((a, b) => a > b ? a : b);
      expect(peak, greaterThan(32767 * 0.9));
    });

    test('the notification plays the same sound, not a different one', () {
      // Android will only sound a notification from its own resources, so the
      // tone ships twice — one generator, two copies. A rest ending in a
      // pocket must not end with a noise the user has never heard.
      final asset = File('assets/sound/rest_done.wav').readAsBytesSync();
      final raw =
          File('android/app/src/main/res/raw/rest_done.wav').readAsBytesSync();
      expect(raw, equals(asset));
    });

    test('it strikes at once and only fades from there', () {
      // A two-note figure gives itself away in the envelope: it decays, then
      // rises again for the second note. One ding never rises after its attack.
      final envelope = wav.envelope(const Duration(milliseconds: 10));
      expect(envelope.length, greaterThan(4),
          reason: 'too short to say anything about the shape of it');

      final peak = envelope.reduce((a, b) => a > b ? a : b);
      final attack = envelope.indexOf(peak);
      expect(attack, lessThanOrEqualTo(5),
          reason: 'a fast attack peaks in the first 50 ms, not later');

      // Allowing 5% of the peak as jitter: a decaying sine's window maxima are
      // not perfectly monotonic, but a second note is a rise of a different
      // order entirely.
      final jitter = peak * 0.05;
      for (var i = attack + 1; i < envelope.length; i++) {
        expect(
          envelope[i],
          lessThanOrEqualTo(envelope[i - 1] + jitter),
          reason: 'the tone gets louder again ${i * 10} ms in — '
              'that is a second note',
        );
      }
    });
  });
}

/// The shipped rest tone, parsed far enough to say what it sounds like.
///
/// Deliberately a hand-rolled RIFF walk rather than a package: the whole point
/// is to read the asset that ships, with nothing between the test and the
/// bytes.
class _RestTone {
  _RestTone({
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.samples,
    required this.bytes,
  });

  final int channels;
  final int sampleRate;
  final int bitsPerSample;

  /// The signed 16-bit samples of the `data` chunk, in order.
  final List<int> samples;

  /// The size of the file on disk.
  final int bytes;

  double get seconds => samples.length / channels / sampleRate;

  /// Reads `assets/sound/rest_done.wav` relative to the package root, which is
  /// where `flutter test` runs from.
  factory _RestTone.read() {
    final raw = File('assets/sound/rest_done.wav').readAsBytesSync();
    final data = ByteData.sublistView(raw);
    String tag(int at) =>
        String.fromCharCodes(raw.sublist(at, at + 4));
    if (tag(0) != 'RIFF' || tag(8) != 'WAVE') {
      throw StateError('not a RIFF/WAVE file');
    }

    var channels = 0, sampleRate = 0, bits = 0;
    var samples = <int>[];
    // Chunks run from byte 12: a four-byte id, a little-endian length, then
    // that many bytes, padded to even.
    var at = 12;
    while (at + 8 <= raw.length) {
      final id = tag(at);
      final size = data.getUint32(at + 4, Endian.little);
      final body = at + 8;
      if (id == 'fmt ') {
        channels = data.getUint16(body + 2, Endian.little);
        sampleRate = data.getUint32(body + 4, Endian.little);
        bits = data.getUint16(body + 14, Endian.little);
      } else if (id == 'data') {
        samples = [
          for (var i = body; i + 1 < body + size; i += 2)
            data.getInt16(i, Endian.little),
        ];
      }
      at = body + size + (size.isOdd ? 1 : 0);
    }
    return _RestTone(
      channels: channels,
      sampleRate: sampleRate,
      bitsPerSample: bits,
      samples: samples,
      bytes: raw.length,
    );
  }

  /// The loudest sample in each [window] of the tone — its shape over time,
  /// which is the part a listener hears as one ding or as two.
  List<int> envelope(Duration window) {
    final width = (sampleRate * channels * window.inMicroseconds) ~/ 1000000;
    final out = <int>[];
    for (var i = 0; i + width <= samples.length; i += width) {
      var loudest = 0;
      for (var j = i; j < i + width; j++) {
        final v = samples[j].abs();
        if (v > loudest) loudest = v;
      }
      out.add(loudest);
    }
    return out;
  }
}

/// A [RestTone] that counts rather than playing. Built over [_NoPlayer], so
/// constructing it cannot reach the audio plugin a test runner does not have.
class _RecordingTone extends RestTone {
  _RecordingTone() : super(player: _NoPlayer());

  int played = 0;

  @override
  Future<void> play() async => played++;
}

/// A [RestAlarm] that records rather than posting. Not-supported, so nothing
/// inherited can reach a notification channel the test runner does not have.
class _RecordingAlarm extends RestAlarm {
  _RecordingAlarm() : super(platformSupported: false);

  /// The body of each notification posted — what the rest said it was for.
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

/// An [AudioPlayer] that would throw if the tone ever reached it. Standing in
/// for the platform channel a widget test does not have, so "switched off does
/// nothing" is a real assertion rather than an absence of one.
class _NoPlayer implements AudioPlayer {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('the tone reached the player while switched off');
}
