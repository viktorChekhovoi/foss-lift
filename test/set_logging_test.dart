import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/state/active_workout.dart';

/// The StrongLifts-style tap cycle and what counts as missing the goal.
void main() {
  group('the tap cycle', () {
    test('the first tap claims the goal', () {
      final s = SetEntry(goalReps: 5, goalWeight: 100);
      expect(s.done, isFalse);

      s.cycle();
      expect(s.reps, 5);
      expect(s.done, isTrue);
      expect(s.missedGoal, isFalse);
    });

    test('each further tap drops one rep, and is a miss', () {
      final s = SetEntry(goalReps: 5, goalWeight: 100)..cycle();

      s.cycle();
      expect(s.reps, 4);
      expect(s.missedGoal, isTrue);

      s.cycle();
      expect(s.reps, 3);
      expect(s.missedGoal, isTrue);
    });

    test('tapping past zero returns the set to untouched', () {
      final s = SetEntry(goalReps: 2, goalWeight: 60);
      for (var i = 0; i < 3; i++) {
        s.cycle();
      }
      expect(s.reps, 0);
      expect(s.done, isTrue);
      expect(s.missedGoal, isTrue);

      s.cycle();
      expect(s.reps, isNull);
      expect(s.done, isFalse);
      expect(s.missedGoal, isFalse, reason: 'an unlogged set has missed nothing');
    });

    test('a zero-rep goal still cycles rather than sticking', () {
      final s = SetEntry(goalReps: 0);
      s.cycle();
      expect(s.reps, 0);
      s.cycle();
      expect(s.reps, isNull);
    });
  });

  group('missing the goal', () {
    test('hitting the goal at the suggested weight is a success', () {
      final s = SetEntry(goalReps: 8, goalWeight: 82.5, reps: 8);
      expect(s.missedGoal, isFalse);
    });

    test('beating the goal is still a success', () {
      final s = SetEntry(goalReps: 8, goalWeight: 82.5, reps: 11);
      expect(s.missedGoal, isFalse);
    });

    test('dropping the weight is a miss even at full reps', () {
      final s = SetEntry(goalReps: 8, goalWeight: 82.5, reps: 8)..weight = 75;
      expect(s.missedGoal, isTrue);
    });

    test('adding weight is not a miss', () {
      final s = SetEntry(goalReps: 8, goalWeight: 82.5, reps: 8)..weight = 85;
      expect(s.missedGoal, isFalse);
    });

    test('a template with no suggested weight cannot fail on weight', () {
      final s = SetEntry(goalReps: 8, reps: 8)..weight = 0;
      expect(s.missedGoal, isFalse);
    });

    test('the weight defaults to what the template suggests', () {
      expect(SetEntry(goalReps: 5, goalWeight: 60).weight, 60);
      expect(SetEntry(goalReps: 5).weight, 0);
    });
  });

  group('session aggregates', () {
    ActiveWorkout workoutOf(List<SetEntry> sets) => ActiveWorkout(
          routineId: null,
          workoutId: null,
          name: 'Test',
          startedAt: DateTime(2026),
          elapsed: 0,
          exercises: [
            ExerciseEntry(
                exerciseId: 1, name: 'Bench', muscle: 'Chest', sets: sets),
          ],
        );

    test('volume and counts ignore sets that were never logged', () {
      final w = workoutOf([
        SetEntry(goalReps: 5, goalWeight: 100, reps: 5),
        SetEntry(goalReps: 5, goalWeight: 100),
      ]);
      expect(w.volume, 500);
      expect(w.doneSets, 1);
      expect(w.totalSets, 2);
      expect(w.missedSets, 0);
    });

    test('a short set counts its actual reps, not the goal', () {
      final w = workoutOf([
        SetEntry(goalReps: 5, goalWeight: 100, reps: 3),
        SetEntry(goalReps: 5, goalWeight: 100, reps: 5),
      ]);
      expect(w.volume, 800);
      expect(w.missedSets, 1);
    });
  });
}
