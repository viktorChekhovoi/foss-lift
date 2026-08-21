// Integration tests for edits made to a workout while its live session is running (features/index.html#sec04).

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

  /// Rewrites the routine behind the day being trained, changing only its
  /// default rest — the number every slot that names none of its own falls back
  /// on. Written the way the routine builder writes it.
  Future<void> editRoutineRest(WidgetTester tester, int seconds) async {
    await tester.runAsync(() async {
      final workout = await db.workoutById(wid);
      final routine = await db.routineById(workout.routineId);
      await db.updateRoutineMeta(
        routine.id,
        name: routine.name,
        color: routine.colorHex,
        restSeconds: seconds,
        scheduleDays: routine.scheduleDays,
        reminderMinutes: routine.reminderMinutes,
        seedKey: routine.seedKey,
        description: routine.description,
      );
    });
    await pumpThroughDatabase(tester);
  }

  /// The rest each exercise on the board would start, in board order.
  List<int> liveRests() => [for (final e in session().exercises) e.restSeconds];

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

    testWidgets("changing a slot's sets and target leaves it alone",
        (tester) async {
      // Rest is the exception, and has a group of its own below.
      await pumpPushScreen(tester);
      final bench = session().exercises[0];
      final sets = bench.sets.length;
      final goal = bench.sets.first.goal;

      await editWorkout(tester, (drafts) {
        drafts[0]
          ..sets = sets + 2
          ..repsMin = 3
          ..repsMax = 3;
      });

      expect(session().exercises[0].sets.length, sets);
      expect(session().exercises[0].sets.first.goal, goal);
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
          muscles: MuscleMap.single('Shoulders'),
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
          muscles: ex.muscles,
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

  group('A rest time changed mid-workout reaches the session', () {
    // Rest is the one edit a running session takes besides an addition, and it
    // can be because it names no row: there is nothing for it to re-file.

    /// Logs Bench's ramp out of the way so the next thing logged is a working
    /// set, and the rest it starts is the exercise's own rather than the short
    /// warm-up one.
    void clearBenchRamp(ActiveWorkoutController ctl) {
      for (var i = 0; i < session().exercises[0].warmups.length; i++) {
        ctl.logNextAtGoal();
        ctl.stopRest(tone: false);
      }
    }

    testWidgets("a slot's own rest is taken by the movement it belongs to",
        (tester) async {
      await pumpPushScreen(tester);
      // The seeded day names no rest of its own, so every slot rests the
      // routine's 120.
      expect(liveRests(), everyElement(120));

      await editWorkout(tester, (drafts) => drafts[0].restSeconds = 200);

      expect(liveRests(), [200, 120, 120, 120, 120],
          reason: 'the next rest on Bench is the one just asked for');

      await stopAll(tester);
    });

    testWidgets("the routine's default reaches a slot that names none of its "
        'own', (tester) async {
      await pumpPushScreen(tester);
      // One slot with a rest of its own; the other four fall back.
      await editWorkout(tester, (drafts) => drafts[1].restSeconds = 200);

      await editRoutineRest(tester, 240);

      expect(liveRests(), [240, 200, 240, 240, 240],
          reason: 'a slot with its own rest keeps it; the rest take the '
              "routine's new default");

      await stopAll(tester);
    });

    testWidgets('a rest already counting down keeps the length it started at',
        (tester) async {
      await pumpPushScreen(tester);
      final ctl = container!.read(activeWorkoutProvider.notifier);
      clearBenchRamp(ctl);
      ctl.logNextAtGoal(); // Bench, first working set → the 120 s rest
      expect(session().restLeft, 120, reason: 'the premise: a rest is running');

      await editWorkout(tester, (drafts) => drafts[0].restSeconds = 200);

      expect(session().restLeft, lessThanOrEqualTo(120),
          reason: 'a clock that grew while you watched it is worse than one '
              'that ends and lets the next rest be the longer one');
      expect(session().restLeft, greaterThan(0),
          reason: 'and it is still running');

      // The next rest started is the one that was asked for.
      ctl.stopRest(tone: false);
      ctl.logNextAtGoal();
      expect(session().restLeft, 200);

      await stopAll(tester);
    });

    testWidgets('and nothing already logged moves with it', (tester) async {
      await pumpPushScreen(tester);
      final ctl = container!.read(activeWorkoutProvider.notifier);
      ctl.cycleSet(0, 0);
      ctl.cycleSet(1, 0);
      final order = session().exercises[1].sets[0].loggedOrder;
      final counts = [for (final e in session().exercises) e.sets.length];
      final goals = [for (final e in session().exercises) e.sets.first.goal];

      await editWorkout(tester, (drafts) {
        for (final d in drafts) {
          d.restSeconds = 200;
        }
      });

      expect(liveRests(), everyElement(200));
      expect(liveNames(), kPushNames);
      expect([for (final e in session().exercises) e.sets.length], counts);
      expect([for (final e in session().exercises) e.sets.first.goal], goals);
      expect(session().exercises[0].sets[0].logged, isNotNull);
      expect(session().exercises[1].sets[0].logged, isNotNull);
      expect(session().exercises[1].sets[0].loggedOrder, order);
      expect(session().doneSets, 2);

      await stopAll(tester);
    });

    testWidgets('a day reordered and re-timed in one save hands its rests out '
        'in board order', (tester) async {
      await pumpPushScreen(tester);

      await editWorkout(tester, (drafts) {
        // Bench moved to the end and every slot given a rest of its own, in
        // one save — the case where matching by position would hand the wrong
        // movement the wrong number.
        drafts.add(drafts.removeAt(0));
        for (var i = 0; i < drafts.length; i++) {
          drafts[i].restSeconds = 100 + i * 10;
        }
      });

      expect(liveNames(), kPushNames, reason: 'the reorder itself waits');
      expect(liveRests(), [140, 100, 110, 120, 130],
          reason: 'slots are matched to the board by movement, not by position');

      await stopAll(tester);
    });
  });
}
