// Integration tests for features/01-exercise-library.md
//
// The exercise library: a curated starter set (form cue + demo link on every
// entry), custom exercises alongside it, a weight type seeded from equipment
// and overridable for any exercise, a measure fixed at creation, and history
// that survives library edits because logged sets store the name denormalised.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';

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

      // ~30 curated movements. Exactly the seeded set is custom-free.
      expect(starters.length, greaterThanOrEqualTo(30));
      expect(all.every((e) => !e.isCustom), isTrue);
    });

    test('every starter carries a form cue and a demo-video link', () async {
      final all = await db.watchExercises().first;

      for (final e in all) {
        expect(
          e.instructions.trim(),
          isNotEmpty,
          reason: '${e.name} has no form cue',
        );
        expect(e.videoUrl, isNotNull, reason: '${e.name} has no demo link');
        expect(e.videoUrl!.trim(), isNotEmpty);
      }
    });

    test('a custom exercise sits alongside the starter set', () async {
      await db.createExercise(
        name: 'Zercher Squat',
        muscle: 'Legs',
        equipment: 'Barbell',
        instructions: 'Cradle the bar in your elbows and squat.',
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
          instructions: 'Drive it.',
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
        instructions: 'Curl.',
      );
      await db.setExerciseWeightType(id, WeightType.bar);
      await db.setExerciseBarWeight(id, 10);

      final e = await db.exerciseById(id);
      expect(e.weightType, WeightType.bar);
      expect(e.barWeight, 10);
    });
  });

  group('measure is a fixed fact of the movement', () {
    test('only the Plank is held in the starter library', () async {
      final all = await db.watchExercises().first;
      final held = all.where((e) => e.measure == ExerciseMeasure.time).toList();

      expect(held.map((e) => e.name), ['Plank']);
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
        instructions: 'Sit against the wall.',
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
        instructions: 'Press the end of the bar up and across.',
      );
      final sessionId = await logOneSet(id, 'Landmine Press');

      await (db.delete(db.exercises)..where((e) => e.id.equals(id))).go();

      final logged = await db.setsForSession(sessionId);
      expect(logged.single.exerciseName, 'Landmine Press');
    });
  });
}
