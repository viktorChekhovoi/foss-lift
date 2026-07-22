// Only the executor type is needed; a bare drift import clashes with matcher.
import 'package:drift/drift.dart' show QueryExecutor, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';

/// The v2 schema, verbatim — the shape every install that has already been
/// through the routines→workouts migration has on disk. v2→v3 only adds the
/// two goal columns to `session_sets`, but history is the one thing an upgrade
/// must never damage, so it gets its own fixture rather than riding on the
/// v1 test's coat-tails.
const _v2Ddl = [
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
       "reps" INTEGER NOT NULL DEFAULT 0,
       "done" INTEGER NOT NULL DEFAULT 0)''',
  '''CREATE TABLE "settings" ("id" INTEGER NOT NULL DEFAULT 1,
       "weight_unit" TEXT NOT NULL DEFAULT 'kg',
       "active_routine_id" INTEGER NULL, PRIMARY KEY ("id"))''',
];

/// A v2 install: one routine with one workout, and one logged session.
QueryExecutor _v2Fixture() {
  return NativeDatabase.memory(setup: (raw) {
    for (final stmt in _v2Ddl) {
      raw.execute(stmt);
    }
    raw.execute("INSERT INTO settings (id, weight_unit, active_routine_id) "
        "VALUES (1, 'kg', 4)");
    raw.execute("INSERT INTO exercises (id, name) VALUES (1, 'Squat')");
    raw.execute("INSERT INTO routines (id, name) VALUES (4, 'Starting Weight')");
    raw.execute(
        "INSERT INTO workouts (id, routine_id, name, position) "
        "VALUES (9, 4, 'Workout A', 0)");
    raw.execute(
        'INSERT INTO workout_items (workout_id, exercise_id, position, '
        'target_sets, reps_min, suggested_weight) VALUES (9, 1, 0, 5, 5, 60.0)');
    raw.execute(
        "INSERT INTO sessions (id, routine_id, workout_id, name, started_at, "
        "ended_at, duration_seconds, total_volume, sets_completed) "
        "VALUES (2, 4, 9, 'Workout A', 1700000000, 1700003600, 3600, 900.0, 3)");
    for (var n = 1; n <= 3; n++) {
      raw.execute(
          "INSERT INTO session_sets (session_id, exercise_id, exercise_name, "
          "set_number, weight, reps, done) "
          "VALUES (2, 1, 'Squat', $n, 60.0, 5, 1)");
    }
    raw.execute('PRAGMA user_version = 2');
  });
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(_v2Fixture()));
  tearDown(() => db.close());

  test('logged sets survive the upgrade intact', () async {
    final sets = await db.setsForSession(2);
    expect(sets, hasLength(3));
    expect(sets.every((s) => s.exerciseName == 'Squat'), isTrue);
    expect(sets.every((s) => s.weight == 60.0 && s.reps == 5), isTrue);
  });

  test('sets logged before goals existed carry no goal', () async {
    final sets = await db.setsForSession(2);
    expect(sets.every((s) => s.goalReps == 0), isTrue);
    expect(sets.every((s) => s.goalWeight == null), isTrue);
  });

  test('and so are never read as failures', () async {
    // The alternative — treating a missing goal as "goal unmet" — would paint
    // every set anyone logged before this release red.
    final sets = await db.setsForSession(2);
    expect(sets.any(setMissedGoal), isFalse);
  });

  test('lifetime totals still count the old history', () async {
    final t = await db.watchLifetimeTotals().first;
    expect(t.volumeKg, 900);
    expect(t.reps, 15);
    expect(t.sets, 3);
  });

  test('templates and settings are untouched', () async {
    expect((await db.routineById(4)).name, 'Starting Weight');
    expect((await db.workoutsForRoutine(4)).single.name, 'Workout A');
    expect((await db.itemsForWorkout(9)).single.item.suggestedWeight, 60.0);
    expect(await db.watchActiveRoutineId().first, 4);
  });

  test('new sets can record what they were aiming at', () async {
    await db.saveSession(
      routineId: 4,
      workoutId: 9,
      name: 'Workout A',
      startedAt: DateTime(2026, 7, 22, 18),
      endedAt: DateTime(2026, 7, 22, 19),
      durationSeconds: 3600,
      totalVolume: 550,
      sets: [
        SessionSetsCompanion.insert(
          sessionId: 0,
          exerciseName: 'Squat',
          setNumber: 1,
          weight: const Value(62.5),
          reps: const Value(5),
          done: const Value(true),
          goalReps: const Value(5),
          goalWeight: const Value(62.5),
        ),
        SessionSetsCompanion.insert(
          sessionId: 0,
          exerciseName: 'Squat',
          setNumber: 2,
          weight: const Value(55),
          reps: const Value(5),
          done: const Value(true),
          goalReps: const Value(5),
          goalWeight: const Value(62.5),
        ),
      ],
    );

    final latest = (await db.watchHistory().first).first;
    final sets = await db.setsForSession(latest.id);
    expect(setMissedGoal(sets[0]), isFalse);
    expect(setMissedGoal(sets[1]), isTrue,
        reason: 'finishing the set at a lower weight is a deload, not a win');
  });
}
