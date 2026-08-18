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
  /// on the one at [at] — the sheet is a sheet over a builder, so it is
  /// exercised the way the builder opens it rather than pumped bare.
  Future<void> openSheet(
    WidgetTester tester,
    ProviderContainer container,
    List<ItemDraft> drafts, {
    String unit = 'kg',
    Size size = const Size(390, 1400),
    int at = 0,
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
    await tester.tap(find.text(drafts[at].name));
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

  group('the weight is nudged by the amounts the slot progresses by', () {
    Finder weightBox() => find.descendant(
          of: find.byKey(kWeightFieldKey),
          matching: find.byType(TextField),
        );

    testWidgets('+ adds the step-up and − takes off the back-off',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;
      // The two rates are deliberately different sizes, which is the point:
      // this slot climbs 2.5 and drops 5.
      final draft = ItemDraft.forExercise(bench)
        ..weightKg = 100
        ..increment = 2.5
        ..deload = 5;

      await openSheet(tester, container, [draft]);

      await tester.tap(stepper(kWeightFieldKey, Icons.add));
      await tester.pumpAndSettle();
      expect(draft.weightKg, closeTo(102.5, 1e-9));
      expect(find.text('102.5'), findsWidgets);

      await tester.tap(stepper(kWeightFieldKey, Icons.remove));
      await tester.pumpAndSettle();
      expect(draft.weightKg, closeTo(97.5, 1e-9));

      await stop(tester);
    });

    testWidgets('a back-off of zero makes − fall back to the step-up',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;
      final draft = ItemDraft.forExercise(bench)
        ..weightKg = 100
        ..increment = 2.5
        ..deload = 0;

      await openSheet(tester, container, [draft]);

      await tester.tap(stepper(kWeightFieldKey, Icons.remove));
      await tester.pumpAndSettle();
      expect(draft.weightKg, closeTo(97.5, 1e-9),
          reason: 'a button that does nothing is not a button');

      await stop(tester);
    });

    testWidgets('on a reps axis the taps are worth the unit\'s own step',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;
      // The slot's rates are now counted in reps, so there is no weight rate to
      // borrow.
      final draft = ItemDraft.forExercise(bench)
        ..weightKg = 100
        ..setMode(ProgressionMode.reps, unit: 'kg');

      await openSheet(tester, container, [draft]);

      await tester.tap(stepper(kWeightFieldKey, Icons.add));
      await tester.pumpAndSettle();
      expect(draft.weightKg, closeTo(102.5, 1e-9));

      await stop(tester);
    });

    testWidgets('− stops at the empty bar', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;
      final draft = ItemDraft.forExercise(bench)
        ..weightKg = 22.5
        ..deload = 5;

      await openSheet(tester, container, [draft]);

      await tester.tap(stepper(kWeightFieldKey, Icons.remove));
      await tester.pumpAndSettle();
      expect(draft.weightKg, closeTo(20, 1e-9),
          reason: 'the bar is the floor on a barbell movement');

      await stop(tester);
    });

    testWidgets('an empty field has a dead − and a + that fills in the floor',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;
      final draft = ItemDraft.forExercise(bench)..weightKg = null;

      await openSheet(tester, container, [draft]);

      await tester.tap(stepper(kWeightFieldKey, Icons.remove));
      await tester.pumpAndSettle();
      expect(draft.weightKg, isNull);

      await tester.tap(stepper(kWeightFieldKey, Icons.add));
      await tester.pumpAndSettle();
      expect(draft.weightKg, closeTo(20, 1e-9));

      await stop(tester);
    });

    testWidgets('typing straight in is untouched by the buttons',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;
      final draft = ItemDraft.forExercise(bench)..weightKg = 100;

      await openSheet(tester, container, [draft]);

      await tester.enterText(weightBox(), '48.75');
      await tester.pumpAndSettle();
      expect(draft.weightKg, closeTo(48.75, 1e-9),
          reason: 'not rounded to a tap');

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
          muscles: MuscleMap.single('Shoulders'),
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
          muscles: MuscleMap.single('Legs'),
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

    test('a to-failure slot keeps its range and still says failure', () async {
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
      // The bound is stored as it stands: every reader asks about failure
      // before it asks about the range, so the sets still run to failure and
      // unticking gives the range back.
      expect(saved.repsMax, 8);
      expect(label(saved), l10nFor().targetFailure);
      expect(saved.goalReps, saved.repsMin,
          reason: 'the number a set has to beat, not the top of the range');
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
      'an axis the slot has not been on opens at that axis\'s defaults',
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

  group('switching the axis keeps the rates set on the axis left behind', () {
    test('the numbers typed on weight come back when weight does', () async {
      final bench = await exerciseNamed(db, 'Bench Press');
      final draft = ItemDraft.forExercise(bench)
        ..increment = 1.25
        ..deload = 7.5;

      draft.setMode(ProgressionMode.reps);
      expect(draft.increment, 1); // the reps axis, at its own defaults
      expect(draft.deload, 2);

      draft.setMode(ProgressionMode.weight);
      expect(draft.increment, 1.25); // not 2.5 — what was typed
      expect(draft.deload, 7.5);
    });

    test('each axis keeps its own pair across repeated switches', () async {
      final bench = await exerciseNamed(db, 'Bench Press');
      final draft = ItemDraft.forExercise(bench)..increment = 5;

      draft.setMode(ProgressionMode.reps);
      draft.increment = 3;
      draft.deload = 1;

      draft.setMode(ProgressionMode.weight);
      expect(draft.increment, 5);
      expect(draft.deload, 5);

      draft.setMode(ProgressionMode.reps);
      expect(draft.increment, 3);
      expect(draft.deload, 1);
    });

    test('only the axis in use reaches the database', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = await exerciseNamed(db, 'Bench Press');
      final draft = ItemDraft.forExercise(bench)
        ..increment = 1.25
        ..deload = 7.5
        ..setMode(ProgressionMode.reps);

      await db.replaceWorkoutItems(
        push,
        itemCompanions([draft], workoutId: push),
      );

      final saved = (await itemNamed(db, push, 'Bench Press')).item;
      expect(saved.progression, ProgressionMode.reps);
      expect(saved.increment, 1);
      expect(saved.deload, 2);
    });

    test('the set-aside rates outlive the sheet and the app', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = await exerciseNamed(db, 'Bench Press');
      final draft = ItemDraft.forExercise(bench)
        ..increment = 1.25
        ..deload = 7.5
        ..setMode(ProgressionMode.reps);

      await db.replaceWorkoutItems(
        push,
        itemCompanions([draft], workoutId: push),
      );

      // The sheet, the screen and the process are all gone: this is the slot as
      // the next session reads it off the phone.
      final reopened = ItemDraft.fromView(await itemNamed(db, push, 'Bench Press'));
      expect(reopened.progression, ProgressionMode.reps);

      reopened.setMode(ProgressionMode.weight);
      expect(reopened.increment, 1.25);
      expect(reopened.deload, 7.5);
    });

    test('the advanced axis keeps its own pair across a save', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = await exerciseNamed(db, 'Bench Press');
      final draft = ItemDraft.forExercise(bench)
        ..repsMin = 6
        ..repsMax = 8
        ..setAdvanced(true);
      draft
        ..increment = 5
        ..deload = 10
        ..setAdvanced(false);
      draft
        ..increment = 1.25
        ..deload = 7.5;

      await db.replaceWorkoutItems(
        push,
        itemCompanions([draft], workoutId: push),
      );

      final reopened = ItemDraft.fromView(await itemNamed(db, push, 'Bench Press'));
      expect(reopened.increment, 1.25, reason: 'the plain weight rates, in use');

      reopened.setAdvanced(true);
      expect(reopened.increment, 5);
      expect(reopened.deload, 10);
    });

    test('a slot saved from the live board keeps them too', () async {
      final push = await workoutIdNamed(db, 'Push');
      final view = await itemNamed(db, push, 'Bench Press');
      final draft = ItemDraft.fromView(view)
        ..increment = 1.25
        ..deload = 7.5
        ..setMode(ProgressionMode.reps);

      // The board's settings sheet writes the one slot through, keeping its id.
      await db.updateWorkoutItem(view.item.id, itemUpdate(draft));

      final reopened = ItemDraft.fromView(await itemNamed(db, push, 'Bench Press'))
        ..setMode(ProgressionMode.weight);
      expect(reopened.increment, 1.25);
      expect(reopened.deload, 7.5);
    });

    test(
      'a slot pushed off its axis by the library finds its numbers again',
      () async {
        final bench = await exerciseNamed(db, 'Bench Press');
        final draft = ItemDraft.forExercise(bench)
          ..increment = 1.25
          ..deload = 7.5;

        // The movement is reclassified as held while the sheet is open: the
        // weight axis is gone, so the slot is moved to time.
        final held = bench.copyWith(measure: ExerciseMeasure.time);
        draft.adoptExercise(held);
        expect(draft.progression, ProgressionMode.time);
        expect(draft.increment, 5); // time defaults
        expect(draft.deload, 10);

        // Reclassified back: time is no longer allowed, so the slot returns to
        // the weight axis — with the numbers it had there.
        draft.adoptExercise(bench);
        expect(draft.progression, ProgressionMode.weight);
        expect(draft.increment, 1.25);
        expect(draft.deload, 7.5);
      },
    );

    test(
      'the advanced axis opens at the weight rates and the rep defaults',
      () async {
        // It is the same load it was about to move, so its weight pair is the
        // slot's own; a rep is not a kilogram, so its rep pair starts at the
        // reps axis's defaults.
        final bench = await exerciseNamed(db, 'Bench Press');
        final draft = ItemDraft.forExercise(bench)
          ..repsMax = 8
          ..increment = 1.25
          ..deload = 7.5;

        draft.setAdvanced(true);

        expect(draft.progression, ProgressionMode.weight);
        expect(draft.increment, 1.25);
        expect(draft.deload, 7.5);
        expect(draft.repsIncrement, 1);
        expect(draft.repsDeload, 2);
      },
    );

    test('weight → advanced → weight finds the plain rates untouched', () async {
      final bench = await exerciseNamed(db, 'Bench Press');
      final draft = ItemDraft.forExercise(bench)
        ..repsMax = 8
        ..increment = 1.25
        ..deload = 7.5;

      draft.setAdvanced(true);
      draft
        ..increment = 5
        ..deload = 10
        ..repsIncrement = 2
        ..repsDeload = 3;

      draft.setAdvanced(false);
      expect(draft.increment, 1.25, reason: 'the plain weight rates, as left');
      expect(draft.deload, 7.5);

      // A third set of numbers on the same terms: the advanced axis keeps its
      // own pair too.
      draft.setAdvanced(true);
      expect(draft.increment, 5);
      expect(draft.deload, 10);
      expect(draft.repsIncrement, 2);
      expect(draft.repsDeload, 3);
    });

    test('reps → advanced puts the slot on weight and keeps the rep rates',
        () async {
      final bench = await exerciseNamed(db, 'Bench Press');
      final draft = ItemDraft.forExercise(bench)
        ..repsMax = 8
        ..increment = 1.25
        ..deload = 7.5;

      draft.setMode(ProgressionMode.reps);
      draft
        ..increment = 3
        ..deload = 1;

      draft.setAdvanced(true);
      expect(draft.progression, ProgressionMode.weight);
      expect(draft.increment, 1.25, reason: 'the weight rates it had');
      expect(draft.deload, 7.5);
      expect(draft.repsIncrement, 1, reason: 'the reps-axis defaults');
      expect(draft.repsDeload, 2);

      // And back to reps: the numbers typed against that axis are still there.
      draft.setMode(ProgressionMode.reps);
      expect(draft.increment, 3);
      expect(draft.deload, 1);
      expect(draft.addWeightAtTopOfRange, isFalse);
    });

    test('only the axis in use reaches the database, rep rates included',
        () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = await exerciseNamed(db, 'Bench Press');
      final draft = ItemDraft.forExercise(bench)
        ..repsMin = 6
        ..repsMax = 8
        ..setAdvanced(true)
        ..increment = 5
        ..repsIncrement = 2
        ..repsDeload = 3;

      await db.replaceWorkoutItems(
        push,
        itemCompanions([draft], workoutId: push),
      );

      final saved = (await itemNamed(db, push, 'Bench Press')).item;
      expect(saved.progression, ProgressionMode.weight);
      expect(saved.increment, 5);
      expect(saved.repsIncrement, 2);
      expect(saved.repsDeload, 3);
    });
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
      await db.advanceProgression(pullUp.id, verdict: SessionVerdict.success);

      final moved = await db.workoutItemById(pullUp.id);
      expect(moved!.repsMin, 7);
      expect(moved.repsMax, 11); // 6–10 becomes 7–11, width still 4
    });

    test('a back-off keeps the width on the way down too', () async {
      final pull = await workoutIdNamed(db, 'Pull');
      final pullUp = (await itemNamed(db, pull, 'Pull-Up')).item;

      // Two misses in a row (default failure threshold) back the range off.
      await db.advanceProgression(pullUp.id, verdict: SessionVerdict.miss);
      await db.advanceProgression(pullUp.id, verdict: SessionVerdict.miss);

      final moved = await db.workoutItemById(pullUp.id);
      final width = moved!.repsMax! - moved.repsMin;
      expect(width, 4); // still 6–10 wide, wherever it landed
    });

    test('a slot on the advanced axis does not move the range at all', () async {
      // There the range is the ladder and the goal is what climbs it, so the
      // range stays put whichever of the two axes pays out.
      final push = await workoutIdNamed(db, 'Push');
      final bench = await exerciseNamed(db, 'Bench Press');
      final draft = ItemDraft.forExercise(bench)
        ..repsMin = 6
        ..repsMax = 8
        ..weightKg = 80
        ..setAdvanced(true);
      await db.replaceWorkoutItems(
        push,
        itemCompanions([draft], workoutId: push),
      );
      final saved = (await itemNamed(db, push, 'Bench Press')).item;

      // A clean session at the bottom of the range: the goal climbs.
      await db.advanceProgression(saved.id,
          verdict: SessionVerdict.success, performedWeight: 80);
      var after = (await db.workoutItemById(saved.id))!;
      expect(after.goalReps, 7);
      expect(after.repsMin, 6);
      expect(after.repsMax, 8);

      // And again from the top, where the weight is what moves.
      await db.updateWorkoutItem(
        saved.id,
        const WorkoutItemsCompanion(repsTarget: Value(8)),
      );
      await db.advanceProgression(saved.id,
          verdict: SessionVerdict.success, performedWeight: 80);
      after = (await db.workoutItemById(saved.id))!;
      expect(after.suggestedWeight, 82.5);
      expect(after.repsMin, 6);
      expect(after.repsMax, 8);
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

    test('every computed weight keeps the arithmetic that made it', () {
      // 90% of 102.5 is 92.25, and that is what the set asks for — snapping to
      // the 2.5 kg a gym counts by would move it to 92.5 and make the app
      // disagree with its own percentage.
      expect(targets(SetScheme.backOff, top: 102.5).map((t) => t.weightKg),
          [102.5, 92.25, 82.0]);
      // The eighth of a kilogram is where it stops: 65% of 77 is 50.05.
      expect(
          targets(SetScheme.custom,
                  sets: 1,
                  top: 77,
                  custom: [const CustomSet(reps: 5, percent: 65)])
              .single
              .weightKg,
          closeTo(50, 1e-9));
      // And a pounds gym lands on the quarter pound instead.
      final lb = targets(SetScheme.custom,
          sets: 1,
          top: toKg(77, 'lb'),
          unit: 'lb',
          custom: [const CustomSet(reps: 5, percent: 65)]);
      expect(toDisplayWeight(lb.single.weightKg!, 'lb'), closeTo(50, 1e-9));
    });

    test('a training-max percentage is not rounded up to the next plate', () {
      // The bug this replaced: 65% of a 75 kg training max is 48.75, and the
      // board showed 50.
      expect(
          targets(SetScheme.custom,
                  sets: 1,
                  top: 75,
                  custom: [const CustomSet(reps: 5, percent: 65)])
              .single
              .weightKg,
          closeTo(48.75, 1e-9));
    });

    test('and never falls under the bar it is loaded on', () {
      final got =
          targets(SetScheme.backOff, sets: 4, percent: 30, top: 60, floorKg: 20);
      expect(got.map((t) => t.weightKg), [60, 42, 24, 20],
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
      expect(sets.map((s) => s.weight), [80, 72, 64],
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
      expect(sets[1].weight, 72);
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

  group('an Advanced toggle is a control the size of the pills above it', () {
    testWidgets('the Target one is no smaller than a mode pill',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final bench = (await tester.runAsync(() async =>
          ItemDraft.forExercise(await exerciseNamed(db, 'Bench Press'))))!;
      await openSheet(tester, container, [bench]);

      final toggle = tester.getSize(find.byKey(kAdvancedToggleKey));
      final pill = tester.getSize(find.byKey(kModeWeightKey));
      expect(toggle.height, greaterThanOrEqualTo(pill.height),
          reason: 'a line of small coloured text reads as a caption on the '
              'half above rather than the way into the half below');
    });
  });

  group('the advanced rule is a pill on the axis row and a tick', () {
    /// A Bench Press draft opened in the config sheet, [configure]d first.
    Future<ItemDraft> openDraft(
      WidgetTester tester,
      ProviderContainer container, {
      String exercise = 'Bench Press',
      Size size = const Size(390, 1400),
      void Function(ItemDraft)? configure,
    }) async {
      final draft = (await tester.runAsync(() async =>
          ItemDraft.forExercise(await exerciseNamed(db, exercise))))!;
      configure?.call(draft);
      await openSheet(tester, container, [draft], size: size);
      return draft;
    }

    /// The checkbox inside the range-climb row.
    Checkbox climbBox(WidgetTester tester) => tester.widget<Checkbox>(
        find.descendant(
            of: find.byKey(kRangeClimbKey), matching: find.byType(Checkbox)));

    Future<void> openProgressionAdvanced(WidgetTester tester) async {
      await tester.tap(find.byKey(kProgressionAdvancedKey));
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, Key key) async {
      await tester.tap(find.byKey(key), warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    testWidgets('a counted lift with a range is offered all three', (
      tester,
    ) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      await openDraft(tester, container, configure: (d) => d..repsMax = 8);

      expect(find.byKey(kModeWeightKey), findsOneWidget);
      expect(find.byKey(kModeRepsKey), findsOneWidget);
      expect(find.byKey(kModeAdvancedKey), findsOneWidget);
      expect(find.byKey(kModeTimeKey), findsNothing,
          reason: 'the row only ever shows axes the exercise allows');

      await stop(tester);
    });

    testWidgets('the Advanced pill turns the tick on and holds the weight axis',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final draft =
          await openDraft(tester, container, configure: (d) => d..repsMax = 8);
      await openProgressionAdvanced(tester);
      expect(climbBox(tester).value, isFalse, reason: 'off by default');

      await tap(tester, kModeAdvancedKey);

      expect(draft.addWeightAtTopOfRange, isTrue);
      expect(draft.onAdvancedAxis, isTrue);
      expect(draft.progression, ProgressionMode.weight,
          reason: 'the load is what waits at the top of the range');
      expect(climbBox(tester).value, isTrue, reason: 'one switch, two ways in');

      await stop(tester);
    });

    testWidgets('the Weight pill turns it back off and leaves the axis alone', (
      tester,
    ) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final draft = await openDraft(tester, container,
          configure: (d) => d
            ..repsMax = 8
            ..setAdvanced(true));

      await tap(tester, kModeWeightKey);

      expect(draft.addWeightAtTopOfRange, isFalse);
      expect(draft.onAdvancedAxis, isFalse);
      expect(draft.progression, ProgressionMode.weight);
      expect(climbBox(tester).value, isFalse);

      await stop(tester);
    });

    testWidgets('the Reps pill turns it off and moves the slot', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final draft = await openDraft(tester, container,
          configure: (d) => d
            ..repsMax = 8
            ..setAdvanced(true));

      await tap(tester, kModeRepsKey);

      expect(draft.addWeightAtTopOfRange, isFalse);
      expect(draft.progression, ProgressionMode.reps);

      await stop(tester);
    });

    testWidgets('the tick is the other way onto the pill', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      // Taller than the group's default: ticking it grows the card by two
      // amount fields and two lines of rule, and the row being tapped has to
      // stay in the viewport across both taps.
      final draft = await openDraft(tester, container,
          size: const Size(390, 1800), configure: (d) => d..repsMax = 8);
      await openProgressionAdvanced(tester);

      await tap(tester, kRangeClimbKey);
      expect(draft.onAdvancedAxis, isTrue);
      expect(find.byKey(kRepsStepUpFieldKey), findsOneWidget,
          reason: 'the axis row moved with it, and so did its amounts');

      await tap(tester, kRangeClimbKey);
      expect(draft.onAdvancedAxis, isFalse);
      expect(find.byKey(kRepsStepUpFieldKey), findsNothing);

      await stop(tester);
    });

    testWidgets('a slot on the reps axis may still pick Advanced', (
      tester,
    ) async {
      // Not a move the slot could make before: picking the advanced rule from
      // the Reps pill is legal, and it is what puts the slot on the weight axis.
      final container = containerFor(db);
      addTearDown(container.dispose);
      final draft = await openDraft(tester, container,
          configure: (d) => d
            ..repsMax = 10
            ..setMode(ProgressionMode.reps));

      await tap(tester, kModeAdvancedKey);

      expect(draft.onAdvancedAxis, isTrue);
      expect(draft.progression, ProgressionMode.weight);

      await stop(tester);
    });

    testWidgets('the pill does nothing while there is no range to climb', (
      tester,
    ) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final draft = await openDraft(tester, container);

      expect(find.byKey(kModeAdvancedKey), findsOneWidget,
          reason: 'greyed where it lives, not taken away');
      await tap(tester, kModeAdvancedKey);

      expect(draft.addWeightAtTopOfRange, isFalse);
      expect(draft.progression, ProgressionMode.weight);

      await stop(tester);
    });

    testWidgets('a held movement is never offered it', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      await openDraft(tester, container, exercise: 'Plank');

      expect(find.byKey(kModeAdvancedKey), findsNothing,
          reason: 'a hold has no second axis to take turns with');

      await stop(tester);
    });
  });

  group('the Progression card carries the advanced rule under its own Advanced',
      () {
    /// A Bench Press draft opened in the config sheet, [configure]d first.
    Future<ItemDraft> openDraft(
      WidgetTester tester,
      ProviderContainer container, {
      String exercise = 'Bench Press',
      Size size = const Size(390, 1400),
      void Function(ItemDraft)? configure,
    }) async {
      final draft = (await tester.runAsync(() async =>
          ItemDraft.forExercise(await exerciseNamed(db, exercise))))!;
      configure?.call(draft);
      await openSheet(tester, container, [draft], size: size);
      return draft;
    }

    /// The rep-range stepper — the one in the Target card's advanced half
    /// showing no upper bound yet, which is the only empty stepper the sheet
    /// draws.
    Finder emptyRangeStepper() =>
        find.byWidgetPredicate((w) => w is NumberStepper && w.isEmpty);

    /// The checkbox inside the range-climb row.
    Checkbox climbBox(WidgetTester tester) => tester.widget<Checkbox>(
        find.descendant(
            of: find.byKey(kRangeClimbKey), matching: find.byType(Checkbox)));

    /// Where a card's caption sits, so a row can be placed under the right one.
    double captionY(WidgetTester tester, String caption) =>
        tester.getTopLeft(find.text(caption.toUpperCase())).dy;

    Future<void> openProgressionAdvanced(WidgetTester tester) async {
      await tester.tap(find.byKey(kProgressionAdvancedKey));
      await tester.pumpAndSettle();
    }

    testWidgets('Advanced is shut by default and opens on a tap',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      await openDraft(tester, container, configure: (d) => d..repsMax = 8);

      expect(find.byKey(kProgressionAdvancedKey), findsOneWidget,
          reason: 'this slot has the range the one control behind it wants');
      expect(find.byKey(kRangeClimbKey), findsNothing,
          reason: 'the ways of advancing most slots never use start shut');

      await openProgressionAdvanced(tester);
      expect(find.byKey(kRangeClimbKey), findsOneWidget);

      await stop(tester);
    });

    testWidgets('a slot on the advanced axis opens Advanced already expanded',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      await openDraft(tester, container,
          configure: (d) => d
            ..repsMax = 8
            ..setAdvanced(true));

      // No tap: nothing a slot actually does is hidden behind a toggle
      // somebody has to think to press.
      expect(find.byKey(kRangeClimbKey), findsOneWidget);
      expect(climbBox(tester).value, isTrue);
      expect(tester.getTopLeft(find.byKey(kRangeClimbKey)).dy,
          greaterThan(captionY(tester, l10nFor().itemEditorProgression)),
          reason: 'it is in the Progression card, not the Target one');

      await stop(tester);
    });

    testWidgets('the Target card no longer offers it', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      // A rep range opens the Target card's advanced half on its own, so this
      // is the card at its most open.
      await openDraft(tester, container, configure: (d) => d..repsMax = 8);

      expect(fieldLabel(l10nFor().itemEditorRepRange), findsOneWidget,
          reason: 'the Target card is open, so this is not a closed-card pass');
      expect(find.text(l10nFor().itemEditorToFailure), findsOneWidget);
      expect(find.byKey(kRangeClimbKey), findsNothing,
          reason: 'progression is configured in one place, and it is not here');

      await stop(tester);
    });

    testWidgets('the tick sits under the line saying what it does', (
      tester,
    ) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final l10n = l10nFor();
      await openDraft(tester, container, configure: (d) => d..repsMax = 8);
      await openProgressionAdvanced(tester);

      expect(find.text(l10n.itemEditorAddWeightAtTop), findsOneWidget);
      expect(find.text(l10n.itemEditorAddWeightAtTopHint), findsOneWidget,
          reason: 'what the combination does, whether or not it can be ticked');
      expect(find.text(l10n.itemEditorRangeClimbNeedsRange), findsNothing,
          reason: 'it has its range; there is nothing left to ask for');

      await stop(tester);
    });

    testWidgets('a fixed rep count gets no toggle, and a greyed pill instead',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      await openDraft(tester, container);

      expect(find.byKey(kProgressionAdvancedKey), findsNothing,
          reason: 'the toggle holds one control, and it cannot be taken');
      expect(find.byKey(kRangeClimbKey), findsNothing);
      expect(find.byKey(kModeAdvancedKey), findsOneWidget,
          reason: 'a control that vanishes entirely teaches nobody where it '
              'went — the pill on the axis row is what stays');
      expect(tester.widget<EditorPill>(find.byKey(kModeAdvancedKey)).onTap,
          isNull,
          reason: 'shown, and doing nothing when tapped');

      await stop(tester);
    });

    testWidgets('a slot running to failure loses it the same way',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      // A range it is not aiming at, which is not a range to climb.
      await openDraft(tester, container,
          configure: (d) => d
            ..repsMax = 8
            ..toFailure = true);

      expect(find.byKey(kProgressionAdvancedKey), findsNothing);
      expect(tester.widget<EditorPill>(find.byKey(kModeAdvancedKey)).onTap,
          isNull);

      await stop(tester);
    });

    testWidgets('a slot on the reps axis with a range may take it', (
      tester,
    ) async {
      // The tick asks whether the rule is available, not which axis the slot is
      // on: coming to it from Reps is a legal move, and taking it moves the
      // slot to the weight axis.
      final container = containerFor(db);
      addTearDown(container.dispose);
      final draft = await openDraft(tester, container,
          configure: (d) => d
            ..repsMax = 10
            ..setMode(ProgressionMode.reps));

      await openProgressionAdvanced(tester);

      expect(draft.canClimbRange, isTrue);
      expect(climbBox(tester).onChanged, isNotNull);
      expect(find.text(l10nFor().itemEditorRangeClimbNeedsRange), findsNothing);

      await tester.tap(find.byKey(kRangeClimbKey));
      await tester.pumpAndSettle();
      expect(draft.onAdvancedAxis, isTrue);
      expect(draft.progression, ProgressionMode.weight);

      await stop(tester);
    });

    testWidgets('a timed slot is offered none of it', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      await openDraft(tester, container, exercise: 'Plank');

      // No second axis to take turns with, so not even the pill: the axis row
      // only ever shows axes the exercise allows.
      expect(find.byKey(kModeAdvancedKey), findsNothing);
      expect(find.byKey(kProgressionAdvancedKey), findsNothing);
      expect(find.byKey(kRangeClimbKey), findsNothing);

      await stop(tester);
    });

    testWidgets('the upper bound brings it alive without moving the row',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final draft = await openDraft(tester, container);

      // The range is authored in Target, the climb in Progression, and the
      // second must react to the first.
      await tester.tap(find.byKey(kAdvancedToggleKey));
      await tester.pumpAndSettle();
      expect(find.byKey(kProgressionAdvancedKey), findsNothing);

      // + on the empty rep-range stepper fills the upper bound in.
      await tester.tap(find.descendant(
          of: emptyRangeStepper(), matching: find.byIcon(Icons.add)));
      await tester.pumpAndSettle();

      expect(draft.repsMax, isNotNull);
      expect(find.byKey(kProgressionAdvancedKey), findsOneWidget,
          reason: 'the toggle arrives with something behind it to open');
      await openProgressionAdvanced(tester);
      expect(climbBox(tester).onChanged, isNotNull, reason: 'now tickable');
      expect(find.text(l10nFor().itemEditorRangeClimbNeedsRange), findsNothing,
          reason: 'it has what it wanted');

      await stop(tester);
    });

    test('the tick, the rates and the goal round-trip through a save', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = await exerciseNamed(db, 'Bench Press');

      final draft = ItemDraft.forExercise(bench)
        ..repsMin = 6
        ..repsMax = 8
        ..setAdvanced(true)
        ..repsIncrement = 2
        ..repsDeload = 3
        // Carried, not edited — like the streaks. Renaming the day must not
        // put somebody back at the bottom of their range.
        ..repsTarget = 7;
      await db.replaceWorkoutItems(
        push,
        itemCompanions([draft], workoutId: push),
      );

      final saved = await itemNamed(db, push, 'Bench Press');
      expect(saved.item.addWeightAtTopOfRange, isTrue);
      expect(saved.item.repsIncrement, 2);
      expect(saved.item.repsDeload, 3);
      expect(saved.item.repsTarget, 7);
      expect(saved.item.climbsRange, isTrue);

      // And back into a draft, so reopening the sheet finds it as it was.
      final back = ItemDraft.fromView(saved);
      expect(back.onAdvancedAxis, isTrue);
      expect(back.repsIncrement, 2);
      expect(back.repsDeload, 3);
      expect(back.repsTarget, 7);
    });

    test('an untouched slot saves with it off, at the rep defaults', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = (await itemNamed(db, push, 'Bench Press')).item;
      expect(bench.repsMax, 8);
      expect(bench.addWeightAtTopOfRange, isFalse);
      expect(bench.repsIncrement, 1);
      expect(bench.repsDeload, 2);
      expect(bench.repsTarget, isNull);
    });
  });

  group('the advanced axis asks for both pairs of amounts', () {
    /// A Bench Press draft opened in the config sheet, [configure]d first.
    Future<ItemDraft> openDraft(
      WidgetTester tester,
      ProviderContainer container, {
      void Function(ItemDraft)? configure,
    }) async {
      final draft = (await tester.runAsync(() async =>
          ItemDraft.forExercise(await exerciseNamed(db, 'Bench Press'))))!;
      configure?.call(draft);
      await openSheet(tester, container, [draft]);
      return draft;
    }

    /// A slot on the advanced axis, 6–8 at the untouched defaults.
    Future<ItemDraft> openAdvanced(
      WidgetTester tester,
      ProviderContainer container,
    ) =>
        openDraft(tester, container,
            configure: (d) => d
              ..repsMin = 6
              ..repsMax = 8
              ..setAdvanced(true));

    testWidgets('four amounts and one pair of thresholds', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final l10n = l10nFor();
      await openAdvanced(tester, container);

      expect(find.byKey(kStepUpFieldKey), findsOneWidget);
      expect(find.byKey(kBackOffFieldKey), findsOneWidget);
      expect(find.byKey(kRepsStepUpFieldKey), findsOneWidget);
      expect(find.byKey(kRepsBackOffFieldKey), findsOneWidget);

      expect(fieldLabel(l10n.itemEditorStepUpWeight), findsOneWidget);
      expect(fieldLabel(l10n.itemEditorStepUpReps), findsOneWidget);
      expect(fieldLabel(l10n.itemEditorBackOffWeight), findsOneWidget);
      expect(fieldLabel(l10n.itemEditorBackOffReps), findsOneWidget);

      // One clean-session count and one miss count govern both axes: a session
      // is clean or missed for the slot, not for one of its axes.
      expect(fieldLabel(l10n.itemEditorCleanSessions), findsOneWidget);
      expect(fieldLabel(l10n.itemEditorMisses), findsOneWidget);

      await stop(tester);
    });

    testWidgets('an ordinary weight slot asks for one pair', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final l10n = l10nFor();
      await openDraft(tester, container, configure: (d) => d..repsMax = 8);

      expect(find.byKey(kRepsStepUpFieldKey), findsNothing);
      expect(find.byKey(kRepsBackOffFieldKey), findsNothing);
      expect(fieldLabel(l10n.itemEditorStepUpBy), findsOneWidget);
      expect(fieldLabel(l10n.itemEditorBackOffBy), findsOneWidget);

      await stop(tester);
    });

    testWidgets('the rep pair moves a rep at a time', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final draft = await openAdvanced(tester, container);
      expect(draft.repsIncrement, 1);
      expect(draft.repsDeload, 2);

      await tester.tap(stepper(kRepsStepUpFieldKey, Icons.add));
      await tester.pumpAndSettle();
      expect(draft.repsIncrement, 2);

      await tester.tap(stepper(kRepsBackOffFieldKey, Icons.remove));
      await tester.pumpAndSettle();
      expect(draft.repsDeload, 1);

      await stop(tester);
    });

    testWidgets('the weight pair is still the weight pair', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final draft = await openAdvanced(tester, container);

      await tester.tap(stepper(kStepUpFieldKey, Icons.add));
      await tester.pumpAndSettle();
      expect(draft.increment, closeTo(3.75, 0.001), reason: 'one tap of 1.25 kg');

      await stop(tester);
    });

    testWidgets('the rule is read back as the three sentences it is', (
      tester,
    ) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final l10n = l10nFor();
      await openAdvanced(tester, container);

      // What a clean session and a miss do to the reps…
      expect(
        find.text(l10n.itemEditorProgressionRule(
          progressionAmount(l10n, 1, ProgressionMode.reps, 'kg'),
          1,
          progressionAmount(l10n, 2, ProgressionMode.reps, 'kg'),
          2,
        )),
        findsOneWidget,
      );
      // …what happens at the top of the range…
      expect(
        find.text(l10n.itemEditorRuleAtTop(
          8,
          progressionAmount(l10n, 2.5, ProgressionMode.weight, 'kg'),
          6,
        )),
        findsOneWidget,
      );
      // …and what happens at the bottom.
      expect(
        find.text(l10n.itemEditorRuleAtBottom(
          6,
          progressionAmount(l10n, 5, ProgressionMode.weight, 'kg'),
          8,
        )),
        findsOneWidget,
      );

      await stop(tester);
    });

    testWidgets('an ordinary slot keeps the one sentence', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final l10n = l10nFor();
      await openDraft(tester, container, configure: (d) => d..repsMax = 8);

      expect(
        find.text(l10n.itemEditorProgressionRule(
          progressionAmount(l10n, 2.5, ProgressionMode.weight, 'kg'),
          1,
          progressionAmount(l10n, 5, ProgressionMode.weight, 'kg'),
          2,
        )),
        findsOneWidget,
      );
      expect(
        find.text(l10n.itemEditorRuleAtTop(
          8,
          progressionAmount(l10n, 2.5, ProgressionMode.weight, 'kg'),
          6,
        )),
        findsNothing,
        reason: 'there is no top to reach on a slot that is not climbing',
      );

      await stop(tester);
    });
  });

  group('ticking to failure greys the rep range rather than taking it away', () {
    /// A Bench Press draft opened in the config sheet with its Target card's
    /// advanced half open — a rep range opens it on its own.
    Future<ItemDraft> openRanged(
      WidgetTester tester,
      ProviderContainer container, {
      bool toFailure = false,
    }) async {
      final draft = (await tester.runAsync(() async =>
          ItemDraft.forExercise(await exerciseNamed(db, 'Bench Press'))))!
        ..repsMin = 6
        ..repsMax = 8
        ..toFailure = toFailure;
      await openSheet(tester, container, [draft]);
      return draft;
    }

    NumberStepper rangeStepper(WidgetTester tester) =>
        tester.widget<NumberStepper>(find.byKey(kRepRangeFieldKey));

    testWidgets('the stepper goes dead and keeps the bound it had', (
      tester,
    ) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final draft = await openRanged(tester, container, toFailure: true);

      expect(find.byKey(kRepRangeFieldKey), findsOneWidget,
          reason: 'a field that vanishes takes the number with it');
      expect(rangeStepper(tester).enabled, isFalse);
      expect(find.text('8'), findsWidgets, reason: 'the bound is still on screen');

      await tester.tap(stepper(kRepRangeFieldKey, Icons.add),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(stepper(kRepRangeFieldKey, Icons.remove),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(draft.repsMax, 8, reason: 'both buttons are dead');

      await stop(tester);
    });

    testWidgets('unticking gives it back where it was', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final draft = await openRanged(tester, container, toFailure: true);

      await tester.tap(find.text(l10nFor().itemEditorToFailure));
      await tester.pumpAndSettle();

      expect(draft.toFailure, isFalse);
      expect(draft.repsMax, 8);
      expect(rangeStepper(tester).enabled, isTrue);

      await stop(tester);
    });

    test('and it survives a save and a reopen', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = await exerciseNamed(db, 'Bench Press');

      await db.replaceWorkoutItems(
        push,
        itemCompanions([
          ItemDraft.forExercise(bench)
            ..repsMin = 6
            ..repsMax = 8
            ..toFailure = true
        ], workoutId: push),
      );

      final saved = await itemNamed(db, push, 'Bench Press');
      expect(saved.item.toFailure, isTrue);
      expect(saved.item.repsMax, 8, reason: 'stored as it stands');

      // Reopened and unticked: the range is exactly where it was left.
      final back = ItemDraft.fromView(saved)..toFailure = false;
      expect(back.repsMax, 8);
      await db.replaceWorkoutItems(
        push,
        itemCompanions([back], workoutId: push),
      );
      expect((await itemNamed(db, push, 'Bench Press')).item.repsMax, 8);
    });

    test('a to-failure slot still trains to failure', () async {
      final bench = await exerciseNamed(db, 'Bench Press');
      final draft = ItemDraft.forExercise(bench)
        ..repsMin = 6
        ..repsMax = 8
        ..toFailure = true;

      // Every reader asks about failure before it asks about the range.
      expect(draft.canClimbRange, isFalse);
      expect(
        draft.targets(unit: 'kg').map((t) => t.reps),
        everyElement(6),
        reason: 'the number a set has to beat, not the top of the range',
      );
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

      final moved =
          await db.advanceProgression(bench.id, verdict: SessionVerdict.success);

      expect(moved.moved, 2.5);
      expect(moved.axis, ProgressionMode.weight);
      expect((await db.workoutItemById(bench.id))!.suggestedWeight, 82.5);
    });

    test('two misses in a row drop a weight slot by 5 kg', () async {
      final push = await workoutIdNamed(db, 'Push');
      final bench = (await itemNamed(db, push, 'Bench Press')).item;

      // First miss: nothing moves yet (streak of one).
      await db.advanceProgression(bench.id, verdict: SessionVerdict.miss);
      expect((await db.workoutItemById(bench.id))!.suggestedWeight, 80);

      // Second miss in a row: the back-off lands.
      await db.advanceProgression(bench.id, verdict: SessionVerdict.miss);
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
    ///
    /// **Narrowing is not the same as arriving at the row.** The muscle filter
    /// keeps everything that *assists* the group as well as everything named
    /// after it, and those sections sort ahead of it — so Legs puts three
    /// headings above the squats and the list runs well past the bottom of the
    /// phone. Hence the scroll, and `hitTestable`: a lazy list builds a screenful
    /// either side of what is showing, so a row can exist while sitting below the
    /// bottom edge, and tapping one of those lands on the sheet's barrier and
    /// closes it.
    Future<void> addBackSquat(WidgetTester tester) async {
      await tester.tap(find.text(l10nFor().itemEditorAdd));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(filterButtonKey('muscle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(filterChipKey('muscle', 'Legs')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(kFilterSheetDoneKey));
      await tester.pumpAndSettle();
      final row = find.text('Back Squat').hitTestable();
      for (var drag = 0; drag < 40 && row.evaluate().isEmpty; drag++) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      await tester.tap(row);
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

  group('a slot can be joined to the one above it as a superset', () {
    /// The exercise list on [drafts], mounted the way the workout builder mounts
    /// it and with no sheet open. The list handed in is the one the editor writes
    /// into, so a test can read what the taps and the drags did.
    Future<void> pumpList(
      WidgetTester tester,
      ProviderContainer container,
      List<ItemDraft> drafts,
    ) async {
      tester.view.physicalSize = const Size(390, 1400);
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
    }

    /// Drafts for [names], in order, with the ones at [joined] tied to the slot
    /// above them.
    Future<List<ItemDraft>> draftsFor(
      WidgetTester tester,
      List<String> names, {
      Set<int> joined = const {},
    }) async =>
        (await tester.runAsync(() async => [
              for (var i = 0; i < names.length; i++)
                ItemDraft.forExercise(await exerciseNamed(db, names[i]))
                  ..supersetWithPrevious = joined.contains(i),
            ]))!;

    /// Drags the [index]th grab handle by [dy], in steps — the reorderable
    /// decides where a row belongs from how far the pointer has travelled, so
    /// one teleporting move tells it nothing.
    Future<void> dragRow(WidgetTester tester, int index, double dy) async {
      final handle = find.byIcon(Icons.drag_indicator).at(index);
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(Offset(0, dy / 8));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('the first slot of a workout has nothing above it to join to',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final drafts =
          await draftsFor(tester, ['Bench Press', 'Overhead Press']);

      await openSheet(tester, container, drafts);
      expect(find.byKey(_supersetCheck), findsNothing,
          reason: 'a control that could only be ticked against nothing');
      await stop(tester);

      await openSheet(tester, container, drafts, at: 1);
      expect(find.byKey(_supersetCheck), findsOneWidget);
      expect(
        find.text(l10nFor().itemEditorSupersetWith('Bench Press')),
        findsOneWidget,
        reason: 'the control names the exercise directly above it',
      );

      await stop(tester);
    });

    testWidgets('ticking it joins the pair', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final drafts =
          await draftsFor(tester, ['Bench Press', 'Overhead Press']);

      await openSheet(tester, container, drafts, at: 1);
      await tester.tap(find.byKey(_supersetCheck));
      await tester.pumpAndSettle();

      expect(drafts[1].supersetWithPrevious, isTrue);
      expect(drafts[0].supersetWithPrevious, isFalse);

      await stop(tester);
    });

    // The trip through the database the builder makes on save, without a tree
    // over it. **Not a widget test**, and not for tidiness: a query issued after
    // a write waits for the write's stream update to be delivered, and a widget
    // test parks that delivery until the tree is pumped — which cannot happen
    // inside the `runAsync` the write needs. Save-and-read-back belongs where
    // there is no fake clock to deadlock against.
    test('and saving keeps them joined', () async {
      final drafts = [
        for (final name in ['Bench Press', 'Overhead Press'])
          ItemDraft.forExercise(await exerciseNamed(db, name)),
      ];
      drafts[1].supersetWithPrevious = true;

      final rid = await db.createRoutine(
          name: 'Joined', color: 'FF0000', restSeconds: 90);
      final wid = await db.createWorkout(rid, 'Day');
      await db.replaceWorkoutItems(wid, itemCompanions(drafts, workoutId: wid));
      final saved = await db.itemsForWorkout(wid);

      expect(saved.map((v) => v.exercise.name),
          ['Bench Press', 'Overhead Press']);
      expect(saved.map((v) => v.item.supersetWithPrevious), [false, true]);
      // And a reload of the same workout opens on the same pair.
      expect(saved.map((v) => ItemDraft.fromView(v).supersetWithPrevious),
          [false, true]);
    });

    testWidgets('a superset reads as a group in the exercise list',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final l10n = l10nFor();

      await pumpList(
        tester,
        container,
        await draftsFor(tester, ['Bench Press', 'Overhead Press']),
      );
      expect(find.text(l10n.commonSuperset), findsNothing,
          reason: 'nothing is joined');
      await stop(tester);

      await pumpList(
        tester,
        container,
        await draftsFor(tester, ['Bench Press', 'Overhead Press'],
            joined: {1}),
      );

      expect(find.text(l10n.commonSuperset), findsOneWidget,
          reason: 'the top row of the group is tagged, once');
      // Each row keeps its own target line: a group is a way of performing
      // slots, not a slot of its own.
      expect(find.text('Overhead Press'), findsOneWidget);
      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));

      await stop(tester);
    });

    testWidgets('a joined slot dragged to the top of the list is unjoined',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final drafts = await draftsFor(
          tester, ['Bench Press', 'Overhead Press'], joined: {1});
      await pumpList(tester, container, drafts);

      // Overhead Press is the joined row; drag it above Bench Press.
      final gap = tester.getTopLeft(find.text('Overhead Press')).dy -
          tester.getTopLeft(find.text('Bench Press')).dy;
      await dragRow(tester, 1, -(gap + 10));

      expect(drafts.map((d) => d.name), ['Overhead Press', 'Bench Press'],
          reason: 'the dragged row did not move');
      expect(drafts.map((d) => d.supersetWithPrevious), [false, false],
          reason: 'the row at the top has nothing above it to be joined to');
      expect(find.text(l10nFor().commonSuperset), findsNothing);

      // Dragging it back down does not restore the join: it belonged to a pair,
      // and which pair is exactly what the drag changed.
      await dragRow(tester, 0, gap + 10);

      expect(drafts.map((d) => d.name), ['Bench Press', 'Overhead Press']);
      expect(drafts.map((d) => d.supersetWithPrevious), [false, false]);

      await stop(tester);
    });

    testWidgets('removing the top row of a superset leaves the rest a group',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final drafts = await draftsFor(
        tester,
        ['Bench Press', 'Overhead Press', 'Incline DB Press'],
        joined: {1, 2},
      );
      await pumpList(tester, container, drafts);
      expect(find.text(l10nFor().commonSuperset), findsOneWidget);

      // Delete the first of the three.
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      expect(drafts.map((d) => d.name), ['Overhead Press', 'Incline DB Press']);
      expect(drafts.map((d) => d.supersetWithPrevious), [false, true],
          reason: 'the second row becomes the top of a group of two');
      expect(find.text(l10nFor().commonSuperset), findsOneWidget);

      // Delete all but one and that one is an ordinary slot again.
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      expect(drafts.map((d) => d.name), ['Incline DB Press']);
      expect(drafts.single.supersetWithPrevious, isFalse);
      expect(find.text(l10nFor().commonSuperset), findsNothing);

      await stop(tester);
    });
  });
}

/// The one checkbox that joins a slot to the one above it.
const _supersetCheck = ValueKey('superset-with-previous');
