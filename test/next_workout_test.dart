// Only Value is needed; a bare drift import clashes with matcher's isNull.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';

/// The next-workout suggestion is derived, not stored — these pin down what it
/// derives, especially when you train out of order.
void main() {
  group('nextWorkoutId', () {
    final ppl = [10, 20, 30];

    test('a routine never trained suggests its first workout', () {
      expect(nextWorkoutId(ppl, null), 10);
    });

    test('suggests the one after whatever was done last', () {
      expect(nextWorkoutId(ppl, 10), 20);
      expect(nextWorkoutId(ppl, 20), 30);
    });

    test('wraps around at the end of the routine', () {
      expect(nextWorkoutId(ppl, 30), 10);
    });

    test('training out of order just follows from what you did', () {
      // Skipping Pull to do Legs does not desync anything: the next suggestion
      // is simply the one after Legs.
      expect(nextWorkoutId(ppl, 30), 10);
    });

    test('falls back to the first when the last workout was deleted', () {
      expect(nextWorkoutId(ppl, 99), 10);
    });

    test('a routine with no workouts suggests nothing', () {
      expect(nextWorkoutId(const [], null), isNull);
      expect(nextWorkoutId(const [], 10), isNull);
    });

    test('a single-workout routine always suggests that workout', () {
      expect(nextWorkoutId(const [7], null), 7);
      expect(nextWorkoutId(const [7], 7), 7);
    });
  });

  group('against the database', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> logSession(int routineId, int workoutId, DateTime at) async {
      await db.saveSession(
        routineId: routineId,
        workoutId: workoutId,
        name: 'x',
        startedAt: at,
        endedAt: at.add(const Duration(hours: 1)),
        durationSeconds: 3600,
        totalVolume: 0,
        sets: const [],
      );
    }

    test('an untrained routine reports no last session', () async {
      final ppl = (await db.watchRoutines().first).first.routine;
      expect(await db.watchLastSessionForRoutine(ppl.id).first, isNull);
    });

    test('the last session is the most recent one, not the last inserted',
        () async {
      final ppl = (await db.watchRoutines().first).first.routine;
      final days = await db.workoutsForRoutine(ppl.id);

      await logSession(ppl.id, days[0].id, DateTime(2026, 7, 20));
      await logSession(ppl.id, days[2].id, DateTime(2026, 7, 10)); // backdated

      final last = await db.watchLastSessionForRoutine(ppl.id).first;
      expect(last!.workoutId, days[0].id);
      expect(
        nextWorkoutId(days.map((w) => w.id).toList(), last.workoutId),
        days[1].id,
      );
    });

    test('another routine\'s history does not leak in', () async {
      final routines = await db.watchRoutines().first;
      final ppl = routines.first.routine;
      final ul = routines.last.routine;
      final pplDays = await db.workoutsForRoutine(ppl.id);

      await logSession(ppl.id, pplDays[1].id, DateTime(2026, 7, 20));

      expect(await db.watchLastSessionForRoutine(ul.id).first, isNull);
    });

    test('an unfinished session does not count as trained', () async {
      final ppl = (await db.watchRoutines().first).first.routine;
      final days = await db.workoutsForRoutine(ppl.id);
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              routineId: Value(ppl.id),
              workoutId: Value(days[0].id),
              name: 'in progress',
              startedAt: DateTime(2026, 7, 21),
            ),
          );

      expect(await db.watchLastSessionForRoutine(ppl.id).first, isNull);
    });
  });
}
