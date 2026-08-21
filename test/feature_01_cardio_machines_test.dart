// Integration tests for the cardio-machine starter rows and their console classification (features/index.html#sec01).

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/util/seed_names.dart';

import 'support/harness.dart';

/// The cardio floor, as the seed names it.
const kCardioMachines = [
  'Treadmill',
  'Elliptical',
  'Stationary Bike',
  'Recumbent Bike',
  'Rowing Machine',
  'Stair Climber',
  'Air Bike',
  'Ski Erg',
  'Arc Trainer',
  "Jacob's Ladder",
];

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  Future<Exercise> named(String name) async =>
      (await db.watchExercises().first).firstWhere((e) => e.name == name);

  group('the cardio machines are in the starter set', () {
    test('every one of them is seeded', () async {
      final names = (await db.watchExercises().first).map((e) => e.name).toSet();
      for (final machine in kCardioMachines) {
        expect(names, contains(machine), reason: '$machine is not seeded');
      }
    });

    test('each files under Cardio with Machine equipment', () async {
      for (final machine in kCardioMachines) {
        final e = await named(machine);
        expect(e.muscles.lead, 'Cardio', reason: machine);
        expect(e.equipment, 'Machine', reason: machine);
      }
    });

    test('each is measured as a work period, not counted in reps', () async {
      for (final machine in kCardioMachines) {
        expect(
          (await named(machine)).measure,
          ExerciseMeasure.time,
          reason: machine,
        );
      }
    });

    test('none of them carries a weight', () async {
      for (final machine in kCardioMachines) {
        final e = await named(machine);
        expect(e.weightType, WeightType.none, reason: machine);
        expect(e.weightType.carriesWeight, isFalse, reason: machine);
      }
    });

    test('a slot on one can only progress by adding time', () async {
      for (final machine in kCardioMachines) {
        expect(
          (await named(machine)).measure.modes,
          [ProgressionMode.time],
          reason: machine,
        );
      }
    });

    test('each names the muscles it leans on, as assists', () async {
      for (final machine in kCardioMachines) {
        final map = (await named(machine)).muscles;
        // Cardio is where it files and the only thing it is *for*; the muscles
        // it uses are named beside it, as assists.
        expect(map.primary, ['Cardio'], reason: machine);
        expect(map.secondary, isNotEmpty, reason: machine);
      }
    });

    test('each is keyed and follows a language switch', () async {
      final en = l10nFor();
      final es = l10nFor(const Locale('es'));
      for (final machine in kCardioMachines) {
        final e = await named(machine);
        expect(e.seedKey, isNotNull, reason: machine);
        expect(seededName(en, e.seedKey, e.name), isNotEmpty, reason: machine);
        expect(
          seededName(es, e.seedKey, e.name),
          isNot(e.seedKey),
          reason: '$machine renders its key rather than a name',
        );
      }
    });

    test('none of them invents vocabulary outside the closed lists', () async {
      for (final machine in kCardioMachines) {
        final e = await named(machine);
        expect(kEquipmentTypes, contains(e.equipment), reason: machine);
        for (final g in e.muscles.all) {
          expect(kMuscleGroups, contains(g), reason: '$machine: $g');
        }
      }
    });
  });

  group('a cardio machine is Cardio plus Machine', () {
    test('the seeded machines all answer yes', () async {
      for (final machine in kCardioMachines) {
        expect((await named(machine)).isCardioMachine, isTrue, reason: machine);
      }
    });

    test('conditioning done on the floor does not', () async {
      for (final floor in ['Burpee', 'Jump Rope', 'Sprint', 'Battle Rope']) {
        expect((await named(floor)).isCardioMachine, isFalse, reason: floor);
      }
    });

    test('a gym machine that is not cardio does not', () async {
      for (final lift in ['Leg Press', 'Machine Chest Press']) {
        expect((await named(lift)).isCardioMachine, isFalse, reason: lift);
      }
    });

    test(
      'a movement you build for your own machine gets it by classifying it',
      () async {
        final id = await db.createExercise(
          name: 'Airdyne',
          muscles: MuscleMap(primary: ['Cardio'], secondary: ['Legs']),
          equipment: 'Machine',
          measure: ExerciseMeasure.time,
          weightType: WeightType.none,
        );
        expect((await db.exerciseById(id)).isCardioMachine, isTrue);
      },
    );

    test('and loses it when reclassified off the machine', () async {
      final id = await db.createExercise(
        name: 'Airdyne',
        muscles: MuscleMap(primary: ['Cardio'], secondary: ['Legs']),
        equipment: 'Machine',
        measure: ExerciseMeasure.time,
        weightType: WeightType.none,
      );
      await db.updateCustomExercise(
        id,
        name: 'Airdyne',
        muscles: MuscleMap(primary: ['Cardio'], secondary: ['Legs']),
        equipment: 'Other',
        videoUrl: null,
        measure: ExerciseMeasure.time,
        weightType: WeightType.none,
      );
      expect((await db.exerciseById(id)).isCardioMachine, isFalse);
    });
  });
}
