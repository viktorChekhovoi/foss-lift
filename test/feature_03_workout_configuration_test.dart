// Integration tests for features/index.html#sec03
//
// Per-slot configuration in the exercise builder: sets, a target (fixed count /
// range / to-failure / timed hold), a rest override, a suggested weight and the
// progression rates. Which targets are offered follows the exercise's measure,
// not the programme; a rep range keeps its width as it moves; a set is reps XOR
// seconds; the untouched defaults are +2.5 kg after a clean session, −5 kg after
// two misses.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/util/target_label.dart';
import 'package:foss_lift/util/units.dart';
import 'package:foss_lift/screens/exercise_detail_screen.dart' show kLoadingChoiceKey;
import 'package:foss_lift/widgets/builder_widgets.dart';
import 'package:foss_lift/widgets/exercise_filters.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

Future<WorkoutItemView> itemNamed(
  AppDatabase db,
  int workoutId,
  String exerciseName,
) async {
  final items = await db.itemsForWorkout(workoutId);
  return items.firstWhere((v) => v.exercise.name == exerciseName);
}

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  /// Mounts the exercise list editor over [drafts] and opens the config sheet
  /// on the first one — the sheet is a sheet over a builder, so it is exercised
  /// the way the builder opens it rather than pumped bare.
  Future<void> openSheet(
    WidgetTester tester,
    ProviderContainer container,
    List<ItemDraft> drafts, {
    String unit = 'kg',
    Size size = const Size(390, 1400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnder(
        container,
        Scaffold(
          body: ListView(
            children: [
              WorkoutItemsEditor(
                items: drafts,
                unit: unit,
                routineRest: 90,
                defaultBarKg: 20,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(drafts.first.name));
    await tester.pumpAndSettle();
  }

  /// A BuilderField's caption, which the grid renders upper-cased and as rich
  /// text — so neither a plain `find.text` nor the label as written matches it.
  /// `containing` rather than exact: a caption may carry a note after it, as
  /// Rest's "· DEFAULT" does, in the same span.
  Finder fieldLabel(String label) =>
      find.textContaining(label.toUpperCase(), findRichText: true);

  Finder stepper(Key field, IconData icon) => find.descendant(
    of: find.byKey(field),
    matching: find.byIcon(icon),
  );

  group('the step-up and back-off amounts are tapped as well as typed', () {
    testWidgets('+ and − move a weight amount by 1.25 kg', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;
      final draft = ItemDraft.forExercise(bench);

      await openSheet(tester, container, [draft]);
      expect(draft.increment, 2.5);

      await tester.tap(stepper(kStepUpFieldKey, Icons.add));
      await tester.pumpAndSettle();
      expect(draft.increment, closeTo(3.75, 0.001));
      expect(find.text('3.75'), findsOneWidget);

      await tester.tap(stepper(kStepUpFieldKey, Icons.remove));
      await tester.pumpAndSettle();
      expect(draft.increment, closeTo(2.5, 0.001));

      await stop(tester);
    });

    testWidgets('in pounds the tap is worth 2.5 lb', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;
      // 5 lb, so the tap lands on a round number a pounds gym recognises.
      final draft = ItemDraft.forExercise(bench)..increment = 2.26796;

      await openSheet(tester, container, [draft], unit: 'lb');
      expect(find.text('5'), findsWidgets);

      await tester.tap(stepper(kStepUpFieldKey, Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('7.5'), findsOneWidget);

      await stop(tester);
    });

    testWidgets('a step-up stops at one tap, never at nothing', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;
      final draft = ItemDraft.forExercise(bench)..increment = 1.25;

      await openSheet(tester, container, [draft]);

      await tester.tap(stepper(kStepUpFieldKey, Icons.remove));
      await tester.pumpAndSettle();
      expect(
        draft.increment,
        closeTo(1.25, 0.001),
        reason: 'a slot that steps up by nothing never progresses',
      );

      await stop(tester);
    });

    testWidgets('a back-off may be taken down to zero', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;
      final draft = ItemDraft.forExercise(bench)..deload = 1.25;

      await openSheet(tester, container, [draft]);

      await tester.tap(stepper(kBackOffFieldKey, Icons.remove));
      await tester.pumpAndSettle();
      expect(draft.deload, 0, reason: 'a miss that never lightens the load');

      await stop(tester);
    });

    testWidgets('a value typed straight in is still taken', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;
      final draft = ItemDraft.forExercise(bench);

      await openSheet(tester, container, [draft]);

      await tester.enterText(
        find.descendant(
          of: find.byKey(kStepUpFieldKey),
          matching: find.byType(TextField),
        ),
        '7',
      );
      await tester.pumpAndSettle();
      expect(draft.increment, 7);

      await stop(tester);
    });
  });

  group('the sheet keeps the field you are typing in above the keyboard', () {
    testWidgets('focusing a field low in the sheet scrolls it into view', (
      tester,
    ) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;

      // A phone-sized viewport, so the progression card starts below the fold.
      await openSheet(
        tester,
        container,
        [ItemDraft.forExercise(bench)],
        size: const Size(390, 700),
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(kBackOffFieldKey),
          matching: find.byType(TextField),
        ),
      );
      // The keyboard comes up over the bottom half of the screen.
      tester.view.viewInsets = const FakeViewPadding(bottom: 340);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(
        tester.getBottomLeft(find.byKey(kBackOffFieldKey)).dy,
        lessThan(700 - 340),
        reason: 'the keyboard would otherwise cover the box being typed in',
      );

      await stop(tester);
    });
  });

  group('the exercise\'s own library properties are on the sheet', () {
    testWidgets('the sheet carries an exercise card, apart from the slot', (
      tester,
    ) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;
      final l10n = l10nFor();

      await openSheet(tester, container, [ItemDraft.forExercise(bench)]);

      expect(find.text(l10n.itemEditorExercise.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.itemEditorExerciseShared), findsOneWidget);
      // Its note and its bar, the two things a starter movement owns.
      expect(find.text(l10n.exerciseDetailNoteEmpty), findsOneWidget);
      expect(find.text(l10n.exerciseDetailBarWeight), findsOneWidget);

      await stop(tester);
    });

    testWidgets('a note written here lands on the exercise', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;
      final l10n = l10nFor();

      await openSheet(tester, container, [ItemDraft.forExercise(bench)]);

      await tester.tap(find.text(l10n.exerciseDetailNoteEmpty));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Pin 7, feet back');
      await tester.tap(find.text(l10n.commonSave));
      await pumpThroughDatabase(tester);

      final saved = (await tester.runAsync(() => db.exerciseById(bench.id)))!;
      expect(saved.notes, 'Pin 7, feet back');

      await stop(tester);
    });

    testWidgets('only a movement you made opens the library form', (
      tester,
    ) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final l10n = l10nFor();
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;

      await openSheet(tester, container, [ItemDraft.forExercise(bench)]);
      expect(
        find.text(l10n.itemEditorEditExercise),
        findsNothing,
        reason: 'a starter name is shared vocabulary',
      );
      await stop(tester);

      final mine = (await tester.runAsync(() async {
        final id = await db.createExercise(
          name: 'Landmine Press',
          muscle: 'Shoulders',
          equipment: 'Barbell',
        );
        return db.exerciseById(id);
      }))!;

      await openSheet(tester, container, [ItemDraft.forExercise(mine)]);
      expect(find.text(l10n.itemEditorEditExercise), findsOneWidget);

      await stop(tester);
    });

    testWidgets('reclassifying the loading here reaches the slot above', (
      tester,
    ) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final l10n = l10nFor();
      final mine = (await tester.runAsync(() async {
        final id = await db.createExercise(
          name: 'Sled Push',
          muscle: 'Legs',
          equipment: 'Other',
        );
        return db.exerciseById(id);
      }))!;
      final draft = ItemDraft.forExercise(mine);

      await openSheet(tester, container, [draft]);
      expect(find.text(l10n.itemEditorBodyweight), findsNothing);

      // Tapping the selected loading clears it: the sled carries no weight of
      // its own. The slot above has to hear about it.
      await tester.tap(
        find.descendant(
          of: find.byKey(kLoadingChoiceKey),
          matching: find.text(l10n.weightTypeMachine),
        ),
      );
      await pumpThroughDatabase(tester);

      expect(draft.weightType, WeightType.none);
      expect(find.text(l10n.itemEditorBodyweight), findsOneWidget);

      await stop(tester);
    });
  });

  group('the sheet has no handle that does nothing', () {
    testWidgets('the config sheet drew a grab bar it could not honour', (
      tester,
    ) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;

      await openSheet(tester, container, [ItemDraft.forExercise(bench)]);

      expect(
        find.byType(SheetGrabber),
        findsNothing,
        reason: 'it sits inside the scroll view, where a drag scrolls instead',
      );

      await stop(tester);
    });
  });

  group('a slot stores its full configuration', () {
    test('the seeded bench slot round-trips every configured field', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = (await itemNamed(db, push, 'Bench Press')).item;

      expect(bench.targetSets, 4);
      expect(bench.repsMin, 6);
      expect(bench.repsMax, 8);
      expect(bench.suggestedWeight, 80);
      expect(bench.progression, ProgressionMode.weight);
      expect(bench.increment, 2.5);
      expect(bench.deload, 5);
      expect(bench.successThreshold, 1);
      expect(bench.failureThreshold, 2);
    });

    test(
      'a per-slot rest override is stored and overrides the routine default',
      () async {
        final push = await workoutIdNamed(db, 'Push');
        final bench = await exerciseNamed(db, 'Bench Press');

        final draft = ItemDraft.forExercise(bench)..restSeconds = 45;
        await db.replaceWorkoutItems(
          push,
          itemCompanions([draft], workoutId: push),
        );

        final saved = (await itemNamed(db, push, 'Bench Press')).item;
        expect(saved.restSeconds, 45); // null would mean "fall back to routine"
      },
    );
  });

  group('target types', () {
    /// A saved slot's target as the screens write it — the label the training
    /// day, the editor and the import confirmation all read from. English here
    /// because the assertion is about the shape of the phrase; feature 18 is
    /// where it is checked in the other four languages.
    String label(WorkoutItem it) => repsTargetLabel(
          l10nFor(),
          progression: it.progression,
          toFailure: it.toFailure,
          holdSeconds: it.holdSeconds,
          repsMin: it.repsMin,
          repsMax: it.repsMax,
        );

    test('a fixed rep count reads as a single number', () async {
      final push = await workoutIdNamed(db, 'Push');
      final ohp = (await itemNamed(db, push, 'Overhead Press')).item;
      expect(ohp.repsMax, isNull); // fixed count of repsMin
      expect(label(ohp), '8');
    });

    test('a rep range reads as low–high', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = (await itemNamed(db, push, 'Bench Press')).item;
      expect(label(bench), '6–8');
    });

    test('a to-failure slot drops its range and says so', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = await exerciseNamed(db, 'Bench Press');

      final draft = ItemDraft.forExercise(bench)
        ..toFailure = true
        ..repsMax = 8;
      await db.replaceWorkoutItems(
        push,
        itemCompanions([draft], workoutId: push),
      );

      final saved = (await itemNamed(db, push, 'Bench Press')).item;
      expect(saved.toFailure, isTrue);
      expect(saved.repsMax, isNull); // a range has no meaning at failure
      expect(label(saved), l10nFor().targetFailure);
    });

    test('a timed hold reads in seconds', () async {
      final plank = await exerciseNamed(db, 'Plank');
      final push = await workoutIdNamed(db, 'Push');

      final draft = ItemDraft.forExercise(plank)..holdSeconds = 45;
      await db.replaceWorkoutItems(
        push,
        itemCompanions([draft], workoutId: push),
      );

      final saved = (await itemNamed(db, push, 'Plank')).item;
      expect(saved.progression, ProgressionMode.time);
      expect(label(saved), l10nFor().unitSecondsShort('45'));
    });
  });

  group('which targets are offered follows the measure, not the programme', () {
    test('a counted lift offers weight and reps', () async {
      final bench = await exerciseNamed(db, 'Bench Press');
      final draft = ItemDraft.forExercise(bench);
      expect(draft.modes, [ProgressionMode.weight, ProgressionMode.reps]);
      expect(draft.progression, ProgressionMode.weight); // opens on load
    });

    test(
      'a held movement offers only time and cannot be switched off it',
      () async {
        final plank = await exerciseNamed(db, 'Plank');
        final draft = ItemDraft.forExercise(plank);
        expect(draft.modes, [ProgressionMode.time]);

        // The builder never offers "a plank progressed by weight".
        draft.setMode(ProgressionMode.weight);
        expect(draft.progression, ProgressionMode.time);
      },
    );

    test('the builder never offers a deadlift progressed by time', () async {
      final deadlift = await exerciseNamed(db, 'Deadlift');
      final draft = ItemDraft.forExercise(deadlift);
      expect(draft.modes, isNot(contains(ProgressionMode.time)));
    });

    test(
      'switching axis resets the step/back-off to that axis\'s defaults',
      () async {
        final bench = await exerciseNamed(db, 'Bench Press');
        final draft = ItemDraft.forExercise(bench);
        expect(draft.increment, 2.5); // weight defaults
        expect(draft.deload, 5);

        draft.setMode(ProgressionMode.reps);
        expect(draft.progression, ProgressionMode.reps);
        expect(draft.increment, 1); // rep defaults, not 2.5 reps
        expect(draft.deload, 2);
      },
    );
  });

  group('a rep range keeps its width as progression moves it', () {
    test('stepping up carries the whole range', () async {
      // Pull-Up is seeded on the reps axis with a 6–10 range (width 4).
      final pull = await workoutIdNamed(db, 'Pull');
      final pullUp = (await itemNamed(db, pull, 'Pull-Up')).item;
      expect(pullUp.progression, ProgressionMode.reps);
      expect(pullUp.repsMin, 6);
      expect(pullUp.repsMax, 10);

      // One clean session (default threshold 1) steps reps up by one.
      await db.advanceProgression(pullUp.id, success: true);

      final moved = await db.workoutItemById(pullUp.id);
      expect(moved!.repsMin, 7);
      expect(moved.repsMax, 11); // 6–10 becomes 7–11, width still 4
    });

    test('a back-off keeps the width on the way down too', () async {
      final pull = await workoutIdNamed(db, 'Pull');
      final pullUp = (await itemNamed(db, pull, 'Pull-Up')).item;

      // Two misses in a row (default failure threshold) back the range off.
      await db.advanceProgression(pullUp.id, success: false);
      await db.advanceProgression(pullUp.id, success: false);

      final moved = await db.workoutItemById(pullUp.id);
      final width = moved!.repsMax! - moved.repsMin;
      expect(width, 4); // still 6–10 wide, wherever it landed
    });
  });

  group('a set is measured in reps or seconds, never both', () {
    test(
      'a timed set logs seconds and leaves reps at zero, off the rep tally',
      () async {
        final now = DateTime(2026, 2, 1, 18);
        await db.saveSession(
          routineId: null,
          workoutId: null,
          name: 'Mixed day',
          startedAt: now,
          endedAt: now.add(const Duration(minutes: 30)),
          durationSeconds: 1800,
          totalVolume: 640,
          sets: [
            // A counted set: eight reps.
            SessionSetsCompanion.insert(
              sessionId: 0,
              exerciseName: 'Bench Press',
              setNumber: 1,
              weight: const Value(80),
              reps: const Value(8),
              done: const Value(true),
            ),
            // A held set: 45 seconds, zero reps.
            SessionSetsCompanion.insert(
              sessionId: 0,
              exerciseName: 'Plank',
              setNumber: 1,
              reps: const Value(0),
              seconds: const Value(45),
              done: const Value(true),
            ),
          ],
        );

        final totals = await db.watchLifetimeTotals().first;
        // The 45-second plank counts as 45 of nothing: only the bench reps show.
        expect(totals.reps, 8);
        expect(totals.sets, 2);
      },
    );

    test(
      'a short hold misses its goal; a short rep count misses its goal too',
      () {
        // Timed: judged on seconds against goalSeconds.
        const heldShort = SessionSet(
          id: 1,
          sessionId: 1,
          exerciseName: 'Plank',
          setNumber: 1,
          weight: 0,
          reps: 0,
          done: true,
          goalReps: 0,
          seconds: 20,
          goalSeconds: 30,
        );
        const heldMet = SessionSet(
          id: 2,
          sessionId: 1,
          exerciseName: 'Plank',
          setNumber: 1,
          weight: 0,
          reps: 0,
          done: true,
          goalReps: 0,
          seconds: 45,
          goalSeconds: 30,
        );
        expect(setMissedGoal(heldShort), isTrue);
        expect(setMissedGoal(heldMet), isFalse);
      },
    );
  });

  group('the sets of a slot can back off, ramp up, or be written out', () {
    // The pure arithmetic first: the four schemes are a list of per-set targets
    // computed off one top weight, and everything else — the sheet, the board,
    // the share code — reads that list.

    List<SetTarget> targets(
      SetScheme scheme, {
      int sets = 3,
      int reps = 8,
      double? top = 100,
      int percent = 10,
      List<CustomSet> custom = const [],
      String unit = 'kg',
      double floorKg = 0,
    }) =>
        resolveSetTargets(
          scheme: scheme,
          sets: sets,
          goalReps: reps,
          topWeightKg: top,
          percent: percent,
          custom: custom,
          unit: unit,
          floorKg: floorKg,
        );

    test('flat is every set alike, and is what a slot starts on', () async {
      expect(
          ItemDraft.forExercise(await exerciseNamed(db, 'Bench Press')).scheme,
          SetScheme.flat);
      expect(targets(SetScheme.flat).map((t) => t.weightKg), [100, 100, 100]);
      expect(targets(SetScheme.flat).map((t) => t.reps), [8, 8, 8]);
    });

    test('back-off opens at the top and takes the percentage off each set', () {
      expect(targets(SetScheme.backOff).map((t) => t.weightKg), [100, 90, 80]);
      expect(targets(SetScheme.backOff, percent: 20).map((t) => t.weightKg),
          [100, 80, 60]);
      expect(targets(SetScheme.backOff).map((t) => t.reps), [8, 8, 8],
          reason: 'only the weight moves; the rep target is the slot\'s');
    });

    test('ramp is the same ladder climbed the other way', () {
      expect(targets(SetScheme.ramp).map((t) => t.weightKg), [80, 90, 100],
          reason: 'the last set is the slot\'s weight, not the first');
    });

    test('a custom scheme carries a rep count and a percentage per set', () {
      final custom = [
        const CustomSet(reps: 5, percent: 100),
        const CustomSet(reps: 8, percent: 80),
      ];
      final got = targets(SetScheme.custom, sets: 2, custom: custom);
      expect(got.map((t) => t.reps), [5, 8]);
      expect(got.map((t) => t.weightKg), [100, 80]);
    });

    test('a custom scheme short of rows falls back to the slot\'s own target',
        () {
      // The set count and the rows are edited separately, so they can disagree
      // for a tap or two. A missing row is the slot's own reps at full weight
      // rather than a set that vanishes.
      final got = targets(SetScheme.custom,
          sets: 3, custom: [const CustomSet(reps: 5, percent: 90)]);
      expect(got, hasLength(3));
      expect(got.map((t) => t.reps), [5, 8, 8]);
      expect(got.map((t) => t.weightKg), [90, 100, 100]);
    });

    test('every computed weight lands on something you can load', () {
      // 90% of 102.5 is 92.25, which is not a bar anybody sets.
      expect(targets(SetScheme.backOff, top: 102.5).map((t) => t.weightKg),
          [102.5, 92.5, 82.5]);
      // And in a pounds gym it snaps to the pound step instead.
      final lb = targets(SetScheme.backOff, top: toKg(225, 'lb'), unit: 'lb');
      for (final t in lb) {
        expect(toDisplayWeight(t.weightKg!, 'lb') % 5, closeTo(0, 1e-6));
      }
    });

    test('and never falls under the bar it is loaded on', () {
      final got =
          targets(SetScheme.backOff, sets: 4, percent: 30, top: 60, floorKg: 20);
      expect(got.map((t) => t.weightKg), [60, 42.5, 25, 20],
          reason: 'an unloadable set is not a lighter set');
    });

    test('and the floor never loads a deliberately bare bar back up', () {
      // Dropping a barbell lift to nothing is how the app says "bodyweight
      // today". The floor stops a percentage landing under the bar; it is not
      // a veto on the number somebody typed.
      expect(targets(SetScheme.backOff, top: 0, floorKg: 20).map((t) => t.weightKg),
          [0, 0, 0]);
    });

    test('a movement carrying no weight has none to scale', () {
      expect(targets(SetScheme.backOff, top: null).map((t) => t.weightKg),
          [null, null, null]);
    });

    test('the custom rows survive a round trip through storage', () {
      const rows = [
        CustomSet(reps: 5, percent: 100),
        CustomSet(reps: 8, percent: 85),
      ];
      final encoded = encodeCustomSets(rows);
      expect(decodeCustomSets(encoded), rows);
      expect(decodeCustomSets(null), isEmpty);
      expect(decodeCustomSets(''), isEmpty);
      expect(decodeCustomSets('nonsense'), isEmpty,
          reason: 'a damaged column is no scheme, not a crash');
    });

    test('a slot keeps its scheme through a save and a reload', () async {
      final bench = await exerciseNamed(db, 'Bench Press');
      final rid = await db.createRoutine(
          name: 'R', color: 'FF0000', restSeconds: 90);
      final wid = await db.createWorkout(rid, 'Day');
      final draft = ItemDraft.forExercise(bench)
        ..sets = 3
        ..weightKg = 100
        ..scheme = SetScheme.backOff
        ..schemePercent = 15;
      await db.replaceWorkoutItems(wid, itemCompanions([draft], workoutId: wid));

      final stored = (await itemNamed(db, wid, 'Bench Press')).item;
      expect(stored.scheme, SetScheme.backOff);
      expect(stored.schemePercent, 15);
      expect(ItemDraft.fromView(await itemNamed(db, wid, 'Bench Press')).scheme,
          SetScheme.backOff);
    });
  });

  group('the scheme is what the board hydrates from', () {
    /// A one-day routine holding a single Back Squat slot on [scheme], and the
    /// live session started on it.
    Future<ActiveWorkoutController> startSchemed(
      ProviderContainer container, {
      required SetScheme scheme,
      int percent = kDefaultSchemePercent,
      List<CustomSet> custom = const [],
      int sets = 3,
      double weightKg = 100,
    }) async {
      final squat = await exerciseNamed(db, 'Back Squat');
      final rid =
          await db.createRoutine(name: 'R', color: 'FF0000', restSeconds: 90);
      final wid = await db.createWorkout(rid, 'Day');
      final draft = ItemDraft.forExercise(squat)
        ..sets = sets
        ..repsMin = 5
        ..weightKg = weightKg
        ..scheme = scheme
        ..schemePercent = percent
        ..customSets = custom;
      await db.replaceWorkoutItems(wid, itemCompanions([draft], workoutId: wid));
      final ctl = container.read(activeWorkoutProvider.notifier);
      await ctl.start(workoutId: wid, name: 'Day');
      return ctl;
    }

    List<double?> weights(ProviderContainer c) => c
        .read(activeWorkoutProvider)!
        .exercises
        .single
        .sets
        .map((s) => s.goalWeight)
        .toList();

    test('each set row opens at its own weight', () async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      await startSchemed(container, scheme: SetScheme.backOff);

      expect(weights(container), [100, 90, 80]);
      // And the row's editable weight opens on the same number, so a back-off
      // set is not one you have to dial down by hand every session.
      expect(
          container
              .read(activeWorkoutProvider)!
              .exercises
              .single
              .sets
              .map((s) => s.weight),
          [100, 90, 80]);
    });

    test('a back-off set is judged against its own weight, not the top one',
        () async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final ctl = await startSchemed(container, scheme: SetScheme.backOff);

      // Every set logged at the goal it was given.
      for (var i = 0; i < 3; i++) {
        ctl.cycleSet(0, i);
      }
      final e = container.read(activeWorkoutProvider)!.exercises.single;
      for (final set in e.sets) {
        expect(set.missedGoal, isFalse,
            reason: 'finishing a back-off set at its own weight is not a miss');
      }
    });

    test('a custom scheme carries its own reps per set', () async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      await startSchemed(container,
          scheme: SetScheme.custom,
          sets: 2,
          custom: const [
            CustomSet(reps: 3, percent: 100),
            CustomSet(reps: 10, percent: 70),
          ]);

      final sets = container.read(activeWorkoutProvider)!.exercises.single.sets;
      expect(sets.map((s) => s.goal), [3, 10]);
      expect(sets.map((s) => s.goalWeight), [100, 70]);
    });

    test('editing the weight mid-session moves the whole ladder', () async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final ctl = await startSchemed(container, scheme: SetScheme.backOff);

      ctl.setWorkingWeight(0, 80);

      final sets = container.read(activeWorkoutProvider)!.exercises.single.sets;
      expect(sets.map((s) => s.weight), [80, 72.5, 65],
          reason: 'the proportions are the scheme; the top of it is the edit');
    });

    test('and sets already logged keep what they were done at', () async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final ctl = await startSchemed(container, scheme: SetScheme.backOff);
      ctl.cycleSet(0, 0);

      ctl.setWorkingWeight(0, 80);

      final sets = container.read(activeWorkoutProvider)!.exercises.single.sets;
      expect(sets.first.weight, 100,
          reason: 'what is in the log is what happened');
      expect(sets[1].weight, 72.5);
    });

    test('a flat slot is unchanged by any of it', () async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final ctl = await startSchemed(container, scheme: SetScheme.flat);
      expect(weights(container), [100, 100, 100]);

      ctl.setWorkingWeight(0, 80);
      final sets = container.read(activeWorkoutProvider)!.exercises.single.sets;
      expect(sets.map((s) => s.weight), [80, 80, 80]);
    });
  });

  group('the Target card opens on sets, reps and rest', () {
    Future<void> openBench(WidgetTester tester, ProviderContainer container,
        {ItemDraft Function(ItemDraft)? configure}) async {
      final bench = (await tester.runAsync(
          () async => ItemDraft.forExercise(
              await exerciseNamed(db, 'Bench Press'))))!;
      await openSheet(tester, container, [configure?.call(bench) ?? bench]);
    }

    testWidgets('and hides the rest of the target behind Advanced',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final l10n = l10nFor();
      await openBench(tester, container);

      for (final label in [
        l10n.itemEditorSets,
        l10n.itemEditorReps,
        l10n.itemEditorRest,
      ]) {
        expect(fieldLabel(label), findsOneWidget,
            reason: 'the three numbers every slot has an answer for');
      }
      expect(fieldLabel(l10n.itemEditorRepRange), findsNothing);
      expect(find.text(l10n.itemEditorToFailure), findsNothing);
      expect(find.byKey(kSchemePickerKey), findsNothing);

      await tester.tap(find.byKey(kAdvancedToggleKey));
      await tester.pumpAndSettle();

      expect(fieldLabel(l10n.itemEditorRepRange), findsOneWidget);
      expect(find.text(l10n.itemEditorToFailure), findsOneWidget);
      expect(find.byKey(kSchemePickerKey), findsOneWidget);
    });

    testWidgets('a slot already using it opens expanded', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      await openBench(tester, container,
          configure: (d) => d..scheme = SetScheme.backOff);

      expect(find.byKey(kSchemePickerKey), findsOneWidget,
          reason: 'nothing a slot actually does is hidden behind a toggle');
    });

    testWidgets('a rep range on its own is enough to open it', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      await openBench(tester, container, configure: (d) => d..repsMax = 10);

      expect(fieldLabel(l10nFor().itemEditorRepRange), findsOneWidget);
    });

    testWidgets('picking back-off offers a percentage and reads the ladder back',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final l10n = l10nFor();
      await openBench(tester, container,
          configure: (d) => d
            ..sets = 3
            ..weightKg = 100
            ..scheme = SetScheme.backOff);

      expect(find.byKey(kSchemePercentKey), findsOneWidget);
      // The scheme read back as the sets it adds up to.
      final preview = tester.widget<Text>(find.byKey(kSchemePreviewKey));
      expect(preview.data, contains('100'));
      expect(preview.data, contains('90'));
      expect(preview.data, contains('80'));
      expect(find.text(l10n.itemEditorSchemeCustom), findsOneWidget,
          reason: 'all four schemes stay on offer while one is chosen');
    });

    testWidgets('a timed slot has no advanced half at all', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final plank = (await tester.runAsync(() async =>
          ItemDraft.forExercise(await exerciseNamed(db, 'Plank'))))!;
      await openSheet(tester, container, [plank]);

      expect(fieldLabel(l10nFor().itemEditorHold), findsOneWidget);
      expect(find.byKey(kAdvancedToggleKey), findsNothing,
          reason: 'a hold has no rep range, no failure and no ladder');
    });
  });

  group('the untouched progression defaults', () {
    test(
      'the weight axis defaults to +2.5 up and −5 down after two misses',
      () {
        expect(ProgressionMode.weight.defaultIncrement, 2.5);
        expect(ProgressionMode.weight.defaultDeload, 5);
        expect(defaultSuccessThreshold, 1);
        expect(defaultFailureThreshold, 2);
      },
    );

    test('one clean session adds 2.5 kg to a weight slot', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = (await itemNamed(db, push, 'Bench Press')).item;
      expect(bench.suggestedWeight, 80);

      final moved = await db.advanceProgression(bench.id, success: true);

      expect(moved, 2.5);
      expect((await db.workoutItemById(bench.id))!.suggestedWeight, 82.5);
    });

    test('two misses in a row drop a weight slot by 5 kg', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = (await itemNamed(db, push, 'Bench Press')).item;

      // First miss: nothing moves yet (streak of one).
      await db.advanceProgression(bench.id, success: false);
      expect((await db.workoutItemById(bench.id))!.suggestedWeight, 80);

      // Second miss in a row: the back-off lands.
      await db.advanceProgression(bench.id, success: false);
      expect((await db.workoutItemById(bench.id))!.suggestedWeight, 75);
    });
  });

  group('a bar-loaded slot cannot be authored under its bar', () {
    test('a weight below the bar is held at the bar on the way in', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = await exerciseNamed(db, 'Bench Press');
      await db.setExerciseBarWeight(bench.id, 20);

      final draft =
          ItemDraft.forExercise(await db.exerciseById(bench.id))..weightKg = 10;
      await db.replaceWorkoutItems(
        push,
        itemCompanions([draft], workoutId: push, defaultBarKg: 20),
      );

      expect((await itemNamed(db, push, 'Bench Press')).item.suggestedWeight, 20,
          reason: '10 kg over a 20 kg bar is not a load');
    });

    test('the exercise\'s own bar beats the app default', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = await exerciseNamed(db, 'Bench Press');
      await db.setExerciseBarWeight(bench.id, 15);

      final draft = ItemDraft.forExercise(await db.exerciseById(bench.id))
        ..weightKg = 12.5;
      await db.replaceWorkoutItems(
        push,
        itemCompanions([draft], workoutId: push, defaultBarKg: 20),
      );

      expect(
          (await itemNamed(db, push, 'Bench Press')).item.suggestedWeight, 15);
    });

    test('a machine slot has no floor, and a held one has no weight', () async {
      final push = await workoutIdNamed(db, 'Push');
      final pushdown = await exerciseNamed(db, 'Triceps Pushdown');
      final plank = await exerciseNamed(db, 'Plank');

      final drafts = [
        ItemDraft.forExercise(pushdown)..weightKg = 0,
        ItemDraft.forExercise(plank)..weightKg = 40,
      ];
      await db.replaceWorkoutItems(
        push,
        itemCompanions(drafts, workoutId: push, defaultBarKg: 20),
      );

      expect((await itemNamed(db, push, 'Triceps Pushdown')).item.suggestedWeight, 0,
          reason: 'a stack can read zero');
      expect((await itemNamed(db, push, 'Plank')).item.suggestedWeight, isNull,
          reason: 'a movement carrying nothing has no weight to suggest');
    });
  });

  group('adding an exercise opens its config', () {
    /// The item list with one slot on it — the Bench Press the Push day opens
    /// with — mounted the way the workout builder mounts it. The list handed in
    /// is the one the editor writes into, so a test can read what the taps did.
    Future<List<ItemDraft>> pumpEditor(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;
      final drafts = [ItemDraft.forExercise(bench)];
      await tester.pumpWidget(
        appUnder(
          container,
          Scaffold(
            body: ListView(
              children: [
                WorkoutItemsEditor(
                  items: drafts,
                  unit: 'kg',
                  routineRest: 90,
                  defaultBarKg: 20,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return drafts;
    }

    /// Takes Back Squat out of the picker, narrowing to Legs to find it the way
    /// the picker's own control does.
    Future<void> addBackSquat(WidgetTester tester) async {
      await tester.tap(find.text(l10nFor().itemEditorAdd));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(filterButtonKey('muscle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(filterChipKey('muscle', 'Legs')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(kFilterSheetDoneKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back Squat'));
      await tester.pumpAndSettle();
    }

    testWidgets('picking a movement lands on its sheet, not back on the list',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final drafts = await pumpEditor(tester, container);

      await addBackSquat(tester);

      expect(drafts.map((d) => d.name), ['Bench Press', 'Back Squat'],
          reason: 'the movement is in the workout either way');
      expect(find.byType(ExercisePicker), findsNothing,
          reason: 'the picker closes behind the sheet');
      expect(find.byKey(kStepUpFieldKey), findsOneWidget,
          reason: 'no configuration sheet opened: adding an exercise is two '
              'taps, and the second one is the one people forget');
      // And it is the new slot's sheet, not the one that was already there.
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Back Squat'),
        ),
        findsOneWidget,
        reason: 'the sheet that opened belongs to another slot',
      );

      await stop(tester);
    });

    testWidgets('backing out of the sheet keeps the exercise at its defaults',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final drafts = await pumpEditor(tester, container);

      await addBackSquat(tester);
      // The sheet is for tuning the slot, not for confirming it, so leaving it
      // untouched is not the same as changing your mind about the exercise.
      await tester.tap(find.byTooltip(l10nFor().itemEditorClose));
      await tester.pumpAndSettle();

      expect(find.byKey(kStepUpFieldKey), findsNothing, reason: 'the sheet');
      expect(drafts.length, 2);
      final added = drafts.last;
      expect(added.name, 'Back Squat');
      expect(added.sets, 3);
      expect(added.repsMin, 8);
      expect(added.repsMax, isNull);
      expect(added.restSeconds, isNull, reason: "the routine's rest stands");
      expect(find.text('Back Squat'), findsOneWidget,
          reason: 'the slot is on the list, where it was added');

      await stop(tester);
    });
  });
}
