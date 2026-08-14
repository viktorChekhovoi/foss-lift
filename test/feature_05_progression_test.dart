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

  // How far progression moved a slot, in the unit of whichever axis it moved.
  // Which axis that was is the point of its own group below, and everywhere
  // else it is the number that matters.
  Future<double> advance(
    int itemId, {
    required SessionVerdict verdict,
    double? performedWeight,
    double? sessionWeight,
  }) async =>
      (await db.advanceProgression(
        itemId,
        verdict: verdict,
        performedWeight: performedWeight,
        sessionWeight: sessionWeight,
      )).moved;

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
      final moved = await advance(
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

      final first = await advance(
        id,
        verdict: SessionVerdict.miss,
      );
      expect(first, 0); // one bad night is not the weight
      var slot = await db.workoutItemById(id);
      expect(slot!.suggestedWeight, 80);
      expect(slot.failStreak, 1);

      final second = await advance(
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

        final moved = await advance(
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

      final first = await advance(
        id,
        verdict: SessionVerdict.miss,
      );
      expect(first, closeTo(-2.5, 1e-9)); // 22.5 → 17.5, held at the 20 kg bar
      expect((await db.workoutItemById(id))!.suggestedWeight, 20);

      final second = await advance(
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
        final moved = await advance(
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
        final moved = await advance(
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

      final moved = await advance(
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
      final moved = await advance(
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
      final moved = await advance(
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
      final moved = await advance(
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
      final moved = await advance(
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
      final moved = await advance(
        id,
        verdict: SessionVerdict.success,
      );
      expect(moved, 5);
      expect((await db.workoutItemById(id))!.holdSeconds, 35);
    });

    test('two misses cut the hold by the configured deload', () async {
      final id = await plankSlot();
      await db.advanceProgression(id, verdict: SessionVerdict.miss);
      final moved = await advance(
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
      final moved = await advance(
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
  // The advanced axis — a weight slot carrying a live rep goal inside its rep
  // range, which climbs before the load moves. Driven through the live
  // session's finish path throughout: the spec is about what a session's reps
  // do to a stored slot, and the verdict is what the board hands progression
  // rather than something a caller states.
  // ==========================================================================

  /// A Push day cut down to one Bench Press slot: three sets of
  /// [repsMin]–[repsMax] at [weight] on the weight axis, on the advanced axis
  /// when [advanced], and carrying [repsTarget] as its live rep goal.
  Future<int> rangedBench({
    required bool advanced,
    int repsMin = 6,
    int? repsMax = 8,
    double weight = 80,
    double increment = 2.5,
    double deload = 5,
    double repsIncrement = 1,
    double repsDeload = 2,
    int? repsTarget,
    bool toFailure = false,
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
        toFailure: Value(toFailure),
        suggestedWeight: Value(weight),
        progression: const Value(ProgressionMode.weight),
        increment: Value(increment),
        deload: Value(deload),
        repsIncrement: Value(repsIncrement),
        repsDeload: Value(repsDeload),
        repsTarget: Value(repsTarget),
        successThreshold: Value(successThreshold),
        failureThreshold: Value(failureThreshold),
        addWeightAtTopOfRange: Value(advanced),
      ),
    ]);
    return (await db.itemsForWorkout(push.id)).single.item.id;
  }

  /// The rep goal every set of the day's one slot opened at, as of the last
  /// [train]. What the board actually asked for, which on the advanced axis is
  /// the slot's live goal rather than either end of its range.
  var boardGoals = <int>[];

  /// Trains that day once, logging [reps] set by set — a null is a set nobody
  /// ever logged — and finishes it. [at] loads the bar to something other than
  /// the slot's own suggestion.
  Future<int> train(List<int?> reps, {double? at}) async {
    final ctrl = container.read(activeWorkoutProvider.notifier);
    await ctrl.start(workoutId: await workoutIdNamed(db, 'Push'), name: 'Push');
    if (at != null) ctrl.setWorkingWeight(0, at);
    boardGoals = [
      for (final s in container.read(activeWorkoutProvider)!.exercises.first.sets)
        s.goal,
    ];
    for (var si = 0; si < reps.length; si++) {
      final logged = reps[si];
      if (logged != null) ctrl.setLogged(0, si, logged);
    }
    return (await ctrl.finish())!;
  }

  /// The day's one slot as it now stands.
  Future<WorkoutItem> bench(int id) async => (await db.workoutItemById(id))!;

  group('a weight slot climbs a rep goal before its load moves', () {
    test('the goal starts at the bottom of the range', () async {
      final id = await rangedBench(advanced: true);

      final slot = await bench(id);
      expect(slot.climbsRange, isTrue);
      expect(slot.repsTarget, isNull, reason: 'the rule has never run');
      expect(slot.goalReps, 6, reason: 'null is the bottom of the range');

      await train([6, 6, 6]);
      expect(boardGoals, [6, 6, 6], reason: 'the board asks for the goal');
    });

    test('a clean session raises the goal and leaves the load alone', () async {
      final id = await rangedBench(advanced: true);
      await train([6, 6, 6]);

      final slot = await bench(id);
      expect(slot.repsTarget, 7);
      expect(slot.goalReps, 7);
      expect(slot.suggestedWeight, 80, reason: 'the reps moved, not the load');
      expect(slot.repsMin, 6);
      expect(slot.repsMax, 8, reason: 'the range is the ladder, not the climb');
      expect(slot.successStreak, 0);
      expect(slot.failStreak, 0);
    });

    test("the goal climbs by the slot's own rep step, and stops at the top",
        () async {
      final id = await rangedBench(advanced: true, repsIncrement: 3);
      await train([6, 6, 6]);

      final slot = await bench(id);
      expect(slot.goalReps, 8, reason: '6 + 3 is past the top of the range');
      expect(slot.suggestedWeight, 80, reason: 'the top is reached, not passed');
    });

    test(
      'the session that earns a step at the top adds the weight and starts the '
      'goal again at the bottom',
      () async {
        final id = await rangedBench(advanced: true, repsTarget: 8);
        await train([8, 8, 8]);
        expect(boardGoals, [8, 8, 8]);

        final slot = await bench(id);
        expect(slot.suggestedWeight, 82.5);
        expect(slot.repsTarget, 6);
        expect(slot.goalReps, 6);
        expect(slot.repsMin, 6);
        expect(slot.repsMax, 8);
        expect(slot.successStreak, 0);
      },
    );

    test('the worked example, week by week', () async {
      // 6–8 at 60 kg, +1 rep / +2.5 kg, one clean session to a step and two
      // misses to a back-off.
      final id = await rangedBench(advanced: true, weight: 60);

      await train([6, 6, 6]); // week 1 — clean
      expect(boardGoals, [6, 6, 6]);
      expect((await bench(id)).goalReps, 7);
      expect((await bench(id)).suggestedWeight, 60);

      await train([7, 7, 7]); // week 2 — clean
      expect(boardGoals, [7, 7, 7]);
      expect((await bench(id)).goalReps, 8);
      expect((await bench(id)).suggestedWeight, 60);

      await train([8, 8, 8]); // week 3 — clean, at the top
      expect(boardGoals, [8, 8, 8]);
      expect((await bench(id)).suggestedWeight, 62.5);
      expect((await bench(id)).goalReps, 6);

      await train([5, 5, 5]); // week 4 — missed twice
      expect(boardGoals, [6, 6, 6]);
      expect((await bench(id)).suggestedWeight, 62.5, reason: 'one bad night');
      await train([5, 5, 5]);

      final slot = await bench(id);
      expect(slot.suggestedWeight, 57.5, reason: '−5, the default back-off');
      expect(slot.goalReps, 8, reason: 'back down a step, at the top again');
      expect(slot.repsMin, 6);
      expect(slot.repsMax, 8);
    });

    test('a session short of the goal is a miss, and moves nothing', () async {
      final id = await rangedBench(advanced: true);
      await train([6, 6, 5]);

      final slot = await bench(id);
      expect(slot.goalReps, 6);
      expect(slot.suggestedWeight, 80);
      expect(slot.failStreak, 1);
      expect(slot.successStreak, 0);
    });

    test('finishing at a reduced weight is a miss even at the goal', () async {
      final id = await rangedBench(advanced: true);
      await train([6, 6, 6], at: 75);

      final slot = await bench(id);
      expect(slot.failStreak, 1, reason: 'the reps were there, the load was not');
      expect(slot.goalReps, 6);
      expect(slot.suggestedWeight, 80);
    });

    test('a skipped set is a miss even when the logged ones made the goal',
        () async {
      final id = await rangedBench(advanced: true);
      await train([6, 6, null]);

      final slot = await bench(id);
      expect(slot.failStreak, 1);
      expect(slot.repsTarget, isNull);
      expect(slot.suggestedWeight, 80);
    });

    test('a back-off owed inside the range drops the goal by the rep back-off',
        () async {
      final id = await rangedBench(advanced: true, repsTarget: 8);

      await train([5, 5, 5]);
      expect((await bench(id)).goalReps, 8, reason: 'one miss is not a back-off');
      await train([5, 5, 5]);

      final slot = await bench(id);
      expect(slot.goalReps, 6, reason: '8 − 2');
      expect(slot.suggestedWeight, 80, reason: 'the load waits at the bottom');
      expect(slot.failStreak, 0);
    });

    test('the rep back-off stops at the bottom of the range', () async {
      final id = await rangedBench(
        advanced: true,
        repsTarget: 8,
        repsDeload: 5,
        failureThreshold: 1,
      );
      await train([5, 5, 5]);

      final slot = await bench(id);
      expect(slot.goalReps, 6, reason: '8 − 5 is under the bottom');
      expect(slot.suggestedWeight, 80);
    });

    test(
      'a back-off owed at the bottom takes the weight down and puts the goal '
      'back at the top',
      () async {
        final id = await rangedBench(advanced: true);

        await train([5, 5, 5]);
        await train([5, 5, 5]);

        final slot = await bench(id);
        expect(slot.suggestedWeight, 75, reason: '−5, the default back-off');
        expect(slot.goalReps, 8);
        expect(slot.repsMin, 6, reason: 'the range does not move on the way down');
        expect(slot.repsMax, 8);
        expect(slot.failStreak, 0);
      },
    );

    test('the goal is stored on the slot, not on the session', () async {
      final id = await rangedBench(advanced: true);
      await train([6, 6, 6]);

      // Read back through the ordinary workout query, which is what the next
      // launch does.
      final stored = (await db.itemsForWorkout(await workoutIdNamed(db, 'Push')))
          .single
          .item;
      expect(stored.repsTarget, 7);
      expect(stored.id, id);

      await train([7, 7, 7]);
      expect(boardGoals, [7, 7, 7], reason: 'the next session opens on it');
    });

    test('editing the range pulls a goal now outside it back inside', () async {
      final id = await rangedBench(advanced: true, repsTarget: 8);

      // The range narrowed under a goal that was sitting at its old top.
      await db.updateWorkoutItem(
        id,
        const WorkoutItemsCompanion(repsMax: Value(7)),
      );
      expect((await bench(id)).goalReps, 7);
      await train([7, 7, 7]);
      expect(boardGoals, [7, 7, 7]);
    });

    test('and a goal now under the bottom is pulled up to it', () async {
      final id = await rangedBench(advanced: true, repsTarget: 6);

      await db.updateWorkoutItem(
        id,
        const WorkoutItemsCompanion(repsMin: Value(8), repsMax: Value(10)),
      );
      expect((await bench(id)).goalReps, 8);
    });

    test('an advanced slot with no range left is an ordinary weight slot',
        () async {
      // Nothing to climb: a clean session at the fixed count steps the load up,
      // and the setting is kept rather than cleared so putting the range back
      // puts the behaviour back.
      final id = await rangedBench(advanced: true, repsMin: 8, repsMax: null);
      expect((await bench(id)).climbsRange, isFalse);
      expect((await bench(id)).goalReps, 8);

      await train([8, 8, 8]);
      final slot = await bench(id);
      expect(slot.suggestedWeight, 82.5);
      expect(slot.repsTarget, isNull, reason: 'no goal was climbed');
      expect(slot.addWeightAtTopOfRange, isTrue, reason: 'kept, not cleared');
    });

    test('and a short session on one is an ordinary miss', () async {
      final id = await rangedBench(advanced: true, repsMin: 8, repsMax: null);
      await train([8, 7, 7]);

      final slot = await bench(id);
      expect(slot.suggestedWeight, 80);
      expect(slot.failStreak, 1);
    });

    test('a slot switched to failure keeps its range and trains to failure',
        () async {
      final id = await rangedBench(advanced: true, toFailure: true);

      final slot = await bench(id);
      expect(slot.repsMax, 8, reason: 'the range is kept, just not aimed at');
      expect(slot.climbsRange, isFalse);
      expect(slot.goalReps, 6, reason: 'the number a set has to beat');

      await train([6, 6, 6]);
      expect(boardGoals, [6, 6, 6]);
      expect((await bench(id)).suggestedWeight, 82.5,
          reason: 'an ordinary clean session on an ordinary weight slot');
    });

    test('an untouched ranged slot is still judged against the top', () async {
      final id = await rangedBench(advanced: false);
      await train([8, 7, 7]);

      final slot = await bench(id);
      expect(slot.suggestedWeight, 80);
      expect(slot.failStreak, 1);
      expect(slot.addWeightAtTopOfRange, isFalse);
    });

    test('and steps up on a clean session as it always did', () async {
      final id = await rangedBench(advanced: false);
      await train([8, 8, 8]);
      expect((await bench(id)).suggestedWeight, 82.5);
    });
  });

  group('progression names the axis that actually moved', () {
    test('a rep goal that climbed is reported on the reps axis', () async {
      final id = await rangedBench(advanced: true);
      final moved = await db.advanceProgression(
        id,
        verdict: SessionVerdict.success,
        performedWeight: 80,
      );

      expect(moved.axis, ProgressionMode.reps);
      expect(moved.moved, 1, reason: 'one rep, not one kilogram');
    });

    test('the session that topped the range is reported on the weight axis',
        () async {
      final id = await rangedBench(advanced: true, repsTarget: 8);
      final moved = await db.advanceProgression(
        id,
        verdict: SessionVerdict.success,
        performedWeight: 80,
      );

      expect(moved.axis, ProgressionMode.weight);
      expect(moved.moved, closeTo(2.5, 1e-9));
    });

    test('a goal that came down is reported as the reps it lost', () async {
      final id = await rangedBench(
        advanced: true,
        repsTarget: 8,
        failureThreshold: 1,
      );
      final moved = await db.advanceProgression(id, verdict: SessionVerdict.miss);

      expect(moved.axis, ProgressionMode.reps);
      expect(moved.moved, -2);
    });

    test('a back-off at the bottom is reported as the weight it lost', () async {
      final id = await rangedBench(advanced: true, failureThreshold: 1);
      final moved = await db.advanceProgression(id, verdict: SessionVerdict.miss);

      expect(moved.axis, ProgressionMode.weight);
      expect(moved.moved, closeTo(-5, 1e-9));
    });

    test("a session that moved nothing reports the slot's own axis", () async {
      final id = await rangedBench(advanced: true, successThreshold: 2);
      final moved = await db.advanceProgression(
        id,
        verdict: SessionVerdict.success,
        performedWeight: 80,
      );

      expect(moved.moved, 0);
      expect(moved.axis, ProgressionMode.weight);
    });

    test('an ordinary slot reports the axis it is filed under', () async {
      final weight = await db.advanceProgression(
        await slotIdNamed(db, 'Push', 'Bench Press'),
        verdict: SessionVerdict.success,
        performedWeight: 80,
      );
      expect(weight.axis, ProgressionMode.weight);

      final reps = await db.advanceProgression(
        await slotIdNamed(db, 'Pull', 'Pull-Up'),
        verdict: SessionVerdict.success,
      );
      expect(reps.axis, ProgressionMode.reps);
    });
  });

  group('the recap reports whichever axis a slot moved on', () {
    test('a session that climbed the goal is reported as the reps it gained',
        () async {
      await rangedBench(advanced: true);
      await train([6, 6, 6]);

      final outcome = container.read(lastProgressionProvider)!.outcomes.single;
      expect(outcome.mode, ProgressionMode.reps);
      expect(outcome.moved, 1);
      expect(outcome.target, 7, reason: 'the goal it now carries');
      expect(outcome.steppedUp, isTrue);
    });

    test('and the session that topped the range is reported as the weight',
        () async {
      await rangedBench(advanced: true, repsTarget: 8);
      await train([8, 8, 8]);

      final outcome = container.read(lastProgressionProvider)!.outcomes.single;
      expect(outcome.mode, ProgressionMode.weight);
      expect(outcome.moved, closeTo(2.5, 1e-9));
      expect(outcome.target, 82.5);
    });

    testWidgets('the recap line reads in reps on the session that gained one', (
      tester,
    ) async {
      late int sessionId;
      await tester.runAsync(() async {
        await rangedBench(advanced: true);
        sessionId = await train([6, 6, 6]);
      });

      await tester.pumpWidget(
        appUnder(container, SummaryScreen(sessionId: sessionId)),
      );
      await pumpUntil(
        tester,
        () => find.text('PROGRESSION').evaluate().isNotEmpty,
      );

      final l10n = l10nFor();
      expect(find.text(l10n.summaryStepReps(1)), findsOneWidget);
      expect(find.text(l10n.summaryTargetReps(7)), findsOneWidget,
          reason: 'where the next session opens, on the axis that moved');

      await stop(tester);
    });

    testWidgets('a slot that moved counts sessions like any other', (
      tester,
    ) async {
      late int sessionId;
      await tester.runAsync(() async {
        // Two clean sessions to a step: this one banks the first, so nothing
        // moved and the countdown is the ordinary one. There is no third
        // verdict left to explain instead.
        await rangedBench(advanced: true, successThreshold: 2);
        sessionId = await train([6, 6, 6]);
      });

      await tester.pumpWidget(
        appUnder(container, SummaryScreen(sessionId: sessionId)),
      );
      await pumpUntil(
        tester,
        () => find.text('PROGRESSION').evaluate().isNotEmpty,
      );

      expect(find.text(l10nFor().summaryHeldCleanSessions(1)), findsOneWidget);

      await stop(tester);
    });
  });

  group('a slot that predates the advanced axis arrives at its defaults', () {
    // A phone on a shipped build holds a database with none of these columns.
    // It is written as the frozen v1 DDL and climbed by the real ladder — every
    // rung of it, the one that adds the rep rates and the live goal included —
    // so the upgrade is handed the bytes a phone would hand it. See
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

    test('a slot written before the columns keeps what it had', () async {
      final db = oldDatabase();
      addTearDown(db.close);

      final slot = (await db.itemsForWorkout(1)).single.item;
      expect(slot.targetSets, 3);
      expect(slot.repsMin, 6);
      expect(slot.repsMax, 8, reason: 'the range it was training');
      expect(slot.suggestedWeight, 80);
    });

    test('and reads back unticked, at the rep defaults, with no goal', () async {
      final db = oldDatabase();
      addTearDown(db.close);

      final slot = (await db.itemsForWorkout(1)).single.item;
      expect(
        slot.addWeightAtTopOfRange,
        isFalse,
        reason:
            'a program built before the tick existed adds weight a '
            'session sooner, not a corrupt one',
      );
      expect(slot.repsIncrement, 1);
      expect(slot.repsDeload, 2);
      expect(slot.repsTarget, isNull, reason: 'no goal has ever been climbed');
      expect(slot.climbsRange, isFalse);
      expect(
        slot.goalReps,
        8,
        reason: 'an ordinary ranged slot still asks for the top of its range',
      );
    });

    test('and the database is left standing on the current rung', () async {
      final db = oldDatabase();
      addTearDown(db.close);

      expect(db.schemaVersion, 12, reason: 'three columns, one rung — the kept '
          'rates a rung above them, and the cycle columns above those');
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      expect(row.data.values.first, db.schemaVersion);
    });
  });
}
