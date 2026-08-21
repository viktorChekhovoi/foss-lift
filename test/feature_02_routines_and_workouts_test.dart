// Integration tests for routines, training days, and exercise slots (features/index.html#sec02).

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/routine_detail_screen.dart';
import 'package:foss_lift/screens/routine_edit_screen.dart';
import 'package:foss_lift/screens/routines_screen.dart';
import 'package:foss_lift/screens/today_screen.dart';
import 'package:foss_lift/screens/workout_detail_screen.dart';
import 'package:foss_lift/util/seed_names.dart';
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

/// One expected exercise slot of a seeded programme.
///
/// [inc], [deload] and [ft] are the progression settings the programme is
/// actually run with — they are what makes Starting Strength a different
/// prescription from StrongLifts rather than the same slot shape twice. They
/// are null on a slot that carries no weight, where the programme says nothing
/// about kilograms and only the axis is worth asserting.
typedef _Slot = ({
  String name,
  int sets,
  int min,
  int? max,
  double? w,
  double? inc,
  double? deload,
  int? ft,
});

/// A slot the programme loads: sets × reps at a weight, stepping [inc] and
/// backing off [deload] after [ft] failed sessions.
_Slot _loaded(
  String name, {
  required int sets,
  required int min,
  int? max,
  required double w,
  required double inc,
  required double deload,
  required int ft,
}) => (
  name: name,
  sets: sets,
  min: min,
  max: max,
  w: w,
  inc: inc,
  deload: deload,
  ft: ft,
);

/// A slot on a movement that carries nothing, so it goes up in reps.
_Slot _unloaded(String name, {required int sets, required int min, int? max}) =>
    (
      name: name,
      sets: sets,
      min: min,
      max: max,
      w: null,
      inc: null,
      deload: null,
      ft: null,
    );

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  // What a program out of the routine library holds once it is added — the
  // prescription each of the five is actually run on, rather than one slot shape
  // copied five times. Which programs the library offers, and in what order, is
  // section 21's; this is about what lands when you take one.
  group('a program added from the library holds its own prescription', () {
    /// Asserts the [day] of [routine] holds exactly [want], in order.
    Future<void> expectSlots(
      String routine,
      String day,
      List<_Slot> want,
    ) async {
      final w = await workoutNamed(db, day, routine: routine);
      final items = await db.itemsForWorkout(w.id);

      expect(
        items.map((v) => v.exercise.name),
        want.map((s) => s.name),
        reason: '$routine / $day holds the wrong movements, or in the wrong '
            'order',
      );

      for (var i = 0; i < want.length; i++) {
        final s = want[i];
        final it = items[i].item;
        final where = '$routine / $day / ${s.name}';
        expect(it.targetSets, s.sets, reason: '$where: sets');
        expect(it.repsMin, s.min, reason: '$where: reps floor');
        expect(it.repsMax, s.max, reason: '$where: reps ceiling');
        expect(it.suggestedWeight, s.w, reason: '$where: suggested weight');
        expect(
          it.progression,
          s.w == null ? ProgressionMode.reps : ProgressionMode.weight,
          reason: '$where: a slot with no load has nothing to add load to',
        );
        if (s.inc != null) {
          expect(it.increment, s.inc, reason: '$where: step up');
          expect(it.deload, s.deload, reason: '$where: back-off');
          expect(
            it.failureThreshold,
            s.ft,
            reason: '$where: sessions missed before the back-off',
          );
        }
      }
    }

    // -- The three beginner strength programmes ----------------------------
    // Each one is the prescription the programme is actually run on, not one
    // slot shape copied five times: the rest default, the training days it
    // alternates, the sets and reps of every lift, and how fast each lift
    // moves.

    group('Starting Strength', () {
      const name = 'Starting Strength';

      test('rests five minutes and is trained Mon/Wed/Fri', () async {
        final r = await routineNamed(db, name);

        expect(r.restSeconds, 300, reason: 'a heavy triple needs five minutes');
        expect(r.scheduleDays, 1 << 0 | 1 << 2 | 1 << 4);
      });

      test('alternates two workouts', () async {
        final r = await routineNamed(db, name);
        final days = await db.workoutsForRoutine(r.id);

        expect(days.map((w) => w.name), ['Workout A', 'Workout B']);
      });

      test('Workout A squats, benches and pulls one set of deadlifts',
          () async {
        await expectSlots(name, 'Workout A', [
          _loaded('Back Squat',
              sets: 3, min: 5, w: 60, inc: 5, deload: 10, ft: 3),
          _loaded('Bench Press',
              sets: 3, min: 5, w: 45, inc: 2.5, deload: 5, ft: 3),
          _loaded('Deadlift',
              sets: 1, min: 5, w: 70, inc: 5, deload: 10, ft: 3),
        ]);
      });

      test('Workout B squats again, presses overhead and cleans', () async {
        await expectSlots(name, 'Workout B', [
          _loaded('Back Squat',
              sets: 3, min: 5, w: 60, inc: 5, deload: 10, ft: 3),
          _loaded('Overhead Press',
              sets: 3, min: 5, w: 30, inc: 2.5, deload: 5, ft: 3),
          _loaded('Power Clean',
              sets: 5, min: 3, w: 40, inc: 2.5, deload: 5, ft: 3),
        ]);
      });
    });

    group('StrongLifts 5x5', () {
      const name = 'StrongLifts 5x5';

      test('rests three minutes and is trained Mon/Wed/Fri', () async {
        final r = await routineNamed(db, name);

        expect(r.restSeconds, 180);
        expect(r.scheduleDays, 1 << 0 | 1 << 2 | 1 << 4);
      });

      test('alternates two workouts', () async {
        final r = await routineNamed(db, name);
        final days = await db.workoutsForRoutine(r.id);

        expect(days.map((w) => w.name), ['Workout A', 'Workout B']);
      });

      test('Workout A is five by five throughout', () async {
        await expectSlots(name, 'Workout A', [
          _loaded('Back Squat',
              sets: 5, min: 5, w: 40, inc: 2.5, deload: 5, ft: 3),
          _loaded('Bench Press',
              sets: 5, min: 5, w: 30, inc: 2.5, deload: 5, ft: 3),
          _loaded('Barbell Row',
              sets: 5, min: 5, w: 30, inc: 2.5, deload: 5, ft: 3),
        ]);
      });

      test('Workout B keeps the deadlift to a single set', () async {
        await expectSlots(name, 'Workout B', [
          _loaded('Back Squat',
              sets: 5, min: 5, w: 40, inc: 2.5, deload: 5, ft: 3),
          _loaded('Overhead Press',
              sets: 5, min: 5, w: 20, inc: 2.5, deload: 5, ft: 3),
          _loaded('Deadlift',
              sets: 1, min: 5, w: 60, inc: 5, deload: 10, ft: 3),
        ]);
      });
    });

    group('Full Body 3x', () {
      const name = 'Full Body 3x';

      test('rests two minutes and is trained Tue/Thu/Sat', () async {
        final r = await routineNamed(db, name);

        expect(r.restSeconds, 120);
        expect(r.scheduleDays, 1 << 1 | 1 << 3 | 1 << 5);
      });

      test('rotates three workouts', () async {
        final r = await routineNamed(db, name);
        final days = await db.workoutsForRoutine(r.id);

        expect(days.map((w) => w.name), [
          'Workout A',
          'Workout B',
          'Workout C',
        ]);
      });

      test('Workout A ends on an unloaded core movement', () async {
        await expectSlots(name, 'Workout A', [
          _loaded('Back Squat',
              sets: 3, min: 5, w: 55, inc: 5, deload: 10, ft: 2),
          _loaded('Bench Press',
              sets: 3, min: 5, w: 40, inc: 2.5, deload: 5, ft: 2),
          _loaded('Seated Cable Row',
              sets: 3, min: 10, w: 45, inc: 2.5, deload: 5, ft: 2),
          _unloaded('Hanging Leg Raise', sets: 3, min: 8, max: 12),
        ]);
      });

      test('Workout B works in rep ranges rather than fixed fives', () async {
        await expectSlots(name, 'Workout B', [
          _loaded('Romanian Deadlift',
              sets: 3, min: 8, w: 60, inc: 5, deload: 10, ft: 2),
          _loaded('Overhead Press',
              sets: 3, min: 6, max: 8, w: 30, inc: 2.5, deload: 5, ft: 2),
          _loaded('Lat Pulldown',
              sets: 3, min: 10, max: 12, w: 50, inc: 2.5, deload: 5, ft: 2),
          _loaded('Cable Crunch',
              sets: 3, min: 12, max: 15, w: 30, inc: 2.5, deload: 5, ft: 2),
        ]);
      });

      test('Workout C opens heavy and finishes on chin-ups', () async {
        await expectSlots(name, 'Workout C', [
          _loaded('Deadlift',
              sets: 2, min: 5, w: 80, inc: 5, deload: 10, ft: 2),
          _loaded('Incline DB Press',
              sets: 3, min: 8, max: 10, w: 22.5, inc: 2.5, deload: 5, ft: 2),
          _unloaded('Chin-Up', sets: 3, min: 5, max: 8),
          _loaded('Leg Curl',
              sets: 3, min: 12, w: 40, inc: 2.5, deload: 5, ft: 2),
        ]);
      });
    });

    test('the linear programmes back off later than the hypertrophy ones',
        () async {
      // The distinguishing rule, asserted once as a rule rather than only as a
      // column of numbers: a beginner who misses a session on Starting
      // Strength is having a bad day, not stalling.
      final ss = await slotNamed(db, 'Workout A', 'Back Squat',
          routine: 'Starting Strength');
      final ppl = await slotNamed(db, 'Legs', 'Back Squat');

      expect(ss.item.failureThreshold, greaterThan(ppl.item.failureThreshold));
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

  group('a routine can say what it is', () {
    /// The description field in the routine builder.
    final field = find.byKey(const ValueKey('routine-description'));

    /// Opens the builder on [rid] and returns once the routine is loaded.
    Future<void> pumpBuilder(WidgetTester tester, int rid,
        {Locale locale = const Locale('en')}) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(routedAppUnder(
          container, RoutineEditScreen(routineId: rid), locale: locale));
      await pumpThroughDatabase(tester);
    }

    /// A routine with one day, [description] and nothing else interesting.
    Future<int> aRoutine(WidgetTester tester, {String? description}) async {
      final rid = (await tester.runAsync(() async {
        final id = await db.createRoutine(
          name: 'My Split',
          color: 'FF6A3D',
          restSeconds: 90,
          description: description,
        );
        await db.createWorkout(id, 'Day 1');
        return id;
      }))!;
      return rid;
    }

    Future<Routine> reload(WidgetTester tester, int rid) async =>
        (await tester.runAsync(() => db.routineById(rid)))!;

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.text(l10nFor().routineEditSave));
      await pumpThroughDatabase(tester);
    }

    testWidgets('what you type in the builder is stored on the routine',
        (tester) async {
      final rid = await aRoutine(tester);
      await pumpBuilder(tester, rid);

      expect(field, findsOneWidget, reason: 'the builder has no description');
      await tester.enterText(field, 'Four days, two of them heavy.');
      await save(tester);

      expect((await reload(tester, rid)).description,
          'Four days, two of them heavy.');

      await stop(tester);
    });

    testWidgets('editing a routine keeps the description it has',
        (tester) async {
      final rid = await aRoutine(tester, description: 'Three days a week.');
      await pumpBuilder(tester, rid);

      expect(find.text('Three days a week.'), findsOneWidget,
          reason: 'the field opens on what is there');
      await save(tester);

      expect((await reload(tester, rid)).description, 'Three days a week.');

      await stop(tester);
    });

    testWidgets('clearing it clears the description', (tester) async {
      final rid = await aRoutine(tester, description: 'Three days a week.');
      await pumpBuilder(tester, rid);

      await tester.enterText(field, '   ');
      await save(tester);

      expect((await reload(tester, rid)).description, isNull,
          reason: 'a blank field means there is nothing to say');

      await stop(tester);
    });

    testWidgets('typing stops at a paragraph', (tester) async {
      final rid = await aRoutine(tester);
      await pumpBuilder(tester, rid);

      await tester.enterText(field, 'x' * (kMaxDescriptionLength + 120));
      await pumpThroughDatabase(tester);

      expect(tester.widget<TextField>(field).controller!.text.length,
          kMaxDescriptionLength,
          reason: 'the cap is enforced while typing, not at the insert');

      await stop(tester);
    });

    testWidgets('a described routine says so on its own page', (tester) async {
      final rid = await aRoutine(tester, description: 'Three days a week.');
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
          appUnder(container, RoutineDetailScreen(routineId: rid)));
      await pumpThroughDatabase(tester);

      expect(find.text('Three days a week.'), findsOneWidget);

      await stop(tester);
    });

    testWidgets('and one nobody has described shows nothing at all',
        (tester) async {
      final rid = await aRoutine(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
          appUnder(container, RoutineDetailScreen(routineId: rid)));
      await pumpThroughDatabase(tester);

      // The workout count is there, so the page has drawn; there is simply no
      // paragraph above it.
      expect(find.textContaining(l10nFor().routineDetailWorkoutCount(1)),
          findsOneWidget);
      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .where((t) => (t.data ?? '').length > 40),
        isEmpty,
        reason: 'nothing stands in for a description that is not there',
      );

      await stop(tester);
    });

    testWidgets('a shipped description follows the language', (tester) async {
      const es = Locale('es');
      final program = kStarterRoutines.first;
      final rid = (await tester
          .runAsync(() => db.addStarterRoutine(program)))!;
      final container = containerFor(db);
      addTearDown(container.dispose);
      final shown = seededDescription(
          l10nFor(es), program.seedKey, program.description)!;

      await tester.pumpWidget(appUnder(
          container, RoutineDetailScreen(routineId: rid), locale: es));
      await pumpThroughDatabase(tester);

      expect(shown, isNot(program.description), reason: 'the premise');
      expect(find.text(shown), findsOneWidget);
      expect(find.text(program.description), findsNothing);

      await stop(tester);
    });

    testWidgets('one you have rewritten is shown as you wrote it',
        (tester) async {
      const es = Locale('es');
      final program = kStarterRoutines.first;
      final rid = (await tester.runAsync(() async {
        final id = await db.addStarterRoutine(program);
        await db.updateRoutineMeta(id,
            name: program.name,
            seedKey: program.seedKey,
            color: program.colorHex,
            restSeconds: program.restSeconds,
            description: 'Mine now, and only three days of it.');
        return id;
      }))!;
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(
          container, RoutineDetailScreen(routineId: rid), locale: es));
      await pumpThroughDatabase(tester);

      expect(find.text('Mine now, and only three days of it.'), findsOneWidget,
          reason: 'a description you typed is not a shipped string');

      await stop(tester);
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
    /// The shipped routine names are the case that has to work: "Push / Pull /
    /// Legs" is ordinary, and cutting it to "Push / Pull / L…" on the first
    /// screen of the app is not a layout, it is a bug.
    ///
    /// It has to be in the list to be measured, and the list starts empty — so
    /// the program is added from the library first, which is also how it gets
    /// there in the app.
    Future<ProviderContainer> pumpAt(
      WidgetTester tester,
      Widget screen, {
      double textScale = 1.0,
    }) async {
      await tester.runAsync(() => routineNamed(db));
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

      // Filtering to Legs leaves everything that works legs at all, which is
      // more than one screenful — the squat is in the list, further down it.
      await tester.scrollUntilVisible(
        find.text('Back Squat'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
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

  group('A workout shows which of its exercises are supersetted', () {
    // features/index.html#sec02 day-shows-which-exercises-are-supersetted — what
    // is trained back to back is answered before Start, not discovered on the
    // board.
    testWidgets('the joined rows are tagged as a group', (tester) async {
      late int w;
      await tester.runAsync(() async {
        w = await workoutIdNamed(db, 'Push');
        final drafts = [
          for (final v in await db.itemsForWorkout(w)) ItemDraft.fromView(v),
        ];
        drafts[1].supersetWithPrevious = true;
        await db.replaceWorkoutItems(w, itemCompanions(drafts, workoutId: w));
      });
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        appUnder(container, WorkoutDetailScreen(workoutId: w)),
      );
      await pumpThroughDatabase(tester);

      expect(find.text(l10nFor().commonSuperset), findsOneWidget,
          reason: 'the group is named once, above the rows it holds');

      await stop(tester);
    });

    testWidgets('and a day with nothing joined says nothing', (tester) async {
      late int w;
      await tester.runAsync(() async => w = await workoutIdNamed(db, 'Push'));
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        appUnder(container, WorkoutDetailScreen(workoutId: w)),
      );
      await pumpThroughDatabase(tester);

      expect(find.text(l10nFor().commonSuperset), findsNothing);

      await stop(tester);
    });
  });

  group('a long routine offers the session you are on, not all of them', () {
    /// A routine of [days] training days, made current — the shape a program
    /// written out session by session arrives in.
    Future<int> longRoutine(WidgetTester tester, int days) async {
      return (await tester.runAsync(() async {
        final rid = await db.createRoutine(
            name: 'Long', color: 'FF6A3D', restSeconds: 90);
        for (var i = 1; i <= days; i++) {
          await db.createWorkout(rid, 'Day $i');
        }
        await db.setActiveRoutineId(rid);
        return rid;
      }))!;
    }

    Future<void> pumpToday(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
          routedAppUnder(container, const TodayScreen(), scaffold: true));
      await pumpThroughDatabase(tester);
    }

    testWidgets('a week of days is listed whole', (tester) async {
      await longRoutine(tester, 7);
      await pumpToday(tester);

      for (var i = 1; i <= 7; i++) {
        expect(find.text('Day $i'), findsOneWidget, reason: 'Day $i is hidden');
      }
      expect(find.byKey(kTodayShowAllWorkoutsKey), findsNothing,
          reason: 'nothing is folded, so nothing offers to unfold it');

      await stop(tester);
    });

    testWidgets('past that, it shows the one you are on and its neighbours',
        (tester) async {
      await longRoutine(tester, 10);
      await pumpToday(tester);

      // Nothing has been trained, so the session you are on is the first: no
      // day before it, and the two after it.
      for (final name in const ['Day 1', 'Day 2', 'Day 3']) {
        expect(find.text(name), findsOneWidget, reason: '$name is not offered');
      }
      for (final name in const ['Day 4', 'Day 10']) {
        expect(find.text(name), findsNothing,
            reason: '$name buries the day you are on');
      }
      expect(find.byKey(kTodayShowAllWorkoutsKey), findsOneWidget);

      await stop(tester);
    });

    testWidgets('and the line underneath opens the rest in place',
        (tester) async {
      await longRoutine(tester, 10);
      await pumpToday(tester);

      await tester.tap(find.byKey(kTodayShowAllWorkoutsKey));
      await pumpThroughDatabase(tester);

      for (var i = 1; i <= 10; i++) {
        expect(find.text('Day $i'), findsOneWidget,
            reason: 'Day $i is still folded away');
      }
      expect(find.byKey(kTodayShowAllWorkoutsKey), findsNothing,
          reason: 'opened, it is the plain list it always was');

      await stop(tester);
    });

    testWidgets('the link says how many there are', (tester) async {
      await longRoutine(tester, 10);
      await pumpToday(tester);

      expect(find.text(l10nFor().todayShowAllWorkouts(10)), findsOneWidget);

      await stop(tester);
    });
  });
}
