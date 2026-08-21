// Integration tests for estimated training-day duration (features/index.html#sec02).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/data/warmup.dart';
import 'package:foss_lift/data/workout_estimate.dart';
import 'package:foss_lift/screens/today_screen.dart';
import 'package:foss_lift/screens/workout_detail_screen.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

/// One counted slot, with everything the estimate reads spelled out.
WorkoutItemsCompanion _slot({
  required int workoutId,
  required int exerciseId,
  int sets = 3,
  int repsMin = 5,
  int? repsMax,
  int? rest,
  double? weight,
  int position = 0,
  bool joined = false,
}) =>
    WorkoutItemsCompanion.insert(
      workoutId: workoutId,
      exerciseId: exerciseId,
      position: Value(position),
      targetSets: Value(sets),
      repsMin: Value(repsMin),
      repsMax: Value(repsMax),
      restSeconds: Value(rest),
      suggestedWeight: Value(weight),
      supersetWithPrevious: Value(joined),
    );

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  group('the model', () {
    test('an empty day has no duration to estimate', () {
      expect(
        estimateWorkoutDuration(items: const [], routineRestSeconds: 90),
        Duration.zero,
      );
    });

    test('a single set is time under the bar and no rest at all', () async {
      final id = (await exerciseNamed(db, 'Bench Press')).id;
      final w = await workoutIdNamed(db, 'Push');
      await db.replaceWorkoutItems(w, [_slot(workoutId: w, exerciseId: id, sets: 1)]);
      final items = (await db.itemsForWorkout(w)).map((v) => v.item).toList();

      expect(
        estimateWorkoutDuration(items: items, routineRestSeconds: 90),
        Duration(seconds: setSeconds(reps: 5)),
      );
    });

    test('every set but the last is followed by its rest', () async {
      final id = (await exerciseNamed(db, 'Bench Press')).id;
      final w = await workoutIdNamed(db, 'Push');

      Future<Duration> withSets(int n) async {
        await db.replaceWorkoutItems(w, [_slot(workoutId: w, exerciseId: id, sets: n)]);
        final items = (await db.itemsForWorkout(w)).map((v) => v.item).toList();
        return estimateWorkoutDuration(items: items, routineRestSeconds: 90);
      }

      final one = await withSets(1);
      final three = await withSets(3);

      // Two more sets: two more efforts and exactly two more rests.
      expect(three - one, Duration(seconds: 2 * setSeconds(reps: 5) + 2 * 90));
    });

    test('a slot rests for its own override, not the routine default',
        () async {
      final id = (await exerciseNamed(db, 'Bench Press')).id;
      final w = await workoutIdNamed(db, 'Push');

      Future<Duration> withRest(int? rest) async {
        await db.replaceWorkoutItems(w, [
          _slot(workoutId: w, exerciseId: id, sets: 3, rest: rest),
        ]);
        final items = (await db.itemsForWorkout(w)).map((v) => v.item).toList();
        return estimateWorkoutDuration(items: items, routineRestSeconds: 60);
      }

      expect(
        (await withRest(180)) - (await withRest(null)),
        const Duration(seconds: 2 * (180 - 60)),
      );
    });

    test('more reps is more time under the bar', () async {
      final id = (await exerciseNamed(db, 'Bench Press')).id;
      final w = await workoutIdNamed(db, 'Push');

      Future<Duration> withReps(int min, int? max) async {
        await db.replaceWorkoutItems(w, [
          _slot(workoutId: w, exerciseId: id, sets: 1, repsMin: min, repsMax: max),
        ]);
        final items = (await db.itemsForWorkout(w)).map((v) => v.item).toList();
        return estimateWorkoutDuration(items: items, routineRestSeconds: 90);
      }

      // A range is planned at its top end, like the goal a live set is given.
      expect(await withReps(6, 8), await withReps(8, null));
      expect(
        (await withReps(10, null)) - (await withReps(5, null)),
        Duration(seconds: setSeconds(reps: 10) - setSeconds(reps: 5)),
      );
    });

    test('a held exercise is estimated by its hold, not by reps', () async {
      final plank = (await exerciseNamed(db, 'Plank')).id;
      final w = await workoutIdNamed(db, 'Push');

      Future<Duration> withHold(int seconds) async {
        await db.replaceWorkoutItems(w, [
          WorkoutItemsCompanion.insert(
            workoutId: w,
            exerciseId: plank,
            targetSets: const Value(1),
            progression: const Value(ProgressionMode.time),
            holdSeconds: Value(seconds),
          ),
        ]);
        final items = (await db.itemsForWorkout(w)).map((v) => v.item).toList();
        return estimateWorkoutDuration(items: items, routineRestSeconds: 90);
      }

      expect(await withHold(30), Duration(seconds: setSeconds(holdSeconds: 30)));
      expect(
        (await withHold(60)) - (await withHold(30)),
        const Duration(seconds: 30),
      );
    });

    test('a loaded slot pays for its warm-up rungs and their shorter rest',
        () async {
      final id = (await exerciseNamed(db, 'Bench Press')).id;
      final w = await workoutIdNamed(db, 'Push');

      Future<Duration> withWeight(double? kg) async {
        await db.replaceWorkoutItems(w, [
          _slot(workoutId: w, exerciseId: id, sets: 3, rest: 90, weight: kg),
        ]);
        final items = (await db.itemsForWorkout(w)).map((v) => v.item).toList();
        return estimateWorkoutDuration(items: items, routineRestSeconds: 90);
      }

      final ramped = await withWeight(80);
      final bare = await withWeight(null);
      final added = (ramped - bare).inSeconds;

      // The rungs rest the short warm-up rest between themselves, and the
      // exercise's own rest after the last one — the working set is next.
      const rests = (kDefaultWarmupSets - 1) * kWarmupRestSeconds + 90;
      expect(added, greaterThan(rests));
      // What is left is the rungs themselves: a handful of reps each.
      expect(added - rests, lessThan(kDefaultWarmupSets * setSeconds(reps: 10)));
    });

    test('the day is priced for the number of rungs Settings asks for',
        () async {
      // How many rungs a ramp opens with is a setting, so the figure on the
      // card has to count that many rather than the constant.
      final id = (await exerciseNamed(db, 'Bench Press')).id;
      final w = await workoutIdNamed(db, 'Push');
      await db.replaceWorkoutItems(w, [
        _slot(workoutId: w, exerciseId: id, sets: 3, rest: 90, weight: 80),
      ]);
      final items = (await db.itemsForWorkout(w)).map((v) => v.item).toList();

      Duration at(int sets) => estimateWorkoutDuration(
            items: items,
            routineRestSeconds: 90,
            warmupSets: sets,
          );

      expect(at(5), greaterThan(at(kDefaultWarmupSets)));
      expect(at(1), lessThan(at(kDefaultWarmupSets)));
      // The default is what an unasked estimate prices.
      expect(
        estimateWorkoutDuration(items: items, routineRestSeconds: 90),
        at(kDefaultWarmupSets),
      );

      // At nothing there is no ramp in the figure at all — the same day as one
      // with no load to warm up to.
      await db.replaceWorkoutItems(w, [
        _slot(workoutId: w, exerciseId: id, sets: 3, rest: 90),
      ]);
      final bare = (await db.itemsForWorkout(w)).map((v) => v.item).toList();
      expect(
        at(0),
        estimateWorkoutDuration(items: bare, routineRestSeconds: 90),
      );
    });

    test('a rung is counted for a loaded counted slot and nothing else',
        () async {
      final bench = (await exerciseNamed(db, 'Bench Press')).id;
      final plank = (await exerciseNamed(db, 'Plank')).id;
      final w = await workoutIdNamed(db, 'Push');

      Future<WorkoutItem> only(WorkoutItemsCompanion slot) async {
        await db.replaceWorkoutItems(w, [slot]);
        return (await db.itemsForWorkout(w)).single.item;
      }

      final loaded = await only(
        _slot(workoutId: w, exerciseId: bench, sets: 3, weight: 80),
      );
      expect(warmupRungsFor(loaded, sets: 5), 5);
      expect(warmupRungsFor(loaded, sets: 0), 0);
      expect(warmupRungsFor(loaded), kDefaultWarmupSets);

      // Nothing on the bar: there is no ramp to climb.
      final unloaded = await only(_slot(workoutId: w, exerciseId: bench));
      expect(warmupRungsFor(unloaded, sets: 5), 0);

      // A held exercise is not warmed up by holding it lighter.
      final held = await only(
        WorkoutItemsCompanion.insert(
          workoutId: w,
          exerciseId: plank,
          targetSets: const Value(2),
          progression: const Value(ProgressionMode.time),
          holdSeconds: const Value(45),
          suggestedWeight: const Value(10),
        ),
      );
      expect(warmupRungsFor(held, sets: 5), 0);
    });
  });

  group('a superset is priced as one rest per round', () {
    /// Two counted slots of [sets] sets each, nothing on the bar so no ramp gets
    /// in the way, with the second [joined] to the first or standing alone.
    Future<Duration> twoSlots({required bool joined, int sets = 3}) async {
      final bench = (await exerciseNamed(db, 'Bench Press')).id;
      final ohp = (await exerciseNamed(db, 'Overhead Press')).id;
      final w = await workoutIdNamed(db, 'Push');
      await db.replaceWorkoutItems(w, [
        _slot(workoutId: w, exerciseId: bench, sets: sets),
        _slot(
          workoutId: w,
          exerciseId: ohp,
          sets: sets,
          position: 1,
          joined: joined,
        ),
      ]);
      final items = (await db.itemsForWorkout(w)).map((v) => v.item).toList();
      return estimateWorkoutDuration(items: items, routineRestSeconds: 90);
    }

    test('joining two slots takes a rest off every round', () async {
      // Three rounds, so three rests fewer than the same two exercises done one
      // after the other.
      expect(
        (await twoSlots(joined: false)) - (await twoSlots(joined: true)),
        const Duration(seconds: 3 * 90),
      );
    });

    test('and what is left is the work back to back', () async {
      // Six 5-rep sets, resting once at the end of each of the three rounds and
      // not at all after the last one.
      expect(
        await twoSlots(joined: true),
        Duration(seconds: 6 * setSeconds(reps: 5) + 2 * 90),
      );
      // The same day unjoined rests after every set but the last.
      expect(
        await twoSlots(joined: false),
        Duration(seconds: 6 * setSeconds(reps: 5) + 5 * 90),
      );
    });
  });

  group('the figure on screen', () {
    test('rounds to five minutes, and never down to nothing', () {
      expect(estimateMinutes(const Duration(minutes: 47)), 45);
      expect(estimateMinutes(const Duration(minutes: 48)), 50);
      expect(estimateMinutes(const Duration(seconds: 30)), 5);
      expect(estimateMinutes(Duration.zero), 0);
    });

    /// The Push day's id and the estimate its template comes to, read on the
    /// real event loop — a drift future awaited in a widget test's own zone
    /// never completes.
    Future<(int, int)> pushAndMinutes(WidgetTester tester) async {
      late int w;
      late int minutes;
      await tester.runAsync(() async {
        w = await workoutIdNamed(db, 'Push');
        final routine = await routineNamed(db);
        final items = (await db.itemsForWorkout(w)).map((v) => v.item).toList();
        minutes = estimateMinutes(
          estimateWorkoutDuration(
            items: items,
            routineRestSeconds: routine.restSeconds,
          ),
        );
      });
      return (w, minutes);
    }

    testWidgets('a training day shows how long it will take', (tester) async {
      final (w, minutes) = await pushAndMinutes(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        appUnder(container, WorkoutDetailScreen(workoutId: w)),
      );
      // Not pumpAndSettle: the loading spinner animates for ever, so the tree
      // is never quiet while the template is on its way out of the database.
      await pumpThroughDatabase(tester);

      expect(minutes, greaterThan(0));
      expect(
        find.text(l10nFor().commonEstimatedMinutes(minutes)),
        findsOneWidget,
      );
    });

    testWidgets('a day with no exercises shows no estimate', (tester) async {
      late int w;
      await tester.runAsync(() async {
        w = await workoutIdNamed(db, 'Push');
        await db.replaceWorkoutItems(w, const []);
      });
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        appUnder(container, WorkoutDetailScreen(workoutId: w)),
      );
      await pumpThroughDatabase(tester);

      expect(find.textContaining('~'), findsNothing);
    });

    testWidgets('the Today card carries the same figure', (tester) async {
      final (_, minutes) = await pushAndMinutes(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        appUnder(container, const Scaffold(body: TodayScreen())),
      );
      await pumpThroughDatabase(tester);

      expect(
        find.textContaining(l10nFor().commonEstimatedMinutes(minutes)),
        findsWidgets,
      );
    });
  });
}
