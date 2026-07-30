// Integration tests for features/index.html#sec07 — the plate solver, the bars
// it stands on, and the line it feeds. The solver (`solvePlates`) is a pure
// function and is where the combinatorial truth lives, so most of this file
// drives it directly across the spec's edge cases; the bar list goes through the
// real database and the real settings screen, and a handful of widget tests
// confirm the line reads back the green / gold / below-bar states.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/screens/bar_settings_screen.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/util/units.dart';
import 'package:foss_lift/widgets/plate_line.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

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
      // A bodyweight movement carries nothing at all, so there is no weight to
      // break down and none to read.
      expect(weightTypeForEquipment('bodyweight'), WeightType.none);
    });

    test('only a bar is loadedPerSide', () {
      expect(WeightType.bar.loadedPerSide, isTrue);
      expect(WeightType.machine.loadedPerSide, isFalse);
      expect(WeightType.dumbbell.loadedPerSide, isFalse);
      expect(WeightType.none.loadedPerSide, isFalse);
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

  // The bars are rows the user owns, not a fixed menu: the standard ones ship as
  // the starting list and behave like anything else in it afterwards. A
  // reference to a bar is its weight (see the `Bars` table), which is what makes
  // the delete and re-weigh behaviour below the interesting part.
  group('the gym is a list of bars', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = memoryDb();
      container = containerFor(db);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    /// The default bar the app resolves to right now, in kilograms.
    Future<double> defaultBar() async {
      final stored = await db.watchPlateSetup().first;
      return resolvePlateSettings(unit: 'kg', barKg: stored.barKg).barKg;
    }

    Future<Bar> kgBarAt(double kg) async =>
        (await db.barsFor('kg')).atWeight(kg)!;

    test('a fresh install racks the standard bars, one list per unit',
        () async {
      final kg = await db.barsFor('kg');
      expect(kg.map((b) => b.name), contains('Olympic bar'));
      expect(kg.atWeight(20)?.name, 'Olympic bar');
      expect(kg.atWeight(10)?.name, 'EZ curl bar');
      // A bar is referred to by its weight, so no two of them may collide.
      expect(kg.map((b) => b.weightKg).toSet().length, kg.length);

      // The pounds list is the round pounds numbers, not converted kilos.
      final lb = await db.barsFor('lb');
      expect(lb.atWeight(toKg(45, 'lb'))?.name, 'Olympic bar');
      expect(lb.map((b) => b.weightKg).toSet().length, lb.length);
    });

    test('a bar of your own can be added, renamed and re-weighed', () async {
      expect(
        await db.addBar(unit: 'kg', name: 'Deadlift bar', kg: 22.5),
        isTrue,
      );
      final mine = await kgBarAt(22.5);
      expect(mine.name, 'Deadlift bar');
      // It joins one list, not both.
      expect((await db.barsFor('lb')).atWeight(22.5), isNull);

      expect(await db.editBar(mine.id, name: 'Stiff bar', kg: 23), isTrue);
      expect((await kgBarAt(23)).name, 'Stiff bar');
      expect((await db.barsFor('kg')).atWeight(22.5), isNull);
    });

    test('a second bar of the same weight is refused', () async {
      expect(await db.addBar(unit: 'kg', name: 'Power bar', kg: 20), isFalse);
      expect(
        (await db.barsFor('kg')).where((b) => b.name == 'Power bar'),
        isEmpty,
      );

      // And so is editing one onto another's weight, which leaves it alone.
      await db.addBar(unit: 'kg', name: 'Deadlift bar', kg: 22.5);
      final mine = await kgBarAt(22.5);
      expect(await db.editBar(mine.id, name: 'Deadlift bar', kg: 20), isFalse);
      expect((await kgBarAt(22.5)).name, 'Deadlift bar');
      expect((await kgBarAt(20)).name, 'Olympic bar');
    });

    test('an exercise on a deleted bar falls back to the default', () async {
      final bench = await exerciseNamed(db, 'Bench Press');
      final trap = await kgBarAt(25);
      await db.setExerciseBarWeight(bench.id, trap.weightKg);
      expect((await db.exerciseById(bench.id)).barWeight, 25);

      await db.deleteBar(trap.id);

      expect((await db.exerciseById(bench.id)).barWeight, isNull,
          reason: 'nothing may point at a bar the gym no longer has');
      expect(await defaultBar(), kDefaultBarKg);
    });

    test('deleting the default bar falls back to the standard bar', () async {
      final smith = await kgBarAt(12.5);
      await db.setBarWeight(smith.weightKg);
      expect(await defaultBar(), 12.5);

      await db.deleteBar(smith.id);

      expect((await db.watchPlateSetup().first).barKg, isNull);
      expect(await defaultBar(), kDefaultBarKg);
    });

    test('re-weighing a bar carries the exercises and the default with it',
        () async {
      final bench = await exerciseNamed(db, 'Bench Press');
      // A bar of your own: the six standard ones cannot be re-weighed.
      await db.addBar(unit: 'kg', name: 'Squat bar', kg: 31);
      final ssb = await kgBarAt(31);
      await db.setExerciseBarWeight(bench.id, ssb.weightKg);
      await db.setBarWeight(ssb.weightKg);

      expect(
        await db.editBar(ssb.id, name: 'Safety squat bar', kg: 32),
        isTrue,
      );

      expect((await db.exerciseById(bench.id)).barWeight, 32);
      expect(await defaultBar(), 32);
    });

    test('a bar left alone by another bar being deleted keeps its exercise',
        () async {
      final bench = await exerciseNamed(db, 'Bench Press');
      final womens = await kgBarAt(15);
      await db.setExerciseBarWeight(bench.id, womens.weightKg);

      await db.deleteBar((await kgBarAt(25)).id); // the trap bar

      expect((await db.exerciseById(bench.id)).barWeight, 15);
    });

    test('a standard bar cannot be renamed or re-weighed', () async {
      // Its weight is what the plate maths trusts and what a shared routine
      // carries to a phone where this row does not exist. A bar of your own is
      // yours to change; "Olympic bar, 20 kg" is not a preference.
      final olympic = await kgBarAt(20);
      expect(olympic.isCustom, isFalse);

      expect(await db.editBar(olympic.id, name: 'My bar', kg: 21), isFalse);

      final after = await kgBarAt(20);
      expect(after.name, 'Olympic bar');
      expect(after.weightKg, 20);
    });

    test('and a bar of your own says so', () async {
      await db.addBar(unit: 'kg', name: 'Deadlift bar', kg: 22.5);
      expect((await kgBarAt(22.5)).isCustom, isTrue);
    });

    testWidgets('only a bar of your own offers the pencil', (tester) async {
      await db.addBar(unit: 'kg', name: 'Deadlift bar', kg: 22.5);
      await tester.pumpWidget(appUnder(container, const BarSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(barEditKey('Deadlift bar')), findsOneWidget);
      expect(find.byKey(barEditKey('Olympic bar')), findsNothing,
          reason: 'a standard bar is a fact, not a setting');
      // Taking one off the rack is still allowed: a gym may simply not have it.
      expect(find.byKey(barRemoveKey('Olympic bar')), findsOneWidget);

      await stop(tester);
    });

    testWidgets('the list picks the default', (tester) async {
      await tester.pumpWidget(appUnder(container, const BarSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Olympic bar'), findsOneWidget);
      expect(find.text('Trap bar'), findsOneWidget);

      await tester.tap(find.text('Trap bar'));
      await pumpThroughDatabase(tester);

      final stored = (await tester.runAsync(() => db.watchPlateSetup().first))!;
      expect(stored.barKg, 25);
      await stop(tester);
    });

    testWidgets('a bar is added from the list itself', (tester) async {
      await tester.pumpWidget(appUnder(container, const BarSettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add a bar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Log bar');
      await tester.enterText(find.byType(TextField).last, '35');
      await tester.tap(find.text('Save'));
      await pumpThroughDatabase(tester);

      final added = (await tester.runAsync(() => db.barsFor('kg')))!;
      expect(added.atWeight(35)?.name, 'Log bar');
      await stop(tester);
    });

    testWidgets('a bar taken off the rack leaves the list', (tester) async {
      await tester.pumpWidget(appUnder(container, const BarSettingsScreen()));
      await tester.pumpAndSettle();

      final row = find.ancestor(
        of: find.text('Smith carriage'),
        matching: find.byType(Row),
      );
      await tester.tap(find.descendant(of: row.last, matching: find.byIcon(Icons.close)));
      await pumpThroughDatabase(tester);

      expect(find.text('Smith carriage'), findsNothing);
      final left = (await tester.runAsync(() => db.barsFor('kg')))!;
      expect(left.map((b) => b.name), isNot(contains('Smith carriage')));
      await stop(tester);
    });
  });
}
