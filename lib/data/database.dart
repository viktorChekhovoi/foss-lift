import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// The exercise library (Bench Press, Squat, …).
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get muscleGroup => text().withDefault(const Constant('Other'))();
}

/// A reusable workout template ("Push Day").
class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get colorHex => text().withDefault(const Constant('FF6A3D'))();
  IntColumn get position => integer().withDefault(const Constant(0))();
}

/// One exercise slot inside a routine template, with target sets/reps.
class RoutineItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId =>
      integer().references(Routines, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get position => integer().withDefault(const Constant(0))();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  TextColumn get targetReps => text().withDefault(const Constant('10'))();
  RealColumn get suggestedWeight => real().nullable()();
}

/// A logged training session.
class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId => integer().nullable()();
  TextColumn get name => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  RealColumn get totalVolume => real().withDefault(const Constant(0))();
  IntColumn get setsCompleted => integer().withDefault(const Constant(0))();
}

/// A single logged set belonging to a workout. `exerciseName` is denormalised
/// so history stays readable even if the library changes later.
class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId =>
      integer().references(Workouts, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().nullable()();
  TextColumn get exerciseName => text()();
  IntColumn get setNumber => integer()();
  RealColumn get weight => real().withDefault(const Constant(0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
}

// ---------------------------------------------------------------------------
// Read-model helpers
// ---------------------------------------------------------------------------

/// A routine plus how many exercises it contains (for list rows).
class RoutineWithCount {
  RoutineWithCount(this.routine, this.exerciseCount);
  final Routine routine;
  final int exerciseCount;
}

/// A routine item joined with its exercise (for the detail screen).
class RoutineItemView {
  RoutineItemView(this.item, this.exercise);
  final RoutineItem item;
  final Exercise exercise;
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(
  tables: [Exercises, Routines, RoutineItems, Workouts, WorkoutSets],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For unit tests: pass an in-memory `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
      );

  // ---- Routines -----------------------------------------------------------

  Stream<List<RoutineWithCount>> watchRoutines() {
    final count = routineItems.id.count();
    final query = select(routines).join([
      leftOuterJoin(
        routineItems,
        routineItems.routineId.equalsExp(routines.id),
      ),
    ])
      ..addColumns([count])
      ..groupBy([routines.id])
      ..orderBy([OrderingTerm(expression: routines.position)]);

    return query.watch().map(
          (rows) => rows
              .map((r) => RoutineWithCount(
                    r.readTable(routines),
                    r.read(count) ?? 0,
                  ))
              .toList(),
        );
  }

  Future<Routine> routineById(int id) =>
      (select(routines)..where((r) => r.id.equals(id))).getSingle();

  Future<List<RoutineItemView>> itemsForRoutine(int routineId) async {
    final query = select(routineItems).join([
      innerJoin(exercises, exercises.id.equalsExp(routineItems.exerciseId)),
    ])
      ..where(routineItems.routineId.equals(routineId))
      ..orderBy([OrderingTerm(expression: routineItems.position)]);

    final rows = await query.get();
    return rows
        .map((r) =>
            RoutineItemView(r.readTable(routineItems), r.readTable(exercises)))
        .toList();
  }

  // ---- History ------------------------------------------------------------

  Stream<List<Workout>> watchHistory() {
    return (select(workouts)
          ..where((w) => w.endedAt.isNotNull())
          ..orderBy([(w) => OrderingTerm.desc(w.startedAt)]))
        .watch();
  }

  Future<List<WorkoutSet>> setsForWorkout(int workoutId) {
    return (select(workoutSets)
          ..where((s) => s.workoutId.equals(workoutId))
          ..orderBy([(s) => OrderingTerm(expression: s.id)]))
        .get();
  }

  /// Persists a finished session and all of its completed sets in one tx.
  Future<int> saveWorkout({
    required int? routineId,
    required String name,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
    required double totalVolume,
    required List<WorkoutSetsCompanion> sets,
  }) {
    return transaction(() async {
      final workoutId = await into(workouts).insert(
        WorkoutsCompanion.insert(
          routineId: Value(routineId),
          name: name,
          startedAt: startedAt,
          endedAt: Value(endedAt),
          durationSeconds: Value(durationSeconds),
          totalVolume: Value(totalVolume),
          setsCompleted: Value(sets.length),
        ),
      );
      for (final s in sets) {
        await into(workoutSets).insert(s.copyWith(workoutId: Value(workoutId)));
      }
      return workoutId;
    });
  }

  // ---- Aggregate stats (Profile) -----------------------------------------

  Stream<({int workouts, double volume})> watchTotals() {
    final countExp = workouts.id.count();
    final volExp = workouts.totalVolume.sum();
    final q = selectOnly(workouts)
      ..addColumns([countExp, volExp])
      ..where(workouts.endedAt.isNotNull());
    return q.watchSingle().map(
          (row) => (
            workouts: row.read(countExp) ?? 0,
            volume: row.read(volExp) ?? 0,
          ),
        );
  }

  // ---- Seed ---------------------------------------------------------------

  Future<void> _seed() async {
    // De-duplicate the exercise library by name.
    final ids = <String, int>{};
    Future<int> ex(String name, String muscle) async {
      return ids[name] ??= await into(exercises).insert(
        ExercisesCompanion.insert(name: name, muscleGroup: Value(muscle)),
      );
    }

    Future<void> routine(
      String name,
      String color,
      int pos,
      List<({String name, String muscle, int sets, String reps, double? w})>
          items,
    ) async {
      final rid = await into(routines).insert(
        RoutinesCompanion.insert(
          name: name,
          colorHex: Value(color),
          position: Value(pos),
        ),
      );
      var i = 0;
      for (final it in items) {
        final eid = await ex(it.name, it.muscle);
        await into(routineItems).insert(
          RoutineItemsCompanion.insert(
            routineId: rid,
            exerciseId: eid,
            position: Value(i++),
            targetSets: Value(it.sets),
            targetReps: Value(it.reps),
            suggestedWeight: Value(it.w),
          ),
        );
      }
    }

    await routine('Push Day', 'FF6A3D', 0, [
      (name: 'Bench Press', muscle: 'Chest', sets: 4, reps: '6–8', w: 80),
      (name: 'Overhead Press', muscle: 'Shoulders', sets: 4, reps: '8', w: 50),
      (name: 'Incline DB Press', muscle: 'Chest', sets: 3, reps: '10', w: 30),
      (name: 'Lateral Raise', muscle: 'Shoulders', sets: 3, reps: '15', w: 12),
      (name: 'Triceps Pushdown', muscle: 'Triceps', sets: 3, reps: '12', w: 35),
    ]);
    await routine('Pull Day', '3ED598', 1, [
      (name: 'Deadlift', muscle: 'Back', sets: 3, reps: '5', w: 140),
      (name: 'Pull-Up', muscle: 'Back', sets: 4, reps: '8', w: null),
      (name: 'Barbell Row', muscle: 'Back', sets: 4, reps: '8', w: 70),
      (name: 'Face Pull', muscle: 'Rear delt', sets: 3, reps: '15', w: 25),
      (name: 'Barbell Curl', muscle: 'Biceps', sets: 3, reps: '10', w: 30),
    ]);
    await routine('Leg Day', 'FFC24B', 2, [
      (name: 'Back Squat', muscle: 'Quads', sets: 4, reps: '6', w: 110),
      (name: 'Romanian Deadlift', muscle: 'Hamstrings', sets: 3, reps: '10', w: 90),
      (name: 'Leg Press', muscle: 'Quads', sets: 3, reps: '12', w: 180),
      (name: 'Leg Curl', muscle: 'Hamstrings', sets: 3, reps: '12', w: 45),
      (name: 'Calf Raise', muscle: 'Calves', sets: 4, reps: '15', w: 60),
    ]);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'foss_lift.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
