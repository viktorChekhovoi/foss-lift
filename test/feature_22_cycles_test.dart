// Integration tests for training cycles and training maxes (features/index.html#sec22).

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/data/routine_code.dart';
import 'package:foss_lift/l10n/app_localizations.dart';
import 'package:foss_lift/data/routine_import.dart';
import 'package:foss_lift/screens/routine_detail_screen.dart';
import 'package:foss_lift/screens/training_max_screen.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/workout_detail_screen.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/util/target_label.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'support/harness.dart';
import 'support/schema_v1.dart';
import 'support/seeded.dart';

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

/// The Bench Press slot on [k531] at week [position], opened in the config
/// sheet — the builder's cycle card, on screen.
///
/// Top-level for the reason [startCycle] is: nothing here may close over a
/// `late` variable a group has not assigned yet.
Future<ItemDraft> openCycleSheet(
  WidgetTester tester,
  AppDatabase db,
  ProviderContainer container, {
  int position = 0,
  List<String> names = const [],
}) async {
  final draft = (await tester.runAsync(() async =>
      ItemDraft.forExercise(await exerciseNamed(db, 'Bench Press'))))!
    ..weightKg = 100
    ..scheme = SetScheme.cycle
    ..cycle = [for (final week in k531) [...week]]
    ..cycleNames = [...names]
    ..cyclePosition = position;
  // Tall: the sheet is long, and a control below the fold is a control a tap
  // cannot reach.
  tester.view.physicalSize = const Size(390, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(appUnder(
    container,
    Scaffold(
      body: ListView(children: [
        WorkoutItemsEditor(
          items: [draft],
          unit: 'kg',
          routineRest: 90,
          defaultBarKg: 20,
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text(draft.name));
  await tester.pumpAndSettle();
  return draft;
}

/// What week [n] of [k531] reads as when it is folded shut.
String foldedWeek(AppLocalizations l10n, int n) =>
    l10n.itemEditorCycleWeekSummary(
      rowsTargetLabel(l10n, k531[n]),
      joinRowLabels(l10n, k531[n].map((r) => '${r.percent}')),
    );

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

  // ----------------------------------------------------- picking it, and (i)

  group('Cycle is a scheme anybody can pick', () {
    testWidgets('the picker offers all five, live', (tester) async {
      final l10n = l10nFor();
      final draft = (await tester.runAsync(() async =>
          ItemDraft.forExercise(await exerciseNamed(db, 'Bench Press'))))!
        ..weightKg = 100;
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(appUnder(
        container,
        Scaffold(
          body: ListView(children: [
            WorkoutItemsEditor(
                items: [draft], unit: 'kg', routineRest: 90, defaultBarKg: 20),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text(draft.name));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(kAdvancedToggleKey));
      await tester.pumpAndSettle();

      for (final label in [
        l10n.itemEditorSchemeFlat,
        l10n.itemEditorSchemeBackOff,
        l10n.itemEditorSchemeRamp,
        l10n.itemEditorSchemeCustom,
        l10n.itemEditorSchemeCycle,
      ]) {
        final pill = find.widgetWithText(EditorPill, label);
        expect(pill, findsOneWidget);
        expect(tester.widget<EditorPill>(pill).onTap, isNotNull,
            reason: 'nothing gates the picker');
      }

      // The (i) rides on the Cycle option and is there before it is taken —
      // "what would I be picking" is asked ahead of the pick.
      expect(find.byKey(kCycleExplainKey), findsOneWidget);
      await tester.tap(find.widgetWithText(
          EditorPill, l10n.itemEditorSchemeCycle));
      await tester.pumpAndSettle();
      expect(draft.scheme, SetScheme.cycle);
      expect(find.byKey(kCycleExplainKey), findsOneWidget,
          reason: 'taking the option does not take its explanation away');
    });

    testWidgets('a written-out row asks for a range and an open end',
        (tester) async {
      final l10n = l10nFor();
      await openCycleSheet(tester, db, container);

      expect(find.text(l10n.itemEditorSchemeAmrap), findsWidgets,
          reason: 'a cycle without an open set cannot be 5/3/1');
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
      // Joined by a slash, not by the middot that separates a slot's summary
      // into fields — "5 · 3 · 1+" reads as three fields, not one week.
      final sep = l10n.targetRowSeparator;
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

  // ------------------------------------------------ the builder's cycle card

  group('a week is a card of its own, and it folds', () {
    testWidgets('the week the next session runs is the one that opens',
        (tester) async {
      final l10n = l10nFor();
      await openCycleSheet(tester, db, container, position: 1);

      // Week two is open, so it is the one week not reading as a single line.
      expect(find.text(foldedWeek(l10n, 1)), findsNothing);
      expect(find.text(foldedWeek(l10n, 0)), findsOneWidget);
      expect(find.text(foldedWeek(l10n, 2)), findsOneWidget,
          reason: 'a folded week still says what it asks for');
    });

    testWidgets('tapping a folded week opens it and shuts the other',
        (tester) async {
      final l10n = l10nFor();
      await openCycleSheet(tester, db, container);

      expect(find.text(foldedWeek(l10n, 0)), findsNothing);
      await tester.tap(find.byKey(cycleWeekKey(2)));
      await tester.pumpAndSettle();

      expect(find.text(foldedWeek(l10n, 2)), findsNothing,
          reason: 'week three is the one open now');
      expect(find.text(foldedWeek(l10n, 0)), findsOneWidget,
          reason: 'and week one has folded behind it');
    });

    testWidgets('a week you have just added is open', (tester) async {
      final l10n = l10nFor();
      final draft = await openCycleSheet(tester, db, container);

      await tester.tap(find.byKey(kCycleAddWeekKey));
      await tester.pumpAndSettle();

      expect(draft.cycle.length, 4);
      expect(find.byKey(cycleWeekKey(3)), findsOneWidget);
      // The new week is a copy of the last, and it is not the one folded.
      expect(find.text(foldedWeek(l10n, 2)), findsOneWidget,
          reason: 'week three folded when week four opened');
    });

    testWidgets("the slot's one line names the weight a training max",
        (tester) async {
      final l10n = l10nFor();
      // Before the sheet: the row in the exercise list under the movement.
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final draft = (await tester.runAsync(() async =>
          ItemDraft.forExercise(await exerciseNamed(db, 'Bench Press'))))!
        ..weightKg = 100
        ..scheme = SetScheme.cycle
        ..cycle = [for (final week in k531) [...week]];
      await tester.pumpWidget(appUnder(
        container,
        Scaffold(
          body: ListView(children: [
            WorkoutItemsEditor(
                items: [draft], unit: 'kg', routineRest: 90, defaultBarKg: 20),
          ]),
        ),
      ));
      await tester.pumpAndSettle();

      final line = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .firstWhere((t) => t.contains(rowsTargetLabel(l10n, k531[0])));
      expect(
        line,
        contains(l10n.itemEditorSummaryTrainingMax(
            l10n.unitWeightShort('100', l10n.unitKgSuffix))),
        reason: 'the number is a training max, not a weight to lift',
      );
      expect(line.split(l10n.itemEditorSchemeSeparator).length, 4,
          reason: 'target, training max, scheme and step — four fields, and '
              'the three sets are one of them',
      );
    });
  });


  // ------------------------------------------------------------- week names

  group('a week of a cycle can be called what it is', () {
    test('the names round-trip through a column of their own', () {
      const names = ['Volume', '', 'Peak'];
      expect(decodeCycleNames(encodeCycleNames(names)), names);
    });

    test('a cycle nobody has named is null in the column', () {
      expect(encodeCycleNames(const []), isNull);
      expect(encodeCycleNames(const ['', '  ', '']), isNull,
          reason: 'blanks are not names');
      expect(decodeCycleNames(null), isEmpty);
    });

    test('a name holding the separator survives it', () {
      const names = ['Heavy|Light', '100% week'];
      expect(decodeCycleNames(encodeCycleNames(names)), names);
    });

    test('a week past the end of the list has no name', () {
      expect(cycleNameAt(const ['Volume'], 0), 'Volume');
      expect(cycleNameAt(const ['Volume'], 1), '');
      expect(cycleNameAt(const [], 0), '');
      expect(cycleNameAt(const ['  Deload  '], 0), 'Deload',
          reason: 'the name is what was typed, trimmed');
    });

    test('a named week is headed by its name and an unnamed one by its number',
        () {
      final l10n = l10nFor();
      expect(cycleWeekTitle(l10n, 'Deload', 3), 'Deload');
      expect(cycleWeekTitle(l10n, '', 3), l10n.itemEditorCycleWeek(4));
    });

    test('the line under the exercise says the name and keeps the count', () {
      final l10n = l10nFor();
      expect(cycleWeekLine(l10n, '', 2, 4), l10n.sessionCycleWeek(2, 4));
      expect(cycleWeekLine(l10n, 'Deload', 4, 4),
          l10n.sessionCycleWeekNamed('Deload', 4, 4));
    });

    test('a stored slot reads back the name of the week it is on', () async {
      final ex = await exerciseNamed(db, 'Bench Press');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          scheme: const Value(SetScheme.cycle),
          cycleBlocks: Value(encodeCycleBlocks(k531)),
          cycleNames: Value(encodeCycleNames(const ['Volume', '', 'Peak'])),
          cyclePosition: const Value(2),
        ),
      ]);
      final item = (await db.itemsForWorkout(push.id)).single.item;
      expect(item.cycleWeekName, 'Peak');
      expect(item.cycleWeekNumber, 3);
    });

    test('a slot whose weeks are unnamed says so rather than throwing',
        () async {
      final ex = await exerciseNamed(db, 'Bench Press');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          scheme: const Value(SetScheme.cycle),
          cycleBlocks: Value(encodeCycleBlocks(k531)),
        ),
      ]);
      final item = (await db.itemsForWorkout(push.id)).single.item;
      expect(item.cycleWeekNameList, isEmpty);
      expect(item.cycleWeekName, '');
    });
  });

  group('a named week is named everywhere the week is shown', () {
    testWidgets('the board writes the name where it wrote "Week"',
        (tester) async {
      late final ActiveWorkoutController ctrl;
      await tester.runAsync(() async {
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
            cycleNames: Value(encodeCycleNames(const ['Volume', 'Peak', ''])),
            cyclePosition: const Value(1),
          ),
        ]);
        ctrl = container.read(activeWorkoutProvider.notifier);
        await ctrl.start(workoutId: push.id, name: 'Push');
      });
      await tester.pumpWidget(appUnder(container, const WorkoutScreen()));
      await tester.pump();

      final l10n = l10nFor();
      expect(find.text(l10n.sessionCycleWeekNamed('Peak', 2, 3)), findsOneWidget);
      expect(find.text(l10n.sessionCycleWeek(2, 3)), findsNothing);

      ctrl.discard();
      await stop(tester);
    });

    testWidgets('the builder heads the card with the name', (tester) async {
      final l10n = l10nFor();
      await openCycleSheet(tester, db, container,
          names: const ['Volume', 'Peak', 'Deload']);

      expect(find.textContaining('Volume'), findsWidgets);
      expect(find.text('Deload'), findsOneWidget);
      expect(find.text(l10n.itemEditorCycleWeek(3)), findsNothing,
          reason: 'week three is called Deload now');
    });

    testWidgets('the pencil names a week, and clearing it puts the number back',
        (tester) async {
      final draft = await openCycleSheet(tester, db, container);

      // The pencil inside week one's card — the week that opens.
      await tester.tap(find.descendant(
        of: find.byKey(cycleWeekKey(0)),
        matching: find.byKey(cycleWeekRenameKey),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(cycleWeekNameFieldKey), 'Volume');
      await tester.tap(find.byKey(cycleWeekNameSaveKey));
      await tester.pumpAndSettle();

      expect(draft.cycleNameOf(0), 'Volume');
      expect(find.textContaining('Volume'), findsWidgets);

      await tester.tap(find.descendant(
        of: find.byKey(cycleWeekKey(0)),
        matching: find.byKey(cycleWeekRenameKey),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(cycleWeekNameFieldKey), '');
      await tester.tap(find.byKey(cycleWeekNameSaveKey));
      await tester.pumpAndSettle();

      expect(draft.cycleNameOf(0), '');
      expect(draft.cycleNames, isEmpty,
          reason: 'a list of nothing but blanks is stored as no names at all');
    });

    testWidgets('removing a week takes its name with it', (tester) async {
      final draft = await openCycleSheet(tester, db, container,
          names: const ['Volume', 'Peak', 'Deload']);

      await tester.tap(find.descendant(
        of: find.byKey(cycleWeekKey(0)),
        matching: find.byIcon(Icons.close),
      ));
      await tester.pumpAndSettle();

      expect(draft.cycle, hasLength(2));
      expect(draft.cycleNames, const ['Peak', 'Deload'],
          reason: 'week two is still called Peak, not Volume');
    });

    test('the names travel in a routine code', () async {
      final ex = await exerciseNamed(db, 'Bench Press');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          scheme: const Value(SetScheme.cycle),
          cycleBlocks: Value(encodeCycleBlocks(k531)),
          cycleNames: Value(encodeCycleNames(const ['Volume', '', 'Peak'])),
        ),
      ]);
      final routine = await routineNamed(db);
      final code = RoutineCode.encode(await db.sharedRoutine(routine.id));
      final back = (RoutineCode.decode(code) as RoutineCodeOk).routine;
      final slot =
          back.workouts.firstWhere((w) => w.name == 'Push').items.single;
      expect(slot.cycle, k531);
      expect(slot.cycleNames, const ['Volume', '', 'Peak']);
    });

    test('a cycle nobody has named costs the code no bytes', () async {
      final ex = await exerciseNamed(db, 'Bench Press');
      final push = await workoutNamed(db, 'Push');
      Future<int> lengthWith(String? names) async {
        await db.replaceWorkoutItems(push.id, [
          WorkoutItemsCompanion.insert(
            workoutId: push.id,
            exerciseId: ex.id,
            scheme: const Value(SetScheme.cycle),
            cycleBlocks: Value(encodeCycleBlocks(k531)),
            cycleNames: Value(names),
          ),
        ]);
        final routine = await routineNamed(db);
        return RoutineCode.encode(await db.sharedRoutine(routine.id)).length;
      }

      expect(await lengthWith(null),
          lessThan(await lengthWith(encodeCycleNames(const ['Volume']))));
    });
  });


  group('an upgraded phone finds its weeks unnamed', () {
    /// A database at the shipped v1 shape with one ordinary slot in it, climbed
    /// all the way up by opening it — see `support/schema_v1.dart`.
    AppDatabase v1Database() => AppDatabase.forTesting(
          NativeDatabase.memory(
            setup: (raw) {
              for (final stmt in kSchemaV1) {
                raw.execute(stmt);
              }
              raw.execute(
                'INSERT INTO exercises (id, name, seed_key, muscle_group, '
                "equipment) VALUES (1, 'Bench Press', 'bench_press', 'Chest', "
                "'Barbell')",
              );
              raw.execute(
                'INSERT INTO routines (id, name, color_hex, position, '
                "rest_seconds) VALUES (1, 'Mine', 'FF6A3D', 0, 120)",
              );
              raw.execute(
                'INSERT INTO workouts (id, routine_id, name, position) '
                "VALUES (1, 1, 'Push', 0)",
              );
              raw.execute(
                'INSERT INTO workout_items (id, workout_id, exercise_id, '
                'position, target_sets, reps_min, suggested_weight) '
                'VALUES (1, 1, 1, 0, 3, 5, 80.0)',
              );
              raw.execute('PRAGMA user_version = 1');
            },
          ),
        );

    test('the column arrives empty, and no slot gains a name', () async {
      final upgraded = v1Database();
      addTearDown(upgraded.close);

      final slot = (await upgraded.itemsForWorkout(1)).single.item;
      expect(slot.cycleNames, isNull);
      expect(slot.cycleWeekNameList, isEmpty);
      expect(slot.cycleWeekName, '');
      expect(slot.runsCycle, isFalse, reason: 'and it gains no cycle either');
    });

    test('and the movements this build ships arrive with it', () async {
      final upgraded = v1Database();
      addTearDown(upgraded.close);

      final names =
          (await upgraded.watchExercises().first).map((e) => e.name).toSet();
      expect(names, containsAll(
          const ['Pause Squat', 'Paused Bench Press', 'Pause Deadlift']));
    });
  });

  group('the card says the rates move the training max', () {
    testWidgets('the rule is read back against the training max',
        (tester) async {
      final l10n = l10nFor();
      await openCycleSheet(tester, db, container);

      expect(
        find.text(l10n.itemEditorProgressionRuleCycle(
          l10n.unitWeightShort('2.5', l10n.unitKgSuffix),
          l10n.unitWeightShort('5', l10n.unitKgSuffix),
          2,
        )),
        findsOneWidget,
      );
      expect(find.textContaining(l10n.itemEditorCleanSessions.toUpperCase(),
          findRichText: true), findsNothing,
          reason: 'a cycle counts weeks, not a run of clean sessions');
    });

    testWidgets('the (i) on the Cycle option says what a cycle is',
        (tester) async {
      final l10n = l10nFor();
      await openCycleSheet(tester, db, container);

      expect(find.byKey(kCycleExplainKey), findsOneWidget);
      await tester.tap(find.byKey(kCycleExplainKey));
      await tester.pumpAndSettle();

      expect(find.text(l10n.itemEditorCycleWhat), findsOneWidget);
      expect(find.text(l10n.itemEditorCycleExplained), findsOneWidget);
      // A cycle is a shape, and the explanation of a shape does not lean on
      // one program built from it.
      expect(l10n.itemEditorCycleExplained, isNot(contains('5/3/1')));
    });
  });

  // ------------------------------------------------- the percentage base

  group('a movement takes its percentages from the lift it is a version of',
      () {
    test('the squat variations come off the back squat', () {
      expect(percentageBaseFor('Front Squat'), 'Back Squat');
    });

    test('the pulling variations come off the deadlift', () {
      for (final name in const [
        'Deadlift to Knees',
        'Block Deadlift',
        'Deficit Deadlift',
      ]) {
        expect(percentageBaseFor(name), 'Deadlift', reason: name);
      }
    });

    test('a movement that names none is its own base', () {
      expect(percentageBaseFor('Back Squat'), 'Back Squat');
      expect(percentageBaseFor('Bench Press'), 'Bench Press');
      expect(percentageBaseFor('Deadlift'), 'Deadlift');
      expect(percentageBaseFor('Zercher Squat'), 'Zercher Squat',
          reason: 'a movement you built is its own base');
    });

    test('no base is itself a variation', () {
      for (final base in kPercentageBases.values.toSet()) {
        expect(percentageBaseFor(base), base,
            reason: '$base is a base and a variation at once');
      }
      for (final base in kPercentageBases.values.toSet()) {
        expect(kPercentageBases.keys, isNot(contains(base)),
            reason: '$base is a key and a value at once');
      }
    });

    test('every movement the table names is in the starter library', () async {
      final library =
          (await db.watchExercises().first).map((e) => e.name).toSet();
      for (final entry in kPercentageBases.entries) {
        expect(library, contains(entry.key));
        expect(library, contains(entry.value));
      }
    });
  });

  // --------------------------------------------- one screen, every max

  group('one screen sets every training max in a routine', () {
    /// Three written-out slots — two on the squat, one on the front squat —
    /// beside a flat bench slot that has no training max at all.
    ///
    /// [frontSquatKg] is the front squat's own base, so a test can make the
    /// slots under one lift disagree.
    Future<int> percentageRoutine({double frontSquatKg = 100}) async {
      final rid = await db.createRoutine(
          name: 'Percentages', color: 'FF6A3D', restSeconds: 90);
      final squat = await exerciseNamed(db, 'Back Squat');
      final front = await exerciseNamed(db, 'Front Squat');
      final bench = await exerciseNamed(db, 'Bench Press');

      final one = await db.createWorkout(rid, 'Day 1');
      await db.replaceWorkoutItems(one, [
        WorkoutItemsCompanion.insert(
          workoutId: one,
          exerciseId: squat.id,
          targetSets: const Value(3),
          repsMin: const Value(5),
          suggestedWeight: const Value(100),
          scheme: const Value(SetScheme.custom),
          customSets: Value(encodeCustomSets(const [
            CustomSet(reps: 5, percent: 70),
            CustomSet(reps: 5, percent: 80),
          ])),
        ),
        WorkoutItemsCompanion.insert(
          workoutId: one,
          exerciseId: front.id,
          targetSets: const Value(2),
          repsMin: const Value(5),
          suggestedWeight: Value(frontSquatKg),
          scheme: const Value(SetScheme.custom),
          customSets: Value(encodeCustomSets(const [
            CustomSet(reps: 5, percent: 60),
          ])),
        ),
        WorkoutItemsCompanion.insert(
          workoutId: one,
          exerciseId: bench.id,
          targetSets: const Value(3),
          repsMin: const Value(5),
          suggestedWeight: const Value(60),
        ),
      ]);

      final two = await db.createWorkout(rid, 'Day 2');
      await db.replaceWorkoutItems(two, [
        WorkoutItemsCompanion.insert(
          workoutId: two,
          exerciseId: squat.id,
          targetSets: const Value(3),
          repsMin: const Value(5),
          suggestedWeight: const Value(100),
          scheme: const Value(SetScheme.cycle),
          cycleBlocks: Value(encodeCycleBlocks(k531)),
        ),
      ]);
      return rid;
    }

    /// Every slot of [rid], by the movement it is on, in day order.
    Future<Map<String, List<WorkoutItem>>> slotsOf(int rid) async {
      final out = <String, List<WorkoutItem>>{};
      for (final w in await db.workoutsForRoutine(rid)) {
        for (final v in await db.itemsForWorkout(w.id)) {
          out.putIfAbsent(v.exercise.name, () => []).add(v.item);
        }
      }
      return out;
    }

    test('the routine is gathered by the lift the percentages come from',
        () async {
      final rid = await percentageRoutine();
      final groups = await db.watchTrainingMaxGroups(rid).first;

      expect(groups, hasLength(1),
          reason: 'the flat bench slot has no training max to set');
      expect(groups.single.base, 'Back Squat');
      expect(groups.single.members, {'Back Squat': 2, 'Front Squat': 1});
    });

    test('a flat slot is not a training max', () async {
      final rid = await db.createRoutine(
          name: 'Flat', color: 'FF6A3D', restSeconds: 90);
      final wid = await db.createWorkout(rid, 'Day 1');
      final bench = await exerciseNamed(db, 'Bench Press');
      await db.replaceWorkoutItems(wid, [
        WorkoutItemsCompanion.insert(
          workoutId: wid,
          exerciseId: bench.id,
          targetSets: const Value(3),
          repsMin: const Value(5),
          suggestedWeight: const Value(60),
        ),
      ]);

      expect(await db.watchTrainingMaxGroups(rid).first, isEmpty,
          reason: 'a routine of flat sets has no training max to set');
    });

    test('a field opens on the number its slots already carry', () async {
      final rid = await percentageRoutine();
      final groups = await db.watchTrainingMaxGroups(rid).first;
      expect(groups.single.weightKg, 100);
    });

    test('and on nothing where they disagree', () async {
      final rid = await percentageRoutine(frontSquatKg: 80);
      final groups = await db.watchTrainingMaxGroups(rid).first;

      expect(groups.single.weightKg, isNull,
          reason: 'the slots differ, so the field cannot claim a number');
      expect(groups.single.members, {'Back Squat': 2, 'Front Squat': 1},
          reason: 'they are still one lift');
    });

    test('setting one lift writes every slot whose base it is', () async {
      final rid = await percentageRoutine(frontSquatKg: 80);
      await db.setTrainingMax(rid, 'Back Squat', 120);

      final slots = await slotsOf(rid);
      expect(slots['Back Squat']!.map((s) => s.suggestedWeight), [120, 120]);
      expect(slots['Front Squat']!.single.suggestedWeight, 120,
          reason: 'the front squat trains off the squat');
      expect(slots['Bench Press']!.single.suggestedWeight, 60,
          reason: 'a lift the field does not name is left alone');
    });

    test('and the field then reads back what it wrote', () async {
      final rid = await percentageRoutine(frontSquatKg: 80);
      await db.setTrainingMax(rid, 'Back Squat', 120);

      expect((await db.watchTrainingMaxGroups(rid).first).single.weightKg, 120);
    });

    test('a routine you built yourself is gathered the same way', () async {
      final rid = await db.createRoutine(
          name: 'Mine', color: 'FF6A3D', restSeconds: 90);
      final wid = await db.createWorkout(rid, 'Bench');
      final bench = await exerciseNamed(db, 'Bench Press');
      await db.replaceWorkoutItems(wid, [
        for (var i = 0; i < 3; i++)
          WorkoutItemsCompanion.insert(
            workoutId: wid,
            exerciseId: bench.id,
            position: Value(i),
            targetSets: const Value(3),
            repsMin: const Value(5),
            suggestedWeight: const Value(90),
            scheme: const Value(SetScheme.custom),
            customSets: Value(encodeCustomSets(const [
              CustomSet(reps: 5, percent: 75),
            ])),
          ),
      ]);

      final groups = await db.watchTrainingMaxGroups(rid).first;
      expect(groups, hasLength(1));
      expect(groups.single.base, 'Bench Press');
      expect(groups.single.members, {'Bench Press': 3});

      await db.setTrainingMax(rid, 'Bench Press', 105);
      final after = await db.itemsForWorkout(wid);
      expect(after.map((v) => v.item.suggestedWeight), [105, 105, 105]);
    });

    test('a lift in another routine is not touched', () async {
      final mine = await percentageRoutine();
      final theirs = await percentageRoutine();
      await db.setTrainingMax(mine, 'Back Squat', 130);

      final untouched = await slotsOf(theirs);
      expect(untouched['Back Squat']!.map((s) => s.suggestedWeight),
          [100, 100]);
    });

    testWidgets('the routine page offers the screen when there is one to set',
        (tester) async {
      final rid = (await tester.runAsync(percentageRoutine))!;
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(routedAppUnder(
        container,
        RoutineDetailScreen(routineId: rid),
        alsoRoutes: ['routine/$rid/training-maxes'],
      ));
      await pumpThroughDatabase(tester);

      final button = find.byKey(const ValueKey('routine-training-maxes'));
      expect(button, findsOneWidget);
      await tester.tap(button);
      await pumpThroughDatabase(tester);
      expect(find.text('at /routine/$rid/training-maxes'), findsOneWidget);

      await stop(tester);
    });

    testWidgets('and does not offer it on a routine of flat sets',
        (tester) async {
      final rid = (await tester.runAsync(() async {
        final id = await db.createRoutine(
            name: 'Flat', color: 'FF6A3D', restSeconds: 90);
        final wid = await db.createWorkout(id, 'Day 1');
        final bench = await exerciseNamed(db, 'Bench Press');
        await db.replaceWorkoutItems(wid, [
          WorkoutItemsCompanion.insert(
            workoutId: wid,
            exerciseId: bench.id,
            targetSets: const Value(3),
            repsMin: const Value(5),
            suggestedWeight: const Value(60),
          ),
        ]);
        return id;
      }))!;
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(routedAppUnder(
          container, RoutineDetailScreen(routineId: rid)));
      await pumpThroughDatabase(tester);

      expect(find.byKey(const ValueKey('routine-training-maxes')), findsNothing,
          reason: 'an action that opens onto nothing is worse than none');

      await stop(tester);
    });

    /// The text of the field keyed on [base].
    String fieldText(WidgetTester tester, String base) => tester
        .widget<EditableText>(find.descendant(
          of: find.byKey(ValueKey('tm-field-$base')),
          matching: find.byType(EditableText),
          matchRoot: true,
        ))
        .controller
        .text;

    Future<void> pumpScreen(WidgetTester tester, int rid) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          routedAppUnder(container, TrainingMaxScreen(routineId: rid)));
      await pumpThroughDatabase(tester);
    }

    testWidgets('the screen offers one field per lift, filled in',
        (tester) async {
      final rid = (await tester.runAsync(percentageRoutine))!;
      await pumpScreen(tester, rid);

      expect(find.byKey(const ValueKey('tm-field-Back Squat')), findsOneWidget);
      expect(find.byKey(const ValueKey('tm-field-Front Squat')), findsNothing,
          reason: 'the front squat trains off the squat and gets no field');
      expect(find.byKey(const ValueKey('tm-field-Bench Press')), findsNothing);
      expect(fieldText(tester, 'Back Squat'), '100');

      await stop(tester);
    });

    testWidgets('each field names the movements it will write, and how many',
        (tester) async {
      final rid = (await tester.runAsync(percentageRoutine))!;
      await pumpScreen(tester, rid);

      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            (w.data ?? '').contains('Back Squat') &&
            (w.data ?? '').contains('Front Squat') &&
            (w.data ?? '').contains('2') &&
            (w.data ?? '').contains('1')),
        findsOneWidget,
        reason: 'a field that reached further than its label would be worse '
            'than no field',
      );

      await stop(tester);
    });

    testWidgets('a field whose slots disagree opens empty and says so',
        (tester) async {
      final rid =
          (await tester.runAsync(() => percentageRoutine(frontSquatKg: 80)))!;
      await pumpScreen(tester, rid);

      expect(fieldText(tester, 'Back Squat'), '');

      await stop(tester);
    });

    testWidgets('typing a number and saving writes every slot under it',
        (tester) async {
      final rid =
          (await tester.runAsync(() => percentageRoutine(frontSquatKg: 80)))!;
      await pumpScreen(tester, rid);

      await tester.enterText(
          find.byKey(const ValueKey('tm-field-Back Squat')), '125');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('tm-save')));
      await pumpThroughDatabase(tester);

      final slots = (await tester.runAsync(() => slotsOf(rid)))!;
      expect(slots['Back Squat']!.map((s) => s.suggestedWeight), [125, 125]);
      expect(slots['Front Squat']!.single.suggestedWeight, 125);
      expect(slots['Bench Press']!.single.suggestedWeight, 60);

      await stop(tester);
    });

    testWidgets('a field left alone changes nothing', (tester) async {
      final rid = (await tester.runAsync(percentageRoutine))!;
      await pumpScreen(tester, rid);

      await tester.tap(find.byKey(const ValueKey('tm-save')));
      await pumpThroughDatabase(tester);

      final slots = (await tester.runAsync(() => slotsOf(rid)))!;
      expect(slots['Back Squat']!.map((s) => s.suggestedWeight), [100, 100]);
      expect(slots['Front Squat']!.single.suggestedWeight, 100);

      await stop(tester);
    });
  });

  // ------------------------------------ a written-out slot is a training max

  group('a written-out slot is a training max, cycle or not', () {
    const rows = [
      CustomSet(reps: 5, percent: 70),
      CustomSet(reps: 3, percent: 80),
      CustomSet(reps: 1, percent: 90),
    ];

    Future<WorkoutItem> customSlot({double tm = 100}) async {
      final ex = await exerciseNamed(db, 'Bench Press');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          targetSets: const Value(3),
          repsMin: const Value(5),
          suggestedWeight: Value(tm),
          scheme: const Value(SetScheme.custom),
          customSets: Value(encodeCustomSets(rows)),
          increment: const Value(2.5),
          deload: const Value(5),
          progression: const Value(ProgressionMode.weight),
        ),
      ]);
      return (await db.itemsForWorkout(push.id)).single.item;
    }

    test('loading the bar past the prescription does not move a custom max',
        () async {
      // Every set is a fraction of this number, so a heavy session must not be
      // read as the number itself having gone up.
      final it = await customSlot();
      await db.advanceProgression(
        it.id,
        verdict: SessionVerdict.success,
        performedWeight: 140,
      );
      final after = (await db.workoutItemById(it.id))!;
      expect(after.suggestedWeight, 102.5,
          reason: 'it steps by its own step, not by what was on the bar');
    });

    test('a custom slot whose step is nothing holds its max', () async {
      final ex = await exerciseNamed(db, 'Bench Press');
      final push = await workoutNamed(db, 'Push');
      await db.replaceWorkoutItems(push.id, [
        WorkoutItemsCompanion.insert(
          workoutId: push.id,
          exerciseId: ex.id,
          targetSets: const Value(3),
          repsMin: const Value(5),
          suggestedWeight: const Value(100),
          scheme: const Value(SetScheme.custom),
          customSets: Value(encodeCustomSets(rows)),
          increment: const Value(0),
          deload: const Value(0),
          progression: const Value(ProgressionMode.weight),
        ),
      ]);
      final it = (await db.itemsForWorkout(push.id)).single.item;
      await db.advanceProgression(
        it.id,
        verdict: SessionVerdict.success,
        performedWeight: 140,
      );
      expect((await db.workoutItemById(it.id))!.suggestedWeight, 100);
    });

    testWidgets("a custom slot's one line names the weight a training max",
        (tester) async {
      final l10n = l10nFor();
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final draft = (await tester.runAsync(() async =>
          ItemDraft.forExercise(await exerciseNamed(db, 'Bench Press'))))!
        ..weightKg = 100
        ..scheme = SetScheme.custom
        ..customSets = [...rows];
      await tester.pumpWidget(appUnder(
        container,
        Scaffold(
          body: ListView(children: [
            WorkoutItemsEditor(
                items: [draft], unit: 'kg', routineRest: 90, defaultBarKg: 20),
          ]),
        ),
      ));
      await tester.pumpAndSettle();

      final line = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .firstWhere((t) => t.contains(rowsTargetLabel(l10n, rows)));
      expect(
        line,
        contains(l10n.itemEditorSummaryTrainingMax(
            l10n.unitWeightShort('100', l10n.unitKgSuffix))),
        reason: 'a custom slot is percentages of its weight exactly as a '
            'cycle is',
      );

      await stop(tester);
    });
  });
}
