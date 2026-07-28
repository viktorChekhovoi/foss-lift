// Integration tests for features/04-live-session.md — the in-memory live
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
import 'package:foss_lift/services/rest_tone.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/util/units.dart';
import 'package:foss_lift/widgets/resume_workout_bar.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

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
      await stop(tester);
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

      await stop(tester);
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

      await stop(tester);
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

      await stop(tester);
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

      await stop(tester);
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

      await stop(tester);
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
      await stop(tester);
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

      await stop(tester);
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

        await stop(tester);
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

      await stop(tester);
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

      await stop(tester);
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

      await stop(tester);
    });
  });

  group('Warm-up rungs land on loads the gym can actually set', () {
    // Every rung of a ramp has to be a weight you can walk up to the rack and
    // make — and the cheapest such weight near the step, so a warm-up costs one
    // pair of plates rather than four. See features/04-live-session.md.

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
      await stop(tester);
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

        // Collapse: unmount the screen. The session is not discarded.
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

  group('A rest says what to do with it', () {
    // The four cases from features/04: another rung, the work, another set, a
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

      await stop(tester);
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

      await stop(tester);
    });
  });

  group('And it makes a sound when it is over', () {
    test('the tone is on by default, and can be turned off', () async {
      // On by default: a rest that ends silently is a rest you overrun with
      // the phone in your pocket, which is what the timer is for.
      expect(await db.watchRestSound().first, isTrue);

      await db.setRestSound(false);
      expect(await db.watchRestSound().first, isFalse);

      await db.setRestSound(true);
      expect(await db.watchRestSound().first, isTrue);
    });

    test('switched off, it does not go near the player', () async {
      // The switch is checked before anything is touched, which is what makes
      // "off" free rather than "played into a muted channel". The enabled path
      // is a platform channel a widget test has none of, so it is not exercised
      // here — see the note on RestTone.
      final tone = RestTone(player: _NoPlayer());
      addTearDown(tone.dispose);

      await expectLater(tone.play(enabled: false), completes);
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

      await stop(tester);
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

      await stop(tester);
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

      await stop(tester);
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

      await stop(tester);
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

      await stop(tester);
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

      // Written through to the library, and on the board without leaving it.
      expect(await storedNote(tester, 'Bench Press'), 'Seat 4, pin 7');
      expect(find.text('Seat 4, pin 7'), findsOneWidget);

      await stop(tester);
    });

    testWidgets('an existing note is edited from the board', (tester) async {
      await noteOn(tester, 'Bench Press', 'Rack pin 7');
      await pumpPushScreen(tester);

      await tester.tap(find.byTooltip('My note').first);
      await frames(tester);
      expect(find.text('Rack pin 7'), findsOneWidget);

      await tester.tap(find.byTooltip('Edit note').first);
      await frames(tester);
      await tester.enterText(find.byType(TextField), 'Rack pin 8');
      await tester.tap(find.text('Save'));
      await pumpThroughDatabase(tester);

      expect(find.text('Rack pin 8'), findsOneWidget);
      expect(await storedNote(tester, 'Bench Press'), 'Rack pin 8');

      await stop(tester);
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

      await stop(tester);
    });
  });
}

/// An [AudioPlayer] that would throw if the tone ever reached it. Standing in
/// for the platform channel a widget test does not have, so "switched off does
/// nothing" is a real assertion rather than an absence of one.
class _NoPlayer implements AudioPlayer {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('the tone reached the player while switched off');
}
