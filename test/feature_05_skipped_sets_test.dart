// Regression tests for feature-requests/skipped-sets-and-timed-deload.md.
// The partial-session progression policy is still open. These assertions cover
// what both policies require, without choosing between a hold and a success.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/state/active_workout.dart';

import 'support/harness.dart';
import 'support/skipped_sets.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = memoryDb();
    container = containerFor(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  for (final option in normalProgressions) {
    group('${option.name}: skipped sets', () {
      for (final streak in [
        (successes: 0, failures: 0),
        (successes: 1, failures: 0),
        (successes: 0, failures: 1),
      ]) {
        test('all skipped preserves targets and streaks $streak', () async {
          final fixture = await skippedSetWorkout(
            db,
            mode: option.mode,
            weightAndReps: option.weightAndReps,
            successes: streak.successes,
            failures: streak.failures,
          );

          final sessionId = await finishSkippedSetWorkout(
            container,
            fixture,
            trainSquat: true,
          );

          expect(await db.workoutItemById(fixture.bench.id), fixture.bench);
          expect(
            (await db.workoutItemById(fixture.squat.id))!.suggestedWeight,
            102.5,
            reason: 'the performed exercise still progresses normally',
          );
          final saved = await db.setsForSession(sessionId);
          expect(saved, hasLength(3));
          expect(
            saved.every((s) => s.exerciseId == fixture.squat.exerciseId),
            isTrue,
          );
        });
      }

      test(
        'the recap does not record a skipped exercise as an outcome',
        () async {
          final fixture = await skippedSetWorkout(
            db,
            mode: option.mode,
            weightAndReps: option.weightAndReps,
          );
          final sessionId = await finishSkippedSetWorkout(
            container,
            fixture,
            trainSquat: true,
          );

          final report = container.read(lastProgressionProvider)!;
          expect(report.sessionId, sessionId);
          expect(report.outcomes.map((o) => o.name), ['Back Squat']);
        },
      );

      test(
        'a workout with no performed sets records no progression outcome',
        () async {
          final fixture = await skippedSetWorkout(
            db,
            mode: option.mode,
            weightAndReps: option.weightAndReps,
            successes: 1,
          );
          final sessionId = await finishSkippedSetWorkout(container, fixture);

          expect(container.read(lastProgressionProvider), isNull);
          expect(await db.setsForSession(sessionId), isEmpty);
          expect(await db.workoutItemById(fixture.bench.id), fixture.bench);
          expect(await db.workoutItemById(fixture.squat.id), fixture.squat);
        },
      );

      test(
        'repeated skips do not spend a pending failure on a deload',
        () async {
          final fixture = await skippedSetWorkout(
            db,
            mode: option.mode,
            weightAndReps: option.weightAndReps,
            failures: 1,
          );
          for (var session = 0; session < 3; session++) {
            await finishSkippedSetWorkout(container, fixture, trainSquat: true);
            expect(
              await db.workoutItemById(fixture.bench.id),
              fixture.bench,
              reason: 'skip ${session + 1} must leave the previous miss alone',
            );
          }
        },
      );

      test(
        'choosing a heavier load without performing a set changes nothing',
        () async {
          final fixture = await skippedSetWorkout(
            db,
            mode: option.mode,
            weightAndReps: option.weightAndReps,
          );
          await finishSkippedSetWorkout(container, fixture, benchWeight: 100);
          expect(await db.workoutItemById(fixture.bench.id), fixture.bench);
        },
      );

      for (final performed in [
        [0],
        [1],
        [2],
        [0, 1],
        [0, 2],
        [1, 2],
      ]) {
        test(
          'performing sets $performed does not turn the others into misses',
          () async {
            final fixture = await skippedSetWorkout(
              db,
              mode: option.mode,
              weightAndReps: option.weightAndReps,
              failures: 1,
            );
            final sessionId = await finishSkippedSetWorkout(
              container,
              fixture,
              benchReps: [
                for (var si = 0; si < 3; si++)
                  performed.contains(si) ? fixture.bench.goalReps : null,
              ],
            );

            final after = (await db.workoutItemById(fixture.bench.id))!;
            expect(
              after.failStreak,
              lessThanOrEqualTo(fixture.bench.failStreak),
            );
            expect(
              after.suggestedWeight,
              greaterThanOrEqualTo(fixture.bench.suggestedWeight!),
            );
            expect(
              after.goalReps,
              greaterThanOrEqualTo(fixture.bench.goalReps),
            );
            expect(
              await db.setsForSession(sessionId),
              hasLength(performed.length),
            );
          },
        );
      }

      test('all performed sets retain normal success progression', () async {
        final fixture = await skippedSetWorkout(
          db,
          mode: option.mode,
          weightAndReps: option.weightAndReps,
          successes: 1,
        );
        await finishSkippedSetWorkout(
          container,
          fixture,
          benchReps: List.filled(3, fixture.bench.goalReps),
        );

        final after = (await db.workoutItemById(fixture.bench.id))!;
        expect(after.successStreak, 0);
        expect(after.failStreak, 0);
        expect(
          after.suggestedWeight,
          option.mode == ProgressionMode.weight && !option.weightAndReps
              ? 82.5
              : 80,
        );
        expect(after.goalReps, option.mode == ProgressionMode.reps ? 9 : 8);
      });

      for (final shortfall in ['reps', 'weight', 'zero reps']) {
        test(
          'a recorded $shortfall shortfall still feeds the failure streak',
          () async {
            final fixture = await skippedSetWorkout(
              db,
              mode: option.mode,
              weightAndReps: option.weightAndReps,
              successes: 1,
            );
            final goal = fixture.bench.goalReps;
            final reps = shortfall == 'zero reps' ? 0 : goal - 1;
            final sessionId = await finishSkippedSetWorkout(
              container,
              fixture,
              benchReps: [goal, shortfall == 'weight' ? goal : reps, goal],
              benchWeight: shortfall == 'weight' ? 75 : null,
            );

            final after = (await db.workoutItemById(fixture.bench.id))!;
            expect(after.failStreak, 1);
            expect(after.successStreak, 0);
            expect(after.suggestedWeight, 80);
            expect(after.goalReps, goal);
            expect(
              await db.setsForSession(sessionId),
              hasLength(3),
              reason: 'a logged zero is a performed shortfall, not a skip',
            );
          },
        );
      }

      test(
        'a real miss after a skip still reaches the performance deload',
        () async {
          final fixture = await skippedSetWorkout(
            db,
            mode: option.mode,
            weightAndReps: option.weightAndReps,
            failures: 1,
          );
          await finishSkippedSetWorkout(container, fixture, trainSquat: true);
          expect(await db.workoutItemById(fixture.bench.id), fixture.bench);

          await finishSkippedSetWorkout(
            container,
            fixture,
            benchReps: List.filled(3, fixture.bench.goalReps - 1),
          );
          final after = (await db.workoutItemById(fixture.bench.id))!;
          expect(after.failStreak, 0);
          expect(after.successStreak, 0);
          expect(
            after.suggestedWeight! < fixture.bench.suggestedWeight! ||
                after.goalReps < fixture.bench.goalReps,
            isTrue,
            reason: 'two recorded misses still earn the configured back-off',
          );
        },
      );
    });
  }

  test(
    'Weight + Reps preserves an untouched rep goal on a fully skipped slot',
    () async {
      final fixture = await skippedSetWorkout(
        db,
        weightAndReps: true,
        repsTarget: null,
        failures: 1,
      );
      await finishSkippedSetWorkout(container, fixture, trainSquat: true);
      expect(await db.workoutItemById(fixture.bench.id), fixture.bench);
    },
  );
}
