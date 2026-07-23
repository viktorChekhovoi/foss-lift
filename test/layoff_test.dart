import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/layoff.dart';
import 'package:foss_lift/data/progression.dart';

/// The layoff arithmetic on its own: how long a gap is, whether it earns a
/// back-off, and where the back-off lands. No database, no clock of its own.
void main() {
  group('daysBetween', () {
    test('counts calendar days, not elapsed hours', () {
      expect(
        daysBetween(DateTime(2026, 3, 1, 23, 30), DateTime(2026, 3, 2, 0, 15)),
        1,
        reason: 'forty-five minutes apart, but it is the next day',
      );
    });

    test('survives a clock change', () {
      // The European spring-forward: 30 March 2025 is a 23-hour day. Counting
      // in elapsed hours would round this pair down to one day.
      expect(daysBetween(DateTime(2025, 3, 29), DateTime(2025, 3, 31)), 2);
    });

    test('is zero on the same day and negative going backwards', () {
      expect(daysBetween(DateTime(2026, 5, 4, 7), DateTime(2026, 5, 4, 22)), 0);
      expect(daysBetween(DateTime(2026, 5, 4), DateTime(2026, 5, 1)), -3);
    });
  });

  group('layoffDeload', () {
    LayoffDeload? deload(int gap, {int days = 14, int percent = 10}) =>
        layoffDeload(
            gapDays: gap, thresholdDays: days, percentPerPeriod: percent);

    test('a gap short of the threshold earns nothing', () {
      expect(deload(0), isNull);
      expect(deload(13), isNull);
    });

    test('the threshold itself is enough', () {
      expect(deload(14), (gapDays: 14, periods: 1, percent: 10));
    });

    test('the cut scales with the gap, in whole periods', () {
      expect(deload(27)?.percent, 10, reason: 'not two weeks twice over yet');
      expect(deload(28)?.percent, 20);
      expect(deload(42)?.percent, 30);
    });

    test('but stops stacking, however long you were away', () {
      final year = deload(365)!;
      expect(year.periods, kMaxLayoffPeriods);
      expect(year.percent, 30);
      expect(year.gapDays, 365, reason: 'the gap itself is still reported');
    });

    test('and never cuts more than the hard ceiling', () {
      expect(deload(365, percent: 50)?.percent, kMaxLayoffCutPercent);
    });

    test('a threshold of zero switches the whole thing off', () {
      expect(deload(999, days: 0), isNull);
      expect(deload(999, percent: 0), isNull);
    });
  });

  group('deloadedTarget', () {
    test('lands weight on a loadable half kilo, rounding down', () {
      expect(deloadedTarget(100, 10, ProgressionMode.weight), 90);
      // 87.5 * 0.9 = 78.75, which is not a weight anyone can load.
      expect(deloadedTarget(87.5, 10, ProgressionMode.weight), 78.5);
    });

    test('rounds reps and seconds down too', () {
      // 8 * 0.9 = 7.2, and 7 is the honest reading of it.
      expect(deloadedTarget(8, 10, ProgressionMode.reps), 7);
      expect(deloadedTarget(45, 10, ProgressionMode.time), 40);
    });

    test('never drives a target below its floor', () {
      expect(deloadedTarget(1, 90, ProgressionMode.reps),
          ProgressionMode.reps.floor);
      expect(deloadedTarget(5, 90, ProgressionMode.time),
          ProgressionMode.time.floor);
      expect(deloadedTarget(2, 90, ProgressionMode.weight), 0,
          reason: 'zero load is a legitimate place to land');
    });

    test('a cut of nothing leaves the target alone', () {
      expect(deloadedTarget(82.5, 0, ProgressionMode.weight), 82.5);
    });
  });
}
