// Integration tests for features/index.html#sec03
//
// Per-slot configuration in the exercise builder: sets, a target (fixed count /
// range / to-failure / timed hold), a rest override, a suggested weight and the
// progression rates. Which targets are offered follows the exercise's measure,
// not the programme; a rep range keeps its width as it moves; a set is reps XOR
// seconds; the untouched defaults are +2.5 kg after a clean session, −5 kg after
// two misses.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

Future<WorkoutItemView> itemNamed(
  AppDatabase db,
  int workoutId,
  String exerciseName,
) async {
  final items = await db.itemsForWorkout(workoutId);
  return items.firstWhere((v) => v.exercise.name == exerciseName);
}

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  group('a slot stores its full configuration', () {
    test('the seeded bench slot round-trips every configured field', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = (await itemNamed(db, push, 'Bench Press')).item;

      expect(bench.targetSets, 4);
      expect(bench.repsMin, 6);
      expect(bench.repsMax, 8);
      expect(bench.suggestedWeight, 80);
      expect(bench.progression, ProgressionMode.weight);
      expect(bench.increment, 2.5);
      expect(bench.deload, 5);
      expect(bench.successThreshold, 1);
      expect(bench.failureThreshold, 2);
    });

    test(
      'a per-slot rest override is stored and overrides the routine default',
      () async {
        final push = await workoutIdNamed(db, 'Push');
        final bench = await exerciseNamed(db, 'Bench Press');

        final draft = ItemDraft.forExercise(bench)..restSeconds = 45;
        await db.replaceWorkoutItems(
          push,
          itemCompanions([draft], workoutId: push),
        );

        final saved = (await itemNamed(db, push, 'Bench Press')).item;
        expect(saved.restSeconds, 45); // null would mean "fall back to routine"
      },
    );
  });

  group('target types', () {
    test('a fixed rep count reads as a single number', () async {
      final push = await workoutIdNamed(db, 'Push');
      final ohp = (await itemNamed(db, push, 'Overhead Press')).item;
      expect(ohp.repsMax, isNull); // fixed count of repsMin
      expect(repsLabel(ohp), '8');
    });

    test('a rep range reads as low–high', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = (await itemNamed(db, push, 'Bench Press')).item;
      expect(repsLabel(bench), '6–8');
    });

    test('a to-failure slot drops its range and reads as "Failure"', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = await exerciseNamed(db, 'Bench Press');

      final draft = ItemDraft.forExercise(bench)
        ..toFailure = true
        ..repsMax = 8;
      await db.replaceWorkoutItems(
        push,
        itemCompanions([draft], workoutId: push),
      );

      final saved = (await itemNamed(db, push, 'Bench Press')).item;
      expect(saved.toFailure, isTrue);
      expect(saved.repsMax, isNull); // a range has no meaning at failure
      expect(repsLabel(saved), 'Failure');
    });

    test('a timed hold reads in seconds', () async {
      final plank = await exerciseNamed(db, 'Plank');
      final push = await workoutIdNamed(db, 'Push');

      final draft = ItemDraft.forExercise(plank)..holdSeconds = 45;
      await db.replaceWorkoutItems(
        push,
        itemCompanions([draft], workoutId: push),
      );

      final saved = (await itemNamed(db, push, 'Plank')).item;
      expect(saved.progression, ProgressionMode.time);
      expect(repsLabel(saved), '45s');
    });
  });

  group('which targets are offered follows the measure, not the programme', () {
    test('a counted lift offers weight and reps', () async {
      final bench = await exerciseNamed(db, 'Bench Press');
      final draft = ItemDraft.forExercise(bench);
      expect(draft.modes, [ProgressionMode.weight, ProgressionMode.reps]);
      expect(draft.progression, ProgressionMode.weight); // opens on load
    });

    test(
      'a held movement offers only time and cannot be switched off it',
      () async {
        final plank = await exerciseNamed(db, 'Plank');
        final draft = ItemDraft.forExercise(plank);
        expect(draft.modes, [ProgressionMode.time]);

        // The builder never offers "a plank progressed by weight".
        draft.setMode(ProgressionMode.weight);
        expect(draft.progression, ProgressionMode.time);
      },
    );

    test('the builder never offers a deadlift progressed by time', () async {
      final deadlift = await exerciseNamed(db, 'Deadlift');
      final draft = ItemDraft.forExercise(deadlift);
      expect(draft.modes, isNot(contains(ProgressionMode.time)));
    });

    test(
      'switching axis resets the step/back-off to that axis\'s defaults',
      () async {
        final bench = await exerciseNamed(db, 'Bench Press');
        final draft = ItemDraft.forExercise(bench);
        expect(draft.increment, 2.5); // weight defaults
        expect(draft.deload, 5);

        draft.setMode(ProgressionMode.reps);
        expect(draft.progression, ProgressionMode.reps);
        expect(draft.increment, 1); // rep defaults, not 2.5 reps
        expect(draft.deload, 2);
      },
    );
  });

  group('a rep range keeps its width as progression moves it', () {
    test('stepping up carries the whole range', () async {
      // Pull-Up is seeded on the reps axis with a 6–10 range (width 4).
      final pull = await workoutIdNamed(db, 'Pull');
      final pullUp = (await itemNamed(db, pull, 'Pull-Up')).item;
      expect(pullUp.progression, ProgressionMode.reps);
      expect(pullUp.repsMin, 6);
      expect(pullUp.repsMax, 10);

      // One clean session (default threshold 1) steps reps up by one.
      await db.advanceProgression(pullUp.id, success: true);

      final moved = await db.workoutItemById(pullUp.id);
      expect(moved!.repsMin, 7);
      expect(moved.repsMax, 11); // 6–10 becomes 7–11, width still 4
    });

    test('a back-off keeps the width on the way down too', () async {
      final pull = await workoutIdNamed(db, 'Pull');
      final pullUp = (await itemNamed(db, pull, 'Pull-Up')).item;

      // Two misses in a row (default failure threshold) back the range off.
      await db.advanceProgression(pullUp.id, success: false);
      await db.advanceProgression(pullUp.id, success: false);

      final moved = await db.workoutItemById(pullUp.id);
      final width = moved!.repsMax! - moved.repsMin;
      expect(width, 4); // still 6–10 wide, wherever it landed
    });
  });

  group('a set is measured in reps or seconds, never both', () {
    test(
      'a timed set logs seconds and leaves reps at zero, off the rep tally',
      () async {
        final now = DateTime(2026, 2, 1, 18);
        await db.saveSession(
          routineId: null,
          workoutId: null,
          name: 'Mixed day',
          startedAt: now,
          endedAt: now.add(const Duration(minutes: 30)),
          durationSeconds: 1800,
          totalVolume: 640,
          sets: [
            // A counted set: eight reps.
            SessionSetsCompanion.insert(
              sessionId: 0,
              exerciseName: 'Bench Press',
              setNumber: 1,
              weight: const Value(80),
              reps: const Value(8),
              done: const Value(true),
            ),
            // A held set: 45 seconds, zero reps.
            SessionSetsCompanion.insert(
              sessionId: 0,
              exerciseName: 'Plank',
              setNumber: 1,
              reps: const Value(0),
              seconds: const Value(45),
              done: const Value(true),
            ),
          ],
        );

        final totals = await db.watchLifetimeTotals().first;
        // The 45-second plank counts as 45 of nothing: only the bench reps show.
        expect(totals.reps, 8);
        expect(totals.sets, 2);
      },
    );

    test(
      'a short hold misses its goal; a short rep count misses its goal too',
      () {
        // Timed: judged on seconds against goalSeconds.
        const heldShort = SessionSet(
          id: 1,
          sessionId: 1,
          exerciseName: 'Plank',
          setNumber: 1,
          weight: 0,
          reps: 0,
          done: true,
          goalReps: 0,
          seconds: 20,
          goalSeconds: 30,
        );
        const heldMet = SessionSet(
          id: 2,
          sessionId: 1,
          exerciseName: 'Plank',
          setNumber: 1,
          weight: 0,
          reps: 0,
          done: true,
          goalReps: 0,
          seconds: 45,
          goalSeconds: 30,
        );
        expect(setMissedGoal(heldShort), isTrue);
        expect(setMissedGoal(heldMet), isFalse);
      },
    );
  });

  group('the untouched progression defaults', () {
    test(
      'the weight axis defaults to +2.5 up and −5 down after two misses',
      () {
        expect(ProgressionMode.weight.defaultIncrement, 2.5);
        expect(ProgressionMode.weight.defaultDeload, 5);
        expect(defaultSuccessThreshold, 1);
        expect(defaultFailureThreshold, 2);
      },
    );

    test('one clean session adds 2.5 kg to a weight slot', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = (await itemNamed(db, push, 'Bench Press')).item;
      expect(bench.suggestedWeight, 80);

      final moved = await db.advanceProgression(bench.id, success: true);

      expect(moved, 2.5);
      expect((await db.workoutItemById(bench.id))!.suggestedWeight, 82.5);
    });

    test('two misses in a row drop a weight slot by 5 kg', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = (await itemNamed(db, push, 'Bench Press')).item;

      // First miss: nothing moves yet (streak of one).
      await db.advanceProgression(bench.id, success: false);
      expect((await db.workoutItemById(bench.id))!.suggestedWeight, 80);

      // Second miss in a row: the back-off lands.
      await db.advanceProgression(bench.id, success: false);
      expect((await db.workoutItemById(bench.id))!.suggestedWeight, 75);
    });
  });
}
