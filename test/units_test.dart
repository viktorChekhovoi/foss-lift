import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/util/units.dart';

void main() {
  group('weight units', () {
    test('kg is identity', () {
      expect(toDisplayWeight(100, 'kg'), 100);
      expect(toKg(100, 'kg'), 100);
      expect(unitLabel('kg'), 'kg');
    });

    test('kg <-> lb round-trips', () {
      final lb = toDisplayWeight(100, 'lb');
      expect(lb, closeTo(220.462, 0.01));
      expect(toKg(lb, 'lb'), closeTo(100, 1e-9));
      expect(unitLabel('lb'), 'lb');
    });

    test('a 45 lb plate is ~20.41 kg', () {
      expect(toKg(45, 'lb'), closeTo(20.4117, 0.001));
    });
  });
}
