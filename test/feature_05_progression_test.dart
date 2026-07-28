// Feature 05 — Automatic progression (features/index.html#sec05).
//
// Every slot advances along a single axis; a clean session steps it up and two
// misses back it off. These tests drive the behaviour the spec describes through
// its real public surface: the pure rules in `progression.dart`, the
// `AppDatabase.advanceProgression` path that applies them to a stored slot, the
// `ExerciseEntry` verdict/lightest-set rules that decide what gets applied, and
// one end-to-end run through the live controller's finish path.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/state/active_workout.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

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
      expect(ExerciseMeasure.reps.modes,
          [ProgressionMode.weight, ProgressionMode.reps]);
      expect(ExerciseMeasure.reps.defaultMode, ProgressionMode.weight);
    });

    test('a held movement may only use time', () {
      expect(ExerciseMeasure.time.modes, [ProgressionMode.time]);
      expect(ExerciseMeasure.time.defaultMode, ProgressionMode.time);
    });

    test('coerce forces a disallowed axis back to the measure default', () {
      // A plank cannot be progressed by reps; a bench cannot be by time.
      expect(ExerciseMeasure.time.coerce(ProgressionMode.reps),
          ProgressionMode.time);
      expect(ExerciseMeasure.reps.coerce(ProgressionMode.time),
          ProgressionMode.weight);
      // An allowed axis is left untouched.
      expect(ExerciseMeasure.reps.coerce(ProgressionMode.reps),
          ProgressionMode.reps);
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
    }) =>
        stepProgression(
          success: success,
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

    test('a success zeroes the failure count — consecutive means consecutive',
        () {
      final s = step(success: true, failures: 1, successThreshold: 3);
      expect(s.failures, 0);
      expect(s.successes, 1);
      expect(s.delta, 0);
    });

    test('a failure zeroes the success count', () {
      final s = step(success: false, successes: 2, failureThreshold: 2);
      expect(s, (successes: 0, failures: 1, delta: 0.0));
    });
  });

  group('advanceTarget never drives a target below the mode floor', () {
    test('weight may fall to zero — a belt lifted off a bodyweight movement',
        () {
      expect(advanceTarget(2.5, -5, ProgressionMode.weight), 0);
      expect(advanceTarget(10, -2.5, ProgressionMode.weight), 7.5);
    });

    test('reps never fall below a single rep', () {
      expect(advanceTarget(2, -5, ProgressionMode.reps), 1);
    });

    test('time never falls below five seconds', () {
      expect(advanceTarget(6, -5, ProgressionMode.time), 5);
    });
  });

  group('the weight axis, applied through the database', () {
    test('a clean session adds the default 2.5 kg', () async {
      final id = await slotIdNamed(db, 'Push', 'Bench Press');
      final moved = await db.advanceProgression(id,
          success: true, performedWeight: 80);
      expect(moved, closeTo(2.5, 1e-9));
      final slot = await db.workoutItemById(id);
      expect(slot!.suggestedWeight, 82.5);
      // The step resets the counters — the next one must be earned afresh.
      expect(slot.successStreak, 0);
      expect(slot.failStreak, 0);
    });

    test('two misses in a row back it off by the default 5 kg', () async {
      final id = await slotIdNamed(db, 'Push', 'Bench Press');

      final first = await db.advanceProgression(id, success: false);
      expect(first, 0); // one bad night is not the weight
      var slot = await db.workoutItemById(id);
      expect(slot!.suggestedWeight, 80);
      expect(slot.failStreak, 1);

      final second = await db.advanceProgression(id, success: false);
      expect(second, closeTo(-5, 1e-9));
      slot = await db.workoutItemById(id);
      expect(slot!.suggestedWeight, 75);
      expect(slot.failStreak, 0);
    });

    test('the streaks are stored across sessions until a step is earned',
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

      await db.advanceProgression(id, success: true, performedWeight: 80);
      expect((await db.workoutItemById(id))!.successStreak, 1);
      await db.advanceProgression(id, success: true, performedWeight: 80);
      expect((await db.workoutItemById(id))!.successStreak, 2);
      // Held at 80 the whole way up.
      expect((await db.workoutItemById(id))!.suggestedWeight, 80);

      final moved =
          await db.advanceProgression(id, success: true, performedWeight: 80);
      expect(moved, closeTo(2.5, 1e-9));
      final slot = await db.workoutItemById(id);
      expect(slot!.suggestedWeight, 82.5);
      expect(slot.successStreak, 0);
    });

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

      await db.advanceProgression(id, success: true, performedWeight: 80);
      expect((await db.workoutItemById(id))!.successStreak, 1);
      await db.advanceProgression(id, success: false);
      final slot = await db.workoutItemById(id);
      expect(slot!.successStreak, 0);
      expect(slot.failStreak, 1);
    });
  });

  group('loading the bar past the suggestion is itself progression', () {
    test('beating the stored target raises it, then the step is added', () async {
      final id = await slotIdNamed(db, 'Push', 'Bench Press');
      // Carried 85 through every set of an 80 kg slot, and earned the step.
      final moved = await db.advanceProgression(id,
          success: true, performedWeight: 85);
      expect(moved, closeTo(7.5, 1e-9)); // 85 + 2.5, measured from 80
      expect((await db.workoutItemById(id))!.suggestedWeight, 87.5);
    });

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

      final moved = await db.advanceProgression(id,
          success: true, performedWeight: 85);
      expect(moved, closeTo(5, 1e-9)); // 85 with no step, up from 80
      final slot = await db.workoutItemById(id);
      expect(slot!.suggestedWeight, 85);
      expect(slot.successStreak, 1); // step still pending
    });

    test('coming in lighter than the target does not raise it', () async {
      // A weight below the suggestion is a deload, answered by the failure path,
      // never by the performed-weight bump.
      final id = await slotIdNamed(db, 'Push', 'Bench Press');
      final moved = await db.advanceProgression(id,
          success: false, performedWeight: 75);
      expect(moved, 0); // one miss, no move; target stays put
      expect((await db.workoutItemById(id))!.suggestedWeight, 80);
    });
  });

  group('the reps axis, applied through the database', () {
    test('a clean session adds a rep and keeps the range width', () async {
      // Pull-Up is 6–10, reps mode, no suggested weight.
      final id = await slotIdNamed(db, 'Pull', 'Pull-Up');
      final moved = await db.advanceProgression(id, success: true);
      expect(moved, 1);
      final slot = await db.workoutItemById(id);
      expect(slot!.repsMin, 7);
      expect(slot.repsMax, 11); // width of 4 preserved
    });

    test('two misses drop the reps and keep the range width', () async {
      final id = await slotIdNamed(db, 'Pull', 'Pull-Up');
      await db.advanceProgression(id, success: false);
      final moved = await db.advanceProgression(id, success: false);
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
      final moved = await db.advanceProgression(id, success: false);
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
      final moved = await db.advanceProgression(id, success: true);
      expect(moved, 5);
      expect((await db.workoutItemById(id))!.holdSeconds, 35);
    });

    test('two misses cut the hold by the configured deload', () async {
      final id = await plankSlot();
      await db.advanceProgression(id, success: false);
      final moved = await db.advanceProgression(id, success: false);
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
      final moved = await db.advanceProgression(id, success: true);
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

    test('the performed weight is the lightest logged set — 100/105/110 is 100',
        () {
      final e = entry([
        SetEntry(goal: 8, weight: 100, logged: 8),
        SetEntry(goal: 8, weight: 105, logged: 8),
        SetEntry(goal: 8, weight: 110, logged: 8),
      ]);
      expect(e.performedWeight, 100);
    });

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

    test('a session with a skipped set backs nothing off but stores the miss',
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
    });
  });
}
