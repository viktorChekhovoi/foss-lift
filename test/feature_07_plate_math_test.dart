// Integration tests for features/07-plate-math.md — the plate solver and the
// line it feeds. The solver (`solvePlates`) is a pure function and is where the
// combinatorial truth lives, so most of this file drives it directly across the
// spec's edge cases; a handful of widget tests confirm the line reads back the
// green / gold / below-bar states through the real widget.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/plates.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/util/units.dart';
import 'package:foss_lift/widgets/plate_line.dart';

import 'support/harness.dart';

/// The standard metric rack a fresh install owns: a pair of everything and a
/// pile of 20s. Read from the code under test rather than hand-copied so the
/// test tracks the shipped rack.
final _kgRack = defaultPlatesFor('kg');

/// A stack for building custom racks in tests.
PlateStack _stack(double kg, int count) => (kg: kg, count: count);

/// Asserts a solution's per-side stack, heaviest first, is exactly [want].
void _expectStack(PlateSolution s, List<(double, int)> want) {
  expect(s.plates.length, want.length, reason: 'stack size');
  for (var i = 0; i < want.length; i++) {
    expect(s.plates[i].kg, closeTo(want[i].$1, 1e-6), reason: 'plate $i kg');
    expect(s.plates[i].count, want[i].$2, reason: 'plate $i count');
  }
}

/// Total plates on one side.
int _plateCount(PlateSolution s) => s.plates.fold(0, (a, p) => a + p.count);

void main() {
  group('solves the breakdown', () {
    test('the everyday case: one plate per side, exact and counting the bar',
        () {
      final s = solvePlates(targetKg: 60, barKg: 20, inventory: _kgRack);
      expect(s.exact, isTrue);
      expect(s.belowBar, isFalse);
      expect(s.achievedKg, closeTo(60, 1e-9));
      expect(s.perSideKg, closeTo(20, 1e-9));
      expect(s.barKg, 20);
      _expectStack(s, [(20, 1)]);
    });

    test('the bar alone when the target is the empty bar', () {
      final s = solvePlates(targetKg: 20, barKg: 20, inventory: _kgRack);
      expect(s.exact, isTrue);
      expect(s.belowBar, isFalse);
      expect(s.plates, isEmpty);
      expect(s.achievedKg, closeTo(20, 1e-9));
    });

    test('small plates: a single 1.25 finishes an exact odd weight', () {
      final s = solvePlates(targetKg: 22.5, barKg: 20, inventory: _kgRack);
      expect(s.exact, isTrue);
      _expectStack(s, [(1.25, 1)]);
      expect(s.perSideKg, closeTo(1.25, 1e-9));
    });

    test('a lighter bar is respected, not the default', () {
      final s = solvePlates(targetKg: 55, barKg: 15, inventory: _kgRack);
      expect(s.exact, isTrue);
      expect(s.barKg, 15);
      expect(s.perSideKg, closeTo(20, 1e-9));
      _expectStack(s, [(20, 1)]);
    });
  });

  group('below the bar is its own case', () {
    test('asking for less than the empty bar sets belowBar, not exact', () {
      final s = solvePlates(targetKg: 15, barKg: 20, inventory: _kgRack);
      expect(s.belowBar, isTrue);
      expect(s.exact, isFalse);
      expect(s.plates, isEmpty);
      expect(s.achievedKg, closeTo(20, 1e-9));
    });
  });

  group('ties break the way a lifter loads a bar', () {
    test('40 kg/side is 25 + 15, not 20 + 20 and never four small plates', () {
      final s = solvePlates(targetKg: 100, barKg: 20, inventory: _kgRack);
      expect(s.exact, isTrue);
      expect(s.perSideKg, closeTo(40, 1e-9));
      expect(_plateCount(s), 2);
      _expectStack(s, [(25, 1), (15, 1)]);
    });

    test('on a count tie the heavier plate wins: 30/side is 25 + 5', () {
      final s = solvePlates(targetKg: 80, barKg: 20, inventory: _kgRack);
      expect(s.exact, isTrue);
      expect(_plateCount(s), 2);
      _expectStack(s, [(25, 1), (5, 1)]);
    });
  });

  group('the search is exhaustive, not greedy', () {
    test('a pounds 45/35/25 rack: 60/side is 35 + 25, not a lone 45', () {
      final b = toKg(45, 'lb');
      final inv = [
        _stack(toKg(45, 'lb'), 2),
        _stack(toKg(35, 'lb'), 2),
        _stack(toKg(25, 'lb'), 2),
      ];
      // 45 + 2 * 60 lb = 165 lb.
      final s = solvePlates(targetKg: toKg(165, 'lb'), barKg: b, inventory: inv);
      expect(s.exact, isTrue, reason: 'greedy would stall on the lone 45');
      expect(s.perSideKg, closeTo(toKg(60, 'lb'), 1e-6));
      _expectStack(s, [(toKg(35, 'lb'), 1), (toKg(25, 'lb'), 1)]);
    });

    test('a 40/25 rack: 50/side is two 25s, not a stranded 40', () {
      final inv = [_stack(40, 2), _stack(25, 4)];
      final s = solvePlates(targetKg: 120, barKg: 20, inventory: inv);
      expect(s.exact, isTrue, reason: 'greedy would stop at 40 (10 short)');
      expect(s.perSideKg, closeTo(50, 1e-9));
      _expectStack(s, [(25, 2)]);
    });
  });

  group('nothing is snapped — the nearest buildable load', () {
    test('unbuildable weight errs light when two loads are equally close', () {
      // Only 5s: 2.5/side sits exactly between the bar (0) and one 5.
      final s = solvePlates(
          targetKg: 25, barKg: 20, inventory: [_stack(5, 2)]);
      expect(s.exact, isFalse);
      expect(s.belowBar, isFalse);
      expect(s.plates, isEmpty, reason: 'the lighter of the two ties');
      expect(s.achievedKg, closeTo(20, 1e-9));
    });

    test('otherwise it picks the genuinely closest load', () {
      // 3.5/side: one 5 (1.5 over) beats the bar alone (3.5 under).
      final s = solvePlates(
          targetKg: 27, barKg: 20, inventory: [_stack(5, 2)]);
      expect(s.exact, isFalse);
      _expectStack(s, [(5, 1)]);
      expect(s.achievedKg, closeTo(30, 1e-9));
    });
  });

  group('the inventory can run out', () {
    test('one pair of 25s cannot make 50/side — nearest is a single 25', () {
      final s = solvePlates(
          targetKg: 120, barKg: 20, inventory: [_stack(25, 2)]);
      expect(s.exact, isFalse);
      _expectStack(s, [(25, 1)]);
      expect(s.achievedKg, closeTo(70, 1e-9));
    });
  });

  group('the rack is pairs — an odd plate is ignored', () {
    test('three 5s give only one usable pair', () {
      // 10/side needs two 5s a side; with three in stock only one pair loads.
      final s = solvePlates(
          targetKg: 40, barKg: 20, inventory: [_stack(5, 3)]);
      expect(s.exact, isFalse);
      _expectStack(s, [(5, 1)]);
      expect(s.achievedKg, closeTo(30, 1e-9));
    });

    test('a lone plate (count 1) is stock the bar cannot use', () {
      // The single 2.5 is ignored, so 2.5/side is unbuildable.
      final s = solvePlates(
          targetKg: 25, barKg: 20,
          inventory: [_stack(20, 2), _stack(2.5, 1)]);
      expect(s.exact, isFalse);
      expect(s.plates, isEmpty);
      expect(s.achievedKg, closeTo(20, 1e-9));
    });
  });

  group('an empty rack is the bar alone', () {
    test('no plates', () {
      final s = solvePlates(targetKg: 60, barKg: 20, inventory: const []);
      expect(s.plates, isEmpty);
      expect(s.achievedKg, closeTo(20, 1e-9));
      expect(s.exact, isFalse);
    });

    test('nothing but odd singles', () {
      final s = solvePlates(
          targetKg: 60, barKg: 20, inventory: [_stack(20, 1)]);
      expect(s.plates, isEmpty);
      expect(s.achievedKg, closeTo(20, 1e-9));
    });
  });

  group('a pounds rack lands exactly on round numbers', () {
    test('225 lb is the bar plus two 45s a side, exact to the pound', () {
      final s = solvePlates(
        targetKg: toKg(225, 'lb'),
        barKg: toKg(45, 'lb'),
        inventory: defaultPlatesFor('lb'),
      );
      expect(s.exact, isTrue, reason: '225 lb must not read 10 g shy');
      expect(toDisplayWeight(s.achievedKg, 'lb'), closeTo(225, 1e-9));
      expect(toDisplayWeight(s.perSideKg, 'lb'), closeTo(90, 1e-9));
      _expectStack(s, [(toKg(45, 'lb'), 2)]);
    });

    test('135 lb is one 45 a side', () {
      final s = solvePlates(
        targetKg: toKg(135, 'lb'),
        barKg: toKg(45, 'lb'),
        inventory: defaultPlatesFor('lb'),
      );
      expect(s.exact, isTrue);
      expect(toDisplayWeight(s.achievedKg, 'lb'), closeTo(135, 1e-9));
      _expectStack(s, [(toKg(45, 'lb'), 1)]);
    });
  });

  group('only a bar breaks down into a per-side load', () {
    test('weightTypeForEquipment maps equipment to a type', () {
      expect(weightTypeForEquipment('barbell'), WeightType.bar);
      expect(weightTypeForEquipment('dumbbell'), WeightType.dumbbell);
      expect(weightTypeForEquipment('machine'), WeightType.machine);
      expect(weightTypeForEquipment('bodyweight'), WeightType.machine);
    });

    test('only a bar is loadedPerSide', () {
      expect(WeightType.bar.loadedPerSide, isTrue);
      expect(WeightType.machine.loadedPerSide, isFalse);
      expect(WeightType.dumbbell.loadedPerSide, isFalse);
    });
  });

  group('the plate line reads back the state', () {
    PlateSettings settings() => (barKg: 20.0, plates: _kgRack);

    Widget lineFor(double weightKg, WeightType type) => Directionality(
          textDirection: TextDirection.ltr,
          child: PlateLine(
            weightKg: weightKg,
            type: type,
            settings: settings(),
            unit: 'kg',
          ),
        );

    testWidgets('green and per-side text for an exact weight', (tester) async {
      await tester.pumpWidget(lineFor(60, WeightType.bar));
      expect(find.textContaining('KG/SIDE'), findsOneWidget);
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style?.color, AppColors.good);
      await stop(tester);
    });

    testWidgets('gold and "nearest you can load" when unbuildable',
        (tester) async {
      // 21 kg needs 0.5/side; the nearest is the bar alone.
      await tester.pumpWidget(lineFor(21, WeightType.bar));
      expect(find.textContaining('NEAREST YOU CAN LOAD'), findsOneWidget);
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style?.color, AppColors.gold);
      await stop(tester);
    });

    testWidgets('gold and a below-bar message under the empty bar',
        (tester) async {
      await tester.pumpWidget(lineFor(10, WeightType.bar));
      expect(find.textContaining('LIGHTER THAN THE BAR'), findsOneWidget);
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style?.color, AppColors.gold);
      await stop(tester);
    });

    testWidgets('a machine gets no line', (tester) async {
      await tester.pumpWidget(lineFor(60, WeightType.machine));
      expect(find.byType(Text), findsNothing);
      await stop(tester);
    });

    testWidgets('a dumbbell gets no line', (tester) async {
      await tester.pumpWidget(lineFor(30, WeightType.dumbbell));
      expect(find.byType(Text), findsNothing);
      await stop(tester);
    });
  });
}
