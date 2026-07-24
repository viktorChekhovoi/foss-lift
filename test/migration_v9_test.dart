// Only the executor type is needed; a bare drift import clashes with matcher.
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/theme/app_theme.dart';

/// The v9 schema, verbatim — an install with the first-run tutorial flag but no
/// notion of a colour theme. v9→v10 adds the theme choice and a slot for a
/// custom palette. The promise is that the upgrade changes nothing visible:
/// both new columns are nullable and null means "nothing chosen", so the
/// default preset (Ignition) still paints the app.
const _v9Ddl = [
  '''CREATE TABLE "exercises" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       "name" TEXT NOT NULL, "muscle_group" TEXT NOT NULL DEFAULT 'Other',
       "equipment" TEXT NOT NULL DEFAULT 'Other',
       "instructions" TEXT NOT NULL DEFAULT '', "video_url" TEXT NULL,
       "is_custom" INTEGER NOT NULL DEFAULT 0,
       "measure" TEXT NOT NULL DEFAULT 'reps',
       "weight_type" TEXT NOT NULL DEFAULT 'machine',
       "bar_weight" REAL NULL)''',
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
       "plate_inventory_lb" TEXT NULL,
       "tutorial_seen" INTEGER NOT NULL DEFAULT 0,
       PRIMARY KEY ("id"))''',
];

/// A v9 install with a couple of preferences already set, so the migration can
/// be shown to leave them alone.
QueryExecutor _v9Fixture() {
  return NativeDatabase.memory(setup: (raw) {
    for (final stmt in _v9Ddl) {
      raw.execute(stmt);
    }
    raw.execute("INSERT INTO settings (id, weight_unit, layoff_days) "
        "VALUES (1, 'lb', 21)");
    raw.execute("INSERT INTO routines (id, name, color_hex) "
        "VALUES (1, 'Strength', 'FF6A3D')");
    raw.execute('PRAGMA user_version = 9');
  });
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(_v9Fixture()));
  tearDown(() => db.close());

  test('no theme is chosen on upgrade, so the default preset stands in',
      () async {
    final setting = await db.watchThemeSetting().first;
    expect(setting.presetId, isNull);
    expect(setting.customJson, isNull);
    expect(resolvePalette(setting.presetId, setting.customJson),
        kDefaultPalette);
  });

  test('the theme choice can then be set and read', () async {
    await db.setThemePreset('violet');
    expect((await db.watchThemeSetting().first).presetId, 'violet');
  });

  test('existing preferences survive the migration', () async {
    expect(await db.watchWeightUnit().first, 'lb');
    expect((await db.watchLayoffSettings().first).days, 21);
  });

  test('a routine keeps its own accent colour through the upgrade', () async {
    final routine = await db.routineById(1);
    expect(routine.colorHex, 'FF6A3D');
  });
}
