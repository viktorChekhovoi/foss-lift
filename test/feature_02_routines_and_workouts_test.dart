// Integration tests for features/02-routines-and-workouts.md
//
// The three-level template hierarchy — routine → workout (training day) →
// exercise slot. Two demo routines seeded on first launch; one current routine;
// split editing where reordering days never disturbs their exercises; drafts
// built in memory before saving; a deleted current routine degrading to "none".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/widgets/builder_widgets.dart';
import 'package:foss_lift/widgets/exercise_filters.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

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
        await tester.pumpWidget(appUnder(
          container,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => picked = await pickExercise(context),
                child: const Text('Add exercise'),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('Add exercise'));
        await tester.pumpAndSettle();
        return picked;
      };
    }

    testWidgets('it filters by the same chips the library does', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      await openPicker(tester, container)();

      // The list opens on Arms, the first group by name.
      expect(find.text('Barbell Curl'), findsOneWidget);

      await tester.tap(find.byKey(filterChipKey('muscle', 'Legs')));
      await tester.pumpAndSettle();

      expect(find.text('Back Squat'), findsOneWidget);
      expect(find.text('Barbell Curl'), findsNothing);

      await stop(tester);
    });

    testWidgets('a movement it does not have can be made without leaving',
        (tester) async {
      // Tall enough for the whole creation form, so this test is about the
      // route it takes and not about scrolling to a button.
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = containerFor(db);
      addTearDown(container.dispose);
      Exercise? picked;

      await tester.pumpWidget(appUnder(
        container,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await pickExercise(context),
              child: const Text('Add exercise'),
            ),
          ),
        ),
      ));
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
