// Integration tests for features/index.html#sec04 — what a running session does
// when the workout behind it is edited: `exercise-added-mid-session-joins-the-end`
// and `other-edits-wait-for-the-next-session`.
//
// The edit is made the way the workout editor makes it — the whole item list
// rewritten — while the session is live and its board is on screen. What is
// asserted is the session itself: the board is one reader of it, and the rule
// is about the session, not about a widget.
//
// Timer discipline is the harness's: a live session is never quiet, so plain
// `pump()`s, `pumpThroughDatabase` for work that goes through SQLite, and
// [stopAll] before the tree comes apart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/data/warmup.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

/// The seeded Push day, in template order.
const kPushNames = [
  'Bench Press',
  'Overhead Press',
  'Incline DB Press',
  'Lateral Raise',
  'Triceps Pushdown',
];

/// The movement wheeled in mid-session. A barbell lift, so it arrives with a
/// ramp — which is where "built from what the session started with" bites.
const kAdded = 'Back Squat';
const kAddedKg = 100.0;
const kAddedSets = 3;

void main() {
  late AppDatabase db;
  ProviderContainer? container;
  late int wid;

  setUp(() => db = memoryDb());
  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  ActiveWorkout session() => container!.read(activeWorkoutProvider)!;
  List<String> liveNames() => [for (final e in session().exercises) e.name];

  /// Puts the session down, then the tree.
  Future<void> stopAll(WidgetTester tester) async {
    container?.read(activeWorkoutProvider.notifier).discard();
    await stop(tester);
  }

  /// The Push day, started and on screen — a session somebody is in the middle
  /// of, which is the only kind this rule is about.
  Future<void> pumpPushScreen(WidgetTester tester) async {
    await tester.runAsync(() async {
      wid = await workoutIdNamed(db, 'Push');
      container = containerFor(db);
      await container!
          .read(activeWorkoutProvider.notifier)
          .start(workoutId: wid, name: 'Push');
    });
    await tester.pumpWidget(appUnder(container!, const WorkoutScreen()));
    await tester.pump();
  }

  /// Edits the workout the session is training, exactly as the workout editor
  /// does: read the slots, change the list, write the whole list back.
  ///
  /// [edit] receives the drafts in template order. Nothing here preserves item
  /// ids — the editor's save does not either, which is half of what makes this
  /// rule hard.
  Future<void> editWorkout(
    WidgetTester tester,
    void Function(List<ItemDraft> drafts) edit,
  ) async {
    await tester.runAsync(() async {
      final views = await db.itemsForWorkout(wid);
      final drafts = [for (final v in views) ItemDraft.fromView(v)];
      edit(drafts);
      await db.replaceWorkoutItems(wid, itemCompanions(drafts, workoutId: wid));
    });
    await pumpThroughDatabase(tester);
  }

  /// Appends [kAdded] to the drafts — the movement decided on halfway through.
  Future<ItemDraft> addedDraft() async {
    final ex = await exerciseNamed(db, kAdded);
    return ItemDraft.forExercise(ex)
      ..sets = kAddedSets
      ..repsMin = 5
      ..weightKg = kAddedKg;
  }

  group('An exercise added mid-session joins the end of the board', () {
    testWidgets('the session picks it up, at the tail', (tester) async {
      await pumpPushScreen(tester);
      expect(liveNames(), kPushNames);

      final extra = await tester.runAsync(addedDraft);
      await editWorkout(tester, (drafts) => drafts.add(extra!));

      expect(
        liveNames(),
        [...kPushNames, kAdded],
        reason: 'the movement joins the end rather than making you finish, '
            'edit and start again',
      );
      expect(session().exercises.last.sets.length, kAddedSets);
      expect(session().exercises.last.sets.first.goalWeight, kAddedKg);
      expect(session().exercises.last.sets.every((s) => !s.done), isTrue);

      await stopAll(tester);
    });

    testWidgets('and the board has a row for it', (tester) async {
      await pumpPushScreen(tester);
      final extra = await tester.runAsync(addedDraft);
      await editWorkout(tester, (drafts) => drafts.add(extra!));

      expect(liveNames().last, kAdded,
          reason: 'the session took the addition; the board can only show what '
              'the session has');
      await tester.scrollUntilVisible(
        find.text(kAdded),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(kAdded), findsOneWidget);

      await stopAll(tester);
    });

    testWidgets('its ramp is built from what the session started with, not '
        'from the settings as they are now', (tester) async {
      await pumpPushScreen(tester);
      final before = session();

      // The gym is re-described while the session runs: a different unit, a
      // rack with almost nothing on it, and a shallower ramp. None of it may
      // reach a session already under way — a ramp nobody is halfway up is the
      // only kind that appears.
      await tester.runAsync(() async {
        await db.setWeightUnit('lb');
        await db.setPlateInventory([(kg: 20.0, count: 2)], 'kg');
        await db.setDefaultWarmupSets(1);
      });
      final extra = await tester.runAsync(addedDraft);
      await editWorkout(tester, (drafts) => drafts.add(extra!));

      final added = session().exercises.last;
      expect(added.name, kAdded, reason: 'the session took the addition');
      expect(session().unit, before.unit, reason: 'the session froze its unit');
      expect(added.warmupCount, kDefaultWarmupSets,
          reason: 'the ramp is as deep as the ones beside it, not as deep as '
              'the setting says now');
      expect(
        added.warmupLadder,
        loadLadder(
          type: added.weightType,
          unit: before.unit,
          maxKg: added.workingKg!,
          barKg: added.warmupBarKg,
          inventory: before.plates,
        ),
        reason: "the ladder comes off the session's own rack",
      );
      expect(added.warmups, isNotEmpty);
      expect(added.warmups.every((w) => w.weight <= added.workingKg!), isTrue);

      await stopAll(tester);
    });

    testWidgets('the sets already logged are not re-filed under it',
        (tester) async {
      await pumpPushScreen(tester);
      final ctl = container!.read(activeWorkoutProvider.notifier);
      // Two sets on two different movements, logged in an order that is part of
      // the record: a set held by position would move under an insertion.
      ctl.cycleSet(2, 0); // Incline DB Press, first set
      ctl.cycleSet(0, 0); // Bench Press, first set
      final inclineOrder = session().exercises[2].sets[0].loggedOrder;
      final benchOrder = session().exercises[0].sets[0].loggedOrder;
      expect(session().doneSets, 2);

      final extra = await tester.runAsync(addedDraft);
      await editWorkout(tester, (drafts) => drafts.add(extra!));

      expect(liveNames(), [...kPushNames, kAdded]);
      expect(session().exercises[0].sets[0].done, isTrue);
      expect(session().exercises[2].sets[0].done, isTrue);
      expect(session().exercises[0].sets[0].loggedOrder, benchOrder);
      expect(session().exercises[2].sets[0].loggedOrder, inclineOrder);
      expect(session().doneSets, 2,
          reason: 'nothing was logged and nothing was lost');
      expect(session().exercises.last.sets.every((s) => !s.done), isTrue);

      await stopAll(tester);
    });

    testWidgets('an edit that removes one and adds another takes only the '
        'addition', (tester) async {
      await pumpPushScreen(tester);
      final extra = await tester.runAsync(addedDraft);
      await editWorkout(tester, (drafts) {
        drafts.removeAt(1); // Overhead Press, out
        drafts.add(extra!);
      });

      expect(
        liveNames(),
        [...kPushNames, kAdded],
        reason: 'the tail is taken; the removal waits for the next session',
      );

      await stopAll(tester);
    });
  });

  group('Every other edit to a running workout waits for the next session', () {
    testWidgets('removing an exercise leaves the running session alone',
        (tester) async {
      await pumpPushScreen(tester);
      await editWorkout(tester, (drafts) => drafts.removeAt(1));

      expect(liveNames(), kPushNames,
          reason: 'a snapshot that re-arranged itself mid-set would be worse '
              'than one that is honestly out of date');
      // And the template really did change — the session is ignoring it, not
      // reading an edit that never landed.
      final left = await tester.runAsync(() => db.itemsForWorkout(wid));
      expect(left!.length, kPushNames.length - 1);

      await stopAll(tester);
    });

    testWidgets('reordering leaves it alone', (tester) async {
      await pumpPushScreen(tester);
      await editWorkout(tester, (drafts) {
        final first = drafts.removeAt(0);
        drafts.add(first);
      });

      expect(liveNames(), kPushNames);
      final now = await tester.runAsync(() => db.itemsForWorkout(wid));
      expect([for (final v in now!) v.exercise.name].last, kPushNames.first);

      await stopAll(tester);
    });

    testWidgets("changing a slot's sets, target and rest leaves it alone",
        (tester) async {
      await pumpPushScreen(tester);
      final bench = session().exercises[0];
      final sets = bench.sets.length;
      final goal = bench.sets.first.goal;
      final rest = bench.restSeconds;

      await editWorkout(tester, (drafts) {
        drafts[0]
          ..sets = sets + 2
          ..repsMin = 3
          ..repsMax = 3
          ..restSeconds = rest + 60;
      });

      expect(session().exercises[0].sets.length, sets);
      expect(session().exercises[0].sets.first.goal, goal);
      expect(session().exercises[0].restSeconds, rest);
      expect(liveNames(), kPushNames);

      await stopAll(tester);
    });

    testWidgets('and renaming the movement does not rename it mid-session',
        (tester) async {
      // A seeded movement cannot be renamed at all, so the slot this asks
      // about is one of your own, added to the day before it was started.
      late int mine;
      await tester.runAsync(() async {
        wid = await workoutIdNamed(db, 'Push');
        mine = await db.createExercise(
          name: 'Landmine Press',
          muscle: 'Shoulders',
          equipment: 'Barbell',
        );
        final views = await db.itemsForWorkout(wid);
        final drafts = [
          for (final v in views) ItemDraft.fromView(v),
          ItemDraft.forExercise(await db.exerciseById(mine))..sets = 2,
        ];
        await db.replaceWorkoutItems(wid, itemCompanions(drafts, workoutId: wid));
        container = containerFor(db);
        await container!
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: wid, name: 'Push');
      });
      await tester.pumpWidget(appUnder(container!, const WorkoutScreen()));
      await tester.pump();
      expect(liveNames(), [...kPushNames, 'Landmine Press']);

      await tester.runAsync(() async {
        final ex = await db.exerciseById(mine);
        await db.updateCustomExercise(
          mine,
          name: 'Landmine Press (left)',
          muscle: ex.muscleGroup,
          equipment: ex.equipment,
          videoUrl: ex.videoUrl,
          measure: ex.measure,
          weightType: ex.weightType,
        );
      });
      await pumpThroughDatabase(tester);

      expect(liveNames(), [...kPushNames, 'Landmine Press']);

      await stopAll(tester);
    });
  });
}
