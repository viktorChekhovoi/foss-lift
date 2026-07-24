import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/warmup.dart';

/// The warm-up ramp on its own: that it climbs toward the working weight without
/// reaching it, drops reps as it goes, respects the empty bar, and degrades
/// sensibly when the working weight is light or the count is odd.
void main() {
  List<double> weights(List<WarmupSet> r) => [for (final s in r) s.weightKg];
  List<int> reps(List<WarmupSet> r) => [for (final s in r) s.reps];

  group('the shape of a normal ramp', () {
    final ramp = computeWarmups(workingKg: 100, barKg: 20);

    test('gives the default number of sets', () {
      expect(ramp.length, kDefaultWarmupSets);
    });

    test('climbs strictly, and stays under the working weight', () {
      final w = weights(ramp);
      for (var i = 1; i < w.length; i++) {
        expect(w[i], greaterThan(w[i - 1]), reason: 'ascending');
      }
      expect(w.last, lessThan(100), reason: 'the last warm-up is not the work');
    });

    test('starts at the empty bar', () {
      expect(weights(ramp).first, 20);
    });

    test('reps never rise as the weight does', () {
      final r = reps(ramp);
      for (var i = 1; i < r.length; i++) {
        expect(r[i], lessThanOrEqualTo(r[i - 1]));
      }
    });

    test('lands on loadable numbers', () {
      for (final w in weights(ramp)) {
        // Everything above the bar is a multiple of the 2.5 kg rounding step.
        if (w != 20) expect((w / 2.5) % 1, 0);
      }
    });
  });

  group('the empty bar is the floor', () {
    test('no warm-up is ever below the bar', () {
      final ramp = computeWarmups(workingKg: 60, barKg: 20, sets: 4);
      for (final s in ramp) {
        expect(s.weightKg, greaterThanOrEqualTo(20));
      }
    });

    test('a bar-only working weight has nothing to ramp', () {
      expect(computeWarmups(workingKg: 20, barKg: 20), isEmpty);
    });

    test('a working weight barely above the bar ramps little or nothing', () {
      final ramp = computeWarmups(workingKg: 22.5, barKg: 20);
      // Whatever it returns, it cannot invent a set at or above the work, nor
      // one below the bar.
      for (final s in ramp) {
        expect(s.weightKg, greaterThanOrEqualTo(20));
        expect(s.weightKg, lessThan(22.5));
      }
    });
  });

  group('non-barbell loads', () {
    test('a machine ramp needs no bar and starts light', () {
      final ramp = computeWarmups(workingKg: 50, barKg: 0);
      expect(ramp, isNotEmpty);
      expect(weights(ramp).first, lessThan(50 * 0.5),
          reason: 'the first machine warm-up is a light set');
      expect(weights(ramp).last, lessThan(50));
    });
  });

  group('the count is honoured', () {
    test('zero sets is no ramp', () {
      expect(computeWarmups(workingKg: 100, barKg: 20, sets: 0), isEmpty);
    });

    test('a single warm-up sits between the floor and the top, not at either',
        () {
      final ramp = computeWarmups(workingKg: 100, barKg: 20, sets: 1);
      expect(ramp.length, 1);
      expect(ramp.first.weightKg, greaterThan(20));
      expect(ramp.first.weightKg, lessThan(85));
    });

    test('many sets still climb without duplicates or overshoot', () {
      final ramp = computeWarmups(workingKg: 140, barKg: 20, sets: 6);
      final w = weights(ramp);
      expect(w.toSet().length, w.length, reason: 'no duplicate loads');
      for (var i = 1; i < w.length; i++) {
        expect(w[i], greaterThan(w[i - 1]));
      }
      expect(w.last, lessThan(140));
    });
  });

  group('degenerate input', () {
    test('a zero or negative working weight is no ramp', () {
      expect(computeWarmups(workingKg: 0, barKg: 20), isEmpty);
      expect(computeWarmups(workingKg: -50, barKg: 20), isEmpty);
    });

    test('a negative bar is treated as no bar', () {
      final ramp = computeWarmups(workingKg: 60, barKg: -20);
      expect(ramp, isNotEmpty);
      for (final s in ramp) {
        expect(s.weightKg, greaterThan(0));
      }
    });
  });

  group('the rep bands', () {
    test('are monotonic in the fraction of the working weight', () {
      expect(warmupReps(0.4), greaterThanOrEqualTo(warmupReps(0.6)));
      expect(warmupReps(0.6), greaterThanOrEqualTo(warmupReps(0.75)));
      expect(warmupReps(0.75), greaterThanOrEqualTo(warmupReps(0.85)));
    });
  });
}
