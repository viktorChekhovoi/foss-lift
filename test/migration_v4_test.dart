// Only the executor type is needed; a bare drift import clashes with matcher.
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';

/// The v3 schema, verbatim — what an install that has been through the goal
/// columns has on disk. v3→v4 hangs progression off every exercise slot and
/// v4→v5 sorts the library into counted and held movements. The whole promise
/// of both is that nobody's programme changes shape underneath them: existing
/// exercises keep adding weight, and their targets stay where the user left
/// them.
const _v3Ddl = [
  '''CREATE TABLE "exercises" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       "name" TEXT NOT NULL, "muscle_group" TEXT NOT NULL DEFAULT 'Other',
       "equipment" TEXT NOT NULL DEFAULT 'Other',
       "instructions" TEXT NOT NULL DEFAULT '', "video_url" TEXT NULL,
       "is_custom" INTEGER NOT NULL DEFAULT 0)''',
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
       "suggested_weight" REAL NULL)''',
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
       "goal_reps" INTEGER NOT NULL DEFAULT 0, "goal_weight" REAL NULL)''',
  '''CREATE TABLE "settings" ("id" INTEGER NOT NULL DEFAULT 1,
       "weight_unit" TEXT NOT NULL DEFAULT 'kg',
       "active_routine_id" INTEGER NULL, PRIMARY KEY ("id"))''',
];

/// A v3 install: one routine, one workout, a barbell slot and a bodyweight
/// one, and a session logged against them.
QueryExecutor _v3Fixture() {
  return NativeDatabase.memory(setup: (raw) {
    for (final stmt in _v3Ddl) {
      raw.execute(stmt);
    }
    raw.execute("INSERT INTO settings (id, weight_unit) VALUES (1, 'kg')");
    raw.execute("INSERT INTO exercises (id, name) VALUES (1, 'Squat')");
    raw.execute("INSERT INTO exercises (id, name) VALUES (2, 'Pull-Up')");
    raw.execute("INSERT INTO exercises (id, name) VALUES (3, 'Plank')");
    raw.execute("INSERT INTO routines (id, name) VALUES (4, 'Strength')");
    raw.execute('INSERT INTO workouts (id, routine_id, name, position) '
        "VALUES (9, 4, 'Day A', 0)");
    raw.execute('INSERT INTO workout_items (id, workout_id, exercise_id, '
        'position, target_sets, reps_min, reps_max, suggested_weight) '
        'VALUES (1, 9, 1, 0, 5, 5, NULL, 60.0)');
    raw.execute('INSERT INTO workout_items (id, workout_id, exercise_id, '
        'position, target_sets, reps_min, reps_max, suggested_weight) '
        'VALUES (2, 9, 2, 1, 3, 6, 10, NULL)');
    raw.execute('INSERT INTO sessions (id, routine_id, workout_id, name, '
        'started_at, ended_at, duration_seconds, total_volume, sets_completed) '
        "VALUES (2, 4, 9, 'Day A', 1700000000, 1700003600, 3600, 900.0, 3)");
    for (var n = 1; n <= 3; n++) {
      raw.execute('INSERT INTO session_sets (session_id, exercise_id, '
          'exercise_name, set_number, weight, reps, done, goal_reps, '
          "goal_weight) VALUES (2, 1, 'Squat', $n, 60.0, 5, 1, 5, 60.0)");
    }
    raw.execute('PRAGMA user_version = 3');
  });
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(_v3Fixture()));
  tearDown(() => db.close());

  test('every existing exercise comes out on weight progression', () async {
    // The acceptance criterion from #10: nobody has to configure anything for
    // their programme to keep behaving the way it did yesterday.
    final items = await db.itemsForWorkout(9);
    expect(items.map((i) => i.item.progression),
        everyElement(ProgressionMode.weight));
  });

  test('and with rates it can actually run on', () async {
    final squat = (await db.workoutItemById(1))!;
    expect(squat.increment, 2.5);
    expect(squat.deload, 5);
    expect(squat.successThreshold, 1);
    expect(squat.failureThreshold, 2);
    expect([squat.successStreak, squat.failStreak], [0, 0],
        reason: 'an upgraded slot has no history of streaks to inherit');
  });

  test('existing targets are left exactly where they were', () async {
    final squat = (await db.workoutItemById(1))!;
    expect(squat.suggestedWeight, 60.0);
    expect([squat.targetSets, squat.repsMin, squat.repsMax], [5, 5, null]);

    final pullUp = (await db.workoutItemById(2))!;
    expect(pullUp.suggestedWeight, isNull);
    expect([pullUp.repsMin, pullUp.repsMax], [6, 10]);
  });

  test('logged history survives and still reads as reps', () async {
    final sets = await db.setsForSession(2);
    expect(sets, hasLength(3));
    expect(sets.every((s) => s.weight == 60.0 && s.reps == 5), isTrue);
    expect(sets.every((s) => s.seconds == null && s.goalSeconds == null), isTrue,
        reason: 'null is the statement that this set was counted, not held');
    expect(sets.any(setMissedGoal), isFalse);
  });

  test('lifetime totals are unmoved by the upgrade', () async {
    final t = await db.watchLifetimeTotals().first;
    expect([t.volumeKg, t.reps, t.sets], [900, 15, 3]);
  });

  test('an upgraded slot progresses from its first session onwards', () async {
    await db.advanceProgression(1, success: true);
    expect((await db.workoutItemById(1))!.suggestedWeight, 62.5);
  });

  group('v4 → v5, which sorts the library into counted and held', () {
    test('everything is counted unless it is a hold', () async {
      // The default is what almost every movement is, so an upgrade cannot
      // quietly turn a squat into something you hold.
      final all = await db.watchExercises().first;
      expect(all.firstWhere((e) => e.name == 'Squat').measure,
          ExerciseMeasure.reps);
    });

    test('the starter library\'s one hold is recognised as one', () async {
      // Matched by name on upgrade: it is the only handle on a seeded row.
      final plank = (await db.watchExercises().first)
          .firstWhere((e) => e.name == 'Plank');
      expect(plank.measure, ExerciseMeasure.time);
      expect(plank.measure.modes, [ProgressionMode.time]);
    });

    test('a counted movement is never offered the time axis', () async {
      final squat = (await db.watchExercises().first)
          .firstWhere((e) => e.name == 'Squat');
      expect(squat.measure.modes,
          [ProgressionMode.weight, ProgressionMode.reps]);
    });
  });
}
