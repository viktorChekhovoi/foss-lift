import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// The exercise library (Bench Press, Squat, …). Ships with a curated set;
/// users can add their own ([isCustom] == true).
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get muscleGroup => text().withDefault(const Constant('Other'))();
  TextColumn get equipment => text().withDefault(const Constant('Other'))();
  TextColumn get instructions => text().withDefault(const Constant(''))();
  TextColumn get videoUrl => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
}

/// A reusable workout template ("Push Day").
class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get colorHex => text().withDefault(const Constant('FF6A3D'))();
  IntColumn get position => integer().withDefault(const Constant(0))();

  /// Default rest between sets for this routine, in seconds.
  IntColumn get restSeconds => integer().withDefault(const Constant(90))();
}

/// One exercise slot inside a routine template. Reps are stored structurally so
/// the app can express a fixed count (10), a range (6–8), or "to failure".
class RoutineItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId =>
      integer().references(Routines, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get position => integer().withDefault(const Constant(0))();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();

  /// Low end of the rep target (also the value used for a fixed count).
  IntColumn get repsMin => integer().withDefault(const Constant(8))();

  /// High end of the rep range. Null means a fixed count of [repsMin].
  IntColumn get repsMax => integer().nullable()();

  /// When true, the set is taken to failure ([repsMin] is the goal to beat).
  BoolColumn get toFailure => boolean().withDefault(const Constant(false))();

  /// Per-exercise rest override, in seconds. Null falls back to the routine.
  IntColumn get restSeconds => integer().nullable()();

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
/// so history stays readable even if the library changes later. Weights are
/// always stored in kilograms; the UI converts for display.
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

/// A single-row key/value store for app-wide preferences (always id == 1).
class Settings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// 'kg' or 'lb'. Weights are stored in kg; this only affects display/input.
  TextColumn get weightUnit => text().withDefault(const Constant('kg'))();

  @override
  Set<Column> get primaryKey => {id};
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

/// A routine item joined with its exercise (for the detail/builder screens).
class RoutineItemView {
  RoutineItemView(this.item, this.exercise);
  final RoutineItem item;
  final Exercise exercise;
}

/// Human-readable rep target, e.g. "10", "6–8", or "To failure".
String repsLabel(RoutineItem it) {
  if (it.toFailure) return 'Failure';
  if (it.repsMax == null || it.repsMax == it.repsMin) return '${it.repsMin}';
  return '${it.repsMin}–${it.repsMax}';
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(
  tables: [Exercises, Routines, RoutineItems, Workouts, WorkoutSets, Settings],
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
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ---- Exercise library --------------------------------------------------

  Stream<List<Exercise>> watchExercises() {
    return (select(exercises)
          ..orderBy([
            (e) => OrderingTerm(expression: e.muscleGroup),
            (e) => OrderingTerm(expression: e.name),
          ]))
        .watch();
  }

  Future<Exercise> exerciseById(int id) =>
      (select(exercises)..where((e) => e.id.equals(id))).getSingle();

  Future<int> createExercise({
    required String name,
    required String muscle,
    required String equipment,
    required String instructions,
    String? videoUrl,
  }) {
    return into(exercises).insert(
      ExercisesCompanion.insert(
        name: name,
        muscleGroup: Value(muscle),
        equipment: Value(equipment),
        instructions: Value(instructions),
        videoUrl: Value(videoUrl),
        isCustom: const Value(true),
      ),
    );
  }

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

  Stream<List<RoutineItemView>> watchItemsForRoutine(int routineId) {
    final query = select(routineItems).join([
      innerJoin(exercises, exercises.id.equalsExp(routineItems.exerciseId)),
    ])
      ..where(routineItems.routineId.equals(routineId))
      ..orderBy([OrderingTerm(expression: routineItems.position)]);

    return query.watch().map(
          (rows) => rows
              .map((r) => RoutineItemView(
                    r.readTable(routineItems),
                    r.readTable(exercises),
                  ))
              .toList(),
        );
  }

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

  Future<int> _nextRoutinePosition() async {
    final maxPos = routines.position.max();
    final row = await (selectOnly(routines)..addColumns([maxPos]))
        .map((r) => r.read(maxPos))
        .getSingleOrNull();
    return (row ?? -1) + 1;
  }

  Future<int> createRoutine({
    required String name,
    required String color,
    required int restSeconds,
  }) async {
    final pos = await _nextRoutinePosition();
    return into(routines).insert(
      RoutinesCompanion.insert(
        name: name,
        colorHex: Value(color),
        position: Value(pos),
        restSeconds: Value(restSeconds),
      ),
    );
  }

  Future<void> updateRoutineMeta(
    int id, {
    required String name,
    required String color,
    required int restSeconds,
  }) {
    return (update(routines)..where((r) => r.id.equals(id))).write(
      RoutinesCompanion(
        name: Value(name),
        colorHex: Value(color),
        restSeconds: Value(restSeconds),
      ),
    );
  }

  /// Deletes a routine; its items cascade away via the foreign key.
  Future<void> deleteRoutine(int id) =>
      (delete(routines)..where((r) => r.id.equals(id))).go();

  /// Replaces the full ordered set of items for a routine in one transaction.
  Future<void> replaceRoutineItems(
    int routineId,
    List<RoutineItemsCompanion> items,
  ) {
    return transaction(() async {
      await (delete(routineItems)..where((i) => i.routineId.equals(routineId)))
          .go();
      for (final it in items) {
        await into(routineItems).insert(it);
      }
    });
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

  // ---- Aggregate stats ----------------------------------------------------

  Stream<int> watchWorkoutCount() {
    final countExp = workouts.id.count();
    final q = selectOnly(workouts)
      ..addColumns([countExp])
      ..where(workouts.endedAt.isNotNull());
    return q.watchSingle().map((row) => row.read(countExp) ?? 0);
  }

  // ---- Settings -----------------------------------------------------------

  Stream<String> watchWeightUnit() {
    return (select(settings)..where((s) => s.id.equals(1)))
        .watchSingleOrNull()
        .map((s) => s?.weightUnit ?? 'kg');
  }

  Future<void> setWeightUnit(String unit) {
    return into(settings).insertOnConflictUpdate(
      SettingsCompanion(id: const Value(1), weightUnit: Value(unit)),
    );
  }

  // ---- Seed ---------------------------------------------------------------

  Future<void> _seed() async {
    await into(settings).insert(
      const SettingsCompanion(id: Value(1), weightUnit: Value('kg')),
      mode: InsertMode.insertOrIgnore,
    );

    // A curated starter library. Each ships with a one-line cue and a demo
    // link (a YouTube search, so the link never rots).
    final ids = <String, int>{};
    Future<int> ex(
      String name,
      String muscle,
      String equip,
      String how,
    ) async {
      return ids[name] ??= await into(exercises).insert(
        ExercisesCompanion.insert(
          name: name,
          muscleGroup: Value(muscle),
          equipment: Value(equip),
          instructions: Value(how),
          videoUrl: Value(
            'https://www.youtube.com/results?search_query='
            '${Uri.encodeQueryComponent('$name proper form')}',
          ),
        ),
      );
    }

    // Chest
    await ex('Bench Press', 'Chest', 'Barbell',
        'Lie flat, lower the bar to mid-chest, and press up while keeping your shoulder blades pinched.');
    await ex('Incline DB Press', 'Chest', 'Dumbbell',
        'On a 30° bench, press the dumbbells up and slightly together without clanking them.');
    await ex('Push-Up', 'Chest', 'Bodyweight',
        'Keep a straight line from head to heels; lower until your chest nearly touches the floor.');
    await ex('Cable Fly', 'Chest', 'Cable',
        'With a slight elbow bend, sweep the handles together in a wide hugging arc.');
    await ex('Machine Chest Press', 'Chest', 'Machine',
        'Set the seat so the handles are at mid-chest, then press without locking out hard.');
    // Back
    await ex('Deadlift', 'Back', 'Barbell',
        'Brace your core, push the floor away, and drag the bar up your legs to a tall lockout.');
    await ex('Pull-Up', 'Back', 'Bodyweight',
        'Start from a dead hang and pull your chest toward the bar, leading with your elbows.');
    await ex('Barbell Row', 'Back', 'Barbell',
        'Hinge to ~45°, keep a flat back, and row the bar to your lower ribs.');
    await ex('Lat Pulldown', 'Back', 'Cable',
        'Pull the bar to your upper chest, driving your elbows down and back.');
    await ex('Seated Cable Row', 'Back', 'Cable',
        'Sit tall, pull to your stomach, and squeeze your shoulder blades together.');
    await ex('Face Pull', 'Back', 'Cable',
        'Pull the rope toward your face, splitting the ends apart at eye level.');
    // Shoulders
    await ex('Overhead Press', 'Shoulders', 'Barbell',
        'Press the bar overhead in a straight line, moving your head "through the window" at lockout.');
    await ex('Lateral Raise', 'Shoulders', 'Dumbbell',
        'Raise the dumbbells out to the sides to shoulder height, leading with your elbows.');
    await ex('Rear Delt Fly', 'Shoulders', 'Dumbbell',
        'Hinge forward and raise the dumbbells out wide, squeezing your rear delts.');
    await ex('Arnold Press', 'Shoulders', 'Dumbbell',
        'Start palms-in at your chest, rotate out as you press overhead.');
    // Legs
    await ex('Back Squat', 'Legs', 'Barbell',
        'Brace, sit down between your hips to at least parallel, and drive up through mid-foot.');
    await ex('Front Squat', 'Legs', 'Barbell',
        'Keep your elbows high and torso upright as you squat down and stand.');
    await ex('Romanian Deadlift', 'Legs', 'Barbell',
        'Push your hips back with soft knees until you feel a hamstring stretch, then stand tall.');
    await ex('Leg Press', 'Legs', 'Machine',
        'Lower until your knees reach ~90°, then press without locking out sharply.');
    await ex('Leg Curl', 'Legs', 'Machine',
        'Curl the pad toward your glutes with control; don’t let it snap back.');
    await ex('Leg Extension', 'Legs', 'Machine',
        'Extend your knees fully and pause briefly at the top.');
    await ex('Calf Raise', 'Legs', 'Machine',
        'Rise onto your toes as high as possible, pause, then lower for a full stretch.');
    await ex('Walking Lunge', 'Legs', 'Dumbbell',
        'Step forward and lower your back knee toward the floor, then drive through your front heel.');
    // Arms
    await ex('Barbell Curl', 'Arms', 'Barbell',
        'Curl the bar with your elbows pinned to your sides; no swinging.');
    await ex('Dumbbell Curl', 'Arms', 'Dumbbell',
        'Curl and supinate (turn your pinky up) at the top of each rep.');
    await ex('Hammer Curl', 'Arms', 'Dumbbell',
        'Curl with a neutral (palms-facing) grip to hit the forearms and biceps.');
    await ex('Triceps Pushdown', 'Arms', 'Cable',
        'Keep your elbows tucked and push down until your arms are fully straight.');
    await ex('Skull Crusher', 'Arms', 'Barbell',
        'Lower the bar toward your forehead by bending only at the elbows, then extend.');
    // Core
    await ex('Plank', 'Core', 'Bodyweight',
        'Hold a straight line on your forearms; squeeze your glutes and brace your abs.');
    await ex('Hanging Leg Raise', 'Core', 'Bodyweight',
        'From a hang, raise your legs to hip height (or higher) without swinging.');
    await ex('Cable Crunch', 'Core', 'Cable',
        'Kneel and crunch your ribs toward your hips, rounding your spine.');

    Future<void> routine(
      String name,
      String color,
      int pos,
      int rest,
      List<({String name, int sets, int min, int? max, double? w})> items,
    ) async {
      final rid = await into(routines).insert(
        RoutinesCompanion.insert(
          name: name,
          colorHex: Value(color),
          position: Value(pos),
          restSeconds: Value(rest),
        ),
      );
      var i = 0;
      for (final it in items) {
        await into(routineItems).insert(
          RoutineItemsCompanion.insert(
            routineId: rid,
            exerciseId: ids[it.name]!,
            position: Value(i++),
            targetSets: Value(it.sets),
            repsMin: Value(it.min),
            repsMax: Value(it.max),
            suggestedWeight: Value(it.w),
          ),
        );
      }
    }

    await routine('Push Day', 'FF6A3D', 0, 120, [
      (name: 'Bench Press', sets: 4, min: 6, max: 8, w: 80),
      (name: 'Overhead Press', sets: 4, min: 8, max: null, w: 50),
      (name: 'Incline DB Press', sets: 3, min: 10, max: 12, w: 30),
      (name: 'Lateral Raise', sets: 3, min: 15, max: null, w: 12),
      (name: 'Triceps Pushdown', sets: 3, min: 12, max: 15, w: 35),
    ]);
    await routine('Pull Day', '3ED598', 1, 120, [
      (name: 'Deadlift', sets: 3, min: 5, max: null, w: 140),
      (name: 'Pull-Up', sets: 4, min: 6, max: 10, w: null),
      (name: 'Barbell Row', sets: 4, min: 8, max: null, w: 70),
      (name: 'Face Pull', sets: 3, min: 15, max: 20, w: 25),
      (name: 'Barbell Curl', sets: 3, min: 10, max: 12, w: 30),
    ]);
    await routine('Leg Day', 'FFC24B', 2, 150, [
      (name: 'Back Squat', sets: 4, min: 6, max: null, w: 110),
      (name: 'Romanian Deadlift', sets: 3, min: 10, max: null, w: 90),
      (name: 'Leg Press', sets: 3, min: 12, max: 15, w: 180),
      (name: 'Leg Curl', sets: 3, min: 12, max: null, w: 45),
      (name: 'Calf Raise', sets: 4, min: 15, max: 20, w: 60),
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
