// Feature 22 — Cycles and training maxes (features/index.html#sec22).
//
// A slot can rotate through a fixed set of weeks, each a written-out set of
// rows, and move the weight those rows are percentages of when the cycle comes
// round. These tests drive it through its real surfaces: the row grammar and
// the block encoding in `set_scheme.dart`, the wrap rule in `progression.dart`,
// the stored slot through `AppDatabase.advanceProgression`, the live board's
// hydration, the routine code, and the builder's switch.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/data/routine_code.dart';
import 'package:foss_lift/data/routine_import.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/exercise_settings_screen.dart';
import 'package:foss_lift/screens/workout_detail_screen.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/util/target_label.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'support/harness.dart';
import 'support/seeded.dart';
import 'support/settle.dart';

/// The 5/3/1 main-lift cycle, written out: three weeks of three sets, the last
/// of each open-ended. The shape every test below leans on.
const List<List<CustomSet>> k531 = [
  [
    CustomSet(reps: 5, percent: 65),
    CustomSet(reps: 5, percent: 75),
    CustomSet(reps: 5, percent: 85, amrap: true),
  ],
  [
    CustomSet(reps: 3, percent: 70),
    CustomSet(reps: 3, percent: 80),
    CustomSet(reps: 3, percent: 90, amrap: true),
  ],
  [
    CustomSet(reps: 5, percent: 75),
    CustomSet(reps: 3, percent: 85),
    CustomSet(reps: 1, percent: 95, amrap: true),
  ],
];

/// A Push day reduced to one bench slot on [k531], hydrated into a live session
/// at week [position], and the controller running it.
///
/// A top-level function rather than a closure inside the group: the container
/// is a parameter, so nothing about which session is being driven depends on
/// when the closure was created.
Future<ActiveWorkoutController> startCycle(
  AppDatabase db,
  ProviderContainer container, {
  required int position,
}) async {
  final ex = await exerciseNamed(db, 'Bench Press');
  final push = await workoutNamed(db, 'Push');
  await db.replaceWorkoutItems(push.id, [
    WorkoutItemsCompanion.insert(
      workoutId: push.id,
      exerciseId: ex.id,
      targetSets: const Value(3),
      repsMin: const Value(5),
      suggestedWeight: const Value(100),
      scheme: const Value(SetScheme.cycle),
      cycleBlocks: Value(encodeCycleBlocks(k531)),
      cyclePosition: Value(position),
    ),
  ]);
  final ctrl = container.read(activeWorkoutProvider.notifier);
  await ctrl.start(workoutId: push.id, name: 'Push');
  return ctrl;
}

void main() {
  // The live-session controller registers itself as a binding observer when
  // there is a binding, and this file mounts a screen as well as driving the
  // controller directly. Initialising once up front keeps every test in it on
  // the same footing — see feature_04, which does the same for the same reason.
  TestWidgetsFlutterBinding.ensureInitialized();

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

  // ---------------------------------------------------------------- the rows

  group('a written-out row takes a count, a range, or a minimum with no top', () {
    test('a plain count is its own goal and its own floor', () {
      const row = CustomSet(reps: 5, percent: 100);
      expect(row.goalReps, 5);
      expect(row.minReps, 5);
      expect(row.amrap, isFalse);
    });

    test('a range asks for its top and is not missed inside itself', () {
      const row = CustomSet(reps: 8, repsMax: 12, percent: 80);
      expect(row.goalReps, 12, reason: 'the top is what it asks for');
      expect(row.minReps, 8, reason: 'and the bottom is the only miss');
    });

    test('a row with no top asks for its minimum', () {
      const row = CustomSet(reps: 5, percent: 85, amrap: true);
      expect(row.goalReps, 5);
      expect(row.minReps, 5);
    });

    test('the three shapes round-trip through the column', () {
      const rows = [
        CustomSet(reps: 5, percent: 65),
        CustomSet(reps: 8, repsMax: 12, percent: 80),
        CustomSet(reps: 5, percent: 85, amrap: true),
      ];
      expect(decodeCustomSets(encodeCustomSets(rows)), rows);
    });

    test('a column written before rows could hold a range still reads', () {
      expect(decodeCustomSets('5:100,8:90'), const [
        CustomSet(reps: 5, percent: 100),
        CustomSet(reps: 8, percent: 90),
      ]);
    });

    test('a column that will not parse reads as no rows rather than throwing', () {
      expect(decodeCustomSets('nonsense'), isEmpty);
      expect(decodeCustomSets('5:'), isEmpty);
      expect(decodeCustomSets(null), isEmpty);
    });
  });

  // -------------------------------------------------------------- the blocks

  group('a cycle is several weeks of those rows', () {
    test('the weeks round-trip through one column', () {
      expect(decodeCycleBlocks(encodeCycleBlocks(k531)), k531);
    });

    test('an empty cycle is null in the column, not an empty string', () {
      expect(encodeCycleBlocks(const []), isNull);
      expect(decodeCycleBlocks(null), isEmpty);
    });

    test('the week after the last is the first again', () {
      expect(cycleBlockAt(k531, 0), k531[0]);
      expect(cycleBlockAt(k531, 2), k531[2]);
      expect(cycleBlockAt(k531, 3), k531[0], reason: 'it wraps');
      expect(cycleBlockAt(k531, 7), k531[1]);
    });

    test('a position past the end of a shortened cycle is held inside it', () {
      // The rule the builder relies on: editing three weeks down to two must
      // not leave a slot pointing at a week that is gone.
      expect(cycleBlockAt(const [], 2), isEmpty);
    });
  });

  group('a cycle resolves to the week it is on', () {
    List<SetTarget> at(int position) => resolveSetTargets(
          scheme: SetScheme.cycle,
          sets: 3,
          goalReps: 5,
          topWeightKg: 100,
          unit: 'kg',
          cycle: k531,
          cyclePosition: position,
        );

    test('week one is 5/5/5 at 65, 75 and 85 per cent', () {
      expect(at(0).map((t) => t.weightKg).toList(), [65.0, 75.0, 85.0]);
      expect(at(0).map((t) => t.reps).toList(), [5, 5, 5]);
    });

    test('week two is 3/3/3 at 70, 80 and 90 per cent', () {
      expect(at(1).map((t) => t.weightKg).toList(), [70.0, 80.0, 90.0]);
      expect(at(1).map((t) => t.reps).toList(), [3, 3, 3]);
    });

    test('week three is 5/3/1', () {
      expect(at(2).map((t) => t.reps).toList(), [5, 3, 1]);
      expect(at(2).map((t) => t.weightKg).toList(), [75.0, 85.0, 95.0]);
    });

    test('a row with no top carries its floor and its openness', () {
      final last = at(0).last;
      expect(last.reps, 5);
      expect(last.minReps, 5);
      expect(last.amrap, isTrue);
    });

    test('a range row asks for its top and floors at its bottom', () {
      final targets = resolveSetTargets(
        scheme: SetScheme.custom,
        sets: 1,
        goalReps: 5,
        topWeightKg: 100,
        unit: 'kg',
        custom: const [CustomSet(reps: 8, repsMax: 12, percent: 50)],
      );
      expect(targets.single.reps, 12);
      expect(targets.single.minReps, 8);
    });

    test("a cycle's weights keep their percentage and hold at the bar", () {
      final targets = resolveSetTargets(
        scheme: SetScheme.cycle,
        sets: 3,
        goalReps: 5,
        topWeightKg: 102.5,
        unit: 'kg',
        floorKg: 20,
        cycle: const [
          [
            CustomSet(reps: 5, percent: 65),
            CustomSet(reps: 5, percent: 10),
          ],
        ],
      );
      // 65% of 102.5 is 66.625, and the eighth of a kilogram the fine grid
      // reaches holds it there rather than rounding the week to 67.5.
      expect(targets[0].weightKg, closeTo(66.625, 1e-9));
      // 10% of 102.5 is under the empty bar.
      expect(targets[1].weightKg, 20.0);
    });

    test('a cycle with no weeks in it trains flat rather than as nothing', () {
      final targets = resolveSetTargets(
        scheme: SetScheme.cycle,
        sets: 2,
        goalReps: 8,
        topWeightKg: 100,
        unit: 'kg',
      );
      expect(targets.map((t) => t.reps).toList(), [8, 8]);
      expect(targets.map((t) => t.weightKg).toList(), [100.0, 100.0]);
    });
  });

  // ---------------------------------------------------------------- the wrap

  group('the wrap is what moves the weight', () {
    CycleStep step({
      required SessionVerdict verdict,
      required int position,
      int misses = 0,
      int weeks = 3,
      int failureThreshold = defaultFailureThreshold,
    }) =>
        stepCycle(
          verdict: verdict,
          position: position,
          misses: misses,
          weeks: weeks,
          failureThreshold: failureThreshold,
          increment: 2.5,
          deload: 5,
        );

    test('a session inside the cycle moves the week and nothing else', () {
      final s = step(verdict: SessionVerdict.success, position: 0);
      expect(s.position, 1);
      expect(s.delta, 0, reason: 'the percentages take care of the weeks');
    });

    test('a clean cycle steps the weight up as it comes round', () {
      final s = step(verdict: SessionVerdict.success, position: 2);
      expect(s.position, 0);
      expect(s.delta, 2.5);
      expect(s.misses, 0);
    });

    test('a miss inside the cycle is remembered until the wrap', () {
      final s = step(verdict: SessionVerdict.miss, position: 0);
      expect(s.misses, 1);
      expect(s.delta, 0, reason: 'the weight does not move mid-cycle');
    });

    test('one miss in a cycle holds the weight rather than backing it off', () {
      final s = step(verdict: SessionVerdict.success, position: 2, misses: 1);
      expect(s.delta, 0);
      expect(s.misses, 0, reason: 'the new cycle starts clean');
    });

    test('misses reaching the threshold back the weight off at the wrap', () {
      final s = step(verdict: SessionVerdict.miss, position: 2, misses: 1);
      expect(s.delta, -5);
      expect(s.misses, 0);
    });

    test('a cycle of one week wraps on every session', () {
      final s = step(verdict: SessionVerdict.success, position: 0, weeks: 1);
      expect(s.position, 0);
      expect(s.delta, 2.5);
    });

    test('a cycle with no weeks does not divide by nothing', () {
      final s = step(verdict: SessionVerdict.success, position: 0, weeks: 0);
      expect(s.position, 0);
      expect(s.delta, 0);
    });
  });

  // ------------------------------------------------------------ on a slot

  group('a stored cycle slot advances week by week', () {
    /// A bench slot running [k531] off a 100 kg training max.
    Future<WorkoutItem> cycleSlot({double tm = 100, int position = 0}) async {
      final ex = await exerciseNamed(db, 'Bench Press');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          targetSets: const Value(3),
          repsMin: const Value(5),
          suggestedWeight: Value(tm),
          scheme: const Value(SetScheme.cycle),
          cycleBlocks: Value(encodeCycleBlocks(k531)),
          cyclePosition: Value(position),
          increment: const Value(2.5),
          deload: const Value(5),
          progression: const Value(ProgressionMode.weight),
        ),
      ]);
      return (await db.itemsForWorkout(push.id)).single.item;
    }

    Future<WorkoutItem> finish(
      WorkoutItem it, {
      required SessionVerdict verdict,
      double? performedWeight,
    }) async {
      await db.advanceProgression(
        it.id,
        verdict: verdict,
        performedWeight: performedWeight,
      );
      return (await db.workoutItemById(it.id))!;
    }

    test('three clean sessions walk the weeks and then add the step', () async {
      var it = await cycleSlot();
      expect(it.cyclePosition, 0);

      it = await finish(it, verdict: SessionVerdict.success);
      expect(it.cyclePosition, 1);
      expect(it.suggestedWeight, 100, reason: 'week two, same training max');

      it = await finish(it, verdict: SessionVerdict.success);
      expect(it.cyclePosition, 2);
      expect(it.suggestedWeight, 100);

      it = await finish(it, verdict: SessionVerdict.success);
      expect(it.cyclePosition, 0, reason: 'back to week one');
      expect(it.suggestedWeight, 102.5, reason: 'and the training max moved');
    });

    test('the move is reported on the weight axis, at the wrap only', () async {
      final it = await cycleSlot(position: 2);
      final move = await db.advanceProgression(
        it.id,
        verdict: SessionVerdict.success,
      );
      expect(move.axis, ProgressionMode.weight);
      expect(move.moved, 2.5);

      final mid = await cycleSlot(position: 0);
      final none = await db.advanceProgression(
        mid.id,
        verdict: SessionVerdict.success,
      );
      expect(none.moved, 0, reason: 'nothing moved in week one');
    });

    test('a cycle with misses in it backs the training max off', () async {
      var it = await cycleSlot(position: 0);
      it = await finish(it, verdict: SessionVerdict.miss);
      it = await finish(it, verdict: SessionVerdict.miss);
      it = await finish(it, verdict: SessionVerdict.success);
      expect(it.cyclePosition, 0);
      expect(it.suggestedWeight, 95, reason: 'two misses reached the threshold');
    });

    test('loading the bar past the prescription does not move the max', () async {
      // The whole point: every set is a percentage of this number, so a heavy
      // week must not be read as the number having gone up.
      var it = await cycleSlot();
      it = await finish(
        it,
        verdict: SessionVerdict.success,
        performedWeight: 140,
      );
      expect(it.suggestedWeight, 100);
    });

    test('the streaks are not what a cycle counts with', () async {
      // A clean week must not fire the ordinary one-session step up.
      final it = await cycleSlot();
      final after = await finish(it, verdict: SessionVerdict.success);
      expect(after.suggestedWeight, 100);
    });
  });

  // ----------------------------------------------------------- the live board

  group('the board hydrates the week the slot is on', () {
    test('week two opens on 3/3/3 at 70, 80 and 90', () async {
      final ctrl = await startCycle(db, container, position: 1);
      final e = container.read(activeWorkoutProvider)!.exercises.single;
      expect(e.sets.map((x) => x.weight).toList(), [70.0, 80.0, 90.0]);
      expect(e.sets.map((x) => x.goal).toList(), [3, 3, 3]);
      ctrl.discard();
    });

    test('the entry knows which week of how many it is', () async {
      final ctrl = await startCycle(db, container, position: 1);
      final e = container.read(activeWorkoutProvider)!.exercises.single;
      expect(e.cycleWeek, 2);
      expect(e.cycleWeeks, 3);
      ctrl.discard();
    });

    test('an open-ended set is not missed by beating its minimum', () async {
      final ctrl = await startCycle(db, container, position: 0);
      final open = container.read(activeWorkoutProvider)!.exercises.single.sets.last;
      expect(open.amrap, isTrue);
      open.logged = 9;
      expect(open.missedGoal, isFalse, reason: '9 beats the 5 it asked for');
      ctrl.discard();
    });

    test('an open-ended set is missed under its minimum', () async {
      final ctrl = await startCycle(db, container, position: 0);
      final open = container.read(activeWorkoutProvider)!.exercises.single.sets.last;
      open.logged = 3;
      expect(open.missedGoal, isTrue);
      ctrl.discard();
    });

    test('the training max moves the whole week at once', () async {
      final ctrl = await startCycle(db, container, position: 0);
      final e = container.read(activeWorkoutProvider)!.exercises.single;
      ctrl.setWorkingWeight(0, 200);
      expect(
        e.sets.map((x) => x.weight).toList(),
        [130.0, 150.0, 170.0],
        reason: 'the percentages are of the new max',
      );
      ctrl.discard();
    });
  });

  group('a range row is judged against its own floor', () {
    test('a set inside its range is not a miss', () {
      final e = SetEntry(goal: 12, goalMin: 8, weight: 60)..logged = 9;
      expect(e.missedGoal, isFalse);
    });

    test('a set under the bottom of its range is', () {
      final e = SetEntry(goal: 12, goalMin: 8, weight: 60)..logged = 7;
      expect(e.missedGoal, isTrue);
    });

    test('a plain set is still its own floor', () {
      final e = SetEntry(goal: 8, weight: 60)..logged = 7;
      expect(e.missedGoal, isTrue);
    });
  });

  // ------------------------------------------------------- the number of sets

  group('a cycle week says how many sets there are', () {
    test("the week's rows are the set count, not the stored one", () async {
      final ex = await exerciseNamed(db, 'Bench Press');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          targetSets: const Value(3),
          repsMin: const Value(5),
          suggestedWeight: const Value(100),
          scheme: const Value(SetScheme.cycle),
          cycleBlocks: Value(encodeCycleBlocks(const [
            [
              CustomSet(reps: 5, percent: 65),
              CustomSet(reps: 5, percent: 75),
              CustomSet(reps: 5, percent: 85, amrap: true),
              CustomSet(reps: 5, percent: 65),
              CustomSet(reps: 5, percent: 65),
            ],
          ])),
        ),
      ]);
      final it = (await db.itemsForWorkout(push.id)).single.item;
      expect(it.setCount, 5, reason: 'the week has five rows in it');

      await container.read(activeWorkoutProvider.notifier).start(workoutId: push.id, name: 'Push');
      expect(container.read(activeWorkoutProvider)!.exercises.single.sets, hasLength(5));
      container.read(activeWorkoutProvider.notifier).discard();
    });

    test('a slot with no cycle keeps its stored set count', () async {
      final ex = await exerciseNamed(db, 'Bench Press');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          targetSets: const Value(4),
        ),
      ]);
      expect((await db.itemsForWorkout(push.id)).single.item.setCount, 4);
    });
  });

  // ------------------------------------------------------- advanced settings

  group('advanced programming is off until asked for', () {
    test('a fresh install has it off', () async {
      expect(await db.watchAdvancedProgramming().first, isFalse);
    });

    test('the setting is stored and read back', () async {
      await db.setAdvancedProgramming(true);
      expect(await db.watchAdvancedProgramming().first, isTrue);
      await db.setAdvancedProgramming(false);
      expect(await db.watchAdvancedProgramming().first, isFalse);
    });

    test('turning it on does not disturb the rest of the settings row', () async {
      await db.setWeightUnit('lb');
      await db.setAdvancedProgramming(true);
      expect(await db.watchWeightUnit().first, 'lb');
    });

    testWidgets('the switch is on the training settings screen, and it writes',
        (tester) async {
      // Tall enough for the whole settings list: a ListView does not build
      // what is below the fold, and the switch sits under the plate rows.
      tester.view.physicalSize = const Size(390, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        routedAppUnder(container, const ExerciseSettingsScreen(), scaffold: true),
      );
      // Plain pumps rather than a settle: the screen's values come off drift
      // streams, so the tree is never quiet of its own accord.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(kAdvancedProgrammingKey), findsOneWidget);

      await tester.tap(find.byKey(kAdvancedProgrammingKey));
      // Read back through the provider rather than the stream: awaiting a
      // drift future under the widget binding's clock never returns.
      await pumpUntil(
        tester,
        () => container.read(advancedProgrammingProvider).value ?? false,
      );
      expect(container.read(advancedProgrammingProvider).value, isTrue);
      await stop(tester);
    });
  });

  group('the builder offers a cycle only where it should', () {
    test('the scheme picker hides Cycle with the switch off', () {
      expect(
        schemesOffered(advanced: false, draftUsesCycle: false),
        isNot(contains(SetScheme.cycle)),
      );
    });

    test('and offers it with the switch on', () {
      expect(
        schemesOffered(advanced: true, draftUsesCycle: false),
        contains(SetScheme.cycle),
      );
    });

    test('a slot already running one shows it whatever the switch says', () {
      expect(
        schemesOffered(advanced: false, draftUsesCycle: true),
        contains(SetScheme.cycle),
      );
    });
  });

  // ------------------------------------------------------------ round-tripping

  group('a cycle survives the builder and the database', () {
    test('a draft carries its weeks and its position through a save', () async {
      final ex = await exerciseNamed(db, 'Bench Press');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          suggestedWeight: const Value(100),
          scheme: const Value(SetScheme.cycle),
          cycleBlocks: Value(encodeCycleBlocks(k531)),
          cyclePosition: const Value(2),
        ),
      ]);
      final drafts = (await db.itemsForWorkout(push.id))
          .map(ItemDraft.fromView)
          .toList();
      expect(drafts.single.cycle, k531);
      expect(drafts.single.cyclePosition, 2);

      // Edit a week and save: the position must survive, because fixing a typo
      // in week three cannot cost the two weeks already trained.
      drafts.single.cycle = [
        ...k531.take(2),
        const [CustomSet(reps: 5, percent: 80)],
      ];
      await db.replaceWorkoutItems(
        push.id,
        itemCompanions(drafts, workoutId: push.id),
      );
      final back = (await db.itemsForWorkout(push.id)).single.item;
      expect(back.cyclePosition, 2);
      expect(back.cycleWeeks.last, const [CustomSet(reps: 5, percent: 80)]);
    });
  });

  group('a cycle travels in a routine code', () {
    test('the weeks arrive, and the position does not', () async {
      final ex = await exerciseNamed(db, 'Bench Press');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          scheme: const Value(SetScheme.cycle),
          cycleBlocks: Value(encodeCycleBlocks(k531)),
          cyclePosition: const Value(2),
        ),
      ]);
      final routine = await routineNamed(db);
      final code = RoutineCode.encode(await db.sharedRoutine(routine.id));
      final back = (RoutineCode.decode(code) as RoutineCodeOk).routine;
      final slot = back.workouts
          .firstWhere((w) => w.name == 'Push')
          .items
          .single;
      expect(slot.scheme, SetScheme.cycle);
      expect(slot.cycle, k531);
    });

    test('a routine with no cycle in it costs no bytes', () async {
      final routine = await routineNamed(db);
      final shared = await db.sharedRoutine(routine.id);
      final back =
          (RoutineCode.decode(RoutineCode.encode(shared)) as RoutineCodeOk).routine;
      expect(back.workouts.first.items.first.cycle, isEmpty);
    });
  });

  // ----------------------------------------------------------- the programs

  group('the library ships four 5/3/1 programs', () {
    List<StarterRoutine> the531() =>
        kStarterRoutines.where((r) => r.key.startsWith('531-')).toList();

    test('there are four of them', () {
      expect(the531(), hasLength(4));
    });

    test('every one of them has a main lift on a cycle', () {
      for (final program in the531()) {
        expect(
          program.days.expand((d) => d.items).any((s) => s.cycle.isNotEmpty),
          isTrue,
          reason: '${program.name} has no cycle in it',
        );
      }
    });

    test('every movement they name is in the starter library', () async {
      final library = (await db.watchExercises().first).map((e) => e.name).toSet();
      for (final program in the531()) {
        for (final day in program.days) {
          for (final slot in day.items) {
            expect(library, contains(slot.exercise),
                reason: '${program.name} names ${slot.exercise}');
          }
        }
      }
    });

    test('adding one writes its cycles onto the slots', () async {
      final program = the531().firstWhere((r) => r.key == '531-bbb');
      await db.addStarterRoutine(program);
      final routine = (await db.watchRoutines().first)
          .firstWhere((r) => r.routine.name == program.name)
          .routine;
      final days = await db.workoutsForRoutine(routine.id);
      final slots = [
        for (final d in days) ...(await db.itemsForWorkout(d.id)).map((v) => v.item),
      ];
      final cycled = slots.where((s) => s.scheme == SetScheme.cycle).toList();
      expect(cycled, isNotEmpty);
      for (final s in cycled) {
        expect(s.cycleWeeks, isNotEmpty);
        expect(s.cyclePosition, 0, reason: 'a copy opens on week one');
        expect(s.suggestedWeight, isNotNull, reason: 'a cycle needs a max');
      }
    });

    test('every program still says what it is', () {
      for (final program in the531()) {
        expect(program.description, isNotEmpty);
      }
    });
  });

  // ------------------------------------------------------------- on screen

  group('the week is on screen', () {
    testWidgets('the board says which week of the cycle you are on',
        (tester) async {
      // The database work runs on the real event loop; the widget clock is
      // fake, and a drift future awaited under it never completes.
      late final ActiveWorkoutController ctrl;
      await tester.runAsync(
          () async => ctrl = await startCycle(db, container, position: 1));
      await tester.pumpWidget(appUnder(container, const WorkoutScreen()));
      await tester.pump();

      final l10n = l10nFor();
      expect(find.text(l10n.sessionCycleWeek(2, 3)), findsOneWidget);
      expect(find.byKey(kCycleWeekKey), findsOneWidget);
      // And the weight above the rows is named for what it is: nothing in the
      // session is done at it.
      expect(find.text(l10n.sessionTrainingMaxShort), findsOneWidget);
      expect(find.text('@'), findsNothing);

      ctrl.discard();
      await stop(tester);
    });

    testWidgets('a week whose rows differ is listed set by set', (tester) async {
      // Week three is 5/3/1+ — three different numbers, so "3 × 5" would be a
      // statement about the week that is not true of two of its sets.
      late final ActiveWorkoutController ctrl;
      await tester.runAsync(
          () async => ctrl = await startCycle(db, container, position: 2));
      await tester.pumpWidget(appUnder(container, const WorkoutScreen()));
      await tester.pump();

      final l10n = l10nFor();
      final sep = l10n.itemEditorSchemeSeparator;
      expect(
        find.text('5${sep}3$sep${l10n.targetAmrap(1)}'),
        findsOneWidget,
      );

      ctrl.discard();
      await stop(tester);
    });

    testWidgets('the training day says it too', (tester) async {
      late final int pushId;
      await tester.runAsync(() async {
        final ex = await exerciseNamed(db, 'Bench Press');
        final push = await workoutNamed(db, 'Push');
        pushId = push.id;
        await db.replaceWorkoutItems(push.id, [
          WorkoutItemsCompanion.insert(
            workoutId: push.id,
            exerciseId: ex.id,
            suggestedWeight: const Value(100),
            scheme: const Value(SetScheme.cycle),
            cycleBlocks: Value(encodeCycleBlocks(k531)),
            cyclePosition: const Value(1),
          ),
        ]);
      });
      await tester.pumpWidget(
        appUnder(container, WorkoutDetailScreen(workoutId: pushId)),
      );
      await pumpThroughDatabase(tester);

      final l10n = l10nFor();
      expect(find.text(l10n.sessionCycleWeek(2, 3)), findsOneWidget);
      expect(
        find.text(rowsTargetLabel(l10n, k531[1])),
        findsOneWidget,
        reason: 'the row list, not a multiplication',
      );
      await stop(tester);
    });
  });
}
