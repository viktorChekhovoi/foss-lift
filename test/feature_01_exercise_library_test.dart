// Integration tests for features/01-exercise-library.md
//
// The exercise library: a curated starter set (a demo link on every entry),
// custom exercises alongside it, a weight type seeded from equipment and
// overridable for any exercise, a measure fixed at creation, and history that
// survives library edits because logged sets store the name denormalised.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/screens/exercise_form_screen.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  group('starter library', () {
    test('ships a curated starter set, none of it marked custom', () async {
      final all = await db.watchExercises().first;
      final starters = all.where((e) => !e.isCustom).toList();

      // ~85 curated movements. Exactly the seeded set is custom-free.
      expect(starters.length, greaterThanOrEqualTo(80));
      expect(all.every((e) => !e.isCustom), isTrue);
    });

    test('no movement is seeded twice', () async {
      final names = (await db.watchExercises().first).map((e) => e.name);
      expect(names.toSet().length, names.length);
    });

    test('the starter set covers every muscle group and every equipment kind',
        () async {
      final all = await db.watchExercises().first;

      // A group nobody can fill from the library is a group the picker offers
      // for nothing.
      for (final group in kMuscleGroups) {
        expect(all.where((e) => e.muscleGroup == group).length,
            greaterThanOrEqualTo(3),
            reason: '$group is thin in the starter library');
      }
      for (final kind in kEquipmentTypes) {
        expect(all.any((e) => e.equipment == kind), isTrue,
            reason: 'nothing in the library is $kind');
      }
    });

    test('the movements a thin library was missing are all present', () async {
      final names = (await db.watchExercises().first).map((e) => e.name);

      expect(
        names,
        containsAll([
          'Hip Thrust', // glutes
          'Romanian Deadlift', // hip hinge
          'Chest Dip', // dip
          'Chin-Up', // vertical pull, supinated
          'Barbell Shrug', // traps
          'Wrist Curl', // forearms
        ]),
      );
    });

    test('the starter library invents no new vocabulary', () async {
      final all = await db.watchExercises().first;

      // Both lists are a wire format for a shared routine — a word outside
      // them costs bytes in every code that carries it.
      for (final e in all) {
        expect(kMuscleGroups, contains(e.muscleGroup), reason: e.name);
        expect(kEquipmentTypes, contains(e.equipment), reason: e.name);
      }
    });

    test('every starter carries a demo-video link', () async {
      final all = await db.watchExercises().first;

      for (final e in all.where((e) => !e.isCustom)) {
        expect(e.videoUrl, isNotNull, reason: '${e.name} has no demo link');
      }
    });

    test('a custom exercise sits alongside the starter set', () async {
      await db.createExercise(
        name: 'Zercher Squat',
        muscle: 'Legs',
        equipment: 'Barbell',
      );

      final all = await db.watchExercises().first;
      final mine = all.firstWhere((e) => e.name == 'Zercher Squat');
      final starter = all.firstWhere((e) => e.name == 'Bench Press');

      expect(mine.isCustom, isTrue);
      expect(starter.isCustom, isFalse);
      // Both are in the one library the picker reads.
      expect(
        all.map((e) => e.name),
        containsAll(['Zercher Squat', 'Bench Press']),
      );
    });
  });

  group('weight type seeded from equipment', () {
    test(
      'barbell → bar, dumbbell → dumbbell, everything else → machine',
      () async {
        expect(
          (await exerciseNamed(db, 'Bench Press')).weightType,
          WeightType.bar,
        );
        expect(
          (await exerciseNamed(db, 'Incline DB Press')).weightType,
          WeightType.dumbbell,
        );
        expect(
          (await exerciseNamed(db, 'Triceps Pushdown')).weightType,
          WeightType.machine,
        ); // cable
        expect(
          (await exerciseNamed(db, 'Push-Up')).weightType,
          WeightType.machine,
        ); // bodyweight
      },
    );

    test(
      'the equipment→type rule itself, including the bodyweight fallthrough',
      () {
        expect(weightTypeForEquipment('Barbell'), WeightType.bar);
        expect(weightTypeForEquipment('Dumbbell'), WeightType.dumbbell);
        expect(weightTypeForEquipment('Cable'), WeightType.machine);
        expect(weightTypeForEquipment('Bodyweight'), WeightType.machine);
        expect(weightTypeForEquipment('anything else'), WeightType.machine);
      },
    );

    test(
      'a new custom exercise defaults to machine when not told otherwise',
      () async {
        final id = await db.createExercise(
          name: 'Sled Push',
          muscle: 'Legs',
          equipment: 'Sled',
        );
        expect((await db.exerciseById(id)).weightType, WeightType.machine);
      },
    );
  });

  group('weight type & bar are overridable for any exercise', () {
    test('the seeded type can be reclassified on a starter lift', () async {
      final bench = await exerciseNamed(db, 'Bench Press');
      expect(bench.weightType, WeightType.bar);

      await db.setExerciseWeightType(bench.id, WeightType.machine);

      expect((await db.exerciseById(bench.id)).weightType, WeightType.machine);
    });

    test(
      'a starter lift can be given its own bar, and handed back to default',
      () async {
        final bench = await exerciseNamed(db, 'Bench Press');
        expect(bench.barWeight, isNull); // uses the app-wide default

        await db.setExerciseBarWeight(bench.id, 15);
        expect((await db.exerciseById(bench.id)).barWeight, 15);

        await db.setExerciseBarWeight(bench.id, null);
        expect((await db.exerciseById(bench.id)).barWeight, isNull);
      },
    );

    test('overrides apply to custom exercises too', () async {
      final id = await db.createExercise(
        name: 'EZ Curl',
        muscle: 'Arms',
        equipment: 'Barbell',
      );
      await db.setExerciseWeightType(id, WeightType.bar);
      await db.setExerciseBarWeight(id, 10);

      final e = await db.exerciseById(id);
      expect(e.weightType, WeightType.bar);
      expect(e.barWeight, 10);
    });
  });

  group('measure is a fixed fact of the movement', () {
    test('the held starters are exactly the movements with no rep to count',
        () async {
      final all = await db.watchExercises().first;
      final held = all.where((e) => e.measure == ExerciseMeasure.time).toList();

      expect(
        held.map((e) => e.name).toSet(),
        {'Plank', 'Side Plank', 'Hollow Hold', 'Dead Hang', "Farmer's Carry"},
      );
      expect(
        (await exerciseNamed(db, 'Bench Press')).measure,
        ExerciseMeasure.reps,
      );
    });

    test('a custom exercise keeps the measure it was created with', () async {
      final id = await db.createExercise(
        name: 'Wall Sit',
        muscle: 'Legs',
        equipment: 'Bodyweight',
        measure: ExerciseMeasure.time,
      );
      expect((await db.exerciseById(id)).measure, ExerciseMeasure.time);
    });

    test(
      'a held movement offers only time; a counted one offers weight & reps',
      () {
        expect(ExerciseMeasure.time.modes, [ProgressionMode.time]);
        expect(ExerciseMeasure.reps.modes, [
          ProgressionMode.weight,
          ProgressionMode.reps,
        ]);
      },
    );

    test('an axis the measure forbids is coerced back to a permitted one', () {
      // A hold can never be progressed by weight; a counted lift never by time.
      expect(
        ExerciseMeasure.time.coerce(ProgressionMode.weight),
        ProgressionMode.time,
      );
      expect(
        ExerciseMeasure.reps.coerce(ProgressionMode.time),
        ProgressionMode.weight,
      );
      // A permitted axis passes straight through.
      expect(
        ExerciseMeasure.reps.coerce(ProgressionMode.reps),
        ProgressionMode.reps,
      );
    });
  });

  group('history survives library edits', () {
    /// Logs a one-set session against [exerciseId], recording [name] on the set.
    Future<int> logOneSet(int exerciseId, String name) {
      final now = DateTime(2026, 1, 1, 9);
      return db.saveSession(
        routineId: null,
        workoutId: null,
        name: 'Test day',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 40)),
        durationSeconds: 2400,
        totalVolume: 640,
        sets: [
          SessionSetsCompanion.insert(
            sessionId: 0, // saveSession fills in the real id
            exerciseName: name,
            setNumber: 1,
            exerciseId: Value(exerciseId),
            weight: const Value(80),
            reps: const Value(8),
            done: const Value(true),
          ),
        ],
      );
    }

    test(
      'renaming an exercise never rewrites the name on a logged set',
      () async {
        final bench = await exerciseNamed(db, 'Bench Press');
        final sessionId = await logOneSet(bench.id, 'Bench Press');

        // Rename the movement in the library.
        await (db.update(db.exercises)..where((e) => e.id.equals(bench.id)))
            .write(const ExercisesCompanion(name: Value('Flat Barbell Press')));

        final logged = await db.setsForSession(sessionId);
        expect(logged.single.exerciseName, 'Bench Press');
        // The library itself did change.
        expect((await db.exerciseById(bench.id)).name, 'Flat Barbell Press');
      },
    );

    test(
      'a rename keeps the whole history gathered under the exercise id',
      () async {
        final bench = await exerciseNamed(db, 'Bench Press');
        await logOneSet(bench.id, 'Bench Press');

        await (db.update(db.exercises)..where((e) => e.id.equals(bench.id)))
            .write(const ExercisesCompanion(name: Value('Flat Barbell Press')));

        // History is matched on id, so the renamed movement still owns its set.
        final hist = await db.watchExerciseSetHistory(bench.id).first;
        expect(hist, hasLength(1));
        expect(hist.single.reps, 8);
      },
    );

    test('deleting an exercise leaves its logged sets standing', () async {
      // A custom, unreferenced exercise: nothing in a workout points at it, so
      // deleting it is legal and only history could be harmed.
      final id = await db.createExercise(
        name: 'Landmine Press',
        muscle: 'Shoulders',
        equipment: 'Barbell',
      );
      final sessionId = await logOneSet(id, 'Landmine Press');

      await (db.delete(db.exercises)..where((e) => e.id.equals(id))).go();

      final logged = await db.setsForSession(sessionId);
      expect(logged.single.exerciseName, 'Landmine Press');
    });
  });

  group('the demo link is tidied as it is entered', () {
    // A surface tall enough for the whole form, so every field is built and can
    // be addressed by position. On a phone-sized surface the demo-link box sits
    // below the fold and is not in the tree at all.
    setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

    Future<void> openForm(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = containerFor(db);
      addTearDown(container.dispose);
      // The form pops on save, so it needs a router above it.
      await tester
          .pumpWidget(routedAppUnder(container, const ExerciseFormScreen()));
      await tester.pumpAndSettle();
    }

    /// The form's two text boxes: the name, and the demo link below it.
    Finder nameField(WidgetTester t) => find.byType(TextField).first;
    Finder linkField(WidgetTester t) => find.byType(TextField).last;

    Future<Exercise> saveWith(WidgetTester tester, String link) async {
      await openForm(tester);
      await tester.enterText(nameField(tester), 'Copenhagen Plank');
      await tester.enterText(linkField(tester), link);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save exercise'));
      await tester.pumpAndSettle();

      final saved = (await tester.runAsync(() => db.watchExercises().first))!;
      return saved.firstWhere((e) => e.name == 'Copenhagen Plank');
    }

    testWidgets('a YouTube link is stored in its short canonical form',
        (tester) async {
      final saved = await saveWith(
          tester, 'https://www.youtube.com/watch?v=aBcD1234_-x&t=90s&list=PLx');

      expect(saved.videoUrl, 'https://youtu.be/aBcD1234_-x',
          reason: 'the timestamp, playlist and www. identify nothing');

      await stop(tester);
    });

    testWidgets('a link to somewhere else is kept exactly as typed',
        (tester) async {
      // A coach's own upload, a private clip: not ours to rewrite, and it still
      // opens from the exercise screen.
      final saved = await saveWith(tester, 'https://example.com/my-technique');

      expect(saved.videoUrl, 'https://example.com/my-technique');

      await stop(tester);
    });

    testWidgets('an empty link stays empty', (tester) async {
      final saved = await saveWith(tester, '   ');

      expect(saved.videoUrl, isNull);

      await stop(tester);
    });


  });
}
