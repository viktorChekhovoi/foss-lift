// Only the executor type is needed; a bare drift import clashes with matcher.
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';

/// The v5 schema, verbatim — what an install that has been through progression
/// and the counted/held split has on disk. v5→v6 adds a weekly schedule and an
/// opt-in reminder to routines, and the layoff rules to settings. The promise
/// is that an existing install comes out the far side scheduling nothing and
/// notifying nobody, with every target exactly where it was left.
const _v5Ddl = [
  '''CREATE TABLE "exercises" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       "name" TEXT NOT NULL, "muscle_group" TEXT NOT NULL DEFAULT 'Other',
       "equipment" TEXT NOT NULL DEFAULT 'Other',
       "instructions" TEXT NOT NULL DEFAULT '', "video_url" TEXT NULL,
       "is_custom" INTEGER NOT NULL DEFAULT 0,
       "measure" TEXT NOT NULL DEFAULT 'reps')''',
  '''CREATE TABLE "routines" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       "name" TEXT NOT NULL, "color_hex" TEXT NOT NULL DEFAULT 'FF6A3D',
       "position" INTEGER NOT NULL DEFAULT 0,
       "rest_seconds" INTEGER NOT NULL DEFAULT 90)''',
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
       "active_routine_id" INTEGER NULL, PRIMARY KEY ("id"))''',
];

/// Whatever the fixture uses for "a long time ago" — old enough that the
/// layoff rules have an opinion about it once they exist.
final _lastTrained = DateTime.now().subtract(const Duration(days: 40));

/// A v5 install: one routine, one workout, a barbell slot, and a session
/// logged against it forty days back.
QueryExecutor _v5Fixture() {
  return NativeDatabase.memory(setup: (raw) {
    for (final stmt in _v5Ddl) {
      raw.execute(stmt);
    }
    raw.execute("INSERT INTO settings (id, weight_unit) VALUES (1, 'kg')");
    raw.execute("INSERT INTO exercises (id, name) VALUES (1, 'Squat')");
    raw.execute("INSERT INTO routines (id, name) VALUES (4, 'Strength')");
    raw.execute('INSERT INTO workouts (id, routine_id, name, position) '
        "VALUES (9, 4, 'Day A', 0)");
    raw.execute('INSERT INTO workout_items (id, workout_id, exercise_id, '
        'position, target_sets, reps_min, suggested_weight, success_streak) '
        'VALUES (1, 9, 1, 0, 5, 5, 100.0, 1)');
    final at = _lastTrained.millisecondsSinceEpoch ~/ 1000;
    raw.execute('INSERT INTO sessions (id, routine_id, workout_id, name, '
        'started_at, ended_at, duration_seconds, total_volume, sets_completed) '
        "VALUES (2, 4, 9, 'Day A', $at, ${at + 3600}, 3600, 2500.0, 5)");
    raw.execute('PRAGMA user_version = 5');
  });
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(_v5Fixture()));
  tearDown(() => db.close());

  test('an existing routine comes out unscheduled and silent', () async {
    final routine = await db.routineById(4);
    expect(routine.scheduleDays, kNoScheduleMask);
    expect(routine.reminderMinutes, isNull,
        reason: 'an upgrade must not start notifying anybody');
  });

  test('the schedule is editable from where it landed', () async {
    await db.updateRoutineMeta(4,
        name: 'Strength',
        color: 'FF6A3D',
        restSeconds: 90,
        scheduleDays: 1 | 1 << 2 | 1 << 4,
        reminderMinutes: 18 * 60);
    final routine = await db.routineById(4);
    expect(scheduleLabel(routine.scheduleDays), 'Mon · Wed · Fri');
    expect(routine.reminderMinutes, 18 * 60);
  });

  test('the layoff rules arrive at their defaults', () async {
    expect(await db.layoffSettings(),
        (days: kDefaultLayoffDays, percent: kDefaultLayoffPercent));
  });

  test('and immediately have something to say about a forty-day gap', () async {
    final layoff = await db.layoffFor(9);
    expect(layoff?.percent, 20, reason: 'two whole periods away');
  });

  test('but the upgrade itself moves no target', () async {
    final squat = (await db.workoutItemById(1))!;
    expect(squat.suggestedWeight, 100.0,
        reason: 'the back-off is offered, never applied behind your back');
    expect(squat.successStreak, 1);
  });

  test('logged history survives the upgrade', () async {
    final history = await db.watchHistory().first;
    expect(history, hasLength(1));
    expect(history.single.setsCompleted, 5);
  });
}
