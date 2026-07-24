import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/exercise_stats.dart';
import 'package:foss_lift/util/units.dart';

/// The per-exercise progress maths and CSV rendering are pure, so they are
/// exercised here without a database or a widget in sight.
void main() {
  ExerciseSetEntry set(
    int session,
    DateTime date, {
    double weight = 0,
    int reps = 0,
    int? seconds,
    bool done = true,
    int setNumber = 1,
    String name = 'Test',
  }) =>
      ExerciseSetEntry(
        sessionId: session,
        date: date,
        sessionName: name,
        setNumber: setNumber,
        weightKg: weight,
        reps: reps,
        seconds: seconds,
        done: done,
      );

  group('estimatedOneRepMax', () {
    test('a single rep is already a max', () {
      expect(estimatedOneRepMax(100, 1), 100);
    });

    test('extra reps at the same weight estimate more', () {
      // Epley: 100 * (1 + 5/30) = 116.666...
      expect(estimatedOneRepMax(100, 5), closeTo(116.6667, 0.001));
    });

    test('a set that was not really performed has no estimate', () {
      expect(estimatedOneRepMax(100, 0), 0);
    });
  });

  group('progressPoints', () {
    test('one point per session, best set kept', () {
      final points = progressPoints([
        set(1, DateTime(2026, 1, 1), weight: 80, reps: 5, setNumber: 1),
        set(1, DateTime(2026, 1, 1), weight: 80, reps: 8, setNumber: 2),
        set(1, DateTime(2026, 1, 1), weight: 60, reps: 12, setNumber: 3),
      ]);
      expect(points, hasLength(1));
      expect(points.first.topWeightKg, 80);
      // Between the two 80 kg sets the one with more reps is the top set.
      expect(points.first.repsAtTop, 8);
      // 80*(1+8/30)=101.33 beats 60*(1+12/30)=84, so it drives the 1RM.
      expect(points.first.est1RMKg, closeTo(101.333, 0.01));
    });

    test('skipped sets do not count, all-skipped sessions vanish', () {
      final points = progressPoints([
        set(1, DateTime(2026, 1, 1), weight: 100, reps: 5, done: false),
        set(2, DateTime(2026, 1, 2), weight: 90, reps: 5, done: true),
      ]);
      expect(points, hasLength(1));
      expect(points.first.topWeightKg, 90);
    });

    test('sorted oldest-first regardless of input order', () {
      final points = progressPoints([
        set(2, DateTime(2026, 1, 10), weight: 90, reps: 5),
        set(1, DateTime(2026, 1, 1), weight: 80, reps: 5),
        set(3, DateTime(2026, 1, 20), weight: 100, reps: 5),
      ]);
      expect(points.map((p) => p.topWeightKg).toList(), [80, 90, 100]);
    });

    test('same-day sessions stay two points', () {
      final points = progressPoints([
        set(1, DateTime(2026, 1, 1, 9), weight: 80, reps: 5),
        set(2, DateTime(2026, 1, 1, 18), weight: 85, reps: 5),
      ]);
      expect(points, hasLength(2));
    });

    test('a held movement carries its best hold', () {
      final points = progressPoints([
        set(1, DateTime(2026, 1, 1), seconds: 45, setNumber: 1),
        set(1, DateTime(2026, 1, 1), seconds: 60, setNumber: 2),
      ]);
      expect(points.first.bestSeconds, 60);
    });
  });

  group('exerciseHistoryCsv', () {
    test('header names the display unit and rows follow', () {
      final csv = exerciseHistoryCsv(
        exerciseName: 'Bench Press',
        unit: 'kg',
        convertWeight: toDisplayWeight,
        sets: [
          set(1, DateTime(2026, 1, 1, 10, 30),
              weight: 80, reps: 5, name: 'Push'),
        ],
      );
      final lines = csv.split('\r\n');
      expect(lines.first,
          'Date,Session,Exercise,Set,Weight (kg),Reps,Seconds,Est 1RM (kg)');
      expect(lines[1],
          startsWith('2026-01-01 10:30,Push,Bench Press,1,80,5,,'));
      // Est 1RM = 80*(1+5/30) = 93.33
      expect(lines[1], endsWith('93.33'));
    });

    test('weights convert to pounds when that is the unit', () {
      final csv = exerciseHistoryCsv(
        exerciseName: 'Squat',
        unit: 'lb',
        convertWeight: toDisplayWeight,
        sets: [set(1, DateTime(2026, 1, 1), weight: 100, reps: 1)],
      );
      final cols = csv.split('\r\n')[1].split(',');
      // 100 kg is 220.46 lb; single rep so the 1RM equals the weight.
      expect(double.parse(cols[4]), closeTo(220.46, 0.01));
      expect(double.parse(cols[7]), closeTo(220.46, 0.01));
    });

    test('a comma in a session name is quoted', () {
      final csv = exerciseHistoryCsv(
        exerciseName: 'Plank',
        unit: 'kg',
        convertWeight: toDisplayWeight,
        sets: [
          set(1, DateTime(2026, 1, 1), seconds: 60, name: 'Legs, day one'),
        ],
      );
      expect(csv, contains('"Legs, day one"'));
      // A timed set fills Seconds, leaves Reps at 0 and the 1RM blank.
      expect(csv.split('\r\n')[1], endsWith(',0,60,'));
    });
  });
}
