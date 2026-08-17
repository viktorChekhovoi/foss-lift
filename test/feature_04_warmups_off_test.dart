// Integration tests for features/index.html#sec04 — `a-workout-can-turn-its-own-ramps-off`:
// a switch in the workout builder that takes the warm-up ramps off one training
// day, stored on the workout so the day opens with none again next week.
//
// The last group belongs to section 02's `workout-carries-estimated-duration`,
// which now says a day with its ramps off is priced on its working sets alone.
// It lives here rather than in `feature_02_workout_duration_test.dart` because
// it needs the same not-yet-existing API the rest of this file does, and that
// file has to keep compiling.
//
// **This file does not compile against the code as it stands.** There is no
// `Workouts.warmupsEnabled` column and no way to write one, which is what
// makes it the red step for this feature: the names below are the API the
// implementation is expected to grow —
//
//   * `Workout.warmupsEnabled` — a boolean column on the workouts table,
//     defaulting to true, reached through `db.workoutById`;
//   * `db.setWorkoutWarmupsEnabled(workoutId, enabled)` — what the builder's
//     switch writes.
//
// Timer discipline is the harness's, as in the other section 04 files.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/data/warmup.dart';
import 'package:foss_lift/data/workout_estimate.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/workout_detail_screen.dart';
import 'package:foss_lift/screens/workout_edit_screen.dart';
import 'package:foss_lift/state/active_workout.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

void main() {
  late AppDatabase db;
  ProviderContainer? container;

  setUp(() => db = memoryDb());
  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  ActiveWorkout session() => container!.read(activeWorkoutProvider)!;

  /// Starts the [day] of the seeded program in a fresh container.
  Future<ActiveWorkoutController> startDay(String day) async {
    final wid = await workoutIdNamed(db, day);
    container = containerFor(db);
    final ctl = container!.read(activeWorkoutProvider.notifier);
    await ctl.start(workoutId: wid, name: day);
    return ctl;
  }

  /// Whether any movement on the board is carrying a ramp.
  bool anyRamp() => session().exercises.any((e) => e.warmups.isNotEmpty);

  group('A single workout can turn its warm-up ramps off', () {
    test('a day ships with them on', () async {
      final wid = await workoutIdNamed(db, 'Push');

      expect((await db.workoutById(wid)).warmupsEnabled, isTrue);

      await startDay('Push');
      expect(anyRamp(), isTrue, reason: 'the premise: this day has ramps');
    });

    test('switched off, the session opens with no ramps on any movement',
        () async {
      final wid = await workoutIdNamed(db, 'Push');
      await db.setWorkoutWarmupsEnabled(wid, false);

      await startDay('Push');

      expect(session().exercises.every((e) => e.warmups.isEmpty), isTrue);
      expect(session().exercises.every((e) => e.warmupCount == 0), isTrue);
      // Only the ramps: the day is otherwise the day.
      expect(session().exercises, hasLength(5));
      expect(session().exercises.first.sets, hasLength(4));
    });

    test('and it belongs to the day, so the others are left alone', () async {
      await db.setWorkoutWarmupsEnabled(await workoutIdNamed(db, 'Push'), false);

      await startDay('Legs');

      expect(anyRamp(), isTrue,
          reason: 'switching Push off leaves Legs alone');
    });

    test('it is stored on the workout, so next week opens with none again',
        () async {
      final wid = await workoutIdNamed(db, 'Push');
      await db.setWorkoutWarmupsEnabled(wid, false);

      final first = await startDay('Push');
      expect(anyRamp(), isFalse);
      await first.discard();
      container!.dispose();
      container = null;

      await startDay('Push');

      expect(anyRamp(), isFalse);
      expect((await db.workoutById(wid)).warmupsEnabled, isFalse);
    });

    test('the stepper on the board still builds one during the session',
        () async {
      await db.setWorkoutWarmupsEnabled(await workoutIdNamed(db, 'Push'), false);
      final ctl = await startDay('Push');

      ctl.setWarmupCount(0, 3);

      expect(session().exercises[0].warmups, isNotEmpty,
          reason: 'what you have already warmed up for is a decision about '
              'today');
    });

    test('the app-wide count at none does the same thing, and either being '
        'off is enough', () async {
      await db.setDefaultWarmupSets(0);
      await startDay('Push');
      expect(anyRamp(), isFalse);
      container!.dispose();
      container = null;

      // The switch off and the count at three: still no ramps.
      await db.setDefaultWarmupSets(kDefaultWarmupSets);
      await db.setWorkoutWarmupsEnabled(await workoutIdNamed(db, 'Push'), false);
      await startDay('Push');
      expect(anyRamp(), isFalse);
    });
  });

  group('A movement can carry a warm-up count of its own', () {
    /// The first movement of Push, pinned to [count] rungs.
    Future<Exercise> pin(int? count) async {
      final wid = await workoutIdNamed(db, 'Push');
      final first = (await db.itemsForWorkout(wid)).first.exercise;
      await db.setExerciseWarmupSets(first.id, count);
      return first;
    }

    test('its ramp opens at its own count, and the others at the app\'s',
        () async {
      await pin(5);
      await startDay('Push');

      expect(session().exercises[0].warmupCount, 5);
      expect(session().exercises[1].warmupCount, kDefaultWarmupSets);
    });

    test('none on a movement means no ramp on that movement alone', () async {
      await pin(0);
      await startDay('Push');

      expect(session().exercises[0].warmups, isEmpty);
      expect(session().exercises[1].warmups, isNotEmpty);
    });

    test('app-wide none still wins outright', () async {
      await pin(5);
      await db.setDefaultWarmupSets(0);
      await startDay('Push');

      expect(anyRamp(), isFalse,
          reason: 'a count on a movement is not an exemption from "off"');
    });

    test('a day with its ramps off wins too', () async {
      await pin(5);
      await db.setWorkoutWarmupsEnabled(await workoutIdNamed(db, 'Push'), false);
      await startDay('Push');

      expect(anyRamp(), isFalse);
    });

    test('the stepper on the board outranks it for today', () async {
      await pin(5);
      final ctl = await startDay('Push');

      ctl.setWarmupCount(0, 2);
      expect(session().exercises[0].warmupCount, 2);
      // And a template edit arriving mid-session does not undo that.
      await ctl.reconfigure(0);
      expect(session().exercises[0].warmupCount, 2);
    });

    test('the day\'s estimate prices what each movement will open with',
        () async {
      final wid = await workoutIdNamed(db, 'Push');
      final routine = await routineNamed(db);
      final items = (await db.itemsForWorkout(wid)).map((v) => v.item).toList();
      final first = await pin(6);

      final flat = estimateWorkoutDuration(
        items: items,
        routineRestSeconds: routine.restSeconds,
      );
      final withOwn = estimateWorkoutDuration(
        items: items,
        routineRestSeconds: routine.restSeconds,
        exerciseWarmupSets: {first.id: 6},
      );
      expect(withOwn, greaterThan(flat),
          reason: 'six rungs cost more than three');
    });
  });

  group('The switch is in the workout builder', () {
    testWidgets('and what it is set to is what the workout stores',
        (tester) async {
      late int wid;
      await tester.runAsync(() async {
        wid = await workoutIdNamed(db, 'Push');
      });
      container = containerFor(db);
      await tester.pumpWidget(
        routedAppUnder(container!, WorkoutEditScreen(workoutId: wid)),
      );
      await pumpThroughDatabase(tester);

      expect(find.byType(Switch), findsOneWidget,
          reason: 'a switch in the workout builder, on until you turn it off');
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await pumpThroughDatabase(tester);
      await tester.tap(find.text(l10nFor().workoutEditSave));
      await pumpThroughDatabase(tester);

      final stored =
          await tester.runAsync(() => db.workoutById(wid));
      expect(stored!.warmupsEnabled, isFalse);
    });
  });

  group('A day with its ramps off is priced on its working sets alone', () {
    // features/index.html#sec02, `workout-carries-estimated-duration`.
    testWidgets('the figure on the day drops to the one with no rungs in it',
        (tester) async {
      late int wid;
      late int withRamps;
      late int without;
      await tester.runAsync(() async {
        wid = await workoutIdNamed(db, 'Push');
        final routine = await routineNamed(db);
        final items = (await db.itemsForWorkout(wid)).map((v) => v.item).toList();
        withRamps = estimateMinutes(estimateWorkoutDuration(
          items: items,
          routineRestSeconds: routine.restSeconds,
        ));
        without = estimateMinutes(estimateWorkoutDuration(
          items: items,
          routineRestSeconds: routine.restSeconds,
          warmupSets: 0,
        ));
        await db.setWorkoutWarmupsEnabled(wid, false);
      });
      expect(without, lessThan(withRamps),
          reason: 'the premise: the rungs cost something');

      container = containerFor(db);
      await tester.pumpWidget(
        appUnder(container!, WorkoutDetailScreen(workoutId: wid)),
      );
      await pumpThroughDatabase(tester);

      expect(find.text(l10nFor().commonEstimatedMinutes(without)),
          findsOneWidget);
      expect(find.text(l10nFor().commonEstimatedMinutes(withRamps)),
          findsNothing);
    });
  });
}
