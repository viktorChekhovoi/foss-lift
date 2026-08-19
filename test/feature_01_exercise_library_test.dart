// Integration tests for features/index.html#sec01
//
// The exercise library: a curated starter set (a demo link on every entry),
// custom exercises alongside it, a weight type seeded from equipment and
// overridable for any exercise, a measure fixed at creation, and history that
// survives library edits because logged sets store the name denormalised.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/data/warmup.dart';
import 'package:foss_lift/data/exercise_filter.dart';
import 'package:foss_lift/screens/exercise_detail_screen.dart';
import 'package:foss_lift/screens/exercise_form_screen.dart';
import 'package:foss_lift/screens/library_screen.dart';
import 'package:foss_lift/util/units.dart';
import 'package:foss_lift/util/video_links.dart';
import 'package:foss_lift/widgets/exercise_filters.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

/// The groups that are actually muscles — what a day of training has to be able
/// to cover with whatever equipment it has.
///
/// `Other` is the shelf everything unclassified lands on, and `Cardio` names what
/// a set is *for* rather than a muscle it works: neither is something a dumbbell
/// day owes you, and demanding coverage of them would be demanding a dumbbell
/// sprint.
final List<String> _muscleGroupsProper =
    kMuscleGroups.where((g) => g != 'Other' && g != 'Cardio').toList();

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  group('starter library', () {
    test('ships a curated starter set, none of it marked custom', () async {
      final all = await db.watchExercises().first;
      final starters = all.where((e) => !e.isCustom).toList();

      // 136 curated movements. Exactly the seeded set is custom-free.
      expect(starters.length, 136);
      expect(all.every((e) => !e.isCustom), isTrue);
    });

    test('no movement is seeded twice', () async {
      final names = (await db.watchExercises().first).map((e) => e.name);
      expect(names.toSet().length, names.length);
    });

    test(
      'the starter set covers every muscle group and every equipment kind',
      () async {
        final all = await db.watchExercises().first;

        // A group nobody can fill from the library is a group the picker offers
        // for nothing. Other is the exception and deliberately so: it is where
        // a movement of your own that answers to nothing on the list goes, and
        // no starter needs it now that a movement can name several groups.
        for (final group in kMuscleGroups.where((g) => g != 'Other')) {
          expect(
            all.where((e) => e.muscles.trains(group)).length,
            greaterThanOrEqualTo(3),
            reason: '$group is thin in the starter library',
          );
        }
        for (final kind in kEquipmentTypes) {
          expect(
            all.any((e) => e.equipment == kind),
            isTrue,
            reason: 'nothing in the library is $kind',
          );
        }
      },
    );

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

    test('a starter demo is optional, and most of the set has one', () async {
      final starters = (await db.watchExercises().first).where(
        (e) => !e.isCustom,
      );

      // No demo is now a real answer: a movement nobody found a video for that
      // they could stand behind ships with none rather than with a guessed id
      // pointing at somebody else's clip. A blank string is *not* that answer —
      // every screen asks whether the field is null, so an empty one reads as a
      // link and opens nothing.
      for (final e in starters) {
        expect(
          e.videoUrl,
          anyOf(isNull, isNotEmpty),
          reason: '${e.name} carries an empty demo link',
        );
      }
      // And the library is still overwhelmingly demonstrated: without a floor,
      // a table that quietly lost its links passes every other check here.
      expect(
        starters.where((e) => e.videoUrl != null).length,
        greaterThanOrEqualTo(93),
        reason: 'three quarters of the 123 starters should show a demo',
      );
    });

    test('and it is a specific video, not a search for one', () async {
      // These were `youtube.com/results?search_query=…`, which is a page of
      // results to pick from rather than a demo — and, having no video id in
      // it, nothing a shared routine could carry either. The starters with no
      // demo at all are not this failure and are skipped.
      final all = await db.watchExercises().first;

      for (final e in all.where((e) => !e.isCustom && e.videoUrl != null)) {
        expect(
          youTubeVideoId(e.videoUrl ?? ''),
          isNotNull,
          reason: '${e.name} links to "${e.videoUrl}", which names no video',
        );
        expect(
          e.videoUrl,
          startsWith('https://youtu.be/'),
          reason: '${e.name} is not stored in the canonical short form',
        );
      }
    });

    test('no two starters point at the same video', () async {
      // A copy-paste slip in the table is invisible on screen — both links
      // work, they are just the wrong demo on one of them.
      final all = (await db.watchExercises().first).where(
        (e) => !e.isCustom && e.videoUrl != null,
      );
      final byId = <String, List<String>>{};
      for (final e in all) {
        byId
            .putIfAbsent(youTubeVideoId(e.videoUrl ?? '')!, () => [])
            .add(e.name);
      }
      final shared = byId.entries.where((x) => x.value.length > 1).toList();
      expect(
        shared,
        isEmpty,
        reason:
            'shared demo videos: '
            '${shared.map((x) => '${x.key} → ${x.value}').join('; ')}',
      );
    });

    test('a custom exercise sits alongside the starter set', () async {
      await db.createExercise(
        name: 'Zercher Squat',
        muscles: MuscleMap.single('Legs'),
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

  group('enough of it to train with nothing, with dumbbells, or for time', () {
    /// The movements the starter set grew by, and what each of them says about
    /// itself: the groups it trains (the first the one it files under), the
    /// groups it assists, what it is done with, and whether a set of it is
    /// counted or run against the clock.
    ///
    /// A gym's library was the starting point, so a routine for an empty room
    /// or a pair of dumbbells had almost nothing to be built out of.
    const grown =
        <String, (List<String>, List<String>, String, ExerciseMeasure)>{
      // An empty room.
      'Air Squat': (['Legs'], ['Core'], 'Bodyweight', ExerciseMeasure.reps),
      'Bodyweight Lunge': (
        ['Legs'],
        ['Core'],
        'Bodyweight',
        ExerciseMeasure.reps,
      ),
      'Pike Push-Up': (
        ['Shoulders', 'Arms'],
        ['Chest', 'Core'],
        'Bodyweight',
        ExerciseMeasure.reps,
      ),
      'Diamond Push-Up': (
        ['Arms', 'Chest'],
        ['Shoulders', 'Core'],
        'Bodyweight',
        ExerciseMeasure.reps,
      ),
      'Wide Push-Up': (
        ['Chest'],
        ['Shoulders', 'Arms', 'Core'],
        'Bodyweight',
        ExerciseMeasure.reps,
      ),
      'Decline Push-Up': (
        ['Chest', 'Shoulders'],
        ['Arms', 'Core'],
        'Bodyweight',
        ExerciseMeasure.reps,
      ),
      'Nordic Curl': (['Legs'], ['Core'], 'Bodyweight', ExerciseMeasure.reps),
      'Single-Leg Glute Bridge': (
        ['Legs'],
        ['Core'],
        'Bodyweight',
        ExerciseMeasure.reps,
      ),
      'Wall Sit': (['Legs'], ['Core'], 'Bodyweight', ExerciseMeasure.time),
      'Superman Hold': (
        ['Back'],
        ['Legs', 'Core'],
        'Bodyweight',
        ExerciseMeasure.time,
      ),
      'Bird Dog': (
        ['Core'],
        ['Back', 'Legs'],
        'Bodyweight',
        ExerciseMeasure.reps,
      ),
      'Sit-Up': (['Core'], [], 'Bodyweight', ExerciseMeasure.reps),
      // Conditioning: some of it counted, most of it a work period.
      'Burpee': (
        ['Cardio'],
        ['Legs', 'Chest', 'Arms', 'Shoulders', 'Core'],
        'Bodyweight',
        ExerciseMeasure.reps,
      ),
      'Mountain Climber': (
        ['Cardio'],
        ['Core', 'Legs', 'Shoulders', 'Chest'],
        'Bodyweight',
        ExerciseMeasure.time,
      ),
      'High Knees': (
        ['Cardio'],
        ['Legs', 'Core'],
        'Bodyweight',
        ExerciseMeasure.time,
      ),
      'Jumping Jack': (
        ['Cardio'],
        ['Legs', 'Shoulders', 'Core'],
        'Bodyweight',
        ExerciseMeasure.reps,
      ),
      'Jump Squat': (
        ['Cardio'],
        ['Legs', 'Core'],
        'Bodyweight',
        ExerciseMeasure.reps,
      ),
      'Box Jump': (
        ['Cardio'],
        ['Legs', 'Core'],
        'Bodyweight',
        ExerciseMeasure.reps,
      ),
      'Skater Jump': (
        ['Cardio'],
        ['Legs', 'Core'],
        'Bodyweight',
        ExerciseMeasure.reps,
      ),
      'Bear Crawl': (
        ['Cardio'],
        ['Core', 'Shoulders', 'Legs', 'Arms'],
        'Bodyweight',
        ExerciseMeasure.time,
      ),
      'Sprint': (
        ['Cardio'],
        ['Legs', 'Core'],
        'Bodyweight',
        ExerciseMeasure.time,
      ),
      'Jump Rope': (
        ['Cardio'],
        ['Legs', 'Shoulders', 'Core'],
        'Other',
        ExerciseMeasure.time,
      ),
      'Battle Rope': (
        ['Cardio'],
        ['Shoulders', 'Arms', 'Back', 'Core'],
        'Other',
        ExerciseMeasure.time,
      ),
      'Shadow Boxing': (
        ['Cardio'],
        ['Shoulders', 'Core', 'Arms', 'Legs'],
        'Bodyweight',
        ExerciseMeasure.time,
      ),
      'Dumbbell Thruster': (
        ['Legs', 'Shoulders'],
        ['Arms', 'Core'],
        'Dumbbell',
        ExerciseMeasure.reps,
      ),
      'Dumbbell Clean and Press': (
        ['Shoulders', 'Legs', 'Back'],
        ['Arms', 'Core'],
        'Dumbbell',
        ExerciseMeasure.reps,
      ),
      'Dumbbell Snatch': (
        ['Legs', 'Shoulders', 'Back'],
        ['Arms', 'Core'],
        'Dumbbell',
        ExerciseMeasure.reps,
      ),
      'Dumbbell Romanian Deadlift': (
        ['Legs', 'Back'],
        ['Core', 'Arms'],
        'Dumbbell',
        ExerciseMeasure.reps,
      ),
      'Dumbbell Deadlift': (
        ['Legs', 'Back'],
        ['Core', 'Arms'],
        'Dumbbell',
        ExerciseMeasure.reps,
      ),
      'Dumbbell Front Squat': (
        ['Legs'],
        ['Core', 'Shoulders', 'Arms'],
        'Dumbbell',
        ExerciseMeasure.reps,
      ),
      'Dumbbell Lunge': (['Legs'], ['Core'], 'Dumbbell', ExerciseMeasure.reps),
      'Dumbbell Lateral Lunge': (
        ['Legs'],
        ['Core'],
        'Dumbbell',
        ExerciseMeasure.reps,
      ),
      'Dumbbell Floor Press': (
        ['Chest', 'Arms'],
        ['Shoulders'],
        'Dumbbell',
        ExerciseMeasure.reps,
      ),
      'Renegade Row': (
        ['Back', 'Core', 'Arms'],
        ['Shoulders', 'Chest'],
        'Dumbbell',
        ExerciseMeasure.reps,
      ),
      'Dumbbell Pullover': (
        ['Chest', 'Back'],
        ['Arms', 'Core'],
        'Dumbbell',
        ExerciseMeasure.reps,
      ),
      'Dumbbell Push Press': (
        ['Shoulders', 'Arms'],
        ['Legs', 'Core'],
        'Dumbbell',
        ExerciseMeasure.reps,
      ),
    };

    /// The starter called [name] — reported as missing rather than as a "Bad
    /// state: No element" from inside a `firstWhere`, which names nothing.
    Future<Exercise> starter(String name) async {
      final match = (await db.watchExercises().first).where(
        (e) => e.name == name,
      );
      expect(match, hasLength(1), reason: '$name is not in the library');
      return match.single;
    }

    test('each of the new movements says what the table says', () async {
      final all = await db.watchExercises().first;

      for (final entry in grown.entries) {
        final matches = all.where((e) => e.name == entry.key);
        expect(matches, hasLength(1), reason: '${entry.key} is not seeded');
        final e = matches.single;
        expect(e.isCustom, isFalse, reason: entry.key);
        expect(e.muscles.primary, entry.value.$1, reason: entry.key);
        expect(e.muscles.secondary, entry.value.$2, reason: entry.key);
        expect(e.equipment, entry.value.$3, reason: entry.key);
        expect(e.measure, entry.value.$4, reason: entry.key);
      }
    });

    test('a session can be furnished with no equipment at all', () async {
      final all = await db.watchExercises().first;
      final bare = all.where((e) => e.equipment == 'Bodyweight').toList();

      expect(
        bare.length,
        greaterThanOrEqualTo(25),
        reason: 'a routine for an empty room is built out of these',
      );
      // A floor is not coverage: every muscle has to be reachable without
      // equipment, or a whole day of a no-equipment routine has nothing in it.
      for (final group in _muscleGroupsProper) {
        expect(
          bare.where((e) => e.muscles.trains(group)),
          isNotEmpty,
          reason: 'nothing bodyweight trains $group',
        );
      }
    });

    test('and the same holds for a pair of dumbbells', () async {
      final all = await db.watchExercises().first;
      final dumbbells = all.where((e) => e.equipment == 'Dumbbell').toList();

      expect(dumbbells.length, greaterThanOrEqualTo(25));
      for (final group in _muscleGroupsProper) {
        expect(
          dumbbells.where((e) => e.muscles.trains(group)),
          isNotEmpty,
          reason: 'nothing on dumbbells trains $group',
        );
      }
    });

    test('the ropes are conditioning kit, not a loaded machine', () async {
      // Their equipment is "Other", which is the shelf everything unnamed lands
      // on and the shelf whose default loading is a machine. A jump rope with a
      // weight column wanting a number is the failure this catches.
      for (final name in ['Jump Rope', 'Battle Rope']) {
        final e = await starter(name);
        expect(e.equipment, 'Other', reason: name);
        expect(e.weightType, WeightType.none, reason: name);
        expect(e.weightType.carriesWeight, isFalse, reason: name);
      }
    });

    test('the conditioning work you can count is counted', () async {
      // A burpee has a bottom and a top, so it has a rep. Only the movements
      // with no rep in them are handed the clock.
      for (final name in [
        'Burpee',
        'Jump Squat',
        'Box Jump',
        'Skater Jump',
        'Jumping Jack',
      ]) {
        expect((await starter(name)).measure, ExerciseMeasure.reps,
            reason: name);
      }
    });

    test('each of them follows a language switch like any other starter',
        () async {
      // The name on screen is rendered from the seed key, so a movement seeded
      // without one is frozen in English while the rest of the library moves.
      for (final name in grown.keys) {
        expect(
          (await starter(name)).seedKey,
          isNotNull,
          reason: '$name has no seed key',
        );
      }
    });
  });

  group('a movement names every group it trains, and every one it helps', () {
    test('the primaries keep the order they were given, the first the lead',
        () {
      final bench = MuscleMap(
        primary: ['Chest', 'Arms'],
        secondary: ['Shoulders'],
      );

      expect(bench.primary, ['Chest', 'Arms']);
      expect(bench.secondary, ['Shoulders']);
      expect(bench.lead, 'Chest', reason: 'the first primary is where it files');
      expect(bench.all, ['Chest', 'Arms', 'Shoulders']);
    });

    test('a group is never both trained and assisted', () {
      final map = MuscleMap(
        primary: ['Back', 'Arms'],
        secondary: ['Arms', 'Core'],
      );

      expect(map.primary, ['Back', 'Arms']);
      expect(
        map.secondary,
        ['Core'],
        reason: 'a group the movement is for is not also a group it helps with',
      );
    });

    test('blanks and repeats are dropped, the first position kept', () {
      final map = MuscleMap(
        primary: ['Legs', '', 'Back', 'Legs'],
        secondary: ['Core', 'Core', ''],
      );

      expect(map.primary, ['Legs', 'Back']);
      expect(map.secondary, ['Core']);
    });

    test('a movement that trains nothing is filed under Other', () {
      // Not a state any screen can reach — the form will not let the last
      // primary go — but a routine code from anywhere can claim it.
      final map = MuscleMap(primary: [], secondary: ['Core']);

      expect(map.primary, ['Other']);
      expect(map.lead, 'Other');
      expect(map.secondary, ['Core']);
    });

    test('one group is the whole map an old row carries', () {
      final map = MuscleMap.single('Legs');

      expect(map.primary, ['Legs']);
      expect(map.secondary, isEmpty);
      expect(map.all, ['Legs']);
    });

    test('trains asks the primaries; touches asks either', () {
      final bench = MuscleMap(
        primary: ['Chest', 'Arms'],
        secondary: ['Shoulders'],
      );

      expect(bench.trains('Chest'), isTrue);
      expect(bench.trains('Shoulders'), isFalse);
      expect(bench.touches('Shoulders'), isTrue);
      expect(bench.touches('Legs'), isFalse);
    });

    /// What the shipped table says each of these movements is for, and what it
    /// works on the way. The compounds are the point: one group was never the
    /// truth about a bench press.
    const expected = <String, (List<String>, List<String>)>{
      'Bench Press': (['Chest', 'Arms'], ['Shoulders']),
      'Back Squat': (['Legs'], ['Core', 'Back']),
      'Deadlift': (['Back', 'Legs'], ['Arms', 'Core']),
      'Pull-Up': (['Back', 'Arms'], ['Core']),
      'Overhead Press': (['Shoulders', 'Arms'], ['Core']),
      'Lateral Raise': (['Shoulders'], []),
      'Plank': (['Core'], []),
      'Power Clean': (['Legs', 'Back', 'Shoulders'], ['Arms', 'Core']),
      'Kettlebell Swing': (['Legs', 'Back'], ['Core', 'Arms']),
      'Turkish Get-Up': (['Core', 'Shoulders'], ['Legs', 'Arms']),
    };

    test('the starter set says what each movement actually trains', () async {
      for (final entry in expected.entries) {
        final e = await exerciseNamed(db, entry.key);
        expect(e.muscles.primary, entry.value.$1, reason: entry.key);
        expect(e.muscles.secondary, entry.value.$2, reason: entry.key);
      }
    });

    test('the lead is the group the row is stored under', () async {
      // Which is what keeps ordering, the history rollups and an FLR1 code
      // reading exactly as they did.
      for (final e in await db.watchExercises().first) {
        expect(e.muscles.lead, e.muscleGroup, reason: e.name);
      }
    });

    test('no starter files under Other any more', () async {
      final all = await db.watchExercises().first;

      expect(
        all.where((e) => e.muscleGroup == 'Other').map((e) => e.name),
        isEmpty,
        reason: 'the swing, the clean and the get-up can name what they train',
      );
      // Other stays in the vocabulary, and stays legal: it is where a movement
      // of your own that answers to nothing on the list goes.
      expect(kMuscleGroups, contains('Other'));
      final id = await db.createExercise(
        name: 'Sandbag Carry',
        muscles: MuscleMap.single('Other'),
        equipment: 'Other',
      );
      expect((await db.exerciseById(id)).muscles.lead, 'Other');
    });

    test('and the maps invent no vocabulary outside the seven', () async {
      for (final e in await db.watchExercises().first) {
        for (final group in e.muscles.all) {
          expect(kMuscleGroups, contains(group), reason: '${e.name} → $group');
        }
      }
    });

    test('a movement of your own stores every group it was made with',
        () async {
      final id = await db.createExercise(
        name: 'Zercher Squat',
        muscles: MuscleMap(
          primary: ['Legs', 'Core'],
          secondary: ['Back', 'Arms'],
        ),
        equipment: 'Barbell',
      );

      final made = await db.exerciseById(id);
      expect(made.muscles.primary, ['Legs', 'Core']);
      expect(made.muscles.secondary, ['Back', 'Arms']);
      expect(
        made.muscleGroup,
        'Legs',
        reason: 'the lead is the column the library files it under',
      );
    });

    test('and an edit rewrites the whole map, lead included', () async {
      final id = await db.createExercise(
        name: 'Zercher Squat',
        muscles: MuscleMap.single('Legs'),
        equipment: 'Barbell',
      );

      await db.updateCustomExercise(
        id,
        name: 'Zercher Squat',
        muscles: MuscleMap(primary: ['Back', 'Legs'], secondary: ['Arms']),
        equipment: 'Barbell',
        videoUrl: null,
        measure: ExerciseMeasure.reps,
        weightType: WeightType.bar,
      );

      final after = await db.exerciseById(id);
      expect(after.muscles.primary, ['Back', 'Legs']);
      expect(after.muscles.secondary, ['Arms']);
      expect(after.muscleGroup, 'Back');
    });

    test('the separator is not a comma, so a shared group can be anything', () {
      // A group that arrived in a routine code is any string the sender typed.
      expect(kGroupSeparator, isNot(contains(',')));
      final map = MuscleMap(
        primary: ['Legs, Glutes and Hips'],
        secondary: ['Core'],
      );
      expect(map.primary, ['Legs, Glutes and Hips']);
    });

    testWidgets('the library lists a compound once, under its lead', (
      tester,
    ) async {
      // A library that showed a compound once per group it trains would be half
      // again as long, and would show the same row twice on the way to a
      // movement you can already see.
      // Tall enough for the whole narrowed list: "listed once" is not a claim
      // you can make about a list that is mostly scrolled off.
      tester.view.physicalSize = const Size(600, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(routedAppUnder(container, const LibraryScreen()));
      await tester.pumpAndSettle();

      // Narrowed to Arms — which the bench press trains, as its second primary.
      for (final (dimension, value) in [
        ('muscle', 'Arms'),
        ('equipment', 'Barbell'),
      ]) {
        await tester.tap(find.byKey(filterButtonKey(dimension)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(filterChipKey(dimension, value)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(kFilterSheetDoneKey));
        await tester.pumpAndSettle();
      }

      expect(
        find.text('Bench Press'),
        findsOneWidget,
        reason: 'once, not once per group it trains',
      );
      expect(
        find.textContaining('CHEST ·'),
        findsOneWidget,
        reason: 'and under the first of its primaries',
      );

      await stop(tester);
    });
  });

  group('the detail page reads the groups as two lines', () {
    Future<void> openDetail(WidgetTester tester, int id) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        routedAppUnder(container, ExerciseDetailScreen(exerciseId: id)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('what it trains, then what it also works', (tester) async {
      final bench = (await tester.runAsync(
        () => exerciseNamed(db, 'Bench Press'),
      ))!;
      await openDetail(tester, bench.id);

      for (final group in ['Chest', 'Arms', 'Shoulders']) {
        expect(find.text(group), findsOneWidget, reason: group);
      }
      // Two lines, in that order: what it is for above what it works on the way.
      final trains = tester.getTopLeft(find.text('Chest')).dy;
      final assists = tester.getTopLeft(find.text('Shoulders')).dy;
      expect(assists, greaterThan(trains));
      expect(
        tester.getTopLeft(find.text('Arms')).dy,
        trains,
        reason: 'both primaries are on the first line',
      );

      await stop(tester);
    });

    testWidgets('and the second line is absent when there is nothing on it', (
      tester,
    ) async {
      final raise = (await tester.runAsync(
        () => exerciseNamed(db, 'Lateral Raise'),
      ))!;
      await openDetail(tester, raise.id);

      expect(find.text('Shoulders'), findsOneWidget);
      for (final group in ['Chest', 'Back', 'Legs', 'Arms', 'Core']) {
        expect(
          find.text(group),
          findsNothing,
          reason: 'a lateral raise has no secondaries to show',
        );
      }

      await stop(tester);
    });
  });

  group('the form ticks the primaries first, then the secondaries', () {
    setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

    /// A movement of your own with [map] on it, ready to reopen in the form.
    Future<int> mine(WidgetTester tester, MuscleMap map) async =>
        (await tester.runAsync(
          () => db.createExercise(
            name: 'Zercher Squat',
            muscles: map,
            equipment: 'Barbell',
            weightType: WeightType.bar,
          ),
        ))!;

    Future<void> openEditor(WidgetTester tester, int id) async {
      // Tall enough for both chip rows and the Save button below them.
      tester.view.physicalSize = const Size(1000, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        routedAppUnder(container, ExerciseFormScreen(exerciseId: id)),
      );
      await tester.pumpAndSettle();
    }

    /// The [group] chip in the row that says what the movement trains (row 0)
    /// or what it also works (row 1). The same seven chips twice, so the two
    /// rows are told apart by where they are.
    Finder chip(String group, int row) => find.text(group).at(row);

    Future<void> tapChip(WidgetTester tester, String group, int row) async {
      await tester.tap(chip(group, row));
      await tester.pumpAndSettle();
    }

    Future<Exercise> save(WidgetTester tester, int id) async {
      await tester.tap(find.text('Save exercise'));
      await tester.pumpAndSettle();
      return (await tester.runAsync(() => db.exerciseById(id)))!;
    }

    testWidgets('two rows offer the same seven groups', (tester) async {
      await openEditor(tester, await mine(tester, MuscleMap.single('Legs')));

      for (final group in kMuscleGroups.where((g) => g != 'Other')) {
        expect(
          find.text(group),
          findsNWidgets(2),
          reason: '$group is offered as a primary and as a secondary',
        );
      }
      // "Other" is a muscle group and an equipment kind both, so it is on the
      // form three times — which is the one collision in the vocabulary.
      expect(find.text('Other'), findsNWidgets(3));

      await stop(tester);
    });

    testWidgets('the order you tick them in is the order they are stored', (
      tester,
    ) async {
      final id = await mine(tester, MuscleMap.single('Legs'));
      await openEditor(tester, id);

      await tapChip(tester, 'Back', 0);
      await tapChip(tester, 'Core', 0);
      final saved = await save(tester, id);

      expect(saved.muscles.primary, ['Legs', 'Back', 'Core']);
      expect(
        saved.muscles.lead,
        'Legs',
        reason: 'the first one picked is the group it files under',
      );

      await stop(tester);
    });

    testWidgets('ticking a group as secondary takes it off the primaries', (
      tester,
    ) async {
      final id = await mine(
        tester,
        MuscleMap(primary: ['Legs', 'Back'], secondary: []),
      );
      await openEditor(tester, id);

      await tapChip(tester, 'Back', 1);
      final saved = await save(tester, id);

      expect(saved.muscles.primary, ['Legs']);
      expect(saved.muscles.secondary, ['Back']);

      await stop(tester);
    });

    testWidgets('and the other way round', (tester) async {
      final id = await mine(
        tester,
        MuscleMap(primary: ['Legs'], secondary: ['Core']),
      );
      await openEditor(tester, id);

      await tapChip(tester, 'Core', 0);
      final saved = await save(tester, id);

      expect(saved.muscles.primary, ['Legs', 'Core']);
      expect(saved.muscles.secondary, isEmpty);

      await stop(tester);
    });

    testWidgets('the last primary cannot be unticked', (tester) async {
      // A movement that trains nothing is not a movement.
      final id = await mine(tester, MuscleMap.single('Legs'));
      await openEditor(tester, id);

      await tapChip(tester, 'Legs', 0);
      final saved = await save(tester, id);

      expect(saved.muscles.primary, ['Legs']);

      await stop(tester);
    });

    testWidgets('a secondary can be let go entirely', (tester) async {
      final id = await mine(
        tester,
        MuscleMap(primary: ['Legs'], secondary: ['Core']),
      );
      await openEditor(tester, id);

      await tapChip(tester, 'Core', 1);
      final saved = await save(tester, id);

      expect(saved.muscles.secondary, isEmpty);
      expect(saved.muscles.primary, ['Legs']);

      await stop(tester);
    });

    testWidgets('a movement made from scratch carries the map it was ticked', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        routedAppUnder(container, const ExerciseFormScreen()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Sandbag Clean');
      await tapChip(tester, 'Core', 1);
      await tester.tap(find.text('Save exercise'));
      await tester.pumpAndSettle();

      final made = (await tester.runAsync(
        () => db.watchExercises().first,
      ))!.firstWhere((e) => e.name == 'Sandbag Clean');
      expect(
        made.muscles.primary,
        isNotEmpty,
        reason: 'every exercise has at least one primary',
      );
      expect(made.muscles.secondary, ['Core']);
      expect(made.muscles.trains('Core'), isFalse);

      await stop(tester);
    });
  });

  group('every starter is seeded with the loading it actually uses', () {
    test('a loaded movement is loaded — never bodyweight', () async {
      // The complaint this answers: a barbell curl is a bar, not something you
      // do with your own weight.
      expect(
        (await exerciseNamed(db, 'Barbell Curl')).weightType,
        WeightType.bar,
      );
      expect(
        (await exerciseNamed(db, 'Bench Press')).weightType,
        WeightType.bar,
      );
      expect(
        (await exerciseNamed(db, 'Incline DB Press')).weightType,
        WeightType.dumbbell,
      );
      expect(
        (await exerciseNamed(db, 'Leg Press')).weightType,
        WeightType.machine,
      );
      expect(
        (await exerciseNamed(db, 'Triceps Pushdown')).weightType,
        WeightType.machine,
      ); // a cable stack reads as a machine

      final all = await db.watchExercises().first;
      final loaded = all.where(
        (e) =>
            // A cardio machine is equipment `Machine` and has no load at all —
            // a treadmill's number is its speed. See _starterLoadings.
            !e.isCardioMachine &&
            (e.equipment == 'Barbell' ||
                e.equipment == 'Dumbbell' ||
                e.equipment == 'Machine' ||
                e.equipment == 'Cable'),
      );
      for (final e in loaded) {
        expect(
          e.weightType,
          isNot(WeightType.none),
          reason: '${e.name} is a ${e.equipment} movement',
        );
      }
    });

    test('the equipment decides it, one kind at a time', () async {
      const expected = {
        'Barbell': WeightType.bar,
        'Dumbbell': WeightType.dumbbell,
        'Machine': WeightType.machine,
        'Cable': WeightType.machine,
        'Bodyweight': WeightType.none,
      };
      // The movements whose equipment does not say how they are held: a
      // kettlebell is a weight in one hand; an ab wheel, a rope you skip and a
      // rope you slam are nothing at all; and a cardio machine is a `Machine`
      // with no weight stack behind it.
      const byHand = {
        'Kettlebell Swing': WeightType.dumbbell,
        'Turkish Get-Up': WeightType.dumbbell,
        'Ab Wheel Rollout': WeightType.none,
        'Jump Rope': WeightType.none,
        'Battle Rope': WeightType.none,
        'Treadmill': WeightType.none,
        'Elliptical': WeightType.none,
        'Stationary Bike': WeightType.none,
        'Recumbent Bike': WeightType.none,
        'Rowing Machine': WeightType.none,
        'Stair Climber': WeightType.none,
        'Air Bike': WeightType.none,
        'Ski Erg': WeightType.none,
        'Arc Trainer': WeightType.none,
        "Jacob's Ladder": WeightType.none,
      };

      for (final e in await db.watchExercises().first) {
        final want = byHand[e.name] ?? expected[e.equipment];
        if (want == null) continue; // 'Other' equipment, typed by hand above
        expect(e.weightType, want, reason: '${e.name} (${e.equipment})');
      }
      final all = await db.watchExercises().first;
      for (final entry in byHand.entries) {
        final match = all.where((e) => e.name == entry.key);
        expect(match, hasLength(1), reason: '${entry.key} is not seeded');
        expect(match.single.weightType, entry.value, reason: entry.key);
      }
    });

    test(
      'nothing carries no loading but the movements that genuinely do not',
      () async {
        final all = await db.watchExercises().first;
        final bare = all
            .where((e) => e.weightType == WeightType.none)
            .map((e) => e.name);

        // Every bodyweight starter, plus the three on the Other shelf that
        // carry nothing: the wheel and the two ropes.
        expect(bare.toSet(), {
          'Push-Up',
          'Chest Dip',
          'Pull-Up',
          'Chin-Up',
          'Inverted Row',
          'Back Extension',
          'Glute Bridge',
          'Triceps Dip',
          'Dead Hang',
          'Ab Wheel Rollout',
          'Plank',
          'Side Plank',
          'Hollow Hold',
          'Hanging Leg Raise',
          'Crunch',
          'Reverse Crunch',
          'Russian Twist',
          'Dead Bug',
          // The room with nothing in it.
          'Air Squat',
          'Bodyweight Lunge',
          'Pike Push-Up',
          'Diamond Push-Up',
          'Wide Push-Up',
          'Decline Push-Up',
          'Nordic Curl',
          'Single-Leg Glute Bridge',
          'Wall Sit',
          'Superman Hold',
          'Bird Dog',
          'Sit-Up',
          // The conditioning work.
          'Burpee',
          'Mountain Climber',
          'High Knees',
          'Jumping Jack',
          'Jump Squat',
          'Box Jump',
          'Skater Jump',
          'Bear Crawl',
          'Sprint',
          'Shadow Boxing',
          'Jump Rope',
          'Battle Rope',
          // The cardio floor: a console with no load to name.
          'Treadmill',
          'Elliptical',
          'Stationary Bike',
          'Recumbent Bike',
          'Rowing Machine',
          'Stair Climber',
          'Air Bike',
          'Ski Erg',
          'Arc Trainer',
          "Jacob's Ladder",
        });
      },
    );

    test('the equipment→type rule itself', () {
      expect(weightTypeForEquipment('Barbell'), WeightType.bar);
      expect(weightTypeForEquipment('Dumbbell'), WeightType.dumbbell);
      expect(weightTypeForEquipment('Cable'), WeightType.machine);
      expect(weightTypeForEquipment('Bodyweight'), WeightType.none);
      expect(weightTypeForEquipment('anything else'), WeightType.machine);
    });

    test(
      'a new custom exercise starts on a real load, not bodyweight',
      () async {
        final id = await db.createExercise(
          name: 'Sled Push',
          muscles: MuscleMap.single('Legs'),
          equipment: 'Sled',
        );
        final made = await db.exerciseById(id);
        expect(made.weightType, WeightType.machine);
        expect(made.weightType, isNot(WeightType.none));
      },
    );

    test('a loading that is nothing is still a stored answer', () async {
      // A weighted pull-up, told it carries nothing again: a seeded barbell lift
      // cannot be, because its equipment settles the question.
      final pull = await exerciseNamed(db, 'Pull-Up');
      await db.setExerciseWeightType(pull.id, WeightType.dumbbell);

      await db.setExerciseWeightType(pull.id, WeightType.none);

      final after = await db.exerciseById(pull.id);
      expect(after.weightType, WeightType.none);
      // And nothing about it breaks down into plates.
      expect(after.weightType.loadedPerSide, isFalse);
      expect(after.weightType.carriesWeight, isFalse);
    });
  });

  group('weight type & bar are overridable where they are a choice', () {
    test(
      'a starter whose equipment says nothing can be reclassified',
      () async {
        // "Other" is the word for equipment that fitted no name, so the seed's
        // loading for it is a guess — and a guess is overrulable.
        final swing = await exerciseNamed(db, 'Kettlebell Swing');
        expect(swing.equipment, 'Other');

        await db.setExerciseWeightType(swing.id, WeightType.dumbbell);

        expect(
          (await db.exerciseById(swing.id)).weightType,
          WeightType.dumbbell,
        );
      },
    );

    test('and a barbell curl cannot: its name has already answered', () async {
      final curl = await exerciseNamed(db, 'Barbell Curl');
      expect(curl.weightType, WeightType.bar);

      await db.setExerciseWeightType(curl.id, WeightType.machine);

      expect((await db.exerciseById(curl.id)).weightType, WeightType.bar);
    });

    test(
      'a barbell lift not named for the bar is still yours to reclassify',
      () async {
        // The user's own examples: a skull crusher is done with dumbbells or on a
        // machine as often as with a bar, and "Barbell" is only what the seed
        // guessed about the gym.
        final skull = await exerciseNamed(db, 'Skull Crusher');
        expect(skull.equipment, 'Barbell');

        await db.setExerciseWeightType(skull.id, WeightType.dumbbell);

        expect(
          (await db.exerciseById(skull.id)).weightType,
          WeightType.dumbbell,
        );
      },
    );

    test('and a machine can be told it is plate-loaded', () async {
      // A chest-supported row is often a bar with plates on it, and the plate
      // maths is the reason to say so.
      final row = await exerciseNamed(db, 'Chest-Supported Row');
      expect(row.equipment, 'Machine');

      await db.setExerciseWeightType(row.id, WeightType.bar);

      expect((await db.exerciseById(row.id)).weightType, WeightType.bar);
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
        muscles: MuscleMap.single('Arms'),
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
    test(
      'the held starters are exactly the movements with no rep to count',
      () async {
        final all = await db.watchExercises().first;
        final held = all
            .where((e) => e.measure == ExerciseMeasure.time)
            .toList();

        // Twenty-four: the positions you get into and stay in, the two you hold
        // under load, the conditioning movements whose set is a work period —
        // nobody counts mountain climbers, they run the clock for thirty
        // seconds — and the ten cardio machines, where twenty minutes is the
        // whole prescription.
        expect(held.map((e) => e.name).toSet(), {
          'Plank',
          'Side Plank',
          'Hollow Hold',
          'Dead Hang',
          "Farmer's Carry",
          'Wall Sit',
          'Superman Hold',
          'High Knees',
          'Mountain Climber',
          'Bear Crawl',
          'Sprint',
          'Jump Rope',
          'Battle Rope',
          'Shadow Boxing',
          'Treadmill',
          'Elliptical',
          'Stationary Bike',
          'Recumbent Bike',
          'Rowing Machine',
          'Stair Climber',
          'Air Bike',
          'Ski Erg',
          'Arc Trainer',
          "Jacob's Ladder",
        });
        expect(
          (await exerciseNamed(db, 'Bench Press')).measure,
          ExerciseMeasure.reps,
        );
      },
    );

    test('a custom exercise keeps the measure it was created with', () async {
      final id = await db.createExercise(
        name: 'Wall Sit',
        muscles: MuscleMap.single('Legs'),
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
        muscles: MuscleMap.single('Shoulders'),
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
      await tester.pumpWidget(
        routedAppUnder(container, const ExerciseFormScreen()),
      );
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

    testWidgets('a YouTube link is stored in its short canonical form', (
      tester,
    ) async {
      final saved = await saveWith(
        tester,
        'https://www.youtube.com/watch?v=aBcD1234_-x&t=90s&list=PLx',
      );

      expect(
        saved.videoUrl,
        'https://youtu.be/aBcD1234_-x',
        reason: 'the timestamp, playlist and www. identify nothing',
      );

      await stop(tester);
    });

    testWidgets('a link to somewhere else is kept exactly as typed', (
      tester,
    ) async {
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
      muscles: MuscleMap.single('Core'),
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
        routedAppUnder(container, ExerciseFormScreen(exerciseId: id)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the form opens on what was stored, not on a blank', (
      tester,
    ) async {
      final id = (await tester.runAsync(mine))!;
      await openEditor(tester, id);

      expect(find.text('Edit exercise'), findsOneWidget);
      expect(find.text('Copenhagen Plank'), findsOneWidget);
      expect(find.text('https://youtu.be/aBcD1234_-x'), findsOneWidget);

      await stop(tester);
    });

    testWidgets(
      'saving rewrites the exercise in place rather than adding one',
      (tester) async {
        final id = (await tester.runAsync(mine))!;
        final before = (await tester.runAsync(
          () => db.watchExercises().first,
        ))!.length;
        await openEditor(tester, id);

        await tester.enterText(
          find.byType(TextField).first,
          'Copenhagen Plank (long lever)',
        );
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
      },
    );

    testWidgets('the name field stops at the length the schema will take', (
      tester,
    ) async {
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

    test(
      'a starter exercise is not renameable through the same door',
      () async {
        final all = await db.watchExercises().first;
        final starter = all.firstWhere((e) => !e.isCustom);

        await db.updateCustomExercise(
          starter.id,
          name: 'Not Bench Press',
          muscles: MuscleMap.single('Chest'),
          equipment: 'Barbell',
          videoUrl: null,
          measure: ExerciseMeasure.reps,
          weightType: WeightType.bar,
        );

        final after = await db.exerciseById(starter.id);
        expect(
          after.name,
          starter.name,
          reason:
              'a starter name is shared vocabulary a routine code relies on',
        );
      },
    );
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
      expect((await db.exerciseById(press.id)).notes, 'Seat 4, back pad on 2');

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

    test(
      'a note is kept, trimmed, on a starter and on a custom alike',
      () async {
        final starter = await exerciseNamed(db, 'Bench Press');
        final custom = await db.createExercise(
          name: 'Zercher Squat',
          muscles: MuscleMap.single('Legs'),
          equipment: 'Barbell',
        );

        await db.setExerciseNotes(starter.id, '  Rack pin 7  ');
        await db.setExerciseNotes(custom, 'Elbows hurt — use the pad');

        expect((await db.exerciseById(starter.id)).notes, 'Rack pin 7');
        expect(
          (await db.exerciseById(custom)).notes,
          'Elbows hurt — use the pad',
        );
      },
    );

    test('a note survives a rename', () async {
      final press = await exerciseNamed(db, 'Leg Press');
      await db.setExerciseNotes(press.id, 'Seat 4');

      await (db.update(
        db.exercises,
      )..where((e) => e.id.equals(press.id))).write(
        const ExercisesCompanion(name: Value('Leg Press (the good one)')),
      );

      expect((await db.exerciseById(press.id)).notes, 'Seat 4');
    });

    testWidgets('the detail screen writes a note and reads it back', (
      tester,
    ) async {
      final press = (await tester.runAsync(
        () => exerciseNamed(db, 'Leg Press'),
      ))!;
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        routedAppUnder(container, ExerciseDetailScreen(exerciseId: press.id)),
      );
      await tester.pumpAndSettle();

      // Empty reads as deliberate, not broken.
      expect(find.text('Nothing noted yet'), findsOneWidget);

      await tester.tap(find.text('Nothing noted yet'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Seat 4, pin 7');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = (await tester.runAsync(() => db.exerciseById(press.id)))!;
      expect(saved.notes, 'Seat 4, pin 7');
      // And the screen is showing it, not the empty state.
      await tester.pumpAndSettle();
      expect(find.text('Seat 4, pin 7'), findsOneWidget);
      expect(find.text('Nothing noted yet'), findsNothing);

      await stop(tester);
    });

    testWidgets('the note box keeps its width as the note grows', (
      tester,
    ) async {
      // A dialog sizes itself to what is in it, so a field left to its own
      // devices stepped wider mid-word.
      final press = (await tester.runAsync(
        () => exerciseNamed(db, 'Leg Press'),
      ))!;
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        routedAppUnder(container, ExerciseDetailScreen(exerciseId: press.id)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nothing noted yet'));
      await tester.pumpAndSettle();

      final field = find.byType(TextField).first;
      final empty = tester.getSize(field).width;

      await tester.enterText(field, 'a');
      await tester.pumpAndSettle();
      expect(tester.getSize(field).width, empty);

      await tester.enterText(
        field,
        'Seat 4, pin 7, back pad on 2, and the left handle is bent',
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(field).width, empty);

      await stop(tester);
    });
  });

  group('finding a movement by what it is, not what it is called', () {
    // "A barbell movement for legs" should not require knowing it is called a
    // back squat. See features/index.html#sec01.

    Future<List<Exercise>> filtered(ExerciseFilter f) async =>
        f.apply(await db.watchExercises().first);

    test('an untouched filter excludes nothing', () async {
      final all = await db.watchExercises().first;
      expect(const ExerciseFilter().apply(all).length, all.length);
    });

    test('equipment and muscle group narrow together', () async {
      final legs = await filtered(
        const ExerciseFilter(equipment: {'Barbell'}, muscles: {'Legs'}),
      );

      expect(legs, isNotEmpty);
      expect(legs.every((e) => e.equipment == 'Barbell'), isTrue);
      expect(legs.every((e) => e.muscles.touches('Legs')), isTrue);
      expect(legs.map((e) => e.name), contains('Back Squat'));
    });

    test(
      'several muscle groups are alternatives, not a narrower search',
      () async {
        final arms = await filtered(const ExerciseFilter(muscles: {'Arms'}));
        final core = await filtered(const ExerciseFilter(muscles: {'Core'}));
        final both = await filtered(
          const ExerciseFilter(muscles: {'Arms', 'Core'}),
        );

        // A union, not a sum: a movement that works both is in all three
        // lists and is still one row in the answer.
        expect(
          both.map((e) => e.id).toSet(),
          {...arms.map((e) => e.id), ...core.map((e) => e.id)},
        );
        expect(
          both.every((e) => e.muscles.touches('Arms') || e.muscles.touches('Core')),
          isTrue,
        );
      },
    );

    test('the same holds for equipment', () async {
      final bar = await filtered(const ExerciseFilter(equipment: {'Barbell'}));
      final db2 = await filtered(const ExerciseFilter(equipment: {'Dumbbell'}));
      final both = await filtered(
        const ExerciseFilter(equipment: {'Barbell', 'Dumbbell'}),
      );

      expect(both.length, bar.length + db2.length);
    });

    test('the chips compose with the search text', () async {
      final pressed = await filtered(
        const ExerciseFilter(query: 'press', equipment: {'Dumbbell'}),
      );

      expect(pressed, isNotEmpty);
      expect(
        pressed.every(
          (e) =>
              e.equipment == 'Dumbbell' &&
              e.name.toLowerCase().contains('press'),
        ),
        isTrue,
      );
      // And the text alone finds more than the pair does.
      final anyPress = await filtered(const ExerciseFilter(query: 'press'));
      expect(anyPress.length, greaterThan(pressed.length));
    });

    test('letting the chips go keeps what was typed', () {
      const f = ExerciseFilter(
        query: 'squat',
        equipment: {'Barbell'},
        muscles: {'Legs'},
      );
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

    /// Ticks [label] in the sheet the [dimension] button opens, and comes out.
    Future<void> narrowBy(
      WidgetTester tester,
      String dimension,
      String label,
    ) async {
      await tester.tap(find.byKey(filterButtonKey(dimension)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(filterChipKey(dimension, label)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(kFilterSheetDoneKey));
      await tester.pumpAndSettle();
    }

    testWidgets('the library filters to what the chips say', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(routedAppUnder(container, const LibraryScreen()));
      await tester.pumpAndSettle();

      // Unfiltered, the whole library is grouped by muscle and Arms is the
      // first group on screen.
      expect(find.textContaining('ARMS ·'), findsOneWidget);

      // A barbell movement for legs, and no name needed to get here: each
      // dimension button opens its own vocabulary to tick.
      await narrowBy(tester, 'equipment', 'Barbell');
      await narrowBy(tester, 'muscle', 'Legs');

      expect(find.text('Back Squat'), findsOneWidget);
      expect(find.textContaining('ARMS ·'), findsNothing);
      expect(find.text('Leg Press'), findsNothing, reason: 'a machine');

      // And letting the buttons go brings the rest back.
      await tester.tap(find.byKey(kFilterClearKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('ARMS ·'), findsOneWidget);

      await stop(tester);
    });
  });

  group('the creation form asks in the order that makes sense', () {
    Future<void> pumpForm(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        routedAppUnder(container, const ExerciseFormScreen()),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('measured in comes before loaded as', (tester) async {
      // Whether a movement is counted or held is the more fundamental fact,
      // and it decides whether the loading question is interesting at all.
      await pumpForm(tester);

      final measured = tester.getTopLeft(find.text('MEASURED IN')).dy;
      final loaded = tester.getTopLeft(find.textContaining('LOADED AS')).dy;

      expect(measured, lessThan(loaded));
    });

    testWidgets('loading stays reachable for a held movement', (tester) async {
      // A weighted plank, a loaded carry and a weighted dead hang are all real,
      // so the control is demoted rather than hidden.
      await pumpForm(tester);

      await tester.tap(find.text('Time held'));
      await tester.pumpAndSettle();

      final l10n = l10nFor();
      // The label is the demoted variant — the loading is now the exception.
      expect(
        find.text(l10n.exerciseFormLoadedAsOptional.toUpperCase()),
        findsOneWidget,
      );
      // "Bar" belongs to this control alone — Machine and Dumbbell are also
      // equipment kinds further up the form.
      expect(find.text('Bar'), findsOneWidget);
      // And it says why it is still being asked. Matched through the strings
      // file rather than a copy of the sentence, so rewording the caption is
      // not a test failure.
      expect(find.text(l10n.exerciseFormHoldLoadNote), findsOneWidget);
    });

    testWidgets('a held movement can be saved with a load on it', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.enterText(find.byType(TextField).first, 'Weighted Plank');
      await tester.tap(find.text('Time held'));
      await tester.pumpAndSettle();
      // The Loaded as row is below Equipment, which offers the same word.
      await tester.tap(find.text('Dumbbell').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save exercise'));
      await tester.pumpAndSettle();

      final made = (await tester.runAsync(
        () => db.watchExercises().first,
      ))!.firstWhere((e) => e.name == 'Weighted Plank');
      expect(made.measure, ExerciseMeasure.time);
      expect(made.weightType, WeightType.dumbbell);

      await stop(tester);
    });

    testWidgets('tapping the chosen loading again clears it', (tester) async {
      // A movement that carries nothing. Deselecting is how you say so.
      await pumpForm(tester);

      // The library ships an air squat of its own, so the row this makes is
      // told apart from that one by isCustom below.
      await tester.enterText(find.byType(TextField).first, 'Air Squat');
      // Barbell is the form's opening equipment, so Bar starts selected.
      await tester.tap(find.text('Bar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save exercise'));
      await tester.pumpAndSettle();

      final made = (await tester.runAsync(
        () => db.watchExercises().first,
      ))!.firstWhere((e) => e.name == 'Air Squat' && e.isCustom);
      expect(made.weightType, WeightType.none);

      await stop(tester);
    });

    testWidgets('choosing held takes the load off', (tester) async {
      // Most holds carry nothing, and the load on screen at that moment is
      // whatever the equipment chip guessed before the question was asked. A
      // plank left reading "Bar" is a weight column wanting a number nobody
      // has.
      await pumpForm(tester);

      await tester.enterText(find.byType(TextField).first, 'Wall Sit');
      await tester.tap(find.text('Time held'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save exercise'));
      await tester.pumpAndSettle();

      final made = (await tester.runAsync(
        () => db.watchExercises().first,
      ))!.firstWhere((e) => e.name == 'Wall Sit' && e.isCustom);
      expect(made.measure, ExerciseMeasure.time);
      expect(made.weightType, WeightType.none);

      await stop(tester);
    });

    testWidgets('and going back to counted puts the equipment\'s load back', (
      tester,
    ) async {
      // The same mistake pointing the other way: a counted barbell movement
      // with nothing loaded on it.
      await pumpForm(tester);

      await tester.enterText(find.byType(TextField).first, 'Front Squat');
      await tester.tap(find.text('Time held'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reps'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save exercise'));
      await tester.pumpAndSettle();

      final made = (await tester.runAsync(
        () => db.watchExercises().first,
      ))!.firstWhere((e) => e.name == 'Front Squat' && e.isCustom);
      expect(made.weightType, WeightType.bar);

      await stop(tester);
    });

    testWidgets('no loading is offered as a chip of its own', (tester) async {
      await pumpForm(tester);

      // Three loadings and a way to want none of them, not four loadings.
      expect(find.text('None'), findsNothing);

      await stop(tester);
    });

    testWidgets('picking bodyweight equipment leaves it unloaded', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.enterText(find.byType(TextField).first, 'Pistol Squat');
      await tester.tap(find.text('Bodyweight'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save exercise'));
      await tester.pumpAndSettle();

      final made = (await tester.runAsync(
        () => db.watchExercises().first,
      ))!.firstWhere((e) => e.name == 'Pistol Squat');
      expect(made.weightType, WeightType.none);

      await stop(tester);
    });
  });

  group('loading is deselectable where it is yours to choose', () {
    Future<void> openDetail(WidgetTester tester, int id) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        routedAppUnder(container, ExerciseDetailScreen(exerciseId: id)),
      );
      await tester.pumpAndSettle();
    }

    /// A barbell movement of your own — its loading is yours to change, unlike a
    /// seeded one, whose equipment settles it.
    Future<Exercise> myBarbellLift(WidgetTester tester) async {
      final id = (await tester.runAsync(
        () => db.createExercise(
          name: 'Zercher Squat',
          muscles: MuscleMap.single('Legs'),
          equipment: 'Barbell',
          weightType: WeightType.bar,
        ),
      ))!;
      return (await tester.runAsync(() => db.exerciseById(id)))!;
    }

    testWidgets(
      'tapping the selected loading clears it, and the bar row with it',
      (tester) async {
        final press = await myBarbellLift(tester);
        await openDetail(tester, press.id);

        expect(find.text('Bar weight'), findsOneWidget);

        await tester.tap(find.text('Bar'));
        await tester.pumpAndSettle();

        expect(
          (await tester.runAsync(() => db.exerciseById(press.id)))!.weightType,
          WeightType.none,
        );
        // Nothing loaded on a bar means nothing to say about the bar.
        await tester.pumpAndSettle();
        expect(find.text('Bar weight'), findsNothing);

        await stop(tester);
      },
    );

    testWidgets('and tapping another one picks it up again', (tester) async {
      final press = await myBarbellLift(tester);
      await openDetail(tester, press.id);

      await tester.tap(find.text('Bar'));
      await tester.runAsync(() => db.exerciseById(press.id));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dumbbell'));
      final after = (await tester.runAsync(() => db.exerciseById(press.id)))!;
      await tester.pumpAndSettle();

      expect(after.weightType, WeightType.dumbbell);

      await stop(tester);
    });

    testWidgets('an unloaded movement shows no bar and no None chip', (
      tester,
    ) async {
      final pull = (await tester.runAsync(() => exerciseNamed(db, 'Pull-Up')))!;
      await openDetail(tester, pull.id);

      expect(pull.weightType, WeightType.none);
      expect(find.text('None'), findsNothing);
      expect(find.text('Bar weight'), findsNothing);
      // The three loadings are still there to be picked for a weighted pull-up.
      expect(find.text('Bar'), findsOneWidget);
      expect(find.text('Dumbbell'), findsOneWidget);

      await stop(tester);
    });
  });

  group('the load type is fixed only where the name states it', () {
    // A barbell curl is loaded on a bar and a dumbbell curl on a dumbbell,
    // because that is what they are called. Everything else is the gym's
    // business: a skull crusher takes a bar, a pair of dumbbells or a machine,
    // and a chest-supported row is often plate-loaded, where "Bar" is the
    // useful answer.
    Future<void> openDetail(WidgetTester tester, int id) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        routedAppUnder(container, ExerciseDetailScreen(exerciseId: id)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'a movement named for its implement states the loading, not offers it',
      (tester) async {
        final press = (await tester.runAsync(
          () => exerciseNamed(db, 'Barbell Curl'),
        ))!;
        await openDetail(tester, press.id);

        expect(
          find.text('Bar'),
          findsOneWidget,
          reason: 'it still says what it is',
        );
        expect(
          find.byKey(kLoadingChoiceKey),
          findsNothing,
          reason: 'a movement called a barbell curl is loaded on a bar',
        );
        // What the seed cannot know is what that bar weighs, and that stays.
        expect(find.text('Bar weight'), findsOneWidget);

        await stop(tester);
      },
    );

    testWidgets('and the writer refuses it too, not just the screen', (
      tester,
    ) async {
      final curl = (await tester.runAsync(
        () => exerciseNamed(db, 'Dumbbell Curl'),
      ))!;
      expect(curl.weightType, WeightType.dumbbell);

      await tester.runAsync(
        () => db.setExerciseWeightType(curl.id, WeightType.none),
      );

      expect(
        (await tester.runAsync(() => db.exerciseById(curl.id)))!.weightType,
        WeightType.dumbbell,
      );
    });

    testWidgets('a bodyweight movement can still be loaded', (tester) async {
      // A weighted pull-up is a real thing, and nothing about "Bodyweight"
      // settles what you hang off yourself.
      final pull = (await tester.runAsync(() => exerciseNamed(db, 'Pull-Up')))!;
      await openDetail(tester, pull.id);

      expect(find.byKey(kLoadingChoiceKey), findsOneWidget);
      await tester.tap(find.text('Dumbbell'));
      await tester.pumpAndSettle();

      expect(
        (await tester.runAsync(() => db.exerciseById(pull.id)))!.weightType,
        WeightType.dumbbell,
      );

      await stop(tester);
    });

    testWidgets('and so can one whose equipment says nothing', (tester) async {
      // Kettlebells and get-ups are filed under Other: the equipment is not a
      // claim about the loading.
      final swing = (await tester.runAsync(
        () => exerciseNamed(db, 'Kettlebell Swing'),
      ))!;
      expect(swing.equipment, 'Other');
      await openDetail(tester, swing.id);

      expect(find.byKey(kLoadingChoiceKey), findsOneWidget);

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
      expect(kg.firstWhere((b) => b.name == 'Olympic bar').weight, 20);
    });

    test('a pounds gym gets the round pounds number, not a converted kilo', () {
      final lb = namedBars('lb');
      final olympic = lb.firstWhere((b) => b.name == 'Olympic bar');
      // 45 lb, which is 20.41 kg — not the metric bar's 20.
      expect(toDisplayWeight(olympic.weight, 'lb'), closeTo(45, 0.01));
      expect(olympic.weight, isNot(20));
    });

    testWidgets('picking one by name sets the exercise to its weight', (
      tester,
    ) async {
      final curl = (await tester.runAsync(
        () => exerciseNamed(db, 'Barbell Curl'),
      ))!;
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        routedAppUnder(container, ExerciseDetailScreen(exerciseId: curl.id)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bar weight'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EZ curl bar'));
      await tester.pumpAndSettle();

      final saved = (await tester.runAsync(() => db.exerciseById(curl.id)))!;
      expect(saved.barWeight, 10);

      await stop(tester);
    });

    testWidgets('a bar the list has not got can be added on the spot', (
      tester,
    ) async {
      final curl = (await tester.runAsync(
        () => exerciseNamed(db, 'Barbell Curl'),
      ))!;
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        routedAppUnder(container, ExerciseDetailScreen(exerciseId: curl.id)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bar weight'));
      await tester.pumpAndSettle();

      // No free-number escape hatch any more: a gym with something odd names it
      // once and it joins the list, so the next exercise can pick it too.
      expect(find.text('Something else'), findsNothing);
      await tester.tap(find.text('Add a bar'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Junior bar');
      await tester.enterText(find.byType(TextField).last, '7.5');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await pumpThroughDatabase(tester);

      final saved = (await tester.runAsync(() => db.exerciseById(curl.id)))!;
      expect(
        saved.barWeight,
        7.5,
        reason: 'the new bar was picked as well as made',
      );
      final bars = (await tester.runAsync(() => db.barsFor('kg')))!;
      expect(bars.map((b) => b.name), contains('Junior bar'));

      await stop(tester);
    });
  });

  group('a movement of its own unit and its own warm-up count', () {
    late AppDatabase db;
    setUp(() => db = memoryDb());
    tearDown(() async => db.close());

    Future<void> openDetail(WidgetTester tester, int id) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        routedAppUnder(container, ExerciseDetailScreen(exerciseId: id)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the unit chips show the app\'s until one is pinned',
        (tester) async {
      final squat =
          (await tester.runAsync(() => exerciseNamed(db, 'Back Squat')))!;
      await openDetail(tester, squat.id);

      expect(find.byKey(kUnitChoiceKey), findsOneWidget);
      expect(find.text('Kilograms'), findsOneWidget);
      expect(find.text('Pounds'), findsOneWidget);

      // Tapping the other unit asks first, in the same words the settings
      // screen asks in.
      await tester.tap(find.text('Pounds'));
      await tester.pumpAndSettle();
      expect(find.text('Switch to pounds?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final untouched =
          (await tester.runAsync(() => db.exerciseById(squat.id)))!;
      expect(untouched.unitOverride, isNull, reason: 'cancel pins nothing');

      await tester.tap(find.text('Pounds'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use pounds'));
      await tester.pumpAndSettle();
      await pumpThroughDatabase(tester);

      final pinned = (await tester.runAsync(() => db.exerciseById(squat.id)))!;
      expect(pinned.unitOverride, 'lb');

      await stop(tester);
    });

    testWidgets('tapping the unit the app is on hands it back', (tester) async {
      final squat =
          (await tester.runAsync(() => exerciseNamed(db, 'Back Squat')))!;
      await tester.runAsync(() => db.setExerciseUnit(squat.id, 'lb'));
      await openDetail(tester, squat.id);

      await tester.tap(find.text('Kilograms'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use kilograms'));
      await tester.pumpAndSettle();
      await pumpThroughDatabase(tester);

      final back = (await tester.runAsync(() => db.exerciseById(squat.id)))!;
      expect(back.unitOverride, isNull,
          reason: 'the app\'s own unit is the follow-the-app answer');

      await stop(tester);
    });

    testWidgets('the warm-up stepper opens on the app-wide count and pins on'
        ' a move', (tester) async {
      final squat =
          (await tester.runAsync(() => exerciseNamed(db, 'Back Squat')))!;
      await openDetail(tester, squat.id);

      expect(find.byKey(kWarmupCountKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(kWarmupCountKey),
          matching: find.text('$kDefaultWarmupSets'),
        ),
        findsOneWidget,
      );
      expect(find.text('Use default'), findsNothing,
          reason: 'nothing to hand back yet');

      await tester.tap(find.descendant(
        of: find.byKey(kWarmupCountKey),
        matching: find.byIcon(Icons.add),
      ));
      await tester.pumpAndSettle();
      await pumpThroughDatabase(tester);

      final own = (await tester.runAsync(() => db.exerciseById(squat.id)))!;
      expect(own.warmupSets, kDefaultWarmupSets + 1);
      expect(find.text('Use default'), findsOneWidget);

      await tester.tap(find.text('Use default'));
      await tester.pumpAndSettle();
      await pumpThroughDatabase(tester);

      final cleared = (await tester.runAsync(() => db.exerciseById(squat.id)))!;
      expect(cleared.warmupSets, isNull);

      await stop(tester);
    });

    testWidgets('and the section is absent while the app suggests no ramps',
        (tester) async {
      final squat =
          (await tester.runAsync(() => exerciseNamed(db, 'Back Squat')))!;
      await tester.runAsync(() => db.setDefaultWarmupSets(0));
      await openDetail(tester, squat.id);

      expect(find.byKey(kWarmupCountKey), findsNothing);
      await stop(tester);
    });
  });
}
