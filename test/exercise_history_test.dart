import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';

/// watchExerciseSetHistory is what feeds the chart and the export, so these
/// cover what it gathers (one exercise, finished sessions, in time order) and
/// what it leaves out (other exercises, live sessions).
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> logSession(
    DateTime when,
    List<({int exerciseId, String name, double weight, int reps})> sets, {
    bool finished = true,
  }) {
    var n = 1;
    return db.saveSession(
      routineId: null,
      workoutId: null,
      name: 'Session',
      startedAt: when,
      // saveSession always stamps endedAt; a live session is faked below.
      endedAt: when.add(const Duration(hours: 1)),
      durationSeconds: 3600,
      totalVolume: 0,
      sets: [
        for (final s in sets)
          SessionSetsCompanion.insert(
            sessionId: 0,
            exerciseId: Value(s.exerciseId),
            exerciseName: s.name,
            setNumber: n++,
            weight: Value(s.weight),
            reps: Value(s.reps),
            done: const Value(true),
          ),
      ],
    );
  }

  test('gathers one exercise across sessions, oldest first', () async {
    await logSession(DateTime(2026, 1, 10), [
      (exerciseId: 1, name: 'Bench Press', weight: 82.5, reps: 6),
    ]);
    await logSession(DateTime(2026, 1, 3), [
      (exerciseId: 1, name: 'Bench Press', weight: 80, reps: 5),
      (exerciseId: 2, name: 'Squat', weight: 120, reps: 5),
    ]);

    final rows = await db.watchExerciseSetHistory(1).first;
    expect(rows, hasLength(2));
    // Oldest session first.
    expect(rows.first.date, DateTime(2026, 1, 3));
    expect(rows.first.weightKg, 80);
    expect(rows.last.weightKg, 82.5);
    // The squat set belongs to another exercise and is not here.
    expect(rows.every((r) => r.sessionName == 'Session'), isTrue);
  });

  test('ignores other exercises entirely', () async {
    await logSession(DateTime(2026, 1, 1), [
      (exerciseId: 2, name: 'Squat', weight: 100, reps: 5),
    ]);
    final rows = await db.watchExerciseSetHistory(1).first;
    expect(rows, isEmpty);
  });

  test('a live, unfinished session does not count', () async {
    // saveSession cannot leave a session open, so build one by hand.
    final live = await db.into(db.sessions).insert(
        SessionsCompanion.insert(name: 'Live', startedAt: DateTime(2026, 2, 1)));
    await db.into(db.sessionSets).insert(SessionSetsCompanion.insert(
          sessionId: live,
          exerciseId: const Value(1),
          exerciseName: 'Bench Press',
          setNumber: 1,
          weight: const Value(90),
          reps: const Value(3),
          done: const Value(true),
        ));

    final rows = await db.watchExerciseSetHistory(1).first;
    expect(rows, isEmpty);
  });

  test('carries seconds through for a held movement', () async {
    await db.saveSession(
      routineId: null,
      workoutId: null,
      name: 'Core',
      startedAt: DateTime(2026, 1, 1),
      endedAt: DateTime(2026, 1, 1, 1),
      durationSeconds: 3600,
      totalVolume: 0,
      sets: [
        SessionSetsCompanion.insert(
          sessionId: 0,
          exerciseId: const Value(9),
          exerciseName: 'Plank',
          setNumber: 1,
          seconds: const Value(60),
          done: const Value(true),
        ),
      ],
    );
    final rows = await db.watchExerciseSetHistory(9).first;
    expect(rows.single.seconds, 60);
    expect(rows.single.timed, isTrue);
  });
}
