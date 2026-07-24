// Only the executor type is needed; a bare drift import clashes with matcher.
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';

/// The v8 schema, verbatim — an install that already knows how each exercise is
/// loaded, keeps a rack per unit, and can give an exercise a bar of its own.
/// v8→v9 adds the first-run tutorial flag. The promise: an existing install is
/// marked as having already seen the tour, so the coach marks never ambush
/// someone mid-programme on the launch after an update.
const _v8Ddl = [
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
       PRIMARY KEY ("id"))''',
];

/// A v8 install that has plainly been used: a routine with a day, a weight on
/// the bar, and a settings row already written.
QueryExecutor _v8Fixture() {
  return NativeDatabase.memory(setup: (raw) {
    for (final stmt in _v8Ddl) {
      raw.execute(stmt);
    }
    raw.execute("INSERT INTO settings (id, weight_unit) VALUES (1, 'kg')");
    raw.execute("INSERT INTO exercises (id, name, equipment, weight_type) "
        "VALUES (1, 'Back Squat', 'Barbell', 'bar')");
    raw.execute("INSERT INTO routines (id, name) VALUES (4, 'Strength')");
    raw.execute('INSERT INTO workouts (id, routine_id, name, position) '
        "VALUES (9, 4, 'Day A', 0)");
    raw.execute('INSERT INTO workout_items (id, workout_id, exercise_id, '
        'position, target_sets, reps_min, suggested_weight) '
        'VALUES (1, 9, 1, 0, 5, 5, 100.0)');
    raw.execute('PRAGMA user_version = 8');
  });
}

void main() {
  group('v8 → v9 upgrade', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(_v8Fixture()));
    tearDown(() => db.close());

    test('an existing install is treated as having seen the tour', () async {
      expect(await db.watchTutorialSeen().first, isTrue,
          reason: 'someone mid-programme is not a first run');
    });

    test('nothing else about the install moves', () async {
      final squat = (await db.workoutItemById(1))!;
      expect(squat.suggestedWeight, 100.0);
      expect((await db.exerciseById(1)).weightType, WeightType.bar);
      expect(await db.watchWeightUnit().first, 'kg');
    });

    test('the flag can still be reset to replay-only state', () async {
      await db.setTutorialSeen(false);
      expect(await db.watchTutorialSeen().first, isFalse);
      await db.setTutorialSeen(true);
      expect(await db.watchTutorialSeen().first, isTrue);
    });
  });

  group('a fresh install', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('has not seen the tour, so it runs once', () async {
      expect(await db.watchTutorialSeen().first, isFalse,
          reason: 'a genuine first run should trigger the coach marks');
    });

    test('and remembers once it has', () async {
      await db.setTutorialSeen(true);
      expect(await db.watchTutorialSeen().first, isTrue);
    });
  });
}
