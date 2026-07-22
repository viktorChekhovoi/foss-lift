// Only the executor type is needed; a bare drift import clashes with matcher.
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';

/// The v1 schema, verbatim, so the v1→v2 migration is exercised against the
/// shape real installs actually have on disk rather than against the current
/// table definitions.
const _v1Ddl = [
  '''CREATE TABLE exercises (
       id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       name TEXT NOT NULL,
       muscle_group TEXT NOT NULL DEFAULT 'Other',
       equipment TEXT NOT NULL DEFAULT 'Other',
       instructions TEXT NOT NULL DEFAULT '',
       video_url TEXT NULL,
       is_custom INTEGER NOT NULL DEFAULT 0)''',
  '''CREATE TABLE routines (
       id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       name TEXT NOT NULL,
       color_hex TEXT NOT NULL DEFAULT 'FF6A3D',
       position INTEGER NOT NULL DEFAULT 0,
       rest_seconds INTEGER NOT NULL DEFAULT 90)''',
  '''CREATE TABLE routine_items (
       id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       routine_id INTEGER NOT NULL REFERENCES routines (id) ON DELETE CASCADE,
       exercise_id INTEGER NOT NULL REFERENCES exercises (id),
       position INTEGER NOT NULL DEFAULT 0,
       target_sets INTEGER NOT NULL DEFAULT 3,
       reps_min INTEGER NOT NULL DEFAULT 8,
       reps_max INTEGER NULL,
       to_failure INTEGER NOT NULL DEFAULT 0,
       rest_seconds INTEGER NULL,
       suggested_weight REAL NULL)''',
  '''CREATE TABLE workouts (
       id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       routine_id INTEGER NULL,
       name TEXT NOT NULL,
       started_at INTEGER NOT NULL,
       ended_at INTEGER NULL,
       duration_seconds INTEGER NOT NULL DEFAULT 0,
       total_volume REAL NOT NULL DEFAULT 0,
       sets_completed INTEGER NOT NULL DEFAULT 0)''',
  '''CREATE TABLE workout_sets (
       id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       workout_id INTEGER NOT NULL REFERENCES workouts (id) ON DELETE CASCADE,
       exercise_id INTEGER NULL,
       exercise_name TEXT NOT NULL,
       set_number INTEGER NOT NULL,
       weight REAL NOT NULL DEFAULT 0,
       reps INTEGER NOT NULL DEFAULT 0,
       done INTEGER NOT NULL DEFAULT 0)''',
  '''CREATE TABLE settings (
       id INTEGER NOT NULL DEFAULT 1,
       weight_unit TEXT NOT NULL DEFAULT 'kg',
       PRIMARY KEY (id))''',
];

/// Builds an in-memory v1 database with one routine, two exercises in it, and
/// one logged session.
QueryExecutor _v1Fixture() {
  return NativeDatabase.memory(setup: (raw) {
    for (final stmt in _v1Ddl) {
      raw.execute(stmt);
    }
    raw.execute("INSERT INTO settings (id, weight_unit) VALUES (1, 'lb')");
    raw.execute("INSERT INTO exercises (id, name) VALUES (1, 'Bench Press')");
    raw.execute("INSERT INTO exercises (id, name) VALUES (2, 'Barbell Row')");
    raw.execute(
        "INSERT INTO routines (id, name, color_hex, position, rest_seconds) "
        "VALUES (7, 'Push Day', '3ED598', 2, 120)");
    raw.execute(
        'INSERT INTO routine_items (routine_id, exercise_id, position, '
        'target_sets, reps_min, reps_max, to_failure, rest_seconds, '
        'suggested_weight) VALUES (7, 1, 0, 4, 6, 8, 0, 150, 82.5)');
    raw.execute(
        'INSERT INTO routine_items (routine_id, exercise_id, position, '
        'target_sets, reps_min, reps_max, to_failure, rest_seconds, '
        'suggested_weight) VALUES (7, 2, 1, 3, 10, NULL, 1, NULL, NULL)');
    raw.execute(
        "INSERT INTO workouts (id, routine_id, name, started_at, ended_at, "
        "duration_seconds, total_volume, sets_completed) "
        "VALUES (3, 7, 'Push Day', 1700000000, 1700003600, 3600, 1650.0, 4)");
    raw.execute(
        "INSERT INTO workout_sets (workout_id, exercise_id, exercise_name, "
        "set_number, weight, reps, done) "
        "VALUES (3, 1, 'Bench Press', 1, 82.5, 6, 1)");
    raw.execute('PRAGMA user_version = 1');
  });
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(_v1Fixture()));
  tearDown(() => db.close());

  test('each v1 routine becomes a routine holding one workout', () async {
    final workouts = await db.workoutsForRoutine(7);
    expect(workouts, hasLength(1));
    expect(workouts.single.name, 'Push Day');
    expect(workouts.single.position, 0);
  });

  test('exercise slots survive with their configuration intact', () async {
    final workout = (await db.workoutsForRoutine(7)).single;
    final items = await db.itemsForWorkout(workout.id);

    expect(items, hasLength(2));
    expect(items[0].exercise.name, 'Bench Press');
    expect(items[0].item.targetSets, 4);
    expect(items[0].item.repsMin, 6);
    expect(items[0].item.repsMax, 8);
    expect(items[0].item.restSeconds, 150);
    expect(items[0].item.suggestedWeight, 82.5);

    expect(items[1].exercise.name, 'Barbell Row');
    expect(items[1].item.toFailure, isTrue);
    expect(items[1].item.repsMax, isNull);
    expect(items[1].item.restSeconds, isNull);
  });

  test('routine metadata is untouched', () async {
    final routine = await db.routineById(7);
    expect(routine.name, 'Push Day');
    expect(routine.colorHex, '3ED598');
    expect(routine.restSeconds, 120);
    expect(routine.position, 2);
  });

  test('logged history survives as sessions and keeps its sets', () async {
    final history = await db.watchHistory().first;
    expect(history, hasLength(1));
    expect(history.single.name, 'Push Day');
    expect(history.single.setsCompleted, 4);
    expect(history.single.totalVolume, 1650.0);

    final sets = await db.setsForSession(history.single.id);
    expect(sets, hasLength(1));
    expect(sets.single.exerciseName, 'Bench Press');
    expect(sets.single.weight, 82.5);
  });

  test('old history is repointed at the workout it would have been', () async {
    final workout = (await db.workoutsForRoutine(7)).single;
    final session = (await db.watchHistory().first).single;
    expect(session.workoutId, workout.id);
    expect(session.routineId, 7);
  });

  test('settings are preserved across the migration', () async {
    expect(await db.watchWeightUnit().first, 'lb');
  });

  test('no routine is made current on upgrade', () async {
    // A v1 user had several routines; guessing which one is "theirs" would be
    // wrong, so Today shows the chooser until they pick.
    expect(await db.watchActiveRoutineId().first, isNull);
  });

  test('deleting a workout cascades to its items but spares history', () async {
    final workout = (await db.workoutsForRoutine(7)).single;
    await db.deleteWorkout(workout.id);

    expect(await db.itemsForWorkout(workout.id), isEmpty);
    expect(await db.watchHistory().first, hasLength(1));
  });

  test('the v1 routine_items table is gone', () async {
    final rows = await db
        .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = 'routine_items'")
        .get();
    expect(rows, isEmpty);
  });
}
