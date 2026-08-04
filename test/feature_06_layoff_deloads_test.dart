// Feature 06 — Layoff deloads (features/index.html#sec06).
//
// Come back to a workout after a long enough break and the app offers a lighter
// start — measured per workout, never applied without asking. These tests drive
// that behaviour through its public surface: the pure rules in `layoff.dart`,
// the `AppDatabase.layoffFor` offer (deterministic via its `now` parameter), the
// `applyLayoffDeload` that moves the template and clears streaks, and the
// app-wide threshold settings.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  // A stable clock, so a slow CI box cannot roll a gap over a day boundary.
  final now = DateTime(2026, 6, 1, 12);

  setUp(() {
    db = memoryDb();
    container = containerFor(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // Logs a finished session of [workout] as having started [daysAgo] days back,
  // which is all `lastTrainedAt` reads.
  Future<void> trained(Workout workout, {required int daysAgo}) async {
    final started = now.subtract(Duration(days: daysAgo));
    await db.saveSession(
      routineId: workout.routineId,
      workoutId: workout.id,
      name: workout.name,
      startedAt: started,
      endedAt: started.add(const Duration(minutes: 40)),
      durationSeconds: 2400,
      totalVolume: 0,
      sets: const [],
    );
  }

  group('the pure rule: how long away is worth how deep a cut', () {
    test('a gap short of the threshold earns nothing', () {
      expect(
          layoffDeload(gapDays: 13, thresholdDays: 14, percentPerPeriod: 10),
          isNull);
    });

    test('a zero-day threshold switches the feature off', () {
      expect(
          layoffDeload(gapDays: 100, thresholdDays: 0, percentPerPeriod: 10),
          isNull);
    });

    test('a zero percent means there is nothing to cut', () {
      expect(
          layoffDeload(gapDays: 100, thresholdDays: 14, percentPerPeriod: 0),
          isNull);
    });

    test('one whole period away is one period at the per-period percent', () {
      final d =
          layoffDeload(gapDays: 14, thresholdDays: 14, percentPerPeriod: 10);
      expect(d, (gapDays: 14, periods: 1, percent: 10));
    });

    test('periods stack — two periods away is twice the cut', () {
      final d =
          layoffDeload(gapDays: 28, thresholdDays: 14, percentPerPeriod: 10);
      expect(d, (gapDays: 28, periods: 2, percent: 20));
    });

    test('the whole-period count ignores the remainder days', () {
      // 20 days over a 14-day threshold is one whole period, not one-and-a-bit.
      final d =
          layoffDeload(gapDays: 20, thresholdDays: 14, percentPerPeriod: 10);
      expect(d, (gapDays: 20, periods: 1, percent: 10));
    });

    test('periods stack only up to the cap', () {
      // 100 days is seven periods of arithmetic, capped at three.
      final d =
          layoffDeload(gapDays: 100, thresholdDays: 14, percentPerPeriod: 10);
      expect(d!.periods, kMaxLayoffPeriods);
      expect(d.percent, 30);
      expect(d.gapDays, 100); // the true gap is still reported
    });

    test('the cut itself is capped, whatever the settings say', () {
      // Three capped periods at 40% each is 120% of arithmetic, held at 90%.
      final d =
          layoffDeload(gapDays: 100, thresholdDays: 14, percentPerPeriod: 40);
      expect(d!.percent, kMaxLayoffCutPercent);
    });
  });

  group('the pure rule: where the cut lands', () {
    test('a weight cut lands on the half kilo and is rounded down', () {
      // 83 kg less 10% is 74.7, which lands on 74.5 — never rounded up to give
      // back part of the cut it just announced.
      expect(deloadedTarget(83, 10, ProgressionMode.weight), 74.5);
      // A clean 10% off 100 is exactly 90.
      expect(deloadedTarget(100, 10, ProgressionMode.weight), 90);
    });

    test('reps and time land on whole units, rounded down', () {
      expect(deloadedTarget(6, 10, ProgressionMode.reps), 5); // 5.4 -> 5
      expect(deloadedTarget(30, 10, ProgressionMode.time), 27);
    });

    test('a cut never drops a target below its mode floor', () {
      expect(deloadedTarget(1, 90, ProgressionMode.reps), 1);
      expect(deloadedTarget(5, 90, ProgressionMode.time), 5);
      // Weight may legitimately reach zero where there is no bar under it.
      expect(deloadedTarget(1, 90, ProgressionMode.weight), 0);
    });

    test('a cut never drops a bar-loaded target below its own bar', () {
      // 25 kg less half is 12.5, which is less than the empty bar it is on.
      expect(deloadedTarget(25, 50, ProgressionMode.weight, floorKg: 20), 20);
      // A cut that still clears the bar is untouched by the floor.
      expect(deloadedTarget(100, 10, ProgressionMode.weight, floorKg: 20), 90);
    });
  });

  group('the offer, measured per workout through the database', () {
    test('a workout that has never been trained has no gap to regress', () async {
      final push = await workoutNamed(db, 'Push');
      expect(await db.layoffFor(push.id, now: now), isNull);
    });

    test('a long enough gap offers a back-off', () async {
      final push = await workoutNamed(db, 'Push');
      await trained(push, daysAgo: 20); // default 14-day threshold
      final offer = await db.layoffFor(push.id, now: now);
      expect(offer, isNotNull);
      expect(offer!.periods, 1);
      expect(offer.percent, 10);
      expect(offer.gapDays, 20);
    });

    test('a recent session earns no offer', () async {
      final push = await workoutNamed(db, 'Push');
      await trained(push, daysAgo: 3);
      expect(await db.layoffFor(push.id, now: now), isNull);
    });

    test('it is per workout, not per routine', () async {
      // Push comes round every week; Legs has not been touched since spring.
      final push = await workoutNamed(db, 'Push');
      final legs = await workoutNamed(db, 'Legs');
      await trained(push, daysAgo: 2);
      await trained(legs, daysAgo: 40);

      expect(await db.layoffFor(push.id, now: now), isNull);
      final legsOffer = await db.layoffFor(legs.id, now: now);
      expect(legsOffer, isNotNull);
      expect(legsOffer!.periods, 2); // 40 / 14 -> 2 whole periods
      expect(legsOffer.percent, 20);
    });

    test('the offer only offers — it does not touch the template', () async {
      final push = await workoutNamed(db, 'Push');
      await trained(push, daysAgo: 40);
      final before =
          (await slotNamed(db, 'Push', 'Bench Press')).item.suggestedWeight;
      await db.layoffFor(push.id, now: now);
      final after =
          (await slotNamed(db, 'Push', 'Bench Press')).item.suggestedWeight;
      expect(after, before); // still 80 kg — nothing applied without asking
    });

    test('declining is nothing to record — training resets the gap by itself',
        () async {
      final push = await workoutNamed(db, 'Push');
      await trained(push, daysAgo: 40);
      expect(await db.layoffFor(push.id, now: now), isNotNull);

      // The user declines and simply trains today; nothing about the decline is
      // stored, and the fresh session alone clears the offer next time.
      await trained(push, daysAgo: 0);
      expect(await db.layoffFor(push.id, now: now), isNull);
    });
  });

  group('applying the deload moves the template and clears momentum', () {
    test('every loaded slot is cut and the count is reported', () async {
      final push = await workoutNamed(db, 'Push');
      final moved = await db.applyLayoffDeload(push.id, 10);
      // Push is five weighted slots; all five move.
      expect(moved, 5);
      final bench = await slotNamed(db, 'Push', 'Bench Press');
      expect(bench.item.suggestedWeight, 72); // 80 less 10%
    });

    test('a deload clears both progression streaks', () async {
      final id = await slotIdNamed(db, 'Push', 'Bench Press');
      // Put some momentum on the slot first: one miss leaves a fail streak.
      await db.advanceProgression(id, success: false);
      expect((await db.workoutItemById(id))!.failStreak, 1);

      final push = await workoutNamed(db, 'Push');
      await db.applyLayoffDeload(push.id, 10);

      final slot = await db.workoutItemById(id);
      expect(slot!.successStreak, 0);
      expect(slot.failStreak, 0);
    });

    test('a slot with no target to cut moves nothing', () async {
      // A weight-mode slot nobody put a number on — there is nothing to take a
      // percentage of, so the workout reports no movement.
      final ex = await exerciseNamed(db, 'Push-Up');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          progression: const Value(ProgressionMode.weight),
        ),
      ]);
      expect(await db.applyLayoffDeload(push.id, 10), 0);
    });

    test('a barbell slot is never cut below its own bar', () async {
      // A light bench: half off 25 kg is 12.5, which is less than the 20 kg bar
      // the movement is done on. The cut lands on the bar instead.
      final ex = await exerciseNamed(db, 'Bench Press');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          suggestedWeight: const Value(25),
          progression: const Value(ProgressionMode.weight),
        ),
      ]);
      final id = (await db.itemsForWorkout(push.id)).single.item.id;

      expect(await db.applyLayoffDeload(push.id, 50), 1);
      expect((await db.workoutItemById(id))!.suggestedWeight, 20);
      // Already on the bar, a second layoff has nothing left to take.
      expect(await db.applyLayoffDeload(push.id, 50), 0);
      expect((await db.workoutItemById(id))!.suggestedWeight, 20);
    });

    test('a reps slot is cut along its own axis, keeping the range width',
        () async {
      // Pull-Up is 6–10 reps, no weight; a layoff cuts the reps target.
      final id = await slotIdNamed(db, 'Pull', 'Pull-Up');
      final pull = await workoutNamed(db, 'Pull');
      await db.applyLayoffDeload(pull.id, 50); // 6 -> 3
      final slot = await db.workoutItemById(id);
      expect(slot!.repsMin, 3);
      expect(slot.repsMax, 7); // width of 4 kept
    });
  });

  group('the thresholds are app-wide', () {
    test('setting the days and percent changes what every offer uses',
        () async {
      await db.setLayoffDays(7);
      await db.setLayoffPercent(15);
      expect(await db.watchLayoffSettings().first, (days: 7, percent: 15));

      final push = await workoutNamed(db, 'Push');
      await trained(push, daysAgo: 14); // two of the new 7-day periods
      final offer = await db.layoffFor(push.id, now: now);
      expect(offer!.periods, 2);
      expect(offer.percent, 30); // 2 x 15
    });

    test('a zero-day threshold switches offers off everywhere', () async {
      await db.setLayoffDays(0);
      final push = await workoutNamed(db, 'Push');
      await trained(push, daysAgo: 90);
      expect(await db.layoffFor(push.id, now: now), isNull);
    });
  });

  // The back-off rules are read back to the user as a sentence, and a sentence
  // has to agree with its numbers — a threshold of one is the default for a
  // weight slot, so the singular is the common case, not the edge one.
  group('a back-off rule reads correctly at every threshold', () {
    final l10n = l10nFor();

    ItemDraft slot({int misses = 1, int cleans = 1}) => ItemDraft(
          exerciseId: 1,
          name: 'Bench Press',
          muscle: 'Chest',
          successThreshold: cleans,
          failureThreshold: misses,
        );

    test('one miss is one missed session, with nothing to be in a row with', () {
      final rule = progressionRule(l10n, slot(), 'kg');
      expect(rule, contains('after 1 missed session.'));
      expect(rule, isNot(contains('sessions')));
      expect(rule, isNot(contains('in a row')));
    });

    test('two or more misses are sessions, in a row', () {
      expect(progressionRule(l10n, slot(misses: 2), 'kg'),
          contains('after 2 missed sessions in a row.'));
      expect(progressionRule(l10n, slot(misses: 10), 'kg'),
          contains('after 10 missed sessions in a row.'));
    });

    test('the clean-session half agrees with its number too', () {
      expect(progressionRule(l10n, slot(cleans: 1), 'kg'),
          contains('after 1 clean session;'));
      expect(progressionRule(l10n, slot(cleans: 3), 'kg'),
          contains('after 3 clean sessions;'));
    });

    test('the amounts are named in the display unit', () {
      expect(progressionRule(l10n, slot(), 'kg'), startsWith('Add 2.5 kg'));
      // Two decimals: a 2.5 kg step is 5.51 lb, and rounding it to 5.5 would
      // be a weight the arithmetic never produced.
      expect(progressionRule(l10n, slot(), 'lb'), startsWith('Add 5.51 lb'));
    });
  });
}
