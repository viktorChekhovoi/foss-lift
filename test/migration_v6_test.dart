// Only the executor type is needed; a bare drift import clashes with matcher.
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';

/// The v6 schema, verbatim — what an install that has been through schedules,
/// reminders and the layoff rules has on disk. v6→v7 gives the library a
/// weight type and the settings row a bar and a plate rack. The promise is that
/// an existing install comes out the far side already classified from its
/// equipment, with a standard rack it never had to configure.
const _v6Ddl = [
  '''CREATE TABLE "exercises" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       "name" TEXT NOT NULL, "muscle_group" TEXT NOT NULL DEFAULT 'Other',
       "equipment" TEXT NOT NULL DEFAULT 'Other',
       "instructions" TEXT NOT NULL DEFAULT '', "video_url" TEXT NULL,
       "is_custom" INTEGER NOT NULL DEFAULT 0,
       "measure" TEXT NOT NULL DEFAULT 'reps')''',
  '''CREATE TABLE "routines" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       "name" TEXT NOT NULL, "color_hex" TEXT NOT NULL DEFAULT 'FF6A3D',
       "position" INTEGER NOT NULL DEFAULT 0,
       "rest_seconds" INTEGER NOT NULL DEFAULT 90,
       "schedule_days" INTEGER NOT NULL DEFAULT 0,
       "reminder_minutes" INTEGER NULL)''',
  '''CREATE TABLE "workouts" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       "routine_id" INTEGER NOT NULL REFERENCES routines (id) ON DELETE CASCADE,
       "name" TEXT NOT NULL, "position" INTEGER NOT NULL DEFAULT 0)''',
  '''CREATE TABLE "workout_items" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       "workout_id" INTEGER NOT NULL REFERENCES workouts (id) ON DELETE CASCADE,
       "exercise_id" INTEGER NOT NULL REFERENCES exercises (id),
       "position" INTEGER NOT NULL DEFAULT 0,
       "target_sets" INTEGER NOT NULL DEFAULT 3,
       "reps_min" INTEGER NOT NULL DEFAULT 8, "reps_max" INTEGER NULL,
       "to_failure" INTEGER NOT NULL DEFAULT 0, "rest_seconds" INTEGER NULL,
       "suggested_weight" REAL NULL,
       "progression" TEXT NOT NULL DEFAULT 'weight',
       "hold_seconds" INTEGER NOT NULL DEFAULT 30,
       "increment" REAL NOT NULL DEFAULT 2.5,
       "success_threshold" INTEGER NOT NULL DEFAULT 1,
       "deload" REAL NOT NULL DEFAULT 5.0,
       "failure_threshold" INTEGER NOT NULL DEFAULT 2,
       "success_streak" INTEGER NOT NULL DEFAULT 0,
       "fail_streak" INTEGER NOT NULL DEFAULT 0)''',
  '''CREATE TABLE "sessions" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       "routine_id" INTEGER NULL, "workout_id" INTEGER NULL,
       "name" TEXT NOT NULL, "started_at" INTEGER NOT NULL,
       "ended_at" INTEGER NULL, "duration_seconds" INTEGER NOT NULL DEFAULT 0,
       "total_volume" REAL NOT NULL DEFAULT 0.0,
       "sets_completed" INTEGER NOT NULL DEFAULT 0)''',
  '''CREATE TABLE "session_sets" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       "session_id" INTEGER NOT NULL REFERENCES sessions (id) ON DELETE CASCADE,
       "exercise_id" INTEGER NULL, "exercise_name" TEXT NOT NULL,
       "set_number" INTEGER NOT NULL, "weight" REAL NOT NULL DEFAULT 0.0,
       "reps" INTEGER NOT NULL DEFAULT 0, "done" INTEGER NOT NULL DEFAULT 0,
       "goal_reps" INTEGER NOT NULL DEFAULT 0, "goal_weight" REAL NULL,
       "seconds" INTEGER NULL, "goal_seconds" INTEGER NULL)''',
  '''CREATE TABLE "settings" ("id" INTEGER NOT NULL DEFAULT 1,
       "weight_unit" TEXT NOT NULL DEFAULT 'kg',
       "active_routine_id" INTEGER NULL,
       "layoff_days" INTEGER NOT NULL DEFAULT 14,
       "layoff_percent" INTEGER NOT NULL DEFAULT 10,
       PRIMARY KEY ("id"))''',
];

/// A v6 install: a library covering all three ways a weight can be loaded, and
/// one workout slot with a target on it.
QueryExecutor _v6Fixture() {
  return NativeDatabase.memory(setup: (raw) {
    for (final stmt in _v6Ddl) {
      raw.execute(stmt);
    }
    raw.execute("INSERT INTO settings (id, weight_unit) VALUES (1, 'kg')");
    raw.execute("INSERT INTO exercises (id, name, equipment) "
        "VALUES (1, 'Back Squat', 'Barbell')");
    raw.execute("INSERT INTO exercises (id, name, equipment) "
        "VALUES (2, 'Hammer Curl', 'Dumbbell')");
    raw.execute("INSERT INTO exercises (id, name, equipment) "
        "VALUES (3, 'Lat Pulldown', 'Cable')");
    raw.execute("INSERT INTO exercises (id, name, equipment, measure) "
        "VALUES (4, 'Plank', 'Bodyweight', 'time')");
    raw.execute("INSERT INTO routines (id, name) VALUES (4, 'Strength')");
    raw.execute('INSERT INTO workouts (id, routine_id, name, position) '
        "VALUES (9, 4, 'Day A', 0)");
    raw.execute('INSERT INTO workout_items (id, workout_id, exercise_id, '
        'position, target_sets, reps_min, suggested_weight) '
        'VALUES (1, 9, 1, 0, 5, 5, 100.0)');
    raw.execute('PRAGMA user_version = 6');
  });
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(_v6Fixture()));
  tearDown(() => db.close());

  test('the library is classified from the equipment it already recorded',
      () async {
    expect((await db.exerciseById(1)).weightType, WeightType.bar);
    expect((await db.exerciseById(2)).weightType, WeightType.dumbbell);
    expect((await db.exerciseById(3)).weightType, WeightType.machine);
    expect((await db.exerciseById(4)).weightType, WeightType.machine,
        reason: 'bodyweight has no bar to break down either');
  });

  test('and can be corrected afterwards', () async {
    await db.setExerciseWeightType(3, WeightType.bar);
    expect((await db.exerciseById(3)).weightType, WeightType.bar);
  });

  test('the bar and the rack arrive unconfigured', () async {
    expect(await db.watchPlateSetup().first, (inventory: null, barKg: null));
  });

  test('which resolves to a standard gym in whatever unit is in use', () async {
    final stored = await db.watchPlateSetup().first;
    final kg = resolvePlateSettings(
        unit: 'kg', inventory: stored.inventory, barKg: stored.barKg);
    expect(kg.barKg, kDefaultBarKg);
    expect(kg.plates, defaultPlatesFor('kg'));

    final lb = resolvePlateSettings(
        unit: 'lb', inventory: stored.inventory, barKg: stored.barKg);
    expect(lb.plates, defaultPlatesFor('lb'),
        reason: 'nothing stored means the unit still gets to decide');
  });

  test('and holds a rack of its own once one is set', () async {
    await db.setBarWeight(15);
    await db.setPlateInventory([(kg: 20, count: 4), (kg: 10, count: 2)]);
    final stored = await db.watchPlateSetup().first;
    final resolved = resolvePlateSettings(
        unit: 'lb', inventory: stored.inventory, barKg: stored.barKg);
    expect(resolved.barKg, 15);
    expect(resolved.plates, [(kg: 20.0, count: 4), (kg: 10.0, count: 2)],
        reason: 'a configured rack outranks the unit');
  });

  test('the layoff rules the upgrade inherited are left alone', () async {
    expect(await db.layoffSettings(),
        (days: kDefaultLayoffDays, percent: kDefaultLayoffPercent));
  });

  test('and no target moves', () async {
    final squat = (await db.workoutItemById(1))!;
    expect(squat.suggestedWeight, 100.0);
    expect(squat.targetSets, 5);
  });
}
