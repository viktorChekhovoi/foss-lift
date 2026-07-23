import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/plates.dart';
import 'package:foss_lift/util/units.dart';

/// The plate arithmetic on its own: what a weight type means, what the standard
/// rack is, and — the part worth being sure of — which plates make a number and
/// what happens when none of them can.
void main() {
  /// The kilogram rack with two pairs of everything: the defaults.
  final kgRack = defaultPlatesFor('kg');

  PlateSolution solve(double target,
          {double bar = 20, List<PlateStack>? rack}) =>
      solvePlates(
          targetKg: target, barKg: bar, inventory: rack ?? kgRack);

  /// The per-side stack as "20+10+1.25", for terse expectations.
  String stack(PlateSolution s) =>
      s.plates.map((p) => '${p.kg}×${p.count}').join(' ');

  group('weight types', () {
    test('come from the equipment, with everything else a machine', () {
      expect(weightTypeForEquipment('Barbell'), WeightType.bar);
      expect(weightTypeForEquipment('Dumbbell'), WeightType.dumbbell);
      expect(weightTypeForEquipment('Cable'), WeightType.machine);
      expect(weightTypeForEquipment('Bodyweight'), WeightType.machine);
      expect(weightTypeForEquipment('Other'), WeightType.machine);
    });

    test('only a bar has sides to load', () {
      expect(WeightType.bar.loadedPerSide, isTrue);
      expect(WeightType.dumbbell.loadedPerSide, isFalse);
      expect(WeightType.machine.loadedPerSide, isFalse);
    });
  });

  group('defaults follow the unit', () {
    test('a kilogram gym gets a kilogram rack', () {
      expect(defaultBarKg('kg'), 20.0);
      expect(kgRack.first.kg, 25.0);
      expect(kgRack.last.kg, 1.25);
    });

    test('with a pair of everything and a pile of the workhorse plate', () {
      PlateStack of(double kg) => kgRack.firstWhere((p) => p.kg == kg);
      expect(of(20).count, kDefaultBigPlateCount);
      expect(of(25).count, kDefaultPlateCount);
      expect(of(1.25).count, kDefaultPlateCount);

      final lb = defaultPlatesFor('lb');
      expect(lb.first.count, kDefaultBigPlateCount, reason: 'the 45s');
      expect(lb.skip(1).every((p) => p.count == kDefaultPlateCount), isTrue);
    });

    test('a pounds gym gets 45s and 25s, not converted metric', () {
      final rack = defaultPlatesFor('lb');
      expect(toDisplayWeight(defaultBarKg('lb'), 'lb'), closeTo(45, 1e-9));
      expect(rack, hasLength(6));
      expect(toDisplayWeight(rack.first.kg, 'lb'), closeTo(45, 1e-9));
      expect(toDisplayWeight(rack.last.kg, 'lb'), closeTo(2.5, 1e-9));
    });

    test('a stored rack wins over the unit; nothing stored falls back', () {
      final stored = encodePlates([(kg: 10, count: 2)]);
      expect(resolvePlateSettings(unit: 'lb', inventory: stored).plates,
          [(kg: 10.0, count: 2)]);
      expect(resolvePlateSettings(unit: 'kg').plates, kgRack);
      expect(resolvePlateSettings(unit: 'kg', barKg: 15).barKg, 15);
    });
  });

  group('formatting', () {
    test('keeps a plate that is not a round number', () {
      expect(fmtPlateWeight(1.25), '1.25');
      expect(fmtPlateWeight(2.5), '2.5');
      expect(fmtPlateWeight(20), '20');
      expect(fmtPlateWeight(100), '100');
      expect(fmtPlateWeight(0), '0');
    });
  });

  group('encoding', () {
    test('round-trips, heaviest first', () {
      final plates = [(kg: 1.25, count: 4), (kg: 20.0, count: 6)];
      expect(decodePlates(encodePlates(plates)),
          [(kg: 20.0, count: 6), (kg: 1.25, count: 4)]);
    });

    test('survives a pound plate, tail and all', () {
      final lb = defaultPlatesFor('lb');
      expect(decodePlates(encodePlates(lb)), lb);
    });

    test('drops nonsense rather than throwing', () {
      expect(decodePlates('20x4;banana;;5xno;0x4;10x2'),
          [(kg: 20.0, count: 4), (kg: 10.0, count: 2)]);
      expect(decodePlates(null), isNull, reason: 'never configured');
      expect(decodePlates(''), isEmpty, reason: 'configured as nothing');
    });
  });

  group('solving a bar', () {
    test('the everyday case', () {
      final s = solve(100);
      expect(s.exact, isTrue);
      expect(s.perSideKg, 40);
      expect(stack(s), '25.0×1 15.0×1');
    });

    test('counts the bar itself', () {
      final s = solve(20);
      expect(s.exact, isTrue);
      expect(s.plates, isEmpty, reason: 'the bar is already the weight');
      expect(s.perSideKg, 0);
    });

    test('flags a weight lighter than the bar', () {
      final s = solve(15);
      expect(s.belowBar, isTrue);
      expect(s.achievedKg, 20, reason: 'the bar is the lightest thing there is');
      expect(s.exact, isFalse);
    });

    test('a lighter bar changes the answer, not the method', () {
      final s = solve(40, bar: 10);
      expect(s.exact, isTrue);
      expect(s.perSideKg, 15);
    });

    test('needs the small plates and finds them', () {
      final s = solve(82.5);
      expect(s.exact, isTrue);
      expect(stack(s), '25.0×1 5.0×1 1.25×1');
    });

    test('prefers the fewest plates for the same load', () {
      final s = solve(60);
      expect(s.exact, isTrue);
      expect(stack(s), '20.0×1',
          reason: 'not 10+5+2.5+2.5, which weighs the same and is four plates');
    });

    test('and the heavier plates when the count ties', () {
      final s = solve(100);
      expect(stack(s), '25.0×1 15.0×1',
          reason: '20+20 is the same two plates; a lifter loads the 25 first');
    });
  });

  group('when the gym cannot make the weight', () {
    test('lands on the nearest load and says it is not the one asked for', () {
      // Nothing here makes a 0.5 kg step: 81 kg is 30.5 a side, and the rack
      // only reaches 30 or 31.25.
      final s = solve(81);
      expect(s.exact, isFalse);
      expect(s.achievedKg, 80, reason: 'half a kilo a side short beats 0.75 over');
      expect(stack(s), '25.0×1 5.0×1');
    });

    test('errs light when two loads are equally close', () {
      // 21.25 a side is available either side of 21.875 — take the lighter.
      final s = solve(63.75);
      expect(s.exact, isFalse);
      expect(s.achievedKg, 62.5);
    });

    test('runs out of plates rather than inventing them', () {
      final s = solve(200, rack: [(kg: 20, count: 2)]);
      expect(s.exact, isFalse);
      expect(s.achievedKg, 60, reason: 'one pair of 20s and the bar');
      expect(stack(s), '20.0×1');
    });

    test('ignores an odd plate that has no partner', () {
      final s = solve(60, rack: [(kg: 20, count: 1), (kg: 10, count: 2)]);
      expect(s.achievedKg, 40, reason: 'the lone 20 cannot go on one side only');
      expect(stack(s), '10.0×1');
    });

    test('an empty rack is just the bar', () {
      final s = solve(100, rack: const []);
      expect(s.plates, isEmpty);
      expect(s.achievedKg, 20);
      expect(s.exact, isFalse);
    });
  });

  group('pounds', () {
    test('a plate rack in pounds still lands exactly on round numbers', () {
      final rack = defaultPlatesFor('lb');
      final s = solvePlates(
        targetKg: toKg(225, 'lb'),
        barKg: defaultBarKg('lb'),
        inventory: rack,
      );
      expect(s.exact, isTrue,
          reason: 'two 45s a side, and the conversion tail must not eat it');
      expect(toDisplayWeight(s.perSideKg, 'lb'), closeTo(90, 1e-6));
      expect(toDisplayWeight(s.achievedKg, 'lb'), closeTo(225, 1e-6));
    });
  });
}
