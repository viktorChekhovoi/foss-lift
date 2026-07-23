import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';

/// The layoff deload against a real database: what the gap is measured from,
/// and what a back-off actually does to a workout's slots.
void main() {
  late AppDatabase db;
  late int routineId;
  late int workoutId;

  /// A workout with one slot on each axis, plus a bodyweight slot that has no
  /// target to cut at all.
  Future<void> buildWorkout() async {
    final library = await db.watchExercises().first;
    int idOf(String name) => library.firstWhere((e) => e.name == name).id;

    routineId =
        await db.createRoutine(name: 'Test', color: 'FF6A3D', restSeconds: 90);
    workoutId = await db.createWorkout(routineId, 'Day A');
    await db.replaceWorkoutItems(workoutId, [
      WorkoutItemsCompanion.insert(
        workoutId: workoutId,
        exerciseId: idOf('Back Squat'),
        position: const Value(0),
        suggestedWeight: const Value(100),
        progression: const Value(ProgressionMode.weight),
        successStreak: const Value(2),
      ),
      WorkoutItemsCompanion.insert(
        workoutId: workoutId,
        exerciseId: idOf('Pull-Up'),
        position: const Value(1),
        repsMin: const Value(8),
        repsMax: const Value(12),
        progression: const Value(ProgressionMode.reps),
        failStreak: const Value(1),
      ),
      WorkoutItemsCompanion.insert(
        workoutId: workoutId,
        exerciseId: idOf('Plank'),
        position: const Value(2),
        holdSeconds: const Value(60),
        progression: const Value(ProgressionMode.time),
      ),
      WorkoutItemsCompanion.insert(
        workoutId: workoutId,
        exerciseId: idOf('Push-Up'),
        position: const Value(3),
        progression: const Value(ProgressionMode.weight),
      ),
    ]);
  }

  Future<void> logSessionAt(DateTime when) async {
    await db.saveSession(
      routineId: routineId,
      workoutId: workoutId,
      name: 'Day A',
      startedAt: when,
      endedAt: when.add(const Duration(hours: 1)),
      durationSeconds: 3600,
      totalVolume: 1000,
      sets: const [],
    );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await buildWorkout();
  });
  tearDown(() => db.close());

  group('deciding there was a layoff', () {
    final now = DateTime(2026, 7, 1, 10);

    test('a workout never trained has no gap to regress from', () async {
      expect(await db.layoffFor(workoutId, now: now), isNull);
    });

    test('a recent session is no layoff', () async {
      await logSessionAt(now.subtract(const Duration(days: 5)));
      expect(await db.layoffFor(workoutId, now: now), isNull);
    });

    test('three weeks off earns one period of back-off', () async {
      await logSessionAt(now.subtract(const Duration(days: 21)));
      expect(await db.layoffFor(workoutId, now: now),
          (gapDays: 21, periods: 1, percent: 10));
    });

    test('and a long absence earns the capped one', () async {
      await logSessionAt(now.subtract(const Duration(days: 400)));
      expect((await db.layoffFor(workoutId, now: now))?.percent, 30);
    });

    test('the gap is measured from the most recent session, not the first',
        () async {
      await logSessionAt(now.subtract(const Duration(days: 400)));
      await logSessionAt(now.subtract(const Duration(days: 20)));
      expect((await db.layoffFor(workoutId, now: now))?.gapDays, 20);
    });

    test('another workout being trained throughout changes nothing', () async {
      // The split case the whole thing exists for: Push comes round every week
      // and Legs has not been touched since spring.
      final other = await db.createWorkout(routineId, 'Day B');
      await db.saveSession(
        routineId: routineId,
        workoutId: other,
        name: 'Day B',
        startedAt: now.subtract(const Duration(days: 1)),
        endedAt: now,
        durationSeconds: 3600,
        totalVolume: 0,
        sets: const [],
      );
      await logSessionAt(now.subtract(const Duration(days: 30)));
      expect((await db.layoffFor(workoutId, now: now))?.gapDays, 30);
    });

    test('switching the rules off silences it entirely', () async {
      await logSessionAt(now.subtract(const Duration(days: 400)));
      await db.setLayoffDays(0);
      expect(await db.layoffFor(workoutId, now: now), isNull);
    });

    test('a shorter threshold is respected', () async {
      await logSessionAt(now.subtract(const Duration(days: 8)));
      await db.setLayoffDays(7);
      await db.setLayoffPercent(15);
      expect(await db.layoffFor(workoutId, now: now),
          (gapDays: 8, periods: 1, percent: 15));
    });
  });

  group('applying it', () {
    test('cuts each slot along its own axis', () async {
      final moved = await db.applyLayoffDeload(workoutId, 10);
      final items = await db.itemsForWorkout(workoutId);

      expect(items[0].item.suggestedWeight, 90);
      expect([items[1].item.repsMin, items[1].item.repsMax], [7, 11],
          reason: 'a range keeps its width on the way down as on the way up');
      expect(items[2].item.holdSeconds, 54);
      expect(moved, 3);
    });

    test('leaves a slot with no target to cut alone', () async {
      await db.applyLayoffDeload(workoutId, 10);
      final pushUp = (await db.itemsForWorkout(workoutId))[3].item;
      expect(pushUp.suggestedWeight, isNull,
          reason: 'there is nothing to take ten percent of');
    });

    test('clears the progression streaks with it', () async {
      await db.applyLayoffDeload(workoutId, 10);
      final items = await db.itemsForWorkout(workoutId);
      expect(items.map((i) => i.item.successStreak), everyElement(0));
      expect(items.map((i) => i.item.failStreak), everyElement(0),
          reason: 'sessions either side of a layoff are not consecutive');
    });

    test('touches nothing outside the workout', () async {
      final other = await db.createWorkout(routineId, 'Day B');
      final library = await db.watchExercises().first;
      await db.replaceWorkoutItems(other, [
        WorkoutItemsCompanion.insert(
          workoutId: other,
          exerciseId: library.firstWhere((e) => e.name == 'Deadlift').id,
          suggestedWeight: const Value(140),
        ),
      ]);
      await db.applyLayoffDeload(workoutId, 10);
      expect((await db.itemsForWorkout(other)).single.item.suggestedWeight, 140);
    });

    test('reports nothing moved when there was nothing to move', () async {
      final bodyweight = await db.createWorkout(routineId, 'Day C');
      final library = await db.watchExercises().first;
      await db.replaceWorkoutItems(bodyweight, [
        WorkoutItemsCompanion.insert(
          workoutId: bodyweight,
          exerciseId: library.firstWhere((e) => e.name == 'Push-Up').id,
        ),
      ]);
      expect(await db.applyLayoffDeload(bodyweight, 10), 0);
    });

    test('leaves logged history untouched', () async {
      await logSessionAt(DateTime(2026, 5, 1, 18));
      await db.applyLayoffDeload(workoutId, 20);
      final history = await db.watchHistory().first;
      expect(history, hasLength(1));
      expect(history.single.startedAt, DateTime(2026, 5, 1, 18));
    });
  });
}
