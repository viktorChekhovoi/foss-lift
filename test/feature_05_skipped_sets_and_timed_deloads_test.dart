// Regression coverage for feature-requests/skipped-sets-and-timed-deload.md.
// Clean partial sessions may hold or progress: that product decision is open.
// They may never manufacture a performance miss from an unlogged set.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/state/session_snapshot.dart';
import 'package:foss_lift/widgets/start_workout.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

const _modes = [
  (name: 'Weight', mode: ProgressionMode.weight, advanced: false),
  (name: 'Reps', mode: ProgressionMode.reps, advanced: false),
  (name: 'Weight + Reps', mode: ProgressionMode.weight, advanced: true),
];

typedef _Fixture = ({Workout workout, WorkoutItem bench, WorkoutItem squat});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  Future<_Fixture> fixture({
    ProgressionMode mode = ProgressionMode.weight,
    bool advanced = false,
    int successes = 0,
    int failures = 0,
    int successThreshold = 3,
  }) async {
    final workout = await workoutNamed(db, 'Push');
    final bench = await exerciseNamed(db, 'Bench Press');
    final squat = await exerciseNamed(db, 'Back Squat');
    await db.replaceWorkoutItems(workout.id, [
      WorkoutItemsCompanion.insert(
        workoutId: workout.id,
        exerciseId: bench.id,
        targetSets: const Value(3),
        repsMin: const Value(6),
        repsMax: const Value(8),
        repsTarget: Value(advanced ? 7 : null),
        suggestedWeight: const Value(80),
        progression: Value(mode),
        addWeightAtTopOfRange: Value(advanced),
        increment: Value(mode.defaultIncrement),
        deload: Value(mode.defaultDeload),
        successThreshold: Value(successThreshold),
        failureThreshold: const Value(2),
        successStreak: Value(successes),
        failStreak: Value(failures),
      ),
      WorkoutItemsCompanion.insert(
        workoutId: workout.id,
        exerciseId: squat.id,
        position: const Value(1),
        targetSets: const Value(3),
        repsMin: const Value(5),
        suggestedWeight: const Value(100),
      ),
    ]);
    final items = await db.itemsForWorkout(workout.id);
    return (workout: workout, bench: items[0].item, squat: items[1].item);
  }

  Future<int> train(
    _Fixture f, {
    List<int> benchSets = const [],
    int? benchReps,
    double? benchWeight,
    bool trainSquat = true,
  }) async {
    final ctrl = container.read(activeWorkoutProvider.notifier);
    await ctrl.start(workoutId: f.workout.id, name: f.workout.name);
    if (benchWeight != null) ctrl.setWorkingWeight(0, benchWeight);
    final live = container.read(activeWorkoutProvider)!;
    for (final si in benchSets) {
      ctrl.setLogged(0, si, benchReps ?? live.exercises[0].sets[si].goal);
    }
    if (trainSquat) {
      for (var si = 0; si < live.exercises[1].sets.length; si++) {
        ctrl.setLogged(1, si, live.exercises[1].sets[si].goal);
      }
    }
    return (await ctrl.finish())!;
  }

  // Save actual history rows, including the exercise id and done marker the
  // finish path persists. A session header alone is not evidence of training.
  Future<int> history(
    _Fixture f,
    DateTime at, {
    int benchSets = 0,
    int squatSets = 3,
    bool benchDone = true,
    int benchReps = 8,
  }) => db.saveSession(
    routineId: f.workout.routineId,
    workoutId: f.workout.id,
    name: f.workout.name,
    startedAt: at,
    endedAt: at.add(const Duration(minutes: 40)),
    durationSeconds: 2400,
    totalVolume: benchSets * 80.0 * benchReps + squatSets * 100.0 * 5,
    sets: [
      for (var i = 0; i < benchSets; i++)
        SessionSetsCompanion.insert(
          sessionId: 0,
          exerciseName: 'Bench Press',
          exerciseId: Value(f.bench.exerciseId),
          setNumber: i + 1,
          reps: Value(benchReps),
          weight: const Value(80),
          done: Value(benchDone),
        ),
      for (var i = 0; i < squatSets; i++)
        SessionSetsCompanion.insert(
          sessionId: 0,
          exerciseName: 'Back Squat',
          exerciseId: Value(f.squat.exerciseId),
          setNumber: i + 1,
          reps: const Value(5),
          weight: const Value(100),
          done: const Value(true),
        ),
    ],
  );

  Future<DateTime?> lastBench(_Fixture f) =>
      db.lastTrainedAt(f.workout.id, exerciseId: f.bench.exerciseId);

  Future<LayoffDeload?> benchOffer(_Fixture f, {DateTime? at}) => db.layoffFor(
    f.workout.id,
    exerciseId: f.bench.exerciseId,
    now: at ?? now,
  );

  for (final config in _modes) {
    group('${config.name}: skipped sets through Finish', () {
      for (final streak in [
        (successes: 0, failures: 0),
        (successes: 2, failures: 0),
        (successes: 0, failures: 1),
      ]) {
        test('fully skipped preserves targets and streaks $streak', () async {
          final f = await fixture(
            mode: config.mode,
            advanced: config.advanced,
            successes: streak.successes,
            failures: streak.failures,
          );
          for (var session = 0; session < 3; session++) {
            await train(f);
            expect(
              await db.workoutItemById(f.bench.id),
              f.bench,
              reason: 'skip ${session + 1} must neither score nor move bench',
            );
          }
        });
      }

      test('only the performed exercise is reported and progressed', () async {
        final f = await fixture(mode: config.mode, advanced: config.advanced);
        final sessionId = await train(f);
        final report = container.read(lastProgressionProvider)!;
        expect(report.sessionId, sessionId);
        expect(report.outcomes.map((o) => o.name), ['Back Squat']);
        expect(report.outcomes.single.moved, 2.5);
        expect((await db.workoutItemById(f.squat.id))!.suggestedWeight, 102.5);
        final rows = await db.setsForSession(sessionId);
        expect(rows, hasLength(3));
        expect(rows.every((s) => s.exerciseId == f.squat.exerciseId), isTrue);
      });

      test('an entirely empty workout has no progression report', () async {
        final f = await fixture(mode: config.mode, advanced: config.advanced);
        final sessionId = await train(f, trainSquat: false);
        expect(container.read(lastProgressionProvider), isNull);
        expect(await db.setsForSession(sessionId), isEmpty);
        expect(await db.workoutItemById(f.bench.id), f.bench);
        expect(await db.workoutItemById(f.squat.id), f.squat);
      });

      for (final performed in [
        [0],
        [1],
        [2],
        [0, 2],
      ]) {
        test(
          'clean partial sets $performed never add a failure or deload',
          () async {
            final f = await fixture(
              mode: config.mode,
              advanced: config.advanced,
              failures: 1,
            );
            final sessionId = await train(f, benchSets: performed);
            final after = (await db.workoutItemById(f.bench.id))!;
            expect(after.suggestedWeight, greaterThanOrEqualTo(80));
            expect(after.repsMin, greaterThanOrEqualTo(f.bench.repsMin));
            expect(after.goalReps, greaterThanOrEqualTo(f.bench.goalReps));
            expect(after.failStreak, lessThanOrEqualTo(f.bench.failStreak));
            final rows = await db.setsForSession(sessionId);
            expect(
              rows.where((s) => s.exerciseId == f.bench.exerciseId),
              hasLength(performed.length),
            );
          },
        );
      }

      test(
        'all sets performed still earn the configured progression',
        () async {
          final f = await fixture(
            mode: config.mode,
            advanced: config.advanced,
            successThreshold: 1,
          );
          await train(f, benchSets: [0, 1, 2]);
          final after = (await db.workoutItemById(f.bench.id))!;
          expect(after.successStreak, 0);
          expect(after.failStreak, 0);
          if (config.advanced) {
            expect(after.repsTarget, 8);
            expect(after.suggestedWeight, 80);
          } else if (config.mode == ProgressionMode.reps) {
            expect(after.repsMin, 7);
            expect(after.repsMax, 9);
            expect(after.suggestedWeight, 80);
          } else {
            expect(after.suggestedWeight, 82.5);
            expect(after.repsMin, 6);
          }
        },
      );

      for (final shortfall in ['reps', 'weight', 'zero reps']) {
        test(
          'recorded $shortfall shortfalls retain performance rules',
          () async {
            final f = await fixture(
              mode: config.mode,
              advanced: config.advanced,
            );
            for (var session = 0; session < 2; session++) {
              await train(
                f,
                benchSets: [0, 1, 2],
                benchReps: shortfall == 'weight'
                    ? null
                    : (shortfall == 'reps' ? 1 : 0),
                benchWeight: shortfall == 'weight' ? 70 : null,
              );
              final after = (await db.workoutItemById(f.bench.id))!;
              expect(after.failStreak, session == 0 ? 1 : 0);
              if (session == 0) {
                expect(after.suggestedWeight, 80);
                expect(after.goalReps, f.bench.goalReps);
              } else if (config.advanced) {
                expect(after.goalReps, 6);
                expect(after.suggestedWeight, 80);
              } else if (config.mode == ProgressionMode.reps) {
                expect(after.repsMin, 4);
                expect(after.repsMax, 6);
              } else {
                expect(after.suggestedWeight, 75);
              }
            }
          },
        );
      }

      test('Finish leaves skipped bench inactive while squat trains', () async {
        final f = await fixture(mode: config.mode, advanced: config.advanced);
        final old = now.subtract(const Duration(days: 20));
        await history(f, old, benchSets: 3);
        await train(f);
        expect(await lastBench(f), old);
        expect(await benchOffer(f), (gapDays: 20, periods: 1, percent: 10));
        final squatLast = await db.lastTrainedAt(
          f.workout.id,
          exerciseId: f.squat.exerciseId,
        );
        expect(squatLast!.isAfter(old), isTrue);
      });

      for (final performed in [
        [2],
        [0, 2],
      ]) {
        test(
          'Finish with partial sets $performed resets bench inactivity',
          () async {
            final f = await fixture(
              mode: config.mode,
              advanced: config.advanced,
            );
            await history(
              f,
              now.subtract(const Duration(days: 20)),
              benchSets: 3,
            );
            final sessionId = await train(
              f,
              benchSets: performed,
              trainSquat: false,
            );
            final saved = await (db.select(
              db.sessions,
            )..where((s) => s.id.equals(sessionId))).getSingle();
            expect(await lastBench(f), saved.startedAt);
            expect(await benchOffer(f, at: saved.startedAt), isNull);
            expect(
              await benchOffer(
                f,
                at: DateTime(
                  saved.startedAt.year,
                  saved.startedAt.month,
                  saved.startedAt.day + 14,
                ),
              ),
              (gapDays: 14, periods: 1, percent: 10),
            );
          },
        );
      }
    });
  }

  group('timed deloads use performed history for each exercise', () {
    test(
      'never-trained bench has no timer even if squat has old history',
      () async {
        final f = await fixture();
        await history(f, now.subtract(const Duration(days: 40)));
        expect(await lastBench(f), isNull);
        expect(await benchOffer(f), isNull);
      },
    );

    test(
      'repeated skips accumulate to the exact threshold without cutting',
      () async {
        final f = await fixture(successes: 2);
        final trained = now.subtract(const Duration(days: 14));
        await history(f, trained, benchSets: 3);
        for (final day in [3, 7, 13]) {
          final at = trained.add(Duration(days: day));
          await history(f, at);
          expect(await lastBench(f), trained);
          expect(await benchOffer(f, at: at), isNull);
        }
        expect(await benchOffer(f), (gapDays: 14, periods: 1, percent: 10));
        expect(await db.workoutItemById(f.bench.id), f.bench);
        expect(await db.workoutItemById(f.squat.id), f.squat);
        expect(
          await db.layoffFor(
            f.workout.id,
            exerciseId: f.squat.exerciseId,
            now: now,
          ),
          isNull,
        );
      },
    );

    test(
      'an empty finished session does not reset a previous training date',
      () async {
        final f = await fixture();
        final old = now.subtract(const Duration(days: 20));
        await history(f, old, benchSets: 3);
        await history(f, now, squatSets: 0);
        expect(await lastBench(f), old);
        expect(await benchOffer(f), (gapDays: 20, periods: 1, percent: 10));
      },
    );

    test('persisted unperformed rows do not reset the training date', () async {
      final f = await fixture();
      final old = now.subtract(const Duration(days: 20));
      await history(f, old, benchSets: 3);
      await history(f, now, benchSets: 3, benchDone: false);
      expect(await lastBench(f), old);
      expect(await benchOffer(f), (gapDays: 20, periods: 1, percent: 10));
    });

    test(
      'unfinished sessions do not replace finished training history',
      () async {
        final f = await fixture();
        final old = now.subtract(const Duration(days: 20));
        await history(f, old, benchSets: 3);
        final pending = await history(f, now, benchSets: 1);
        await (db.update(db.sessions)..where((s) => s.id.equals(pending)))
            .write(const SessionsCompanion(endedAt: Value(null)));
        expect(await lastBench(f), old);
        expect(await benchOffer(f), (gapDays: 20, periods: 1, percent: 10));
      },
    );

    for (final reps in [8, 1, 0]) {
      test('a performed set recording $reps reps resets inactivity', () async {
        final f = await fixture();
        await history(f, now.subtract(const Duration(days: 40)), benchSets: 3);
        await history(f, now, benchSets: 1, benchReps: reps);
        expect(await lastBench(f), now);
        expect(await benchOffer(f), isNull);
        expect(await benchOffer(f, at: now.add(const Duration(days: 14))), (
          gapDays: 14,
          periods: 1,
          percent: 10,
        ));
      });
    }

    test(
      'out-of-order history uses the most recent performed session',
      () async {
        final f = await fixture();
        final latest = now.subtract(const Duration(days: 16));
        await history(f, latest, benchSets: 1);
        await history(f, now.subtract(const Duration(days: 40)), benchSets: 3);
        await history(f, now);
        expect(await lastBench(f), latest);
        expect(await benchOffer(f), (gapDays: 16, periods: 1, percent: 10));
      },
    );

    test(
      'custom periods and percentage apply despite recent skipped sessions',
      () async {
        final f = await fixture();
        await db.setLayoffDays(7);
        await db.setLayoffPercent(15);
        await history(f, now.subtract(const Duration(days: 16)), benchSets: 3);
        await history(f, now);
        expect(await benchOffer(f), (gapDays: 16, periods: 2, percent: 30));
      },
    );

    test(
      'long inactivity keeps the existing period and percentage caps',
      () async {
        final f = await fixture();
        await db.setLayoffPercent(40);
        await history(f, now.subtract(const Duration(days: 100)), benchSets: 3);
        await history(f, now);
        expect(await benchOffer(f), (gapDays: 100, periods: 3, percent: 90));
      },
    );

    for (final disabled in ['days', 'percent']) {
      test(
        'zero $disabled disables offers without losing the training date',
        () async {
          final f = await fixture();
          final old = now.subtract(const Duration(days: 40));
          await history(f, old, benchSets: 3);
          await history(f, now);
          if (disabled == 'days') {
            await db.setLayoffDays(0);
          } else {
            await db.setLayoffPercent(0);
          }
          expect(await benchOffer(f), isNull);
          expect(await lastBench(f), old);
        },
      );
    }

    test(
      'declining and skipping again leaves the offer and targets intact',
      () async {
        final f = await fixture(failures: 1);
        await history(f, now.subtract(const Duration(days: 20)), benchSets: 3);
        final offer = await benchOffer(f);
        expect(offer, (gapDays: 20, periods: 1, percent: 10));
        // Decline is the absence of applyLayoffDeload, just as in the dialog.
        await history(f, now);
        expect(await benchOffer(f), offer);
        expect(await db.workoutItemById(f.bench.id), f.bench);
      },
    );

    test(
      'accepting bench reduction preserves the active squat and its streaks',
      () async {
        final f = await fixture(failures: 1);
        await db.updateWorkoutItem(
          f.squat.id,
          const WorkoutItemsCompanion(successStreak: Value(2)),
        );
        final squatBefore = await db.workoutItemById(f.squat.id);
        final old = now.subtract(const Duration(days: 20));
        await history(f, old, benchSets: 3);
        await history(f, now);
        final moved = await db.applyLayoffDeload(
          f.workout.id,
          10,
          exerciseId: f.bench.exerciseId,
        );
        expect(moved, 1);
        final bench = (await db.workoutItemById(f.bench.id))!;
        expect(bench.suggestedWeight, 72);
        expect(bench.repsMin, f.bench.repsMin);
        expect(bench.repsMax, f.bench.repsMax);
        expect(bench.successStreak, 0);
        expect(bench.failStreak, 0);
        expect(await db.workoutItemById(f.squat.id), squatBefore);
        expect(await lastBench(f), old, reason: 'acceptance is not training');
      },
    );

    test(
      'an exercise outside the workout has no history or targets to cut',
      () async {
        final f = await fixture();
        final other = await exerciseNamed(db, 'Pull-Up');
        await history(f, now.subtract(const Duration(days: 20)), benchSets: 3);
        expect(
          await db.lastTrainedAt(f.workout.id, exerciseId: other.id),
          isNull,
        );
        expect(
          await db.layoffFor(f.workout.id, exerciseId: other.id, now: now),
          isNull,
        );
        expect(
          await db.applyLayoffDeload(f.workout.id, 10, exerciseId: other.id),
          0,
        );
        expect(await db.workoutItemById(f.bench.id), f.bench);
        expect(await db.workoutItemById(f.squat.id), f.squat);
      },
    );
  });

  group('the start-workout offer uses exercise inactivity', () {
    test('older snapshots retain workout-wide notices or no notice', () {
      final raw = jsonDecode(encodeSession(ActiveWorkout(
        routineId: null,
        workoutId: null,
        name: 'Workout',
        startedAt: now,
        exercises: [],
        elapsed: 0,
      ))) as Map<String, dynamic>;
      raw.remove('notice');
      expect(decodeSession(jsonEncode(raw))!.notices, isEmpty);
      raw['notice'] = {'percent': 20, 'days': 28};
      expect(decodeSession(jsonEncode(raw))!.notices, [
        (percent: 20, days: 28, exerciseName: null, seedKey: null),
      ]);
    });

    for (final acceptSquat in [false, true]) {
      testWidgets('accepted reductions remain named; acceptSquat=$acceptSquat', (
        tester,
      ) async {
        final f = (await tester.runAsync(() async {
          final f = await fixture();
          final today = DateTime.now();
          await history(
            f,
            today.subtract(const Duration(days: 42)),
            benchSets: 3,
            squatSets: 0,
          );
          await history(f, today.subtract(const Duration(days: 14)));
          return f;
        }))!;
        final l10n = l10nFor();
        await tester.pumpWidget(
          routedAppUnder(
            container,
            Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () =>
                    startWorkout(context, ref, f.workout.id, f.workout.name),
                child: const Text('Start test workout'),
              ),
            ),
            scaffold: true,
            alsoRoutes: ['session'],
          ),
        );
        try {
          await tester.tap(find.text('Start test workout'));
          await pumpThroughDatabase(tester);
          expect(
            find.text(l10n.startWorkoutLayoffBody('Bench Press', 42, 30)),
            findsOneWidget,
          );
          await tester.tap(find.text(l10n.startWorkoutDeload(30)));
          await pumpThroughDatabase(tester);
          expect(
            find.text(l10n.startWorkoutLayoffBody('Back Squat', 14, 10)),
            findsOneWidget,
          );
          await tester.tap(find.text(
            acceptSquat
                ? l10n.startWorkoutDeload(10)
                : l10n.startWorkoutKeepWeights,
          ));
          await pumpThroughDatabase(tester);
          expect(find.text('at /session'), findsOneWidget);
          final live = container.read(activeWorkoutProvider)!;
          expect(live.exercises[0].sets.first.goalWeight, 56);
          expect(live.exercises[1].sets.first.goalWeight, acceptSquat ? 90 : 100);
          expect(live.notices, hasLength(acceptSquat ? 2 : 1));
          expect(decodeSession(encodeSession(live))!.notices, live.notices);
          await tester.pumpWidget(appUnder(container, const WorkoutScreen()));
          await tester.pump();
          expect(
            find.text('Bench Press: ${l10n.startWorkoutDeloadNotice(30, 42)}'),
            findsOneWidget,
          );
          expect(
            find.text('Back Squat: ${l10n.startWorkoutDeloadNotice(10, 14)}'),
            acceptSquat ? findsOneWidget : findsNothing,
          );
        } finally {
          await tester.runAsync(
            () => container.read(activeWorkoutProvider.notifier).discard(),
          );
          await stop(tester);
        }
      });
    }

    for (final config in [
      for (final accept in [false, true])
        for (final gzclFirst in [null, true, false])
          (accept: accept, gzclFirst: gzclFirst),
    ]) {
      final accept = config.accept;
      testWidgets('a skipped bench offers a deload; $config', (
        tester,
      ) async {
        final f = (await tester.runAsync(() async {
          final f = await fixture(failures: 1);
          if (config.gzclFirst != null) {
            await db.into(db.workoutItems).insert(
              WorkoutItemsCompanion.insert(
                workoutId: f.workout.id,
                exerciseId: f.bench.exerciseId,
                position: Value(config.gzclFirst! ? -1 : 2),
                gzclTier: const Value(GzclTier.t1),
                suggestedWeight: const Value(80),
              ),
            );
          }
          final today = DateTime.now();
          await history(
            f,
            today.subtract(const Duration(days: 20)),
            benchSets: 3,
          );
          await history(f, today.subtract(const Duration(days: 1)));
          return f;
        }))!;
        final l10n = l10nFor();
        await tester.pumpWidget(
          routedAppUnder(
            container,
            Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () =>
                    startWorkout(context, ref, f.workout.id, f.workout.name),
                child: const Text('Start test workout'),
              ),
            ),
            scaffold: true,
            alsoRoutes: ['session'],
          ),
        );
        try {
          await tester.tap(find.text('Start test workout'));
          await pumpThroughDatabase(tester);
          expect(find.text(l10n.startWorkoutLayoffTitle), findsOneWidget);
          expect(container.read(activeWorkoutProvider), isNull);
          final before = await tester.runAsync(
            () => db.workoutItemById(f.bench.id),
          );
          expect(
            before,
            f.bench,
            reason: 'offering must not apply a reduction',
          );
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
          expect(
            live.exercises.firstWhere((e) => e.itemId == f.bench.id)
                .sets.first.goalWeight,
            accept ? 72 : 80,
          );
          expect(
            live.exercises.firstWhere((e) => e.itemId == f.squat.id)
                .sets.first.goalWeight,
            100,
          );
          final after = await tester.runAsync(
            () => db.workoutItemById(f.bench.id),
          );
          expect(after!.failStreak, accept ? 0 : 1);
        } finally {
          await tester.runAsync(
            () => container.read(activeWorkoutProvider.notifier).discard(),
          );
          await stop(tester);
        }
      });
    }
  });
}
