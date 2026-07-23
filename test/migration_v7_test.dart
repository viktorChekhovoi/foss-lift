// Only the executor type is needed; a bare drift import clashes with matcher.
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';

/// The v7 schema, verbatim — an install that already knows how each exercise is
/// loaded and has one rack. v7→v8 gives each exercise a bar of its own and
/// splits the rack in two, one per unit. The promise is that an upgrade changes
/// nothing about how any existing weight loads: every new column is nullable
/// and null means "nothing said yet".
const _v7Ddl = [
  '''CREATE TABLE "exercises" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       "name" TEXT NOT NULL, "muscle_group" TEXT NOT NULL DEFAULT 'Other',
       "equipment" TEXT NOT NULL DEFAULT 'Other',
       "instructions" TEXT NOT NULL DEFAULT '', "video_url" TEXT NULL,
       "is_custom" INTEGER NOT NULL DEFAULT 0,
       "measure" TEXT NOT NULL DEFAULT 'reps',
       "weight_type" TEXT NOT NULL DEFAULT 'machine')''',
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
       "plate_inventory" TEXT NULL, "bar_weight" REAL NULL,
       PRIMARY KEY ("id"))''',
];

/// A v7 install: a library covering all three ways a weight can be loaded, and
/// one workout slot with a target on it.
QueryExecutor _v7Fixture() {
  return NativeDatabase.memory(setup: (raw) {
    for (final stmt in _v7Ddl) {
      raw.execute(stmt);
    }
    raw.execute("INSERT INTO settings (id, weight_unit) VALUES (1, 'kg')");
    raw.execute("INSERT INTO exercises (id, name, equipment, weight_type) "
        "VALUES (1, 'Back Squat', 'Barbell', 'bar')");
    raw.execute("INSERT INTO exercises (id, name, equipment, weight_type) "
        "VALUES (2, 'EZ Bar Curl', 'Barbell', 'bar')");
    raw.execute("INSERT INTO routines (id, name) VALUES (4, 'Strength')");
    raw.execute('INSERT INTO workouts (id, routine_id, name, position) '
        "VALUES (9, 4, 'Day A', 0)");
    raw.execute('INSERT INTO workout_items (id, workout_id, exercise_id, '
        'position, target_sets, reps_min, suggested_weight) '
        'VALUES (1, 9, 1, 0, 5, 5, 100.0)');
    raw.execute("UPDATE settings SET plate_inventory = '20.0x4;10.0x2'");
    raw.execute('PRAGMA user_version = 7');
  });
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(_v7Fixture()));
  tearDown(() => db.close());

  test('no exercise arrives with a bar of its own', () async {
    expect((await db.exerciseById(1)).barWeight, isNull);
    expect((await db.exerciseById(2)).barWeight, isNull,
        reason: 'null is the gym default, which is what it was using before');
  });

  test('but one can be given one, and handed back', () async {
    await db.setExerciseBarWeight(2, 10);
    expect((await db.exerciseById(2)).barWeight, 10,
        reason: 'an EZ bar is not the gym bar');
    expect((await db.exerciseById(1)).barWeight, isNull,
        reason: 'and says nothing about the squat rack');

    await db.setExerciseBarWeight(2, null);
    expect((await db.exerciseById(2)).barWeight, isNull);
  });

  test('the rack it already had becomes the metric one', () async {
    final stored = await db.watchPlateSetup().first;
    expect(stored.kgRack, '20.0x4;10.0x2');
    expect(stored.lbRack, isNull, reason: 'the pounds gym is a separate rack');

    expect(
      resolvePlateSettings(unit: 'kg', kgRack: stored.kgRack).plates,
      [(kg: 20.0, count: 4), (kg: 10.0, count: 2)],
    );
    expect(
      resolvePlateSettings(unit: 'lb', lbRack: stored.lbRack).plates,
      defaultPlatesFor('lb'),
      reason: 'rather than the metric rack read out in decimals',
    );
  });

  test('and each unit is edited without disturbing the other', () async {
    await db.setPlateInventory([(kg: 20.4117, count: 10)], 'lb');
    final stored = await db.watchPlateSetup().first;
    expect(stored.kgRack, '20.0x4;10.0x2', reason: 'untouched');
    expect(decodePlates(stored.lbRack), hasLength(1));

    await db.resetPlateInventory('lb');
    expect((await db.watchPlateSetup().first).lbRack, isNull);
    expect((await db.watchPlateSetup().first).kgRack, '20.0x4;10.0x2');
  });

  test('the default bar survives being set and reset', () async {
    expect((await db.watchPlateSetup().first).barKg, isNull);
    await db.setBarWeight(15);
    expect((await db.watchPlateSetup().first).barKg, 15);
    await db.resetBarWeight();
    expect((await db.watchPlateSetup().first).barKg, isNull);
  });

  test('no target moves', () async {
    final squat = (await db.workoutItemById(1))!;
    expect(squat.suggestedWeight, 100.0);
    expect(squat.targetSets, 5);
  });
}
