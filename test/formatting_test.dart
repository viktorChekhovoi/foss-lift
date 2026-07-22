import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/state/active_workout.dart' show fmtWeight;
import 'package:foss_lift/util/format.dart';
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

  group('fmtTotal', () {
    test('groups digits up to five figures', () {
      expect(fmtTotal(0), '0');
      expect(fmtTotal(940), '940');
      expect(fmtTotal(9850), '9,850');
    });
    test('switches to k at five figures', () {
      expect(fmtTotal(10000), '10k');
      expect(fmtTotal(12460), '12.5k');
      expect(fmtTotal(999400), '999.4k');
    });
    test('switches to M at seven figures', () {
      expect(fmtTotal(1000000), '1M');
      expect(fmtTotal(1248300), '1.2M');
    });
    test('rounds fractional volumes', () {
      expect(fmtTotal(255.5), '256');
    });
  });
}
