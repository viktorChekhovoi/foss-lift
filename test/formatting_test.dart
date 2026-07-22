import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/screens/workout_screen.dart' show fmtDuration;

void main() {
  group('fmtWeight', () {
    test('drops trailing .0 for whole numbers', () {
      expect(fmtWeight(80), '80');
      expect(fmtWeight(140.0), '140');
    });
    test('keeps one decimal for fractional plates', () {
      expect(fmtWeight(12.5), '12.5');
    });
  });

  group('fmtDuration', () {
    test('formats minutes and zero-padded seconds', () {
      expect(fmtDuration(0), '0:00');
      expect(fmtDuration(9), '0:09');
      expect(fmtDuration(65), '1:05');
      expect(fmtDuration(600), '10:00');
    });
  });

  group('ActiveWorkout aggregates', () {
    test('volume counts only completed sets', () {
      final w = ActiveWorkout(
        routineId: null,
        workoutId: null,
        name: 'Test',
        startedAt: DateTime(2026),
        elapsed: 0,
        exercises: [
          ExerciseEntry(
            exerciseId: 1,
            name: 'Bench',
            muscle: 'Chest',
            sets: [
              SetEntry(weight: 100, reps: 5, done: true),
              SetEntry(weight: 100, reps: 5), // not done
            ],
          ),
        ],
      );
      expect(w.volume, 500);
      expect(w.doneSets, 1);
      expect(w.totalSets, 2);
    });
  });
}
