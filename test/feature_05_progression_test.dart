// Feature 05 — Automatic progression (features/index.html#sec05).
//
// Every slot advances along a single axis; a clean session steps it up and two
// misses back it off. These tests drive the behaviour the spec describes through
// its real public surface: the pure rules in `progression.dart`, the
// `AppDatabase.advanceProgression` path that applies them to a stored slot, the
// `ExerciseEntry` verdict/lightest-set rules that decide what gets applied, and
// one end-to-end run through the live controller's finish path.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/summary_screen.dart';
import 'package:foss_lift/state/active_workout.dart';

import 'support/harness.dart';
import 'support/schema_v1.dart';
import 'support/seeded.dart';
import 'support/settle.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = memoryDb();
    container = containerFor(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // A named exercise, e in the muscle group Chest, built directly from sets for
  // the verdict rules — kept here so every verdict test reads one line.
  ExerciseEntry entry(List<SetEntry> sets) =>
      ExerciseEntry(exerciseId: 1, name: 'X', muscle: 'Chest', sets: sets);

  group('the axis is constrained by the exercise measure', () {
    test('a counted movement may use weight or reps, in that order', () {
      expect(ExerciseMeasure.reps.modes, [
        ProgressionMode.weight,
        ProgressionMode.reps,
      ]);
      expect(ExerciseMeasure.reps.defaultMode, ProgressionMode.weight);
    });

    test('a held movement may only use time', () {
      expect(ExerciseMeasure.time.modes, [ProgressionMode.time]);
      expect(ExerciseMeasure.time.defaultMode, ProgressionMode.time);
    });

    test('coerce forces a disallowed axis back to the measure default', () {
      // A plank cannot be progressed by reps; a bench cannot be by time.
      expect(
        ExerciseMeasure.time.coerce(ProgressionMode.reps),
        ProgressionMode.time,
      );
      expect(
        ExerciseMeasure.reps.coerce(ProgressionMode.time),
        ProgressionMode.weight,
      );
      // An allowed axis is left untouched.
      expect(
        ExerciseMeasure.reps.coerce(ProgressionMode.reps),
        ProgressionMode.reps,
      );
    });
  });

  group('stepProgression folds a session into the streaks', () {
    ProgressionStep step({
      required bool success,
      int successes = 0,
      int failures = 0,
      int successThreshold = defaultSuccessThreshold,
      int failureThreshold = defaultFailureThreshold,
      double increment = 2.5,
      double deload = 5,
    }) => stepProgression(
      verdict: success ? SessionVerdict.success : SessionVerdict.miss,
      successes: successes,
      failures: failures,
      successThreshold: successThreshold,
      failureThreshold: failureThreshold,
      increment: increment,
      deload: deload,
    );

    test('one clean session earns the step and resets both counters', () {
      final s = step(success: true);
      expect(s.delta, 2.5);
      expect(s, (successes: 0, failures: 0, delta: 2.5));
    });

    test('a success below a higher threshold holds and counts up', () {
      final s = step(success: true, successes: 0, successThreshold: 3);
      expect(s, (successes: 1, failures: 0, delta: 0.0));
    });

    test('the success at the threshold moves the target and resets', () {
      final s = step(success: true, successes: 2, successThreshold: 3);
      expect(s, (successes: 0, failures: 0, delta: 2.5));
    });

    test('a single miss below the failure threshold only counts', () {
      final s = step(success: false); // default failureThreshold 2
      expect(s, (successes: 0, failures: 1, delta: 0.0));
    });

    test('two misses in a row back the target off and reset', () {
      final s = step(success: false, failures: 1); // second miss
      expect(s, (successes: 0, failures: 0, delta: -5.0));
    });

    test(
      'a success zeroes the failure count — consecutive means consecutive',
      () {
        final s = step(success: true, failures: 1, successThreshold: 3);
        expect(s.failures, 0);
        expect(s.successes, 1);
        expect(s.delta, 0);
      },
    );

    test('a failure zeroes the success count', () {
      final s = step(success: false, successes: 2, failureThreshold: 2);
      expect(s, (successes: 0, failures: 1, delta: 0.0));
    });
  });

  group('advanceTarget never drives a target below the mode floor', () {
    test(
      'weight may fall to zero — a belt lifted off a bodyweight movement',
      () {
        expect(advanceTarget(2.5, -5, ProgressionMode.weight), 0);
        expect(advanceTarget(10, -2.5, ProgressionMode.weight), 7.5);
      },
    );

    test('reps never fall below a single rep', () {
      expect(advanceTarget(2, -5, ProgressionMode.reps), 1);
    });

    test('time never falls below five seconds', () {
      expect(advanceTarget(6, -5, ProgressionMode.time), 5);
    });

    test('a bar-loaded target stops at the bar, not at nothing', () {
      // The empty bar is the lightest thing a barbell lift can be set to, so a
      // back-off lands on it and stays there.
      expect(advanceTarget(22.5, -5, ProgressionMode.weight, floorKg: 20), 20);
      expect(advanceTarget(20, -5, ProgressionMode.weight, floorKg: 20), 20);
    });

    test('a target already under its bar is brought back up to it', () {
      expect(advanceTarget(0, 2.5, ProgressionMode.weight, floorKg: 20), 20);
    });

    test('no bar means no floor above zero', () {
      expect(advanceTarget(2.5, -5, ProgressionMode.weight, floorKg: 0), 0);
    });
  });

  group('the weight axis, applied through the database', () {
    test('a clean session adds the default 2.5 kg', () async {
      final id = await slotIdNamed(db, 'Push', 'Bench Press');
      final moved = await db.advanceProgression(
        id,
        verdict: SessionVerdict.success,
        performedWeight: 80,
      );
      expect(moved, closeTo(2.5, 1e-9));
      final slot = await db.workoutItemById(id);
      expect(slot!.suggestedWeight, 82.5);
      // The step resets the counters — the next one must be earned afresh.
      expect(slot.successStreak, 0);
      expect(slot.failStreak, 0);
    });

    test('two misses in a row back it off by the default 5 kg', () async {
      final id = await slotIdNamed(db, 'Push', 'Bench Press');

      final first = await db.advanceProgression(
        id,
        verdict: SessionVerdict.miss,
      );
      expect(first, 0); // one bad night is not the weight
      var slot = await db.workoutItemById(id);
      expect(slot!.suggestedWeight, 80);
      expect(slot.failStreak, 1);

      final second = await db.advanceProgression(
        id,
        verdict: SessionVerdict.miss,
      );
      expect(second, closeTo(-5, 1e-9));
      slot = await db.workoutItemById(id);
      expect(slot!.suggestedWeight, 75);
      expect(slot.failStreak, 0);
    });

    test(
      'the streaks are stored across sessions until a step is earned',
      () async {
        // A slot that needs three clean sessions before it moves.
        final ex = await exerciseNamed(db, 'Bench Press');
        final push = await workoutNamed(db, 'Push');
        await db.replaceWorkoutItems(push.id, [
          WorkoutItemsCompanion.insert(
            workoutId: push.id,
            exerciseId: ex.id,
            suggestedWeight: const Value(80),
            progression: const Value(ProgressionMode.weight),
            successThreshold: const Value(3),
          ),
        ]);
        final id = (await db.itemsForWorkout(push.id)).single.item.id;

        await db.advanceProgression(
          id,
          verdict: SessionVerdict.success,
          performedWeight: 80,
        );
        expect((await db.workoutItemById(id))!.successStreak, 1);
        await db.advanceProgression(
          id,
          verdict: SessionVerdict.success,
          performedWeight: 80,
        );
        expect((await db.workoutItemById(id))!.successStreak, 2);
        // Held at 80 the whole way up.
        expect((await db.workoutItemById(id))!.suggestedWeight, 80);

        final moved = await db.advanceProgression(
          id,
          verdict: SessionVerdict.success,
          performedWeight: 80,
        );
        expect(moved, closeTo(2.5, 1e-9));
        final slot = await db.workoutItemById(id);
        expect(slot!.suggestedWeight, 82.5);
        expect(slot.successStreak, 0);
      },
    );

    test('a failure zeroes a pending success streak in storage', () async {
      final ex = await exerciseNamed(db, 'Bench Press');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          suggestedWeight: const Value(80),
          progression: const Value(ProgressionMode.weight),
          successThreshold: const Value(3),
        ),
      ]);
      final id = (await db.itemsForWorkout(push.id)).single.item.id;

      await db.advanceProgression(
        id,
        verdict: SessionVerdict.success,
        performedWeight: 80,
      );
      expect((await db.workoutItemById(id))!.successStreak, 1);
      await db.advanceProgression(id, verdict: SessionVerdict.miss);
      final slot = await db.workoutItemById(id);
      expect(slot!.successStreak, 0);
      expect(slot.failStreak, 1);
    });
  });

  group('a target is never stored below its own bar', () {
    // A single Bench Press slot at [kg], so the whole Push day is one barbell
    // lift standing on the gym's default 20 kg bar.
    Future<int> benchAt(double? kg, {int failureThreshold = 2}) async {
      final ex = await exerciseNamed(db, 'Bench Press');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          targetSets: const Value(3),
          repsMin: const Value(8),
          suggestedWeight: Value(kg),
          progression: const Value(ProgressionMode.weight),
          failureThreshold: Value(failureThreshold),
        ),
      ]);
      return (await db.itemsForWorkout(push.id)).single.item.id;
    }

    test('repeated back-offs land on the empty bar and stay there', () async {
      final id = await benchAt(22.5, failureThreshold: 1);

      final first = await db.advanceProgression(
        id,
        verdict: SessionVerdict.miss,
      );
      expect(first, closeTo(-2.5, 1e-9)); // 22.5 → 17.5, held at the 20 kg bar
      expect((await db.workoutItemById(id))!.suggestedWeight, 20);

      final second = await db.advanceProgression(
        id,
        verdict: SessionVerdict.miss,
      );
      expect(second, 0); // there is nowhere lighter to go
      expect((await db.workoutItemById(id))!.suggestedWeight, 20);
    });

    test(
      'a target left under its bar is floored as progression touches it',
      () async {
        // What an older build could store: a slot backed off to nothing under a
        // 20 kg bar. Trained at the bar and stepped up, it reports the step it
        // took — not the whole climb back to the bar as a step up.
        final id = await benchAt(0);
        final moved = await db.advanceProgression(
          id,
          verdict: SessionVerdict.success,
          performedWeight: 20,
        );
        expect(moved, closeTo(2.5, 1e-9));
        expect((await db.workoutItemById(id))!.suggestedWeight, 22.5);
      },
    );

    test('a movement with no bar under it may still fall to nothing', () async {
      // A belt on a bodyweight movement: zero load is a real place to end up.
      final ex = await exerciseNamed(db, 'Push-Up');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          suggestedWeight: const Value(2.5),
          progression: const Value(ProgressionMode.weight),
          failureThreshold: const Value(1),
        ),
      ]);
      final id = (await db.itemsForWorkout(push.id)).single.item.id;
      await db.advanceProgression(id, verdict: SessionVerdict.miss);
      expect((await db.workoutItemById(id))!.suggestedWeight, 0);
    });
  });

  group('a slot with no stored target takes one from the session', () {
    /// A single weight-axis slot for [exercise] with no suggested weight at all.
    Future<int> untargetedSlot(String exercise) async {
      final ex = await exerciseNamed(db, exercise);
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          targetSets: const Value(3),
          repsMin: const Value(8),
          progression: const Value(ProgressionMode.weight),
          // suggestedWeight left absent — the builder was never given one.
        ),
      ]);
      return (await db.itemsForWorkout(push.id)).single.item.id;
    }

    test(
      'a weight worked on the board becomes the target, and steps on',
      () async {
        final id = await untargetedSlot('Bench Press');
        final ctrl = container.read(activeWorkoutProvider.notifier);
        await ctrl.start(
          workoutId: await workoutIdNamed(db, 'Push'),
          name: 'Push',
        );
        ctrl.setWorkingWeight(0, 60);
        final live = container.read(activeWorkoutProvider)!;
        for (var si = 0; si < live.exercises[0].sets.length; si++) {
          ctrl.setLogged(0, si, 8);
        }
        await ctrl.finish();

        expect((await db.workoutItemById(id))!.suggestedWeight, 62.5);
        final report = container.read(lastProgressionProvider)!;
        expect(report.outcomes, hasLength(1));
        expect(report.outcomes.single.target, 62.5);
        expect(report.outcomes.single.moved, closeTo(2.5, 1e-9));
      },
    );

    test(
      'a weight set but never lifted still establishes the target',
      () async {
        final id = await untargetedSlot('Bench Press');
        final ctrl = container.read(activeWorkoutProvider.notifier);
        await ctrl.start(
          workoutId: await workoutIdNamed(db, 'Push'),
          name: 'Push',
        );
        ctrl.setWorkingWeight(0, 60); // set up, then the session ended
        await ctrl.finish();

        expect((await db.workoutItemById(id))!.suggestedWeight, 60);
        final report = container.read(lastProgressionProvider)!;
        expect(report.outcomes.single.target, 60);
        expect(report.outcomes.single.moved, 0);
      },
    );

    test(
      'no target and no weight is the one case with nothing to move',
      () async {
        final id = await untargetedSlot('Push-Up');
        final ctrl = container.read(activeWorkoutProvider.notifier);
        await ctrl.start(
          workoutId: await workoutIdNamed(db, 'Push'),
          name: 'Push',
        );
        final live = container.read(activeWorkoutProvider)!;
        for (var si = 0; si < live.exercises[0].sets.length; si++) {
          ctrl.setLogged(0, si, 8);
        }
        await ctrl.finish();

        expect((await db.workoutItemById(id))!.suggestedWeight, isNull);
        expect(container.read(lastProgressionProvider), isNull);
      },
    );
  });

  group('loading the bar past the suggestion is itself progression', () {
    test(
      'beating the stored target raises it, then the step is added',
      () async {
        final id = await slotIdNamed(db, 'Push', 'Bench Press');
        // Carried 85 through every set of an 80 kg slot, and earned the step.
        final moved = await db.advanceProgression(
          id,
          verdict: SessionVerdict.success,
          performedWeight: 85,
        );
        expect(moved, closeTo(7.5, 1e-9)); // 85 + 2.5, measured from 80
        expect((await db.workoutItemById(id))!.suggestedWeight, 87.5);
      },
    );

    test('beating the target raises it even before a step is earned', () async {
      // successThreshold 2: a single clean session does not earn the +2.5, but
      // the load actually carried still pulls the target up to meet it.
      final ex = await exerciseNamed(db, 'Bench Press');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          suggestedWeight: const Value(80),
          progression: const Value(ProgressionMode.weight),
          successThreshold: const Value(2),
        ),
      ]);
      final id = (await db.itemsForWorkout(push.id)).single.item.id;

      final moved = await db.advanceProgression(
        id,
        verdict: SessionVerdict.success,
        performedWeight: 85,
      );
      expect(moved, closeTo(5, 1e-9)); // 85 with no step, up from 80
      final slot = await db.workoutItemById(id);
      expect(slot!.suggestedWeight, 85);
      expect(slot.successStreak, 1); // step still pending
    });

    test('coming in lighter than the target does not raise it', () async {
      // A weight below the suggestion is a deload, answered by the failure path,
      // never by the performed-weight bump.
      final id = await slotIdNamed(db, 'Push', 'Bench Press');
      final moved = await db.advanceProgression(
        id,
        verdict: SessionVerdict.miss,
        performedWeight: 75,
      );
      expect(moved, 0); // one miss, no move; target stays put
      expect((await db.workoutItemById(id))!.suggestedWeight, 80);
    });
  });

  group('the reps axis, applied through the database', () {
    test('a clean session adds a rep and keeps the range width', () async {
      // Pull-Up is 6–10, reps mode, no suggested weight.
      final id = await slotIdNamed(db, 'Pull', 'Pull-Up');
      final moved = await db.advanceProgression(
        id,
        verdict: SessionVerdict.success,
      );
      expect(moved, 1);
      final slot = await db.workoutItemById(id);
      expect(slot!.repsMin, 7);
      expect(slot.repsMax, 11); // width of 4 preserved
    });

    test('two misses drop the reps and keep the range width', () async {
      final id = await slotIdNamed(db, 'Pull', 'Pull-Up');
      await db.advanceProgression(id, verdict: SessionVerdict.miss);
      final moved = await db.advanceProgression(
        id,
        verdict: SessionVerdict.miss,
      );
      expect(moved, -2);
      final slot = await db.workoutItemById(id);
      expect(slot!.repsMin, 4);
      expect(slot.repsMax, 8);
    });

    test('the reps target is not driven below a single rep', () async {
      final ex = await exerciseNamed(db, 'Pull-Up');
      final pull = await workoutNamed(db, 'Pull');
      await db.replaceWorkoutItems(pull.id, [
        WorkoutItemsCompanion.insert(
          workoutId: pull.id,
          exerciseId: ex.id,
          repsMin: const Value(2),
          progression: const Value(ProgressionMode.reps),
          deload: const Value(2),
          failureThreshold: const Value(1),
        ),
      ]);
      final id = (await db.itemsForWorkout(pull.id)).single.item.id;
      final moved = await db.advanceProgression(
        id,
        verdict: SessionVerdict.miss,
      );
      expect(moved, -1); // 2 would go to 0, floored back to 1
      expect((await db.workoutItemById(id))!.repsMin, 1);
    });
  });

  group('the time axis, applied through the database', () {
    Future<int> plankSlot() async {
      final plank = await exerciseNamed(db, 'Plank');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: plank.id,
          progression: const Value(ProgressionMode.time),
          holdSeconds: const Value(30),
          increment: const Value(5),
          deload: const Value(10),
        ),
      ]);
      return (await db.itemsForWorkout(push.id)).single.item.id;
    }

    test('a clean session holds five seconds longer', () async {
      final id = await plankSlot();
      final moved = await db.advanceProgression(
        id,
        verdict: SessionVerdict.success,
      );
      expect(moved, 5);
      expect((await db.workoutItemById(id))!.holdSeconds, 35);
    });

    test('two misses cut the hold by the configured deload', () async {
      final id = await plankSlot();
      await db.advanceProgression(id, verdict: SessionVerdict.miss);
      final moved = await db.advanceProgression(
        id,
        verdict: SessionVerdict.miss,
      );
      expect(moved, -10);
      expect((await db.workoutItemById(id))!.holdSeconds, 20);
    });
  });

  group('a weight-mode slot with no suggested weight has nothing to move', () {
    test('a clean session invents no load for a push-up', () async {
      final ex = await exerciseNamed(db, 'Push-Up');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          progression: const Value(ProgressionMode.weight),
          // suggestedWeight left absent — never given a number.
        ),
      ]);
      final id = (await db.itemsForWorkout(push.id)).single.item.id;
      final moved = await db.advanceProgression(
        id,
        verdict: SessionVerdict.success,
      );
      expect(moved, 0);
      expect((await db.workoutItemById(id))!.suggestedWeight, isNull);
    });
  });

  group('the verdict and the lightest logged set', () {
    test('clean when every planned set is logged and none is short', () {
      final e = entry([
        SetEntry(goal: 8, goalWeight: 80, weight: 80, logged: 8),
        SetEntry(goal: 8, goalWeight: 80, weight: 80, logged: 8),
      ]);
      expect(e.succeeded, isTrue);
    });

    test('a skipped set is a miss', () {
      final e = entry([
        SetEntry(goal: 8, goalWeight: 80, weight: 80, logged: 8),
        SetEntry(goal: 8, goalWeight: 80, weight: 80), // never logged
      ]);
      expect(e.succeeded, isFalse);
    });

    test('finishing a set short of the goal is a miss', () {
      final e = entry([
        SetEntry(goal: 8, goalWeight: 80, weight: 80, logged: 7),
      ]);
      expect(e.succeeded, isFalse);
    });

    test('finishing at a reduced weight is a miss', () {
      final e = entry([
        SetEntry(goal: 8, goalWeight: 80, weight: 75, logged: 8),
      ]);
      expect(e.succeeded, isFalse);
    });

    test(
      'the performed weight is the lightest logged set — 100/105/110 is 100',
      () {
        final e = entry([
          SetEntry(goal: 8, weight: 100, logged: 8),
          SetEntry(goal: 8, weight: 105, logged: 8),
          SetEntry(goal: 8, weight: 110, logged: 8),
        ]);
        expect(e.performedWeight, 100);
      },
    );

    test('an even load is its own performed weight — 105/105/105 is 105', () {
      final e = entry([
        SetEntry(goal: 8, weight: 105, logged: 8),
        SetEntry(goal: 8, weight: 105, logged: 8),
      ]);
      expect(e.performedWeight, 105);
    });

    test('unlogged sets do not count toward the performed weight', () {
      final e = entry([
        SetEntry(goal: 8, weight: 90), // not logged, ignored
        SetEntry(goal: 8, weight: 100, logged: 8),
      ]);
      expect(e.performedWeight, 100);
    });
  });

  group('end to end through the live controller finish', () {
    test('a clean session steps the slot up on Finish', () async {
      // Reduce Push to a single bench slot so the whole session is one exercise.
      final ex = await exerciseNamed(db, 'Bench Press');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          targetSets: const Value(3),
          repsMin: const Value(8),
          suggestedWeight: const Value(80),
          progression: const Value(ProgressionMode.weight),
        ),
      ]);
      final id = (await db.itemsForWorkout(push.id)).single.item.id;

      final ctrl = container.read(activeWorkoutProvider.notifier);
      await ctrl.start(workoutId: push.id, name: 'Push');
      final live = container.read(activeWorkoutProvider)!;
      for (var si = 0; si < live.exercises[0].sets.length; si++) {
        ctrl.setLogged(0, si, 8); // hit the goal at the suggested 80 kg
      }
      await ctrl.finish();

      expect((await db.workoutItemById(id))!.suggestedWeight, 82.5);
    });

    test(
      'a session with a skipped set backs nothing off but stores the miss',
      () async {
        final ex = await exerciseNamed(db, 'Bench Press');
        final push = await workoutNamed(db, 'Push');
        await db.replaceWorkoutItems(push.id, [
          WorkoutItemsCompanion.insert(
            workoutId: push.id,
            exerciseId: ex.id,
            targetSets: const Value(3),
            repsMin: const Value(8),
            suggestedWeight: const Value(80),
            progression: const Value(ProgressionMode.weight),
          ),
        ]);
        final id = (await db.itemsForWorkout(push.id)).single.item.id;

        final ctrl = container.read(activeWorkoutProvider.notifier);
        await ctrl.start(workoutId: push.id, name: 'Push');
        // Log only two of the three planned sets — a skipped set is a miss.
        ctrl.setLogged(0, 0, 8);
        ctrl.setLogged(0, 1, 8);
        await ctrl.finish();

        final slot = await db.workoutItemById(id);
        expect(slot!.suggestedWeight, 80); // one miss: held, not backed off
        expect(slot.failStreak, 1); // the miss is stored
      },
    );
  });

  // ==========================================================================
  // Double progression — a weight slot that climbs its rep range before the
  // load moves. Driven through the live session's finish path throughout: the
  // spec is about what a session's reps do to a stored slot, and the verdict is
  // what the board hands progression rather than something a caller states.
  // ==========================================================================

  /// A Push day cut down to one Bench Press slot: three sets of
  /// [repsMin]–[repsMax] at 80 kg on the weight axis, ticked to add weight at
  /// the top of the range when [climbs].
  Future<int> rangedBench({
    required bool climbs,
    int repsMin = 6,
    int? repsMax = 8,
    double increment = 2.5,
    int successThreshold = 1,
    int failureThreshold = 2,
  }) async {
    final ex = await exerciseNamed(db, 'Bench Press');
    final push = await workoutNamed(db, 'Push');
    await db.replaceWorkoutItems(push.id, [
      WorkoutItemsCompanion.insert(
        workoutId: push.id,
        exerciseId: ex.id,
        targetSets: const Value(3),
        repsMin: Value(repsMin),
        repsMax: Value(repsMax),
        suggestedWeight: const Value(80),
        progression: const Value(ProgressionMode.weight),
        increment: Value(increment),
        successThreshold: Value(successThreshold),
        failureThreshold: Value(failureThreshold),
        addWeightAtTopOfRange: Value(climbs),
      ),
    ]);
    return (await db.itemsForWorkout(push.id)).single.item.id;
  }

  /// Trains that day once at its suggested weight, logging [reps] set by set —
  /// a null is a set nobody ever logged — and finishes it.
  Future<int> train(List<int?> reps) async {
    final ctrl = container.read(activeWorkoutProvider.notifier);
    await ctrl.start(workoutId: await workoutIdNamed(db, 'Push'), name: 'Push');
    for (var si = 0; si < reps.length; si++) {
      final logged = reps[si];
      if (logged != null) ctrl.setLogged(0, si, logged);
    }
    return (await ctrl.finish())!;
  }

  group('a weight slot can climb its rep range before the load moves', () {
    test(
      'topping the range at every set steps the load up by the increment',
      () async {
        final id = await rangedBench(climbs: true);
        await train([8, 8, 8]);

        final slot = await db.workoutItemById(id);
        expect(slot!.suggestedWeight, 82.5); // 80 + the slot's own increment
        // The range is the ladder, and a ladder that climbs with you is no
        // ladder: 6–8 is still 6–8 at the new weight.
        expect(slot.repsMin, 6);
        expect(slot.repsMax, 8);
        expect(slot.successStreak, 0);
        expect(slot.failStreak, 0);
        // And the tick stays where it was — this is how the slot works now.
        expect(slot.addWeightAtTopOfRange, isTrue);
      },
    );

    test('the step is the slot\'s increment, whatever it is', () async {
      final id = await rangedBench(climbs: true, increment: 5);
      await train([8, 8, 8]);
      expect((await db.workoutItemById(id))!.suggestedWeight, 85);
    });

    test('a session inside the range moves nothing at all', () async {
      final id = await rangedBench(climbs: true);
      await train([8, 7, 7]); // above the bottom, short of the top

      final slot = await db.workoutItemById(id);
      expect(slot!.suggestedWeight, 80);
      expect(slot.repsMin, 6);
      expect(slot.repsMax, 8);
      expect(slot.successStreak, 0);
      expect(slot.failStreak, 0);
    });

    test(
      'a held session does not spend a clean session already banked',
      () async {
        // Two clean sessions earn the step. One is banked, a session inside the
        // range follows, and the streak is exactly where it was — so three
        // sessions spent working up through the range neither earn a step nor
        // spend one.
        final id = await rangedBench(climbs: true, successThreshold: 2);

        await train([8, 8, 8]);
        expect((await db.workoutItemById(id))!.successStreak, 1);

        await train([8, 7, 7]);
        var slot = await db.workoutItemById(id);
        expect(slot!.successStreak, 1, reason: 'a hold is not a failure');
        expect(slot.failStreak, 0);
        expect(slot.suggestedWeight, 80);

        await train([8, 8, 8]);
        slot = await db.workoutItemById(id);
        expect(slot!.suggestedWeight, 82.5);
        expect(slot.successStreak, 0);
      },
    );

    test('a held session does not advance a pending miss either', () async {
      final id = await rangedBench(climbs: true);

      await train([5, 5, 5]); // below the bottom of the range: a real miss
      expect((await db.workoutItemById(id))!.failStreak, 1);

      await train([8, 7, 7]);
      final slot = await db.workoutItemById(id);
      expect(slot!.failStreak, 1, reason: 'a hold is not a miss');
      expect(slot.suggestedWeight, 80);
    });

    test(
      'falling below the bottom of the range still buys the back-off',
      () async {
        // The bottom is the weight's price of admission, so two sessions under it
        // deload exactly as they do on any other weight slot.
        final id = await rangedBench(climbs: true);

        await train([5, 5, 5]);
        expect((await db.workoutItemById(id))!.suggestedWeight, 80);

        await train([5, 5, 5]);
        final slot = await db.workoutItemById(id);
        expect(slot!.suggestedWeight, 75); // −5, the default back-off
        expect(slot.failStreak, 0);
        expect(slot.repsMin, 6); // the range does not move on the way down
        expect(slot.repsMax, 8);
      },
    );

    test(
      'a skipped set is a miss even when the logged ones topped the range',
      () async {
        final id = await rangedBench(climbs: true);
        await train([8, 8, null]);

        final slot = await db.workoutItemById(id);
        expect(slot!.suggestedWeight, 80);
        expect(slot.failStreak, 1);
        expect(slot.successStreak, 0);
      },
    );

    test('an untouched ranged slot still counts anything short of the top as a '
        'miss', () async {
      // The regression: without the tick the goal for a ranged slot is the top
      // of the range, and 8/7/7 is a missed session like any other.
      final id = await rangedBench(climbs: false);
      await train([8, 7, 7]);

      final slot = await db.workoutItemById(id);
      expect(slot!.suggestedWeight, 80);
      expect(slot.failStreak, 1);
      expect(slot.addWeightAtTopOfRange, isFalse);
    });

    test(
      'an untouched ranged slot steps up on a clean session as it always did',
      () async {
        final id = await rangedBench(climbs: false);
        await train([8, 8, 8]);
        expect((await db.workoutItemById(id))!.suggestedWeight, 82.5);
      },
    );

    test('a ticked slot with no range left is an ordinary weight slot', () async {
      // Take the range off and there is nothing to top: a clean session at the
      // fixed count steps the load up. The tick is kept rather than cleared, so
      // putting the range back puts the behaviour back.
      final id = await rangedBench(climbs: true, repsMin: 8, repsMax: null);
      await train([8, 8, 8]);

      final slot = await db.workoutItemById(id);
      expect(slot!.suggestedWeight, 82.5);
      expect(slot.addWeightAtTopOfRange, isTrue);
    });

    test('and a short session on one is an ordinary miss', () async {
      final id = await rangedBench(climbs: true, repsMin: 8, repsMax: null);
      await train([8, 7, 7]);

      final slot = await db.workoutItemById(id);
      expect(slot!.suggestedWeight, 80);
      expect(slot.failStreak, 1);
    });
  });

  group('the recap tells a held slot climbing a range what it is waiting for', () {
    test('a held climb is reported as a hold that moved nothing', () async {
      await rangedBench(climbs: true);
      await train([8, 7, 7]);

      final report = container.read(lastProgressionProvider)!;
      final outcome = report.outcomes.single;
      expect(outcome.held, isTrue);
      expect(outcome.moved, 0);
      expect(outcome.target, 80);
      expect(outcome.successes, 0);
      expect(outcome.failures, 0);
    });

    testWidgets('and it is told to top the range, not to count sessions', (
      tester,
    ) async {
      late int sessionId;
      await tester.runAsync(() async {
        // Two clean sessions to a step, one of them already banked: an ordinary
        // held exercise here would count down "1 more clean session to a step",
        // which is a countdown this session did not touch and so never arrives.
        await rangedBench(climbs: true, successThreshold: 2);
        await train([8, 8, 8]);
        sessionId = await train([8, 7, 7]);
      });

      await tester.pumpWidget(
        appUnder(container, SummaryScreen(sessionId: sessionId)),
      );
      await pumpUntil(
        tester,
        () => find.text('PROGRESSION').evaluate().isNotEmpty,
      );

      // The string behind `summaryHeldTopTheRange` — the one thing that would
      // actually move this slot.
      expect(find.text('Top the range on every set'), findsOneWidget);
      expect(find.text(l10nFor().summaryHeldCleanSessions(1)), findsNothing);

      await stop(tester);
    });
  });

  group('the tick arrives off on every slot that predates it', () {
    // A phone on a shipped build holds a database with no such column. It is
    // written as the frozen v1 DDL and climbed by the real ladder, so the
    // upgrade is handed the bytes a phone would hand it — see
    // `support/schema_v1.dart`.
    AppDatabase oldDatabase() => AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          for (final stmt in kSchemaV1) {
            raw.execute(stmt);
          }
          raw.execute(
            'INSERT INTO exercises (id, name, seed_key, muscle_group, '
            "equipment) VALUES (1, 'Bench Press', 'bench_press', 'Chest', "
            "'Barbell')",
          );
          raw.execute(
            'INSERT INTO routines (id, name, color_hex, position, '
            "rest_seconds) VALUES (1, 'Mine', 'FF6A3D', 0, 120)",
          );
          raw.execute(
            'INSERT INTO workouts (id, routine_id, name, position) '
            "VALUES (1, 1, 'Push', 0)",
          );
          raw.execute(
            'INSERT INTO workout_items (id, workout_id, exercise_id, '
            'position, target_sets, reps_min, reps_max, suggested_weight) '
            'VALUES (1, 1, 1, 0, 3, 6, 8, 80.0)',
          );
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );

    test('a slot written before the column reads back unticked', () async {
      final db = oldDatabase();
      addTearDown(db.close);

      final items = await db.itemsForWorkout(1);
      expect(items.single.item.repsMax, 8, reason: 'the range it was training');
      expect(
        items.single.item.addWeightAtTopOfRange,
        isFalse,
        reason:
            'a program built before the tick existed adds weight a '
            'session sooner, not a corrupt one',
      );
    });

    test('and the database is left standing on the current rung', () async {
      final db = oldDatabase();
      addTearDown(db.close);

      final row = await db.customSelect('PRAGMA user_version').getSingle();
      expect(row.data.values.first, db.schemaVersion);
    });
  });
}
