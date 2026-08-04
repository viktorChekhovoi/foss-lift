// Integration tests for features/index.html#sec09 — the single app-wide kg/lb toggle.
// The conversion helpers are pure functions and get direct coverage; the
// end-to-end paths (the stored setting, the per-unit rack that follows the
// unit, and the confirm dialog) go through the AppDatabase, the providers, and
// the real ExerciseSettingsScreen.
//
// Drift streams emit asynchronously, so provider-derived state is read through
// the shared settle helpers — `readWhen` in pure-Dart tests, `pumpUntil` under
// the widget binding — rather than by awaiting `.future` (which never settles
// for a stream that only fires once the event loop is pumped).
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/exercise_settings_screen.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/util/format.dart';
import 'package:foss_lift/util/units.dart';
import 'package:foss_lift/widgets/board_cells.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

import 'support/harness.dart';
import 'support/seeded.dart';
import 'support/settle.dart';

/// A one-day routine holding a single Back Squat slot at [weightKg], with
/// whatever step rates are passed. Returns the slot's workout id.
Future<int> _slotAt(
  AppDatabase db, {
  double? weightKg,
  double? increment,
  double? deload,
  String exercise = 'Back Squat',
}) async {
  final ex = await exerciseNamed(db, exercise);
  final rid = await db.createRoutine(name: 'Solo', color: 'FF0000', restSeconds: 90);
  final wid = await db.createWorkout(rid, 'Day');
  final draft = ItemDraft.forExercise(ex)
    ..sets = 3
    ..repsMin = 5
    ..weightKg = weightKg;
  if (increment != null) draft.increment = increment;
  if (deload != null) draft.deload = deload;
  await db.replaceWorkoutItems(wid, itemCompanions([draft], workoutId: wid));
  return wid;
}

/// The single slot of a workout built by [_slotAt], read back.
Future<WorkoutItem> _onlySlot(AppDatabase db, int workoutId) async =>
    (await db.itemsForWorkout(workoutId)).single.item;

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
      expect(unitSuffix(l10nFor(), 'stone'), l10nFor().unitKgSuffix);
    });

    test('the label follows the unit', () {
      final l10n = l10nFor();
      expect(unitSuffix(l10n, 'kg'), l10n.unitKgSuffix);
      expect(unitSuffix(l10n, 'lb'), l10n.unitLbSuffix);
    });

    test('the standard bar is named in the unit but stored in kg', () {
      expect(defaultBarKg('kg'), closeTo(20, 1e-9));
      expect(defaultBarKg('lb'), closeTo(toKg(45, 'lb'), 1e-9));
    });
  });

  group('a weight reads to two decimals', () {
    test('trailing zeros are dropped, 1.25 is not rounded to 1.3', () {
      expect(fmtWeight(100), '100');
      expect(fmtWeight(102.5), '102.5');
      expect(fmtWeight(1.25), '1.25');
      expect(fmtWeight(toDisplayWeight(100, 'lb')), '220.46');
    });

    test('one helper formats every weight the app shows', () {
      // A plate, a step and a set row all read the same — see rule 6 in
      // CLAUDE.md, and the two helpers this replaced.
      for (final v in [1.25, 2.5, 20.0, 220.462262]) {
        expect(fmtWeight(v), fmtUpTo(v, 2));
      }
    });
  });

  group('a fresh install takes its unit from the phone\'s region', () {
    test('the phone\'s region decides', () {
      expect(localeDefaultUnit(const [Locale('en', 'US')]), 'lb');
      expect(localeDefaultUnit(const [Locale('en', 'LR')]), 'lb');
      expect(localeDefaultUnit(const [Locale('my', 'MM')]), 'lb');
      expect(localeDefaultUnit(const [Locale('en', 'GB')]), 'kg');
      expect(localeDefaultUnit(const [Locale('uk', 'UA')]), 'kg');
      expect(localeDefaultUnit(const [Locale('en')]), 'kg',
          reason: 'a locale with no country is not the United States');
      expect(localeDefaultUnit(const []), 'kg');
    });

    test('nothing is stored until the guess is made', () async {
      final db = memoryDb();
      addTearDown(() async => db.close());

      expect(await db.watchUnitChosen().first, isFalse);
      // Unstored still reads as kilograms everywhere, so nothing in between
      // launch and the write has to cope with a null unit.
      expect(await db.watchWeightUnit().first, 'kg');

      await db.seedWeightUnit('lb');
      expect(await db.watchUnitChosen().first, isTrue);
      expect(await db.watchWeightUnit().first, 'lb');
    });

    test('a region change later never moves a unit already stored', () async {
      final db = memoryDb();
      addTearDown(() async => db.close());

      await db.seedWeightUnit('lb');
      // A phone that moves to Britain, or an app language switched to Ukrainian.
      await db.seedWeightUnit('kg');
      expect(await db.watchWeightUnit().first, 'lb',
          reason: 'by now it is a setting somebody has trained against');
    });

    testWidgets('the app stores the region\'s unit on its first launch',
        (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      final db = memoryDb();
      final container = containerFor(db);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      // Watching the provider is what the app root does, and all it does — the
      // unit question is gone, so there is no screen in front of the app.
      await tester.pumpWidget(appUnder(
          container,
          Consumer(builder: (_, ref, _) {
            ref.watch(unitSeedProvider);
            return const Text('the app itself');
          })));
      await pumpThroughDatabase(tester);

      expect(find.text('the app itself'), findsOneWidget);
      expect(await tester.runAsync(() => db.watchWeightUnit().first), 'lb');
      expect(await tester.runAsync(() => db.watchUnitChosen().first), isTrue);
      await stop(tester);
    });
  });

  group('each unit has its own default step', () {
    test('the weight axis steps by 2.5 kg or by 5 lb', () {
      expect(defaultIncrementFor(ProgressionMode.weight, 'kg'), 2.5);
      expect(defaultIncrementFor(ProgressionMode.weight, 'lb'),
          closeTo(toKg(5, 'lb'), 1e-9));
      expect(defaultDeloadFor(ProgressionMode.weight, 'kg'), 5);
      expect(defaultDeloadFor(ProgressionMode.weight, 'lb'),
          closeTo(toKg(10, 'lb'), 1e-9));
    });

    test('reps and seconds are not a unit anybody converts', () {
      for (final unit in ['kg', 'lb']) {
        expect(defaultIncrementFor(ProgressionMode.reps, unit), 1);
        expect(defaultIncrementFor(ProgressionMode.time, unit), 5);
        expect(defaultDeloadFor(ProgressionMode.reps, unit), 2);
      }
    });

    test('a slot left on the default takes the new unit\'s default', () async {
      final db = memoryDb();
      addTearDown(() async => db.close());

      final wid = await _slotAt(db, weightKg: 100);
      expect((await _onlySlot(db, wid)).increment, 2.5);

      await db.setWeightUnit('lb');
      final after = await _onlySlot(db, wid);
      expect(after.increment, closeTo(toKg(5, 'lb'), 1e-6),
          reason: '2.5 kg steps become 5 lb steps, not 5.51 lb');
      expect(after.deload, closeTo(toKg(10, 'lb'), 1e-6));

      await db.setWeightUnit('kg');
      final back = await _onlySlot(db, wid);
      expect(back.increment, closeTo(2.5, 1e-6));
      expect(back.deload, closeTo(5, 1e-6));
    });

    test('a rate you set yourself is kept, not swapped', () async {
      final db = memoryDb();
      addTearDown(() async => db.close());

      final wid = await _slotAt(db, weightKg: 100, increment: 7.5, deload: 15);
      await db.setWeightUnit('lb');

      final after = await _onlySlot(db, wid);
      expect(after.increment, 7.5, reason: '7.5 kg was deliberate');
      expect(after.deload, 15);
    });

    test('a reps-axis slot is untouched by a unit switch', () async {
      final db = memoryDb();
      addTearDown(() async => db.close());

      final wid = await _slotAt(db, exercise: 'Pull-Up');
      final before = await _onlySlot(db, wid);
      expect(before.progression, ProgressionMode.reps);

      await db.setWeightUnit('lb');
      final after = await _onlySlot(db, wid);
      expect(after.increment, before.increment);
      expect(after.deload, before.deload);
    });
  });

  group('a converted target is snapped', () {
    test('100 kg becomes 220 lb, not 220.46', () async {
      final db = memoryDb();
      addTearDown(() async => db.close());

      final wid = await _slotAt(db, weightKg: 100);
      await db.setWeightUnit('lb');

      final slot = await _onlySlot(db, wid);
      expect(toDisplayWeight(slot.suggestedWeight!, 'lb'), closeTo(220, 1e-6));

      // And back the other way: the nearest 2.5 kg to 99.79 is 100.
      await db.setWeightUnit('kg');
      expect((await _onlySlot(db, wid)).suggestedWeight, closeTo(100, 1e-6));
    });

    test('a slot with no weight stays without one', () async {
      final db = memoryDb();
      addTearDown(() async => db.close());

      final wid = await _slotAt(db, exercise: 'Pull-Up');
      await db.setWeightUnit('lb');
      expect((await _onlySlot(db, wid)).suggestedWeight, isNull);
    });

    test('logged sets keep the kilograms they were lifted at', () async {
      final db = memoryDb();
      addTearDown(() async => db.close());

      final wid = await _slotAt(db, weightKg: 100);
      final item = await _onlySlot(db, wid);
      final sessionId = await db.saveSession(
        routineId: null,
        workoutId: wid,
        name: 'Day',
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
        durationSeconds: 600,
        totalVolume: 500,
        sets: [
          SessionSetsCompanion.insert(
            sessionId: 0,
            exerciseId: Value(item.exerciseId),
            exerciseName: 'Back Squat',
            setNumber: 1,
            weight: const Value(100),
            reps: const Value(5),
            done: const Value(true),
            goalReps: const Value(5),
            goalWeight: const Value(100),
          ),
        ],
      );

      await db.setWeightUnit('lb');

      final sets = await db.setsForSession(sessionId);
      expect(sets.single.weight, 100, reason: 'history is never rewritten');
      expect(sets.single.goalWeight, 100);
    });

    test('the gym\'s bars and plates are left alone', () async {
      final db = memoryDb();
      addTearDown(() async => db.close());

      await db.setBarWeight(20);
      await db.setPlateInventory([(kg: 1.25, count: 2)], 'kg');
      await db.setWeightUnit('lb');

      final setup = await db.watchPlateSetup().first;
      expect(setup.barKg, 20, reason: 'a 20 kg bar weighs 20 kg in any unit');
    });
  });

  group('an exercise\'s weight and its set rows are one load', () {
    test('a suggestion off the unit\'s step opens snapped in both places',
        () async {
      final db = memoryDb();
      final container = containerFor(db);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      await db.setWeightUnit('lb');
      // Set after the switch, so the slot really is holding a weight that does
      // not sit on the step a pounds gym counts by.
      final wid = await _slotAt(db, weightKg: 100);
      await container
          .read(activeWorkoutProvider.notifier)
          .start(workoutId: wid, name: 'Day');

      final e = container.read(activeWorkoutProvider)!.exercises.single;
      expect(toDisplayWeight(e.workingKg!, 'lb'), closeTo(220, 1e-6));
      for (final s in e.sets) {
        expect(s.weight, e.workingKg,
            reason: 'the header and the rows describe one bar');
      }
    });

    test('a weight set on the board lands on the step its sets use', () async {
      final db = memoryDb();
      final container = containerFor(db);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final wid = await _slotAt(db, weightKg: 100);
      final ctrl = container.read(activeWorkoutProvider.notifier);
      await ctrl.start(workoutId: wid, name: 'Day');
      ctrl.setWorkingWeight(0, 101); // a metric gym counts by 2.5

      final e = container.read(activeWorkoutProvider)!.exercises.single;
      expect(e.workingKg, 100);
      for (final s in e.sets) {
        expect(s.weight, 100);
      }
    });
  });

  group('a weight and its unit are joined one way', () {
    // Every screen formats the number the same; what used to differ was the
    // decoration around it — an upper-cased symbol in one place, a hand-spaced
    // one in another, "0" where the header said "—".

    /// A live board at [weightKg] (null for a slot nobody has loaded), mounted.
    Future<ProviderContainer> board(
      WidgetTester tester, {
      required double? weightKg,
      String exercise = 'Back Squat',
    }) async {
      final db = memoryDb();
      final container = containerFor(db);
      addTearDown(() async {
        container.read(activeWorkoutProvider.notifier).discard();
        container.dispose();
        await db.close();
      });
      await tester.runAsync(() async {
        final wid = await _slotAt(db, weightKg: weightKg, exercise: exercise);
        await container
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: wid, name: 'Day');
      });
      await tester.pumpWidget(appUnder(container, const WorkoutScreen()));
      await tester.pump();
      return container;
    }

    testWidgets('the symbol is never re-cased, heading or plate line',
        (tester) async {
      await board(tester, weightKg: 100);
      expect(find.textContaining('KG'), findsNothing);
      // The column over the weight cells names the unit, once.
      expect(
        find.descendant(
          of: find.byType(BoardColumnHeaders),
          matching: find.text('kg'),
        ),
        findsWidgets,
      );
      await stop(tester);
    });

    testWidgets('the working weight carries its unit through the catalogue',
        (tester) async {
      await board(tester, weightKg: 100);
      final l10n = l10nFor();
      // The control sets the symbol quieter than the number, so the two are
      // separate runs with a fixed gap between them — but they are the pieces
      // of the catalogue's own pattern, in the order it puts them.
      final runs = tester
          .widgetList<Text>(find.descendant(
            of: find.byKey(const ValueKey('working-weight-0')),
            matching: find.byType(Text),
          ))
          .map((t) => t.data)
          .toList();
      expect(
        runs.join(' '),
        l10n.unitWeightShort('100', l10n.unitKgSuffix),
      );
      await stop(tester);
    });

    testWidgets('a weight nobody has chosen reads "—", header and rows alike',
        (tester) async {
      // A machine slot with no suggested weight: the load is yours to name.
      await board(tester, weightKg: null, exercise: 'Triceps Pushdown');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('working-weight-0')),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('0-0-Triceps Pushdown')),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
      expect(find.text('0'), findsNothing);
      await stop(tester);
    });
  });

  group('a converted weight still fits the board', () {
    testWidgets('a six-character weight does not overflow a set row',
        (tester) async {
      final db = memoryDb();
      final container = containerFor(db);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      late int wid;
      await tester.runAsync(() async {
        await db.setWeightUnit('lb');
        wid = await _slotAt(db, weightKg: 100);
        final ctrl = container.read(activeWorkoutProvider.notifier);
        await ctrl.start(workoutId: wid, name: 'Day');
        // One set dropped to an awkward load. The exercise's own weight and the
        // sets that follow it are snapped, but a single set is the deload that
        // finishes a set and is taken at face value — so this is where six
        // characters still reach a row.
        ctrl.setWeight(0, 0, 100);
      });

      final overflows = await overflowsDuring(() async {
        await tester.pumpWidget(appUnder(container, const WorkoutScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      });

      expect(overflows, isEmpty, reason: overflows.join('\n'));
      expect(find.text('220.46'), findsWidgets);
      await stop(tester);
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
    /// Pumps a freshly-mounted ExerciseSettingsScreen and lets its drift-backed
    /// providers emit their first value.
    Future<ProviderContainer> pumpSettings(WidgetTester tester) async {
      final db = memoryDb();
      final container = containerFor(db);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      await tester.pumpWidget(appUnder(container, const ExerciseSettingsScreen()));
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
