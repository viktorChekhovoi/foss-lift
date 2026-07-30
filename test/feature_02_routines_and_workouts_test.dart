// Integration tests for features/index.html#sec02
//
// The three-level template hierarchy — routine → workout (training day) →
// exercise slot. Two demo routines seeded on first launch; one current routine;
// split editing where reordering days never disturbs their exercises; drafts
// built in memory before saving; a deleted current routine degrading to "none".
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/routine_edit_screen.dart';
import 'package:foss_lift/screens/routines_screen.dart';
import 'package:foss_lift/screens/today_screen.dart';
import 'package:foss_lift/widgets/builder_widgets.dart';
import 'package:foss_lift/widgets/exercise_filters.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

/// Whether the text [finder] found had to be cut short to fit where it is.
///
/// The rendered paragraph is asked directly, so this is a claim about the
/// layout at the viewport under test rather than about a font size.
bool wasTruncated(WidgetTester tester, Finder finder) =>
    (tester.renderObject(finder) as RenderParagraph).didExceedMaxLines;

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  group('seeded hierarchy', () {
    test('two demo routines are seeded, with their day counts', () async {
      final routines = await db.watchRoutines().first;

      expect(
        routines.map((r) => r.routine.name),
        containsAll(['Push / Pull / Legs', 'Upper / Lower']),
      );
      expect(
        (await routineWithCountNamed(db, 'Push / Pull / Legs')).workoutCount,
        3,
      );
      expect(
        (await routineWithCountNamed(db, 'Upper / Lower')).workoutCount,
        4,
      );
    });

    test('a routine holds its ordered training days', () async {
      final ppl = await routineWithCountNamed(db, 'Push / Pull / Legs');
      final days = await db.workoutsForRoutine(ppl.routine.id);

      expect(days.map((w) => w.name), ['Push', 'Pull', 'Legs']);
    });

    test('a training day holds its ordered exercise slots', () async {
      final push = await workoutNamed(db, 'Push');
      final items = await db.itemsForWorkout(push.id);

      expect(items, hasLength(5));
      final first = items.first;
      expect(first.exercise.name, 'Bench Press');
      expect(first.item.targetSets, 4);
      expect(first.item.repsMin, 6);
      expect(first.item.repsMax, 8);
      expect(first.item.suggestedWeight, 80);
    });
  });

  group('workout names need not be unique inside a routine', () {
    test('two days in the same routine may share a name', () async {
      final ppl = await routineWithCountNamed(db, 'Push / Pull / Legs');
      await db.createWorkout(ppl.routine.id, 'Push');

      final pushes = (await db.workoutsForRoutine(
        ppl.routine.id,
      )).where((w) => w.name == 'Push').toList();
      expect(pushes, hasLength(2));
    });
  });

  group('the current routine', () {
    test('is seeded to PPL and resolves through the provider', () async {
      final ppl = await routineWithCountNamed(db, 'Push / Pull / Legs');
      final container = containerFor(db);
      addTearDown(container.dispose);
      container.listen(currentRoutineProvider, (_, _) {});

      await container.read(routinesProvider.future);
      await container.read(activeRoutineIdProvider.future);

      expect(
        container.read(currentRoutineProvider)?.routine.id,
        ppl.routine.id,
      );
    });

    test(
      'changing the active routine changes what resolves as current',
      () async {
        final upper = await routineWithCountNamed(db, 'Upper / Lower');
        await db.setActiveRoutineId(upper.routine.id);

        final container = containerFor(db);
        addTearDown(container.dispose);
        container.listen(currentRoutineProvider, (_, _) {});
        await container.read(routinesProvider.future);
        await container.read(activeRoutineIdProvider.future);

        expect(
          container.read(currentRoutineProvider)?.routine.name,
          'Upper / Lower',
        );
      },
    );

    test('clearing the active routine leaves no current routine', () async {
      await db.setActiveRoutineId(null);

      final container = containerFor(db);
      addTearDown(container.dispose);
      container.listen(currentRoutineProvider, (_, _) {});
      await container.read(routinesProvider.future);
      await container.read(activeRoutineIdProvider.future);

      expect(container.read(currentRoutineProvider), isNull);
    });
  });

  group('editing is split to match the hierarchy', () {
    test('reordering and renaming days never touches their exercises', () async {
      final ppl = await routineWithCountNamed(db, 'Push / Pull / Legs');
      final rid = ppl.routine.id;
      final days = await db.workoutsForRoutine(rid);
      final push = days.firstWhere((w) => w.name == 'Push');
      final legs = days.firstWhere((w) => w.name == 'Legs');
      final pushItemsBefore = await db.itemsForWorkout(push.id);

      // Legs first, Push renamed, Pull unchanged — items:null everywhere means
      // "leave the exercises alone".
      final reordered = [
        for (final w in [legs, ...days.where((d) => d.id != legs.id)])
          (id: w.id, name: w.id == push.id ? 'Press Day' : w.name, items: null)
              as WorkoutDraft,
      ];
      await db.replaceRoutineWorkouts(rid, reordered);

      final after = await db.workoutsForRoutine(rid);
      expect(after.first.name, 'Legs'); // reordered to the front
      expect(after.any((w) => w.name == 'Press Day'), isTrue); // renamed
      // The renamed day kept every exercise it had.
      final pushItemsAfter = await db.itemsForWorkout(push.id);
      expect(
        pushItemsAfter.map((v) => v.exercise.name),
        pushItemsBefore.map((v) => v.exercise.name),
      );
    });

    test('only workouts actually removed from the list are deleted', () async {
      final ppl = await routineWithCountNamed(db, 'Push / Pull / Legs');
      final rid = ppl.routine.id;
      final days = await db.workoutsForRoutine(rid);
      final legs = days.firstWhere((w) => w.name == 'Legs');

      // Drop Legs; keep Push and Pull.
      final kept = [
        for (final w in days.where((d) => d.id != legs.id))
          (id: w.id, name: w.name, items: null) as WorkoutDraft,
      ];
      await db.replaceRoutineWorkouts(rid, kept);

      final after = await db.workoutsForRoutine(rid);
      expect(after.map((w) => w.name), ['Push', 'Pull']);
      // Legs' exercises cascaded away with it.
      expect(await db.itemsForWorkout(legs.id), isEmpty);
    });

    test(
      'a draft carrying items replaces just that day\'s exercises',
      () async {
        final ppl = await routineWithCountNamed(db, 'Push / Pull / Legs');
        final rid = ppl.routine.id;
        final days = await db.workoutsForRoutine(rid);
        final push = days.firstWhere((w) => w.name == 'Push');
        final pull = days.firstWhere((w) => w.name == 'Pull');
        final pullItemsBefore = await db.itemsForWorkout(pull.id);

        final squat = await exerciseNamed(db, 'Back Squat');
        final drafts = <WorkoutDraft>[
          for (final w in days)
            (
              id: w.id,
              name: w.name,
              // Only Push gets a new exercise list; the rest keep theirs.
              items: w.id == push.id
                  ? itemCompanions([
                      ItemDraft.forExercise(squat),
                    ], workoutId: w.id)
                  : null,
            ),
        ];
        await db.replaceRoutineWorkouts(rid, drafts);

        final pushAfter = await db.itemsForWorkout(push.id);
        expect(pushAfter.map((v) => v.exercise.name), ['Back Squat']);
        // Pull, passed items:null, is untouched.
        final pullAfter = await db.itemsForWorkout(pull.id);
        expect(
          pullAfter.map((v) => v.exercise.name),
          pullItemsBefore.map((v) => v.exercise.name),
        );
      },
    );
  });

  group('building a routine before saving it', () {
    test('drafts held in memory are written on save', () async {
      // No routine, no workout, no items exist yet — build them in memory.
      final bench = await exerciseNamed(db, 'Bench Press');
      final ohp = await exerciseNamed(db, 'Overhead Press');
      final drafts = [
        ItemDraft.forExercise(bench)
          ..sets = 5
          ..repsMin = 5
          ..weightKg = 100,
        ItemDraft.forExercise(ohp)..sets = 3,
      ];

      final rid = await db.createRoutine(
        name: 'My Split',
        color: 'FF6A3D',
        restSeconds: 90,
      );
      final ids = await db.replaceRoutineWorkouts(rid, [
        (id: null, name: 'Day 1', items: itemCompanions(drafts)),
      ]);

      final saved = await db.itemsForWorkout(ids.single);
      expect(saved.map((v) => v.exercise.name), [
        'Bench Press',
        'Overhead Press',
      ]);
      expect(saved.first.item.targetSets, 5);
      expect(saved.first.item.suggestedWeight, 100);
    });
  });

  group('a deleted current routine degrades to "none"', () {
    test('the current routine resolves to null once it is deleted', () async {
      final ppl = await routineWithCountNamed(db, 'Push / Pull / Legs');
      // It is the seeded current routine; delete it out from under Today.
      await db.deleteRoutine(ppl.routine.id);

      final container = containerFor(db);
      addTearDown(container.dispose);
      container.listen(currentRoutineProvider, (_, _) {});
      await container.read(routinesProvider.future);
      await container.read(activeRoutineIdProvider.future);

      // The stored active id still dangles at the deleted routine, but nothing
      // resolves it — Today falls back to the chooser.
      expect(container.read(currentRoutineProvider), isNull);
    });
  });

  group('a routine name gets the room it needs', () {
    /// The seeded routine names are the case that has to work: "Push / Pull /
    /// Legs" is ordinary, and cutting it to "Push / Pull / L…" on the first
    /// screen of the app is not a layout, it is a bug.
    Future<ProviderContainer> pumpAt(
      WidgetTester tester,
      Widget screen, {
      double textScale = 1.0,
    }) async {
      // A Pixel 4a is 393 dp wide; 390 is the number to design to.
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        appUnder(container, Scaffold(body: screen), textScale: textScale),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('Today gives it the whole row, not half of one', (
      tester,
    ) async {
      await pumpAt(tester, const TodayScreen());

      final heading = find.text(kPpl.toUpperCase());
      expect(heading, findsOneWidget);
      // "LIFETIME" is one line of the same style further down the screen, so
      // equal heights mean the routine name fitted on one line too — which it
      // cannot do if something beside it is taking half the row.
      expect(
        tester.getSize(heading).height,
        tester.getSize(find.text('LIFETIME')).height,
        reason: 'the routine name is being squeezed onto a second line',
      );
      // The action beside it is still there, and still on the right.
      final change = find.text('Change');
      expect(change, findsOneWidget);
      expect(tester.getRect(change).right, greaterThan(300.0));

      await stop(tester);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('Today shows it whole at $scale×', (tester) async {
        await pumpAt(tester, const TodayScreen(), textScale: scale);

        final heading = find.text(kPpl.toUpperCase());
        expect(heading, findsOneWidget);
        expect(
          wasTruncated(tester, heading),
          isFalse,
          reason: 'the current routine name is cut short on Today',
        );

        await stop(tester);
      });

      testWidgets('a routine card shows it whole at $scale×', (tester) async {
        await pumpAt(tester, const RoutinesScreen(), textScale: scale);

        final name = find.text(kPpl);
        expect(name, findsOneWidget);
        expect(
          wasTruncated(tester, name),
          isFalse,
          reason: 'the routine card cuts an ordinary name short',
        );

        await stop(tester);
      });
    }

    testWidgets('and a long name pushes nothing off the edge', (tester) async {
      await db.createRoutine(
        name: 'Upper / Lower / Push / Pull / Legs / Arms',
        color: 'FF6A3D',
        restSeconds: 90,
      );
      final overflows = await overflowsDuring(() async {
        await pumpAt(tester, const RoutinesScreen());
      });
      expect(overflows, isEmpty);
      await stop(tester);
    });
  });

  group('training days are dragged into order', () {
    /// Opens the builder on the seeded three-day routine.
    Future<int> pumpBuilder(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // runAsync, because a drift future only completes on the real event loop
      // and this body runs in the test's fake one.
      final rid = (await tester.runAsync(
        () => routineWithCountNamed(db),
      ))!.routine.id;
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        routedAppUnder(container, RoutineEditScreen(routineId: rid)),
      );
      // Not pumpAndSettle: the loading spinner animates for ever, so the tree
      // is only quiet once the routine has come back off the database.
      await pumpThroughDatabase(tester);
      return rid;
    }

    /// Drags the [index]th drag handle by [dy].
    Future<void> dragDay(WidgetTester tester, int index, double dy) async {
      final handle = find.byIcon(Icons.drag_indicator).at(index);
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      // In steps: the reorderable decides where the row belongs from where the
      // pointer has travelled, so one teleporting move tells it nothing.
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(Offset(0, dy / 8));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('every day has a handle, and no up/down buttons', (
      tester,
    ) async {
      await pumpBuilder(tester);

      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(3));
      expect(
        find.byIcon(Icons.keyboard_arrow_up),
        findsNothing,
        reason: 'the handle replaces the arrows, as in a workout',
      );
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);

      await stop(tester);
    });

    testWidgets('dragging a day reorders it, exercises and all', (
      tester,
    ) async {
      final rid = await pumpBuilder(tester);
      final push = (await tester.runAsync(() => workoutNamed(db, 'Push')))!;
      final before = (await tester.runAsync(
        () => db.itemsForWorkout(push.id),
      ))!.map((v) => v.exercise.name).toList();
      expect(before, isNotEmpty);

      // Push is first; drag it below Pull.
      final gap =
          tester.getTopLeft(find.text('Pull')).dy -
          tester.getTopLeft(find.text('Push')).dy;
      await dragDay(tester, 0, gap + 10);

      expect(
        tester.getTopLeft(find.text('Push')).dy,
        greaterThan(tester.getTopLeft(find.text('Pull')).dy),
        reason: 'the dragged day did not move',
      );

      await tester.tap(find.text('Save routine'));
      await pumpThroughDatabase(tester);

      final after = (await tester.runAsync(() => db.workoutsForRoutine(rid)))!;
      expect(after.map((w) => w.name), ['Pull', 'Push', 'Legs']);
      // Reordering days leaves the exercises inside them alone.
      final items = (await tester.runAsync(() => db.itemsForWorkout(push.id)))!;
      expect(items.map((v) => v.exercise.name), before);

      await stop(tester);
    });
  });

  group('a slot cannot ask for a weight the movement never carries', () {
    test('an unloaded movement is offered no weight axis', () async {
      final pullUp = await exerciseNamed(db, 'Pull-Up');
      expect(
        pullUp.weightType.carriesWeight,
        isFalse,
        reason: 'a pull-up carries nothing — the premise of this test',
      );

      final slot = ItemDraft.forExercise(pullUp);
      expect(slot.modes, [ProgressionMode.reps]);
      expect(
        slot.progression,
        ProgressionMode.reps,
        reason: 'a pull-up gets more reps, not more kilograms',
      );

      // Asking for load anyway changes nothing, as asking for time on a squat
      // already does.
      slot.setMode(ProgressionMode.weight);
      expect(slot.progression, ProgressionMode.reps);
    });

    test('a loaded movement still gets both axes', () async {
      final bench = await exerciseNamed(db, 'Bench Press');
      final slot = ItemDraft.forExercise(bench);

      expect(
        slot.modes,
        containsAll([ProgressionMode.weight, ProgressionMode.reps]),
      );
      expect(slot.progression, ProgressionMode.weight);
    });

    test('an unloaded slot carries no suggested weight', () async {
      final pullUp = await exerciseNamed(db, 'Pull-Up');
      // Even asked for one — a movement reclassified after the slot was built.
      final slot = ItemDraft(
        exerciseId: pullUp.id,
        name: pullUp.name,
        muscle: pullUp.muscleGroup,
        weightType: pullUp.weightType,
        weightKg: 40,
      );

      expect(slot.weightKg, isNull);
      expect(itemCompanions([slot]).single.suggestedWeight.value, isNull);
    });

    testWidgets('the sheet says "Bodyweight" instead of an empty box', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = containerFor(db);
      addTearDown(container.dispose);
      final pullUp = (await tester.runAsync(
        () => exerciseNamed(db, 'Pull-Up'),
      ))!;

      await tester.pumpWidget(
        appUnder(
          container,
          Scaffold(
            body: ListView(
              children: [
                WorkoutItemsEditor(
                  items: [ItemDraft.forExercise(pullUp)],
                  unit: 'kg',
                  routineRest: 90,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pull-Up'));
      await tester.pumpAndSettle();

      expect(find.text('Bodyweight'), findsOneWidget);
      expect(
        find.text('Not set yet'),
        findsNothing,
        reason: 'there is no weight to fill in',
      );
      // The card is captioned without a unit — there is no number in it.
      expect(find.text('WEIGHT'), findsOneWidget);
      // And no weight axis to choose, so the axis is stated, not offered.
      expect(find.text('More reps'), findsOneWidget);

      await stop(tester);
    });

    testWidgets('a loaded slot asks for the number it is missing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = containerFor(db);
      addTearDown(container.dispose);
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;

      await tester.pumpWidget(
        appUnder(
          container,
          Scaffold(
            body: ListView(
              children: [
                WorkoutItemsEditor(
                  items: [ItemDraft.forExercise(bench)],
                  unit: 'kg',
                  routineRest: 90,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bench Press'));
      await tester.pumpAndSettle();

      // A blank weight on a bar is a number still to come, not bodyweight.
      expect(find.text('Not set yet'), findsOneWidget);
      expect(find.text('Bodyweight'), findsNothing);
      expect(find.text('Reps'), findsWidgets, reason: 'both axes are offered');

      await stop(tester);
    });
  });

  group('the picker: finding a movement, and making one that is missing', () {
    /// A screen with one button that opens the picker, keeping whatever came
    /// back. The picker is a sheet over a builder, so it is exercised the way
    /// the builder uses it rather than pumped bare.
    Future<Exercise?> Function() openPicker(
      WidgetTester tester,
      ProviderContainer container,
    ) {
      Exercise? picked;
      return () async {
        await tester.pumpWidget(
          appUnder(
            container,
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async => picked = await pickExercise(context),
                  child: const Text('Add exercise'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Add exercise'));
        await tester.pumpAndSettle();
        return picked;
      };
    }

    testWidgets('it filters by the same control the library does', (
      tester,
    ) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      await openPicker(tester, container)();

      // The list opens on Arms, the first group by name.
      expect(find.text('Barbell Curl'), findsOneWidget);

      // Through the dimension button and its sheet, as on the library screen.
      await tester.tap(find.byKey(filterButtonKey('muscle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(filterChipKey('muscle', 'Legs')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(kFilterSheetDoneKey));
      await tester.pumpAndSettle();

      expect(find.text('Back Squat'), findsOneWidget);
      expect(find.text('Barbell Curl'), findsNothing);

      await stop(tester);
    });

    testWidgets('a movement it does not have can be made without leaving', (
      tester,
    ) async {
      // Tall enough for the whole creation form, so this test is about the
      // route it takes and not about scrolling to a button.
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = containerFor(db);
      addTearDown(container.dispose);
      Exercise? picked;

      await tester.pumpWidget(
        appUnder(
          container,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => picked = await pickExercise(context),
                child: const Text('Add exercise'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add exercise'));
      await tester.pumpAndSettle();

      // Nothing in the library is a Zercher squat.
      await tester.enterText(find.byType(TextField).first, 'Zercher');
      await tester.pumpAndSettle();
      expect(find.text('Zercher Squat'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('picker-new-exercise')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Zercher Squat');
      await tester.tap(find.text('Save exercise'));
      await tester.pumpAndSettle();

      // It comes back selected — you asked for that exercise — and the sheet
      // is gone, so the builder is where you left it.
      expect(picked, isNotNull);
      expect(picked!.name, 'Zercher Squat');
      expect(picked!.isCustom, isTrue);
      expect(find.byKey(const ValueKey('picker-new-exercise')), findsNothing);

      // And it is in the library for next time.
      final all = await tester.runAsync(() => db.watchExercises().first);
      expect(all!.map((e) => e.name), contains('Zercher Squat'));

      await stop(tester);
    });
  });
}
