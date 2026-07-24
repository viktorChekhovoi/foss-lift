import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/exercise_stats.dart';

/// The per-exercise progress maths are pure, so they are exercised here without
/// a database or a widget in sight.
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
}
