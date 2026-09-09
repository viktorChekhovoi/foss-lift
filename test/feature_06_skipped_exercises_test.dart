// Per-exercise inactivity regressions for skipped-sets-and-timed-deload.md.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/widgets/start_workout.dart';

import 'support/harness.dart';
import 'support/skipped_sets.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final now = DateTime(2026, 6, 1, 12);

  setUp(() {
    db = memoryDb();
    container = containerFor(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // Historical performance, without moving today's template to manufacture it.
  // An empty list is a fully skipped bench; the other exercise may still train.
  Future<int> history(
    SkippedSetWorkout fixture, {
    required DateTime at,
    List<int> benchReps = const [8, 8, 8],
    bool trainSquat = true,
    bool done = true,
  }) => db.saveSession(
    routineId: fixture.workout.routineId,
    workoutId: fixture.workout.id,
    name: fixture.workout.name,
    startedAt: at,
    endedAt: at.add(const Duration(minutes: 40)),
    durationSeconds: 2400,
    totalVolume: 0,
    sets: [
      if (trainSquat)
        SessionSetsCompanion.insert(
          sessionId: 0,
          exerciseName: 'Back Squat',
          exerciseId: Value(fixture.squat.exerciseId),
          setNumber: 1,
          weight: const Value(100),
          reps: const Value(5),
          done: const Value(true),
        ),
      for (var si = 0; si < benchReps.length; si++)
        SessionSetsCompanion.insert(
          sessionId: 0,
          exerciseName: 'Bench Press',
          exerciseId: Value(fixture.bench.exerciseId),
          setNumber: si + 1,
          weight: const Value(80),
          reps: Value(benchReps[si]),
          done: Value(done),
        ),
    ],
  );

  for (final option in normalProgressions) {
    group('${option.name}: inactivity belongs to the exercise', () {
      test(
        'never-trained exercises and empty history produce no offer',
        () async {
          final fixture = await skippedSetWorkout(
            db,
            mode: option.mode,
            weightAndReps: option.weightAndReps,
          );
          expect(
            await db.layoffsForWorkout(fixture.workout.id, now: now),
            isEmpty,
          );
          await history(
            fixture,
            at: now.subtract(const Duration(days: 40)),
            benchReps: [],
            trainSquat: false,
          );
          expect(
            await db.layoffsForWorkout(fixture.workout.id, now: now),
            isEmpty,
          );
        },
      );

      test(
        'an old workout does not invent training for an always-skipped bench',
        () async {
          final fixture = await skippedSetWorkout(
            db,
            mode: option.mode,
            weightAndReps: option.weightAndReps,
          );
          await history(
            fixture,
            at: now.subtract(const Duration(days: 20)),
            benchReps: [],
          );
          expect(await db.layoffsForWorkout(fixture.workout.id, now: now), {
            fixture.squat.id: (gapDays: 20, periods: 1, percent: 10),
          });
        },
      );

      test(
        'repeated skips preserve the old training time while squats train',
        () async {
          final fixture = await skippedSetWorkout(
            db,
            mode: option.mode,
            weightAndReps: option.weightAndReps,
            failures: 1,
          );
          await history(fixture, at: now.subtract(const Duration(days: 28)));
          for (final days in [21, 14, 7, 1]) {
            await history(
              fixture,
              at: now.subtract(Duration(days: days)),
              benchReps: [],
            );
          }

          expect(await db.layoffsForWorkout(fixture.workout.id, now: now), {
            fixture.bench.id: (gapDays: 28, periods: 2, percent: 20),
          });
          expect(
            await db.workoutItemById(fixture.bench.id),
            fixture.bench,
            reason: 'offering a timed deload must not apply it',
          );
          expect(await db.workoutItemById(fixture.squat.id), fixture.squat);
        },
      );

      test(
        'skips do not reduce targets before the configured threshold',
        () async {
          final fixture = await skippedSetWorkout(
            db,
            mode: option.mode,
            weightAndReps: option.weightAndReps,
          );
          await history(fixture, at: now.subtract(const Duration(days: 13)));
          await history(
            fixture,
            at: now.subtract(const Duration(days: 1)),
            benchReps: [],
          );

          expect(
            await db.layoffsForWorkout(fixture.workout.id, now: now),
            isEmpty,
          );
          expect(await db.workoutItemById(fixture.bench.id), fixture.bench);
          expect(
            await db.layoffsForWorkout(
              fixture.workout.id,
              now: now.add(const Duration(days: 1)),
            ),
            {fixture.bench.id: (gapDays: 14, periods: 1, percent: 10)},
          );
        },
      );

      for (final reps in [
        [8],
        [8, 8],
        [8, 8, 8],
        [5],
        [0],
      ]) {
        test(
          'recorded sets $reps reset inactivity even with a shortfall',
          () async {
            final fixture = await skippedSetWorkout(
              db,
              mode: option.mode,
              weightAndReps: option.weightAndReps,
            );
            await history(fixture, at: now.subtract(const Duration(days: 40)));
            await history(
              fixture,
              at: now.subtract(const Duration(days: 1)),
              benchReps: reps,
            );

            expect(
              await db.layoffsForWorkout(fixture.workout.id, now: now),
              isEmpty,
            );
            // Check the new clock at its boundary, so an implementation that
            // simply suppresses all partial-session offers cannot satisfy this.
            expect(
              await db.layoffsForWorkout(
                fixture.workout.id,
                now: now.add(const Duration(days: 13)),
              ),
              {
                fixture.squat.id: (gapDays: 14, periods: 1, percent: 10),
                fixture.bench.id: (gapDays: 14, periods: 1, percent: 10),
              },
            );
          },
        );
      }

      test(
        'controller persistence distinguishes a skipped bench from one set',
        () async {
          final fixture = await skippedSetWorkout(
            db,
            mode: option.mode,
            weightAndReps: option.weightAndReps,
          );
          final today = DateTime.now();
          await history(fixture, at: today.subtract(const Duration(days: 20)));
          await finishSkippedSetWorkout(container, fixture, trainSquat: true);
          expect(await db.layoffsForWorkout(fixture.workout.id, now: today), {
            fixture.bench.id: (gapDays: 20, periods: 1, percent: 10),
          });

          await finishSkippedSetWorkout(
            container,
            fixture,
            benchReps: [null, fixture.bench.goalReps, null],
          );
          expect(
            await db.layoffsForWorkout(fixture.workout.id, now: today),
            isEmpty,
          );
        },
      );

      test('accepting only the bench offer preserves the other slot', () async {
        final fixture = await skippedSetWorkout(
          db,
          mode: option.mode,
          weightAndReps: option.weightAndReps,
          failures: 1,
        );
        // Supply the accepted offer directly so application is tested even
        // while the offer-query skeleton still returns an empty map.
        final moved = await db.applyLayoffDeloads({
          fixture.bench.id: (gapDays: 14, periods: 1, percent: 10),
        });
        expect(moved, 1);
        final bench = (await db.workoutItemById(fixture.bench.id))!;
        expect(
          bench.suggestedWeight,
          option.mode == ProgressionMode.reps ? 80 : 72,
        );
        expect(bench.repsMin, option.mode == ProgressionMode.reps ? 5 : 6);
        expect(bench.repsMax, option.mode == ProgressionMode.reps ? 7 : 8);
        expect(bench.successStreak, 0);
        expect(bench.failStreak, 0);
        expect(await db.workoutItemById(fixture.squat.id), fixture.squat);
      });
    });
  }

  test(
    'finishing an entirely skipped workout preserves both training clocks',
    () async {
      final fixture = await skippedSetWorkout(db);
      final today = DateTime.now();
      await history(fixture, at: today.subtract(const Duration(days: 20)));
      await finishSkippedSetWorkout(container, fixture);

      expect(await db.layoffsForWorkout(fixture.workout.id, now: today), {
        fixture.squat.id: (gapDays: 20, periods: 1, percent: 10),
        fixture.bench.id: (gapDays: 20, periods: 1, percent: 10),
      });
    },
  );

  test(
    'each offer uses its own gap, the custom settings, and the period cap',
    () async {
      final fixture = await skippedSetWorkout(db);
      await db.setLayoffDays(7);
      await db.setLayoffPercent(15);
      await history(fixture, at: now.subtract(const Duration(days: 100)));
      await history(
        fixture,
        at: now.subtract(const Duration(days: 14)),
        benchReps: [],
      );
      expect(await db.layoffsForWorkout(fixture.workout.id, now: now), {
        fixture.squat.id: (gapDays: 14, periods: 2, percent: 30),
        fixture.bench.id: (gapDays: 100, periods: 3, percent: 45),
      });
    },
  );

  for (final disabled in ['days', 'percent']) {
    test('zero $disabled disables offers for skipped exercises', () async {
      final fixture = await skippedSetWorkout(db);
      await history(fixture, at: now.subtract(const Duration(days: 100)));
      await history(
        fixture,
        at: now.subtract(const Duration(days: 1)),
        benchReps: [],
      );
      if (disabled == 'days') {
        await db.setLayoffDays(0);
      } else {
        await db.setLayoffPercent(0);
      }
      expect(await db.layoffsForWorkout(fixture.workout.id, now: now), isEmpty);
    });
  }

  test('unperformed stored rows do not reset the exercise clock', () async {
    final fixture = await skippedSetWorkout(db);
    await history(fixture, at: now.subtract(const Duration(days: 20)));
    await history(
      fixture,
      at: now.subtract(const Duration(days: 1)),
      done: false,
    );
    expect(await db.layoffsForWorkout(fixture.workout.id, now: now), {
      fixture.bench.id: (gapDays: 20, periods: 1, percent: 10),
    });
  });

  test(
    'an unfinished session does not replace finished training history',
    () async {
      final fixture = await skippedSetWorkout(db);
      await history(fixture, at: now.subtract(const Duration(days: 20)));
      final unfinished = await history(fixture, at: now);
      await (db.update(db.sessions)..where((s) => s.id.equals(unfinished)))
          .write(const SessionsCompanion(endedAt: Value(null)));
      expect(await db.layoffsForWorkout(fixture.workout.id, now: now), {
        fixture.squat.id: (gapDays: 20, periods: 1, percent: 10),
        fixture.bench.id: (gapDays: 20, periods: 1, percent: 10),
      });
    },
  );

  test(
    'acceptance uses each offered percentage rather than a workout-wide cut',
    () async {
      final fixture = await skippedSetWorkout(db);
      expect(
        await db.applyLayoffDeloads({
          fixture.bench.id: (gapDays: 28, periods: 2, percent: 20),
          fixture.squat.id: (gapDays: 14, periods: 1, percent: 10),
        }),
        2,
      );
      expect((await db.workoutItemById(fixture.bench.id))!.suggestedWeight, 64);
      expect((await db.workoutItemById(fixture.squat.id))!.suggestedWeight, 90);
    },
  );

  for (final target in [(from: 83.0, to: 74.5), (from: 20.0, to: 20.0)]) {
    test(
      'an accepted cut at ${target.from} retains rounding and the bar floor',
      () async {
        final fixture = await skippedSetWorkout(db, successes: 1);
        await (db.update(db.workoutItems)
              ..where((i) => i.id.equals(fixture.bench.id)))
            .write(WorkoutItemsCompanion(suggestedWeight: Value(target.from)));
        expect(
          await db.applyLayoffDeloads({
            fixture.bench.id: (gapDays: 14, periods: 1, percent: 10),
          }),
          target.from == target.to ? 0 : 1,
        );

        final bench = (await db.workoutItemById(fixture.bench.id))!;
        expect(bench.suggestedWeight, target.to);
        expect(
          bench.successStreak,
          0,
          reason: 'accepted deloads clear momentum even at the weight floor',
        );
        expect(await db.workoutItemById(fixture.squat.id), fixture.squat);
      },
    );
  }

  test('an offer for a slot deleted before acceptance is harmless', () async {
    final fixture = await skippedSetWorkout(db);
    final accepted = {fixture.bench.id: (gapDays: 14, periods: 1, percent: 10)};
    await (db.delete(
      db.workoutItems,
    )..where((i) => i.id.equals(fixture.bench.id))).go();
    expect(await db.applyLayoffDeloads(accepted), 0);
    expect(await db.workoutItemById(fixture.squat.id), fixture.squat);
  });

  test('an empty accepted selection changes nothing', () async {
    final fixture = await skippedSetWorkout(db, successes: 1);
    expect(await db.applyLayoffDeloads({}), 0);
    expect(await db.workoutItemById(fixture.bench.id), fixture.bench);
    expect(await db.workoutItemById(fixture.squat.id), fixture.squat);
  });

  for (final accept in [false, true]) {
    testWidgets(
      'a due skipped bench can be ${accept ? 'accepted' : 'declined'} '
      'when the workout was trained recently',
      (tester) async {
        late SkippedSetWorkout fixture;
        await tester.runAsync(() async {
          fixture = await skippedSetWorkout(db, failures: 1);
          final today = DateTime.now();
          await history(fixture, at: today.subtract(const Duration(days: 20)));
          await history(
            fixture,
            at: today.subtract(const Duration(days: 1)),
            benchReps: [],
          );
        });

        await tester.pumpWidget(
          routedAppUnder(
            container,
            Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => startWorkout(
                  context,
                  ref,
                  fixture.workout.id,
                  fixture.workout.name,
                ),
                child: const Text('Start fixture'),
              ),
            ),
            scaffold: true,
            alsoRoutes: ['session'],
          ),
        );
        try {
          await tester.tap(find.text('Start fixture'));
          await pumpThroughDatabase(tester);
          final l10n = l10nFor();
          expect(find.text(l10n.startWorkoutLayoffTitle), findsOneWidget);
          expect(
            container.read(activeWorkoutProvider),
            isNull,
            reason: 'the offer must be answered before training starts',
          );
          await tester.runAsync(() async {
            expect(await db.workoutItemById(fixture.bench.id), fixture.bench);
          });

          await tester.tap(
            find.text(
              accept
                  ? l10n.startWorkoutDeload(10)
                  : l10n.startWorkoutKeepWeights,
            ),
          );
          await pumpThroughDatabase(tester);
          expect(find.text('at /session'), findsOneWidget);
          final live = container.read(activeWorkoutProvider)!;
          expect(live.exercises[1].workingKg, accept ? 72 : 80);
          expect(live.exercises[0].workingKg, 100);
          await tester.runAsync(() async {
            final bench = (await db.workoutItemById(fixture.bench.id))!;
            expect(bench.suggestedWeight, accept ? 72 : 80);
            expect(bench.failStreak, accept ? 0 : 1);
            expect(await db.workoutItemById(fixture.squat.id), fixture.squat);
            if (!accept) {
              expect(
                await db.layoffsForWorkout(fixture.workout.id),
                {fixture.bench.id: (gapDays: 20, periods: 1, percent: 10)},
                reason: 'declining without performing sets does not reset time',
              );
            }
          });
        } finally {
          await tester.runAsync(
            () => container.read(activeWorkoutProvider.notifier).discard(),
          );
          await stop(tester);
        }
      },
    );
  }
}
