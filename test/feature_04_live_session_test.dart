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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/data/warmup.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

// The seeded PPL Push day, in template order.
const kPushSize = 5; // Bench, Overhead, Incline DB, Lateral, Triceps
const kPushTotalSets = 17; // 4 + 4 + 3 + 3 + 3
const benchGoal = 8; // 6–8 range → top of range
const benchWeight = 80.0;

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

      final row = find.byKey(const ValueKey('0-0-Bench Press'));
      // The reps cell is the row's GestureDetector; the weight is a TextField.
      await tester.tap(
        find.descendant(of: row, matching: find.byType(GestureDetector)),
      );
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
      final row = find.byKey(const ValueKey('0-0-Bench Press'));
      await tester.tap(
        find.descendant(of: row, matching: find.byType(GestureDetector)),
      );
      await tester.pump();

      // The banner opens at the slot's configured rest (routine default 120s).
      expect(find.text('REST'), findsOneWidget);
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
      expect(find.text('REST'), findsNothing);

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
}
