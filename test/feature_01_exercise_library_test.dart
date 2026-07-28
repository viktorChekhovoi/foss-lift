// Integration tests for features/01-exercise-library.md
//
// The exercise library: a curated starter set (a demo link on every entry),
// custom exercises alongside it, a weight type seeded from equipment and
// overridable for any exercise, a measure fixed at creation, and history that
// survives library edits because logged sets store the name denormalised.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/data/exercise_filter.dart';
import 'package:foss_lift/screens/exercise_detail_screen.dart';
import 'package:foss_lift/screens/exercise_form_screen.dart';
import 'package:foss_lift/screens/library_screen.dart';
import 'package:foss_lift/util/units.dart';
import 'package:foss_lift/util/video_links.dart';
import 'package:foss_lift/widgets/exercise_filters.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  group('starter library', () {
    test('ships a curated starter set, none of it marked custom', () async {
      final all = await db.watchExercises().first;
      final starters = all.where((e) => !e.isCustom).toList();

      // ~85 curated movements. Exactly the seeded set is custom-free.
      expect(starters.length, greaterThanOrEqualTo(80));
      expect(all.every((e) => !e.isCustom), isTrue);
    });

    test('no movement is seeded twice', () async {
      final names = (await db.watchExercises().first).map((e) => e.name);
      expect(names.toSet().length, names.length);
    });

    test('the starter set covers every muscle group and every equipment kind',
        () async {
      final all = await db.watchExercises().first;

      // A group nobody can fill from the library is a group the picker offers
      // for nothing.
      for (final group in kMuscleGroups) {
        expect(all.where((e) => e.muscleGroup == group).length,
            greaterThanOrEqualTo(3),
            reason: '$group is thin in the starter library');
      }
      for (final kind in kEquipmentTypes) {
        expect(all.any((e) => e.equipment == kind), isTrue,
            reason: 'nothing in the library is $kind');
      }
    });

    test('the movements a thin library was missing are all present', () async {
      final names = (await db.watchExercises().first).map((e) => e.name);

      expect(
        names,
        containsAll([
          'Hip Thrust', // glutes
          'Romanian Deadlift', // hip hinge
          'Chest Dip', // dip
          'Chin-Up', // vertical pull, supinated
          'Barbell Shrug', // traps
          'Wrist Curl', // forearms
        ]),
      );
    });

    test('the starter library invents no new vocabulary', () async {
      final all = await db.watchExercises().first;

      // Both lists are a wire format for a shared routine — a word outside
      // them costs bytes in every code that carries it.
      for (final e in all) {
        expect(kMuscleGroups, contains(e.muscleGroup), reason: e.name);
        expect(kEquipmentTypes, contains(e.equipment), reason: e.name);
      }
    });

    test('every starter carries a demo-video link', () async {
      final all = await db.watchExercises().first;

      for (final e in all.where((e) => !e.isCustom)) {
        expect(e.videoUrl, isNotNull, reason: '${e.name} has no demo link');
      }
    });

    test('and it is a specific video, not a search for one', () async {
      // These were `youtube.com/results?search_query=…`, which is a page of
      // results to pick from rather than a demo — and, having no video id in
      // it, nothing a shared routine could carry either.
      final all = await db.watchExercises().first;

      for (final e in all.where((e) => !e.isCustom)) {
        expect(youTubeVideoId(e.videoUrl ?? ''), isNotNull,
            reason: '${e.name} links to "${e.videoUrl}", which names no video');
        expect(e.videoUrl, startsWith('https://youtu.be/'),
            reason: '${e.name} is not stored in the canonical short form');
      }
    });

    test('no two starters point at the same video', () async {
      // A copy-paste slip in the table is invisible on screen — both links
      // work, they are just the wrong demo on one of them.
      final all = (await db.watchExercises().first).where((e) => !e.isCustom);
      final byId = <String, List<String>>{};
      for (final e in all) {
        byId.putIfAbsent(youTubeVideoId(e.videoUrl ?? '')!, () => []).add(e.name);
      }
      final shared = byId.entries.where((x) => x.value.length > 1).toList();
      expect(shared, isEmpty,
          reason: 'shared demo videos: '
              '${shared.map((x) => '${x.key} → ${x.value}').join('; ')}');
    });

    test('a custom exercise sits alongside the starter set', () async {
      await db.createExercise(
        name: 'Zercher Squat',
        muscle: 'Legs',
        equipment: 'Barbell',
      );

      final all = await db.watchExercises().first;
      final mine = all.firstWhere((e) => e.name == 'Zercher Squat');
      final starter = all.firstWhere((e) => e.name == 'Bench Press');

      expect(mine.isCustom, isTrue);
      expect(starter.isCustom, isFalse);
      // Both are in the one library the picker reads.
      expect(
        all.map((e) => e.name),
        containsAll(['Zercher Squat', 'Bench Press']),
      );
    });
  });

  group('weight type seeded from equipment', () {
    test(
      'barbell → bar, dumbbell → dumbbell, everything else → machine',
      () async {
        expect(
          (await exerciseNamed(db, 'Bench Press')).weightType,
          WeightType.bar,
        );
        expect(
          (await exerciseNamed(db, 'Incline DB Press')).weightType,
          WeightType.dumbbell,
        );
        expect(
          (await exerciseNamed(db, 'Triceps Pushdown')).weightType,
          WeightType.machine,
        ); // cable
        expect(
          (await exerciseNamed(db, 'Push-Up')).weightType,
          WeightType.machine,
        ); // bodyweight
      },
    );

    test(
      'the equipment→type rule itself, including the bodyweight fallthrough',
      () {
        expect(weightTypeForEquipment('Barbell'), WeightType.bar);
        expect(weightTypeForEquipment('Dumbbell'), WeightType.dumbbell);
        expect(weightTypeForEquipment('Cable'), WeightType.machine);
        expect(weightTypeForEquipment('Bodyweight'), WeightType.machine);
        expect(weightTypeForEquipment('anything else'), WeightType.machine);
      },
    );

    test(
      'a new custom exercise defaults to machine when not told otherwise',
      () async {
        final id = await db.createExercise(
          name: 'Sled Push',
          muscle: 'Legs',
          equipment: 'Sled',
        );
        expect((await db.exerciseById(id)).weightType, WeightType.machine);
      },
    );
  });

  group('weight type & bar are overridable for any exercise', () {
    test('the seeded type can be reclassified on a starter lift', () async {
      final bench = await exerciseNamed(db, 'Bench Press');
      expect(bench.weightType, WeightType.bar);

      await db.setExerciseWeightType(bench.id, WeightType.machine);

      expect((await db.exerciseById(bench.id)).weightType, WeightType.machine);
    });

    test(
      'a starter lift can be given its own bar, and handed back to default',
      () async {
        final bench = await exerciseNamed(db, 'Bench Press');
        expect(bench.barWeight, isNull); // uses the app-wide default

        await db.setExerciseBarWeight(bench.id, 15);
        expect((await db.exerciseById(bench.id)).barWeight, 15);

        await db.setExerciseBarWeight(bench.id, null);
        expect((await db.exerciseById(bench.id)).barWeight, isNull);
      },
    );

    test('overrides apply to custom exercises too', () async {
      final id = await db.createExercise(
        name: 'EZ Curl',
        muscle: 'Arms',
        equipment: 'Barbell',
      );
      await db.setExerciseWeightType(id, WeightType.bar);
      await db.setExerciseBarWeight(id, 10);

      final e = await db.exerciseById(id);
      expect(e.weightType, WeightType.bar);
      expect(e.barWeight, 10);
    });
  });

  group('measure is a fixed fact of the movement', () {
    test('the held starters are exactly the movements with no rep to count',
        () async {
      final all = await db.watchExercises().first;
      final held = all.where((e) => e.measure == ExerciseMeasure.time).toList();

      expect(
        held.map((e) => e.name).toSet(),
        {'Plank', 'Side Plank', 'Hollow Hold', 'Dead Hang', "Farmer's Carry"},
      );
      expect(
        (await exerciseNamed(db, 'Bench Press')).measure,
        ExerciseMeasure.reps,
      );
    });

    test('a custom exercise keeps the measure it was created with', () async {
      final id = await db.createExercise(
        name: 'Wall Sit',
        muscle: 'Legs',
        equipment: 'Bodyweight',
        measure: ExerciseMeasure.time,
      );
      expect((await db.exerciseById(id)).measure, ExerciseMeasure.time);
    });

    test(
      'a held movement offers only time; a counted one offers weight & reps',
      () {
        expect(ExerciseMeasure.time.modes, [ProgressionMode.time]);
        expect(ExerciseMeasure.reps.modes, [
          ProgressionMode.weight,
          ProgressionMode.reps,
        ]);
      },
    );

    test('an axis the measure forbids is coerced back to a permitted one', () {
      // A hold can never be progressed by weight; a counted lift never by time.
      expect(
        ExerciseMeasure.time.coerce(ProgressionMode.weight),
        ProgressionMode.time,
      );
      expect(
        ExerciseMeasure.reps.coerce(ProgressionMode.time),
        ProgressionMode.weight,
      );
      // A permitted axis passes straight through.
      expect(
        ExerciseMeasure.reps.coerce(ProgressionMode.reps),
        ProgressionMode.reps,
      );
    });
  });

  group('history survives library edits', () {
    /// Logs a one-set session against [exerciseId], recording [name] on the set.
    Future<int> logOneSet(int exerciseId, String name) {
      final now = DateTime(2026, 1, 1, 9);
      return db.saveSession(
        routineId: null,
        workoutId: null,
        name: 'Test day',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 40)),
        durationSeconds: 2400,
        totalVolume: 640,
        sets: [
          SessionSetsCompanion.insert(
            sessionId: 0, // saveSession fills in the real id
            exerciseName: name,
            setNumber: 1,
            exerciseId: Value(exerciseId),
            weight: const Value(80),
            reps: const Value(8),
            done: const Value(true),
          ),
        ],
      );
    }

    test(
      'renaming an exercise never rewrites the name on a logged set',
      () async {
        final bench = await exerciseNamed(db, 'Bench Press');
        final sessionId = await logOneSet(bench.id, 'Bench Press');

        // Rename the movement in the library.
        await (db.update(db.exercises)..where((e) => e.id.equals(bench.id)))
            .write(const ExercisesCompanion(name: Value('Flat Barbell Press')));

        final logged = await db.setsForSession(sessionId);
        expect(logged.single.exerciseName, 'Bench Press');
        // The library itself did change.
        expect((await db.exerciseById(bench.id)).name, 'Flat Barbell Press');
      },
    );

    test(
      'a rename keeps the whole history gathered under the exercise id',
      () async {
        final bench = await exerciseNamed(db, 'Bench Press');
        await logOneSet(bench.id, 'Bench Press');

        await (db.update(db.exercises)..where((e) => e.id.equals(bench.id)))
            .write(const ExercisesCompanion(name: Value('Flat Barbell Press')));

        // History is matched on id, so the renamed movement still owns its set.
        final hist = await db.watchExerciseSetHistory(bench.id).first;
        expect(hist, hasLength(1));
        expect(hist.single.reps, 8);
      },
    );

    test('deleting an exercise leaves its logged sets standing', () async {
      // A custom, unreferenced exercise: nothing in a workout points at it, so
      // deleting it is legal and only history could be harmed.
      final id = await db.createExercise(
        name: 'Landmine Press',
        muscle: 'Shoulders',
        equipment: 'Barbell',
      );
      final sessionId = await logOneSet(id, 'Landmine Press');

      await (db.delete(db.exercises)..where((e) => e.id.equals(id))).go();

      final logged = await db.setsForSession(sessionId);
      expect(logged.single.exerciseName, 'Landmine Press');
    });
  });

  group('the demo link is tidied as it is entered', () {
    // A surface tall enough for the whole form, so every field is built and can
    // be addressed by position. On a phone-sized surface the demo-link box sits
    // below the fold and is not in the tree at all.
    setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

    Future<void> openForm(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = containerFor(db);
      addTearDown(container.dispose);
      // The form pops on save, so it needs a router above it.
      await tester
          .pumpWidget(routedAppUnder(container, const ExerciseFormScreen()));
      await tester.pumpAndSettle();
    }

    /// The form's two text boxes: the name, and the demo link below it.
    Finder nameField(WidgetTester t) => find.byType(TextField).first;
    Finder linkField(WidgetTester t) => find.byType(TextField).last;

    Future<Exercise> saveWith(WidgetTester tester, String link) async {
      await openForm(tester);
      await tester.enterText(nameField(tester), 'Copenhagen Plank');
      await tester.enterText(linkField(tester), link);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save exercise'));
      await tester.pumpAndSettle();

      final saved = (await tester.runAsync(() => db.watchExercises().first))!;
      return saved.firstWhere((e) => e.name == 'Copenhagen Plank');
    }

    testWidgets('a YouTube link is stored in its short canonical form',
        (tester) async {
      final saved = await saveWith(
          tester, 'https://www.youtube.com/watch?v=aBcD1234_-x&t=90s&list=PLx');

      expect(saved.videoUrl, 'https://youtu.be/aBcD1234_-x',
          reason: 'the timestamp, playlist and www. identify nothing');

      await stop(tester);
    });

    testWidgets('a link to somewhere else is kept exactly as typed',
        (tester) async {
      // A coach's own upload, a private clip: not ours to rewrite, and it still
      // opens from the exercise screen.
      final saved = await saveWith(tester, 'https://example.com/my-technique');

      expect(saved.videoUrl, 'https://example.com/my-technique');

      await stop(tester);
    });

    testWidgets('an empty link stays empty', (tester) async {
      final saved = await saveWith(tester, '   ');

      expect(saved.videoUrl, isNull);

      await stop(tester);
    });
  });

  group('a custom exercise stays editable after it is saved', () {
    setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

    Future<int> mine() => db.createExercise(
          name: 'Copenhagen Plank',
          muscle: 'Core',
          equipment: 'Bodyweight',
          videoUrl: 'https://youtu.be/aBcD1234_-x',
          measure: ExerciseMeasure.time,
          weightType: WeightType.machine,
        );

    Future<void> openEditor(WidgetTester tester, int id) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
          routedAppUnder(container, ExerciseFormScreen(exerciseId: id)));
      await tester.pumpAndSettle();
    }

    testWidgets('the form opens on what was stored, not on a blank',
        (tester) async {
      final id = (await tester.runAsync(mine))!;
      await openEditor(tester, id);

      expect(find.text('Edit exercise'), findsOneWidget);
      expect(find.text('Copenhagen Plank'), findsOneWidget);
      expect(find.text('https://youtu.be/aBcD1234_-x'), findsOneWidget);

      await stop(tester);
    });

    testWidgets('saving rewrites the exercise in place rather than adding one',
        (tester) async {
      final id = (await tester.runAsync(mine))!;
      final before =
          (await tester.runAsync(() => db.watchExercises().first))!.length;
      await openEditor(tester, id);

      await tester.enterText(
          find.byType(TextField).first, 'Copenhagen Plank (long lever)');
      // "Dumbbell" is both an equipment and a loading; the second is the
      // "Loaded as" row, which sits below Equipment on the form.
      await tester.tap(find.text('Dumbbell').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save exercise'));
      await tester.pumpAndSettle();

      final all = (await tester.runAsync(() => db.watchExercises().first))!;
      expect(all.length, before, reason: 'an edit is not a second exercise');
      final saved = all.firstWhere((e) => e.id == id);
      expect(saved.name, 'Copenhagen Plank (long lever)');
      expect(saved.weightType, WeightType.dumbbell);
      expect(saved.isCustom, isTrue);

      await stop(tester);
    });

    testWidgets('the name field stops at the length the schema will take',
        (tester) async {
      final id = (await tester.runAsync(mine))!;
      await openEditor(tester, id);

      // Typing past the cap would otherwise be a failed insert rather than a
      // truncated one — the column rejects it.
      await tester.enterText(find.byType(TextField).first, 'x' * 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save exercise'));
      await tester.pumpAndSettle();

      final all = (await tester.runAsync(() => db.watchExercises().first))!;
      expect(all.firstWhere((e) => e.id == id).name.length, kMaxNameLength);

      await stop(tester);
    });

    test('a starter exercise is not renameable through the same door',
        () async {
      final all = await db.watchExercises().first;
      final starter = all.firstWhere((e) => !e.isCustom);

      await db.updateCustomExercise(
        starter.id,
        name: 'Not Bench Press',
        muscle: 'Chest',
        equipment: 'Barbell',
        videoUrl: null,
        measure: ExerciseMeasure.reps,
        weightType: WeightType.bar,
      );

      final after = await db.exerciseById(starter.id);
      expect(after.name, starter.name,
          reason: 'a starter name is shared vocabulary a routine code relies on');
    });
  });

  group('a personal note on a movement', () {
    test('every exercise starts with no note', () async {
      for (final e in await db.watchExercises().first) {
        expect(e.notes, isNull, reason: '${e.name} was seeded with a note');
      }
    });

    test('a note can be written, rewritten and cleared', () async {
      final press = await exerciseNamed(db, 'Leg Press');

      await db.setExerciseNotes(press.id, 'Seat 4, back pad on 2');
      expect(
        (await db.exerciseById(press.id)).notes,
        'Seat 4, back pad on 2',
      );

      await db.setExerciseNotes(press.id, 'Seat 3 now');
      expect((await db.exerciseById(press.id)).notes, 'Seat 3 now');

      await db.setExerciseNotes(press.id, null);
      expect((await db.exerciseById(press.id)).notes, isNull);
    });

    test('a note of nothing but whitespace is no note at all', () async {
      final press = await exerciseNamed(db, 'Leg Press');

      await db.setExerciseNotes(press.id, 'Seat 4');
      await db.setExerciseNotes(press.id, '   \n ');

      // Otherwise every screen has to ask "is it empty, or only blank?"
      expect((await db.exerciseById(press.id)).notes, isNull);
    });

    test('a note is kept, trimmed, on a starter and on a custom alike',
        () async {
      final starter = await exerciseNamed(db, 'Bench Press');
      final custom = await db.createExercise(
        name: 'Zercher Squat',
        muscle: 'Legs',
        equipment: 'Barbell',
      );

      await db.setExerciseNotes(starter.id, '  Rack pin 7  ');
      await db.setExerciseNotes(custom, 'Elbows hurt — use the pad');

      expect((await db.exerciseById(starter.id)).notes, 'Rack pin 7');
      expect(
        (await db.exerciseById(custom)).notes,
        'Elbows hurt — use the pad',
      );
    });

    test('a note survives a rename', () async {
      final press = await exerciseNamed(db, 'Leg Press');
      await db.setExerciseNotes(press.id, 'Seat 4');

      await (db.update(db.exercises)..where((e) => e.id.equals(press.id)))
          .write(const ExercisesCompanion(
              name: Value('Leg Press (the good one)')));

      expect((await db.exerciseById(press.id)).notes, 'Seat 4');
    });

    testWidgets('the detail screen writes a note and reads it back',
        (tester) async {
      final press = (await tester.runAsync(() => exerciseNamed(db, 'Leg Press')))!;
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(routedAppUnder(
        container,
        ExerciseDetailScreen(exerciseId: press.id),
      ));
      await tester.pumpAndSettle();

      // Empty reads as deliberate, not broken.
      expect(find.text('Nothing noted yet'), findsOneWidget);

      await tester.tap(find.text('Nothing noted yet'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Seat 4, pin 7');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved =
          (await tester.runAsync(() => db.exerciseById(press.id)))!;
      expect(saved.notes, 'Seat 4, pin 7');
      // And the screen is showing it, not the empty state.
      await tester.pumpAndSettle();
      expect(find.text('Seat 4, pin 7'), findsOneWidget);
      expect(find.text('Nothing noted yet'), findsNothing);

      await stop(tester);
    });
  });

  group('finding a movement by what it is, not what it is called', () {
    // "A barbell movement for legs" should not require knowing it is called a
    // back squat. See features/01-exercise-library.md.

    Future<List<Exercise>> filtered(ExerciseFilter f) async =>
        f.apply(await db.watchExercises().first);

    test('an untouched filter excludes nothing', () async {
      final all = await db.watchExercises().first;
      expect(const ExerciseFilter().apply(all).length, all.length);
    });

    test('equipment and muscle group narrow together', () async {
      final legs = await filtered(const ExerciseFilter(
        equipment: {'Barbell'},
        muscles: {'Legs'},
      ));

      expect(legs, isNotEmpty);
      expect(legs.every((e) => e.equipment == 'Barbell'), isTrue);
      expect(legs.every((e) => e.muscleGroup == 'Legs'), isTrue);
      expect(legs.map((e) => e.name), contains('Back Squat'));
    });

    test('several muscle groups are alternatives, not a narrower search',
        () async {
      final arms = await filtered(const ExerciseFilter(muscles: {'Arms'}));
      final glutes = await filtered(const ExerciseFilter(muscles: {'Glutes'}));
      final both =
          await filtered(const ExerciseFilter(muscles: {'Arms', 'Glutes'}));

      expect(both.length, arms.length + glutes.length);
      expect(
        both.every((e) => e.muscleGroup == 'Arms' || e.muscleGroup == 'Glutes'),
        isTrue,
      );
    });

    test('the same holds for equipment', () async {
      final bar = await filtered(const ExerciseFilter(equipment: {'Barbell'}));
      final db2 = await filtered(const ExerciseFilter(equipment: {'Dumbbell'}));
      final both = await filtered(
          const ExerciseFilter(equipment: {'Barbell', 'Dumbbell'}));

      expect(both.length, bar.length + db2.length);
    });

    test('the chips compose with the search text', () async {
      final pressed = await filtered(const ExerciseFilter(
        query: 'press',
        equipment: {'Dumbbell'},
      ));

      expect(pressed, isNotEmpty);
      expect(
        pressed.every((e) =>
            e.equipment == 'Dumbbell' &&
            e.name.toLowerCase().contains('press')),
        isTrue,
      );
      // And the text alone finds more than the pair does.
      final anyPress = await filtered(const ExerciseFilter(query: 'press'));
      expect(anyPress.length, greaterThan(pressed.length));
    });

    test('letting the chips go keeps what was typed', () {
      const f = ExerciseFilter(
          query: 'squat', equipment: {'Barbell'}, muscles: {'Legs'});
      expect(f.facetCount, 2);

      final cleared = f.withoutFacets;
      expect(cleared.query, 'squat');
      expect(cleared.facetCount, 0);
      expect(cleared.isEmpty, isFalse);
    });

    test('tapping a chip twice puts it back', () {
      final on = const ExerciseFilter().toggleMuscle('Back');
      expect(on.muscles, {'Back'});
      expect(on.toggleMuscle('Back').muscles, isEmpty);
    });

    testWidgets('the library filters to what the chips say', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(routedAppUnder(container, const LibraryScreen()));
      await tester.pumpAndSettle();

      // Unfiltered, the whole library is grouped by muscle and Arms is the
      // first group on screen.
      expect(find.textContaining('ARMS ·'), findsOneWidget);

      // A barbell movement for legs: two taps, and no name needed to get here.
      await tester.tap(find.byKey(filterChipKey('equipment', 'Barbell')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(filterChipKey('muscle', 'Legs')));
      await tester.pumpAndSettle();

      expect(find.text('Back Squat'), findsOneWidget);
      expect(find.textContaining('ARMS ·'), findsNothing);
      expect(find.text('Leg Press'), findsNothing, reason: 'a machine');

      // And letting the chips go brings the rest back.
      await tester.tap(find.byKey(kFilterClearKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('ARMS ·'), findsOneWidget);

      await stop(tester);
    });
  });

  group('a bar can be chosen by name', () {
    test('the named bars are the ones a gym actually racks', () {
      final kg = namedBars('kg');
      expect(kg.map((b) => b.name), contains('EZ curl bar'));
      expect(kg.map((b) => b.name), contains('Trap bar'));
      expect(kg.map((b) => b.name), contains('Smith carriage'));

      // Every one of them carries a real weight, in canonical kilograms.
      expect(kg.every((b) => b.weight > 0), isTrue);
      expect(
        kg.firstWhere((b) => b.name == 'Olympic bar').weight,
        20,
      );
    });

    test('a pounds gym gets the round pounds number, not a converted kilo', () {
      final lb = namedBars('lb');
      final olympic = lb.firstWhere((b) => b.name == 'Olympic bar');
      // 45 lb, which is 20.41 kg — not the metric bar's 20.
      expect(toDisplayWeight(olympic.weight, 'lb'), closeTo(45, 0.01));
      expect(olympic.weight, isNot(20));
    });

    testWidgets('picking one by name sets the exercise to its weight',
        (tester) async {
      final curl =
          (await tester.runAsync(() => exerciseNamed(db, 'Barbell Curl')))!;
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(routedAppUnder(
          container, ExerciseDetailScreen(exerciseId: curl.id)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bar weight'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EZ curl bar'));
      await tester.pumpAndSettle();

      final saved = (await tester.runAsync(() => db.exerciseById(curl.id)))!;
      expect(saved.barWeight, 10);

      await stop(tester);
    });

    testWidgets('an odd bar is still a number you can type', (tester) async {
      final curl =
          (await tester.runAsync(() => exerciseNamed(db, 'Barbell Curl')))!;
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(routedAppUnder(
          container, ExerciseDetailScreen(exerciseId: curl.id)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bar weight'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Something else'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '7.5');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = (await tester.runAsync(() => db.exerciseById(curl.id)))!;
      expect(saved.barWeight, 7.5);

      await stop(tester);
    });
  });
}
