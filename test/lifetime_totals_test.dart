import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';

/// Lifetime volume/reps/sets are derived from the logged sets, so these cover
/// what gets counted — and, just as importantly, what does not.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> logSession(List<({double weight, int reps, bool done})> sets) {
    var n = 1;
    return db.saveSession(
      routineId: null,
      workoutId: null,
      name: 'Test',
      startedAt: DateTime(2026, 1, 1),
      endedAt: DateTime(2026, 1, 1, 1),
      durationSeconds: 3600,
      totalVolume: 0,
      sets: [
        for (final s in sets)
          SessionSetsCompanion.insert(
            sessionId: 0, // replaced inside saveSession
            exerciseName: 'Bench Press',
            setNumber: n++,
            weight: Value(s.weight),
            reps: Value(s.reps),
            done: Value(s.done),
          ),
      ],
    );
  }

  test('a fresh install has nothing to show', () async {
    final t = await db.watchLifetimeTotals().first;
    expect(t.volumeKg, 0);
    expect(t.reps, 0);
    expect(t.sets, 0);
  });

  test('totals accumulate across sessions', () async {
    await logSession([
      (weight: 100, reps: 5, done: true),
      (weight: 100, reps: 4, done: true),
    ]);
    await logSession([(weight: 60, reps: 10, done: true)]);

    final t = await db.watchLifetimeTotals().first;
    expect(t.volumeKg, 500 + 400 + 600);
    expect(t.reps, 19);
    expect(t.sets, 3);
  });

  test('unfinished sets and unfinished sessions do not count', () async {
    await logSession([
      (weight: 100, reps: 5, done: true),
      (weight: 100, reps: 5, done: false),
    ]);

    // A session still in progress — saveSession cannot produce one, but a
    // crash mid-workout could leave one behind.
    final live = await db.into(db.sessions).insert(
        SessionsCompanion.insert(name: 'Live', startedAt: DateTime(2026, 1, 2)));
    await db.into(db.sessionSets).insert(SessionSetsCompanion.insert(
          sessionId: live,
          exerciseName: 'Bench Press',
          setNumber: 1,
          weight: const Value(80),
          reps: const Value(8),
          done: const Value(true),
        ));

    final t = await db.watchLifetimeTotals().first;
    expect(t.volumeKg, 500);
    expect(t.reps, 5);
    expect(t.sets, 1);
  });

  test('bodyweight sets add reps but no volume', () async {
    await logSession([(weight: 0, reps: 12, done: true)]);

    final t = await db.watchLifetimeTotals().first;
    expect(t.volumeKg, 0);
    expect(t.reps, 12);
    expect(t.sets, 1);
  });

  test('history logged before this feature existed is counted', () async {
    // Nothing is stored per session, so sets written by an older build show up
    // the moment the query runs.
    await logSession([(weight: 42.5, reps: 6, done: true)]);
    final t = await db.watchLifetimeTotals().first;
    expect(t.volumeKg, closeTo(255, 0.0001));
  });
}
