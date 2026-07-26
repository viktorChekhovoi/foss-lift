// Integration tests for features/09-units.md — the single app-wide kg/lb toggle.
// The conversion helpers are pure functions and get direct coverage; the
// end-to-end paths (the stored setting, the per-unit rack that follows the
// unit, and the confirm dialog) go through the AppDatabase, the providers, and
// the real SettingsScreen.
//
// Drift streams emit asynchronously, so provider-derived state is read through
// the shared settle helpers — `readWhen` in pure-Dart tests, `pumpUntil` under
// the widget binding — rather than by awaiting `.future` (which never settles
// for a stream that only fires once the event loop is pumped).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/settings_screen.dart';
import 'package:foss_lift/util/units.dart';

import 'support/harness.dart';
import 'support/settle.dart';

void main() {
  group('conversion is pure display arithmetic', () {
    test('kilograms are the identity', () {
      expect(toDisplayWeight(100, 'kg'), 100);
      expect(toKg(100, 'kg'), 100);
    });

    test('a 100 kg lift reads as ~220.5 lb', () {
      expect(toDisplayWeight(100, 'lb'), closeTo(220.462, 1e-3));
    });

    test('typed pounds convert back to kilograms', () {
      expect(toKg(225, 'lb'), closeTo(102.058, 1e-3));
    });

    test('round-tripping a display value is lossless', () {
      for (final v in [45.0, 135.0, 225.0, 2.5]) {
        expect(toDisplayWeight(toKg(v, 'lb'), 'lb'), closeTo(v, 1e-9));
      }
    });

    test('unknown units are treated as kilograms', () {
      expect(toDisplayWeight(50, 'stone'), 50);
      expect(toKg(50, 'stone'), 50);
      expect(unitLabel('stone'), 'kg');
    });

    test('the label follows the unit', () {
      expect(unitLabel('kg'), 'kg');
      expect(unitLabel('lb'), 'lb');
    });

    test('the standard bar is named in the unit but stored in kg', () {
      expect(defaultBarKg('kg'), closeTo(20, 1e-9));
      expect(defaultBarKg('lb'), closeTo(toKg(45, 'lb'), 1e-9));
    });
  });

  group('one app-wide setting, stored and read back', () {
    test('defaults to kilograms and persists a switch', () async {
      final db = memoryDb();
      final container = containerFor(db);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      expect(await db.watchWeightUnit().first, 'kg');
      await readWhen(container, weightUnitProvider, (v) => v.value == 'kg');

      await db.setWeightUnit('lb');
      expect(await db.watchWeightUnit().first, 'lb');
    });
  });

  group('history is never rewritten', () {
    test('switching units leaves stored kilograms untouched', () async {
      final db = memoryDb();
      addTearDown(() async => db.close());

      await db.setBarWeight(60); // canonical kilograms
      await db.setWeightUnit('lb');

      final setup = await db.watchPlateSetup().first;
      expect(setup.barKg, 60, reason: 'the stored value is still 60 kg');
      // The change is display-only: 60 kg simply reads as ~132.3 lb.
      expect(toDisplayWeight(60, 'lb'), closeTo(132.277, 1e-3));
    });
  });

  group('each unit keeps its own rack', () {
    test('the two racks are stored apart', () async {
      final db = memoryDb();
      addTearDown(() async => db.close());

      await db.setPlateInventory([(kg: 30.0, count: 2)], 'kg');
      await db.setPlateInventory([(kg: toKg(35, 'lb'), count: 2)], 'lb');

      final setup = await db.watchPlateSetup().first;
      expect(setup.kgRack, isNotNull);
      expect(setup.lbRack, isNotNull);
      expect(setup.kgRack, isNot(setup.lbRack));
    });

    test('on lb, the rack you see is the lb rack (values stay kg)', () async {
      final db = memoryDb();
      final container = containerFor(db);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      await db.setWeightUnit('lb');
      await db.setPlateInventory([(kg: 30.0, count: 2)], 'kg');
      await db.setPlateInventory([(kg: toKg(35, 'lb'), count: 2)], 'lb');

      await readWhen(container, weightUnitProvider, (v) => v.value == 'lb');
      await readWhen(container, storedPlateSetupProvider,
          (v) => v.value?.lbRack != null && v.value?.kgRack != null);

      final plates = container.read(plateSettingsProvider).plates;
      expect(plates.any((p) => (p.kg - toKg(35, 'lb')).abs() < 1e-6), isTrue);
      expect(plates.any((p) => (p.kg - 30).abs() < 1e-6), isFalse,
          reason: 'the kg rack must not leak into lb');
    });

    test('on kg, the rack you see is the kg rack', () async {
      final db = memoryDb();
      final container = containerFor(db);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      await db.setWeightUnit('kg');
      await db.setPlateInventory([(kg: 30.0, count: 2)], 'kg');
      await db.setPlateInventory([(kg: toKg(35, 'lb'), count: 2)], 'lb');

      await readWhen(container, weightUnitProvider, (v) => v.value == 'kg');
      await readWhen(container, storedPlateSetupProvider,
          (v) => v.value?.lbRack != null && v.value?.kgRack != null);

      final plates = container.read(plateSettingsProvider).plates;
      expect(plates.any((p) => (p.kg - 30).abs() < 1e-6), isTrue);
      expect(plates.any((p) => (p.kg - toKg(35, 'lb')).abs() < 1e-6), isFalse);
    });

    test('an unedited unit falls back to its standard rack', () async {
      final db = memoryDb();
      final container = containerFor(db);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      // Only the kg rack is edited; lb is never touched.
      await db.setWeightUnit('lb');
      await db.setPlateInventory([(kg: 30.0, count: 2)], 'kg');

      await readWhen(container, weightUnitProvider, (v) => v.value == 'lb');
      await readWhen(container, storedPlateSetupProvider,
          (v) => v.value?.kgRack != null);

      final settings = container.read(plateSettingsProvider);
      expect(settings.plates, equals(defaultPlatesFor('lb')));
    });
  });

  group('switching pops a confirm dialog', () {
    /// Pumps a freshly-mounted SettingsScreen and lets its drift-backed
    /// providers emit their first value.
    Future<ProviderContainer> pumpSettings(WidgetTester tester) async {
      final db = memoryDb();
      final container = containerFor(db);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      await tester.pumpWidget(appUnder(container, const SettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      return container;
    }

    testWidgets('tapping the current unit does nothing', (tester) async {
      await pumpSettings(tester);

      // A fresh install is on kg; tapping Kilograms is not a switch.
      await tester.tap(find.text('Kilograms · kg'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AlertDialog), findsNothing);
      await stop(tester);
    });

    testWidgets('tapping the other unit confirms first, and cancel is a no-op',
        (tester) async {
      final container = await pumpSettings(tester);

      await tester.tap(find.text('Pounds · lb'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Switch to pounds?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AlertDialog), findsNothing);
      expect(container.read(weightUnitProvider).value, isNot('lb'),
          reason: 'cancel must not switch');
      await stop(tester);
    });

    testWidgets('confirming the switch stores the new unit', (tester) async {
      final container = await pumpSettings(tester);

      await tester.tap(find.text('Pounds · lb'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Use pounds'));
      await pumpUntil(
          tester, () => container.read(weightUnitProvider).value == 'lb');

      expect(container.read(weightUnitProvider).value, 'lb');
      await stop(tester);
    });
  });
}
