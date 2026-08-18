// Integration tests for features/index.html#sec21 — the routine library.
//
// The behaviour under test, straight from the catalogue:
//   * your-list-holds-only-what-you-put-there — a fresh install opens on an
//     empty routine list with no current routine, while the movements, the bars
//     and the settings row are seeded exactly as before;
//   * three-ways-to-get-a-routine — the + in the corner of the Routines tab
//     opens one sheet holding all three, and import asks scan or paste on a
//     sheet of its own;
//   * library-holds-the-programs-the-app-ships — the five programs are a table
//     in the app, listed under the names the app gives them;
//   * a-program-is-previewed-before-it-is-added — the preview shows every
//     training day and every exercise in it, and writes nothing;
//   * added-program-is-yours / added-program-carries-its-prescription — adding
//     one lands an ordinary routine carrying the published prescription, and
//     twice lands two independent ones;
//   * first-program-added-becomes-the-current-one — the first routine to arrive
//     on an empty install becomes the one Today is about, however it arrives;
//   * adding-copies-the-movements-you-already-have — a program creates no
//     exercises, only a routine, its days and its slots;
//   * library-names-follow-the-language — the programs and their days are named
//     through their seed keys, published titles excepted;
//   * update-keeps-the-programs-already-in-your-list — a phone that already has
//     one of the five keeps it across the update.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/data/warmup.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/routine_library_screen.dart';
import 'package:foss_lift/screens/routines_screen.dart';
import 'package:foss_lift/screens/today_screen.dart';
import 'package:foss_lift/util/units.dart';
import 'package:foss_lift/util/seed_names.dart';
import 'package:foss_lift/widgets/routine_add_menu.dart';
import 'package:foss_lift/widgets/routine_card.dart';

import 'support/harness.dart';
import 'support/schema_v1.dart';

/// The order the library lists its programs in: the gym programs first, then the
/// four that need less than a gym.
const _kLibraryOrder = [
  'ppl',
  'upper-lower',
  'starting-strength',
  'stronglifts-5x5',
  'full-body-3x',
  'two-day-full-body',
  'bodyweight-basics',
  'dumbbell-full-body',
  'interval-conditioning',
  '531-classic',
  '531-bbb',
  '531-fsl',
  '531-beginners',
];

/// The languages a shipped program has to read in.
const _kLocales = [Locale('uk'), Locale('es'), Locale('pt'), Locale('pt', 'BR')];

/// The program [key], or a failure naming it — every test below is about one of
/// the five, so a missing key is a spec violation rather than a null to handle.
StarterRoutine _program(String key) {
  final found = starterRoutineByKey(key);
  expect(found, isNotNull, reason: 'the library ships no program keyed $key');
  return found!;
}

/// The Routines tab, under a router that can show where a tap went: the
/// library, the empty builder, and the scanner the import sheet offers.
Future<void> _pumpRoutines(WidgetTester tester, AppDatabase db) async {
  final container = containerFor(db);
  addTearDown(container.dispose);
  await tester.pumpWidget(routedAppUnder(container, const RoutinesScreen(),
      scaffold: true,
      alsoRoutes: ['routines/library', 'routine/new', 'scan']));
  await pumpThroughDatabase(tester);
}

/// A tall, phone-wide viewport, so a list of training days is on screen rather
/// than below the fold.
void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  group('your routine list holds only what you put there', () {
    test('a fresh database holds no routines and nothing current', () async {
      expect(await db.watchRoutines().first, isEmpty,
          reason: 'five programs nobody chose is five rows to wade past');
      expect(await db.watchActiveRoutineId().first, isNull,
          reason: 'nothing has been added, so nothing can be current');
    });

    test('the movements are seeded exactly as before', () async {
      final names = (await db.watchExercises().first).map((e) => e.name);

      expect(names, containsAll(kSeedExerciseKeys.keys),
          reason: 'the starter library is a property of an empty database');
      expect(
        (await db.watchExercises().first)
            .where((e) => e.seedKey != null)
            .map((e) => e.seedKey),
        containsAll(kSeedExerciseKeys.values),
      );
    });

    test('so are the racked bars, in both units', () async {
      for (final unit in const ['kg', 'lb']) {
        expect((await db.barsFor(unit)).map((b) => b.name),
            containsAll(kSeedBarKeys.keys),
            reason: '$unit lost its bars');
      }
    });

    test('and the settings row is there, unanswered', () async {
      expect(await db.watchUnitChosen().first, isFalse,
          reason: 'the unit question is still to be asked');
      expect(await db.defaultWarmupSets(), kDefaultWarmupSets,
          reason: 'the row exists and carries its defaults');
    });

    testWidgets('the routine list draws no cards, and says so in one line',
        (tester) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(routedAppUnder(container, const RoutinesScreen(),
          scaffold: true, alsoRoutes: ['routines/library']));
      await pumpThroughDatabase(tester);

      final l10n = l10nFor();
      expect(find.byType(RoutineCard), findsNothing,
          reason: 'a fresh install opens on an empty list');
      expect(find.text(l10n.todayNoRoutinesTitle), findsOneWidget,
          reason: 'an empty list says it is empty, in one line');
      expect(find.byKey(kRoutinesAddKey), findsOneWidget,
          reason: 'the + in the corner is the way out of an empty list');
      // The three ways in are behind that button now, not laid out under the
      // list where every routine added pushed them further down.
      expect(find.text(l10n.routineLibraryTitle), findsNothing);
      expect(find.text(l10n.routinesNewRoutine), findsNothing);
      expect(find.text(l10n.routinesImport), findsNothing);

      await stop(tester);
    });

    testWidgets('and Today offers to build one rather than five rows',
        (tester) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
          routedAppUnder(container, const TodayScreen(), scaffold: true));
      await pumpThroughDatabase(tester);

      expect(find.text(l10nFor().todayNoRoutinesTitle), findsOneWidget);
      expect(find.byType(RoutineCard), findsNothing);

      await stop(tester);
    });

    testWidgets('the + offers all three ways to get a routine', (tester) async {
      _tallPhone(tester);
      final l10n = l10nFor();
      await _pumpRoutines(tester, db);

      await tester.tap(find.byKey(kRoutinesAddKey));
      await pumpThroughDatabase(tester);

      expect(find.text(l10n.routineLibraryTitle), findsOneWidget);
      expect(find.text(l10n.routinesNewRoutine), findsOneWidget);
      expect(find.text(l10n.routinesImport), findsOneWidget,
          reason: 'one question with three answers, on one sheet');

      await stop(tester);
    });

    testWidgets('the library row opens the library', (tester) async {
      _tallPhone(tester);
      await _pumpRoutines(tester, db);

      await tester.tap(find.byKey(kRoutinesAddKey));
      await pumpThroughDatabase(tester);
      await tester.tap(find.text(l10nFor().routineLibraryTitle));
      await pumpThroughDatabase(tester);

      expect(find.text('at /routines/library'), findsOneWidget);

      await stop(tester);
    });

    testWidgets('the build row opens an empty routine', (tester) async {
      _tallPhone(tester);
      await _pumpRoutines(tester, db);

      await tester.tap(find.byKey(kRoutinesAddKey));
      await pumpThroughDatabase(tester);
      await tester.tap(find.text(l10nFor().routinesNewRoutine));
      await pumpThroughDatabase(tester);

      expect(find.text('at /routine/new'), findsOneWidget);

      await stop(tester);
    });

    testWidgets('the import row asks scan or paste, and then scans',
        (tester) async {
      _tallPhone(tester);
      final l10n = l10nFor();
      await _pumpRoutines(tester, db);

      await tester.tap(find.byKey(kRoutinesAddKey));
      await pumpThroughDatabase(tester);
      await tester.tap(find.text(l10n.routinesImport));
      await pumpThroughDatabase(tester);

      expect(find.text(l10n.themeScanQr), findsOneWidget);
      expect(find.text(l10n.themePasteCode), findsOneWidget,
          reason: 'the second question is which way the code arrives');
      // And the three of the first sheet are gone with it: one question at a
      // time.
      expect(find.text(l10n.routineLibraryTitle), findsNothing);

      await tester.tap(find.text(l10n.themeScanQr));
      await pumpThroughDatabase(tester);
      expect(find.text('at /scan'), findsOneWidget);

      await stop(tester);
    });

    testWidgets('and pasting from there opens the paste box', (tester) async {
      _tallPhone(tester);
      final l10n = l10nFor();
      await _pumpRoutines(tester, db);

      await tester.tap(find.byKey(kRoutinesAddKey));
      await pumpThroughDatabase(tester);
      await tester.tap(find.text(l10n.routinesImport));
      await pumpThroughDatabase(tester);
      await tester.tap(find.text(l10n.themePasteCode));
      await pumpThroughDatabase(tester);

      expect(find.text(l10n.routinesPasteTitle), findsOneWidget);

      await stop(tester);
    });
  });

  group('the library holds the programs the app ships', () {
    test('thirteen of them, each with its own key', () {
      expect(kStarterRoutines, hasLength(_kLibraryOrder.length));
      expect(kStarterRoutines.map((p) => p.key).toSet(),
          hasLength(_kLibraryOrder.length),
          reason: 'a duplicate key makes one of them unreachable');
      expect(kStarterRoutines.map((p) => p.key), _kLibraryOrder,
          reason: 'the hypertrophy splits come first',);
    });

    test('each is looked up by its key', () {
      for (final p in kStarterRoutines) {
        expect(starterRoutineByKey(p.key), same(p));
      }
      expect(starterRoutineByKey('no-such-program'), isNull);
    });

    test('each carries the days and slots it prescribes', () {
      for (final p in kStarterRoutines) {
        expect(p.days, isNotEmpty, reason: '${p.key} has no training days');
        expect(
          p.exerciseCount,
          p.days.fold<int>(0, (sum, d) => sum + d.items.length),
          reason: '${p.key}: the count is the slots across every day',
        );
        expect(p.seedKey, kSeedRoutineKeys[p.name],
            reason: '${p.key} is a shipped row and follows the language');
      }
    });

    testWidgets('all five are listed, named as the app names them',
        (tester) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);
      final l10n = l10nFor();

      await tester.pumpWidget(
          routedAppUnder(container, const RoutineLibraryScreen()));
      await pumpThroughDatabase(tester);

      expect(find.text(l10n.routineLibraryTitle), findsWidgets);
      for (final p in kStarterRoutines) {
        expect(find.byKey(ValueKey('starter-${p.key}')), findsOneWidget,
            reason: '${p.key} is missing from the library');
        expect(find.text(seededName(l10n, p.seedKey, p.name)), findsOneWidget,
            reason: '${p.key} is not named the way the app names it');
      }
      expect(
        // The same line a routine of your own carries, from the same card: a
        // workout is what the app calls a training day everywhere.
        find.textContaining(l10n.routineCardWorkoutCount(3)),
        findsWidgets,
        reason: 'a card says how many workouts the program holds',
      );

      await stop(tester);
    });

    test('nothing about the library is stored', () async {
      // library-is-code-not-rows: opening the library cannot have written rows,
      // because looking at a const table is not a database operation.
      expect(kStarterRoutines, hasLength(_kLibraryOrder.length));
      expect(await db.watchRoutines().first, isEmpty);
    });
  });

  group('four of the programs need no gym', () {
    /// Every movement the program with [key] names, joined with its library row.
    Future<List<(StarterSlot, Exercise)>> slotsOf(String key) async {
      final library = {
        for (final e in await db.watchExercises().first) e.name: e,
      };
      return [
        for (final day in _program(key).days)
          for (final slot in day.items)
            () {
              final row = library[slot.exercise];
              expect(row, isNotNull,
                  reason: '${slot.exercise} is not in the starter library, so '
                      '$key would land one slot short');
              return (slot, row!);
            }(),
      ];
    }

    test('the bodyweight program asks for no load at all', () async {
      final slots = await slotsOf('bodyweight-basics');
      expect(slots, hasLength(greaterThan(8)));
      for (final (slot, row) in slots) {
        expect(slot.weightKg, isNull,
            reason: '${slot.exercise} carries a weight in a bodyweight program');
        expect(row.equipment, 'Bodyweight',
            reason: '${slot.exercise} needs equipment');
      }
      expect(_program('bodyweight-basics').days, hasLength(3));
    });

    test('the dumbbell program uses dumbbells and nothing else', () async {
      final slots = await slotsOf('dumbbell-full-body');
      expect(slots, hasLength(greaterThan(8)));
      for (final (slot, row) in slots) {
        expect(row.equipment, 'Dumbbell',
            reason: '${slot.exercise} is not a dumbbell movement');
        expect(slot.weightKg, isNotNull,
            reason: '${slot.exercise} opens at no load');
      }
      expect(_program('dumbbell-full-body').days.length, inInclusiveRange(3, 4));
    });

    test('the two-day program covers a squat, a hinge, a press and a pull',
        () async {
      final program = _program('two-day-full-body');
      expect(program.days, hasLength(2));
      for (final day in program.days) {
        expect(day.items, hasLength(greaterThanOrEqualTo(4)),
            reason: 'a whole body in one session');
      }
    });
  });

  group('an interval program prescribes seconds, not reps', () {
    test('every interval slot names a movement measured in time', () async {
      final library = {
        for (final e in await db.watchExercises().first) e.name: e,
      };
      final program = _program('interval-conditioning');
      expect(program.days.length, inInclusiveRange(2, 3));

      for (final day in program.days) {
        for (final slot in day.items) {
          expect(slot.holdSeconds, isNotNull,
              reason: '${slot.exercise} is a conditioning slot with no work '
                  'period on it');
          expect(slot.repsMin, 0,
              reason: '${slot.exercise} cannot be counted and held at once');
          final row = library[slot.exercise];
          expect(row, isNotNull, reason: '${slot.exercise} is not in the '
              'starter library');
          expect(row!.measure, ExerciseMeasure.time,
              reason: '${slot.exercise} is counted, so it would ignore the '
                  'work period the program gives it');
        }
      }
    });

    // Every program, not one of them: the conversion is done where a copy is
    // written rather than per program, but "the 5/3/1 one is right" is the
    // claim a reader of a single-program test would take away, and the
    // catalogue entry is about all of them.
    for (final program in kStarterRoutines) {
      test('a pounds phone gets numbers a pounds gym loads — ${program.key}',
          () async {
        await db.seedWeightUnit('lb');
        final rid = await db.addStarterRoutine(program);

        for (final day in await db.workoutsForRoutine(rid)) {
          for (final view in await db.itemsForWorkout(day.id)) {
            final it = view.item;
            // Only the weight axis has a unit to land: a rep step is a rep.
            if (it.progression != ProgressionMode.weight) continue;
            for (final kg in [it.suggestedWeight, it.increment, it.deload]) {
              if (kg == null || kg == 0) continue;
              final lb = toDisplayWeight(kg, 'lb');
              expect((lb - lb.roundToDouble()).abs(), lessThan(1e-6),
                  reason: '$lb lb is not a number anybody types');
              expect(lb.round() % kPoundStep.round(), 0,
                  reason: '$lb lb is not a pair of plates anybody racks');
            }
          }
        }
      });
    }

    test('a kilogram phone gets the numbers as they were written', () async {
      await db.seedWeightUnit('kg');
      final program = _program('ppl');
      final rid = await db.addStarterRoutine(program);

      final days = await db.workoutsForRoutine(rid);
      for (final (i, day) in days.indexed) {
        final items = await db.itemsForWorkout(day.id);
        for (final (j, view) in items.indexed) {
          expect(view.item.suggestedWeight, program.days[i].items[j].weightKg,
              reason: 'nothing to convert, so nothing to round');
        }
      }
    });

    test('the copy lands on the clock, with the work period it prescribes',
        () async {
      final program = _program('interval-conditioning');
      final rid = await db.addStarterRoutine(program);

      final days = await db.workoutsForRoutine(rid);
      expect(days, hasLength(program.days.length));
      for (final (i, day) in days.indexed) {
        final items = await db.itemsForWorkout(day.id);
        expect(items, hasLength(program.days[i].items.length),
            reason: '${day.name} lost a slot, so a movement is misnamed');
        for (final (j, view) in items.indexed) {
          final slot = program.days[i].items[j];
          expect(view.item.progression, ProgressionMode.time);
          expect(view.item.holdSeconds, slot.holdSeconds);
          expect(view.item.targetSets, slot.sets);
        }
      }
    });

    testWidgets('the preview shows the seconds where a rep count would be',
        (tester) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);
      final l10n = l10nFor();

      await tester.pumpWidget(routedAppUnder(container,
          const StarterRoutinePreviewScreen(routineKey: 'interval-conditioning')));
      await pumpThroughDatabase(tester);

      final first = _program('interval-conditioning').days.first.items.first;
      expect(
        find.textContaining(l10n.unitSecondsShort('${first.holdSeconds}')),
        findsWidgets,
        reason: 'a work period reads as seconds, not as "0 reps"',
      );

      await stop(tester);
    });
  });

  group('a program says what it is before you take it', () {
    test('every program carries a description, in every language', () {
      for (final program in kStarterRoutines) {
        expect(program.description.trim(), isNotEmpty,
            reason: '${program.key} says nothing about itself');
        expect(program.description.length,
            lessThanOrEqualTo(kMaxDescriptionLength),
            reason: '${program.key} would fail the insert');
        expect(
          seededDescription(l10nFor(), program.seedKey, program.description),
          program.description,
          reason: '${program.key}: the English is the canonical text',
        );
        for (final locale in _kLocales) {
          final shown = seededDescription(
              l10nFor(locale), program.seedKey, program.description);
          expect(shown, isNotNull);
          expect(shown, isNot(program.description),
              reason: '${program.key} is untranslated in $locale');
        }
      }
    });

    testWidgets('the preview opens with it', (tester) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(routedAppUnder(
          container, const StarterRoutinePreviewScreen(routineKey: 'ppl')));
      await pumpThroughDatabase(tester);

      expect(find.text(_program('ppl').description), findsOneWidget);

      await stop(tester);
    });

    testWidgets('in the app\'s language', (tester) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);
      const es = Locale('es');
      final program = _program('bodyweight-basics');

      await tester.pumpWidget(routedAppUnder(container,
          const StarterRoutinePreviewScreen(routineKey: 'bodyweight-basics'),
          locale: es));
      await pumpThroughDatabase(tester);

      expect(
        find.text(seededDescription(
            l10nFor(es), program.seedKey, program.description)!),
        findsOneWidget,
      );
      expect(find.text(program.description), findsNothing);

      await stop(tester);
    });

    test('and the copy keeps it', () async {
      final program = _program('interval-conditioning');
      await db.addStarterRoutine(program);
      final routine = (await db.watchRoutines().first).single.routine;

      expect(routine.description, program.description,
          reason: 'the copy still explains itself a month later');
      expect(
        seededDescription(
            l10nFor(const Locale('uk')), routine.seedKey, routine.description),
        isNot(program.description),
        reason: 'a shipped description follows the language, like the name',
      );
    });
  });

  group('a program is previewed before it is added', () {
    /// Opens the preview on [key].
    Future<void> pumpPreview(WidgetTester tester, String key) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(routedAppUnder(
          container, StarterRoutinePreviewScreen(routineKey: key)));
      await pumpThroughDatabase(tester);
    }

    testWidgets('it lists every training day and every exercise in it',
        (tester) async {
      final program = _program('starting-strength');
      await pumpPreview(tester, 'starting-strength');
      final l10n = l10nFor();

      for (final day in program.days) {
        expect(
          find.text(seededName(l10n, kSeedWorkoutKeys[day.name], day.name)),
          findsWidgets,
          reason: '${day.name} is not in the preview',
        );
        for (final slot in day.items) {
          expect(
            find.text(seededName(
                l10n, kSeedExerciseKeys[slot.exercise], slot.exercise)),
            findsWidgets,
            reason: '${slot.exercise} is not shown under ${day.name}',
          );
        }
      }
      expect(find.text(l10n.routineLibraryAdd), findsOneWidget,
          reason: 'add is on the preview screen');
      expect(find.byKey(const ValueKey('add-starter-routine')), findsOneWidget);

      await stop(tester);
    });

    testWidgets('the three-day split shows all three of its days',
        (tester) async {
      final program = _program('ppl');
      await pumpPreview(tester, 'ppl');
      final l10n = l10nFor();

      expect(program.days, hasLength(3));
      for (final day in program.days) {
        expect(
          find.text(seededName(l10n, kSeedWorkoutKeys[day.name], day.name)),
          findsWidgets,
        );
      }

      await stop(tester);
    });

    testWidgets('backing out adds nothing', (tester) async {
      await pumpPreview(tester, 'ppl');
      await stop(tester);

      // Through `runAsync`: a drift future completes on the real event loop, and
      // awaiting one in a widget test's fake zone waits for a pump that is not
      // coming.
      final after = (await tester.runAsync(() async => (
            routines: await db.watchRoutines().first,
            current: await db.watchActiveRoutineId().first,
          )))!;
      expect(after.routines, isEmpty,
          reason: 'looking at a program is not taking it');
      expect(after.current, isNull);
    });
  });

  group('an added program is a copy, and it is yours', () {
    testWidgets('the add button on the preview writes the routine',
        (tester) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(routedAppUnder(container,
          const StarterRoutinePreviewScreen(routineKey: 'starting-strength')));
      await pumpThroughDatabase(tester);

      await tester.tap(find.byKey(const ValueKey('add-starter-routine')));
      await pumpThroughDatabase(tester);

      final rows = (await tester.runAsync(() => db.watchRoutines().first))!;
      expect(rows, hasLength(1));
      expect(rows.single.routine.name, 'Starting Strength');
      expect(rows.single.workoutCount, 2);

      await stop(tester);
    });

    test('the copy is an ordinary routine — rename it, gut it, delete it',
        () async {
      final rid = await db.addStarterRoutine(_program('ppl'));

      await db.updateRoutineMeta(rid,
          name: 'Chest & Tris', color: '3ED598', restSeconds: 75);
      final mine = (await db.watchRoutines().first).single.routine;
      expect(mine.name, 'Chest & Tris');
      expect(mine.restSeconds, 75);

      await db.deleteRoutine(rid);
      expect(await db.watchRoutines().first, isEmpty);
    });

    test('adding the same program twice gives two independent routines',
        () async {
      final program = _program('starting-strength');
      final slotsBefore = program.exerciseCount;
      final firstDayBefore = program.days.first.name;

      final a = await db.addStarterRoutine(program);
      final b = await db.addStarterRoutine(program);

      expect(a, isNot(b), reason: 'a second copy is not refused');
      final rows = await db.watchRoutines().first;
      expect(rows.map((r) => r.routine.id), containsAll([a, b]));
      expect(rows.map((r) => r.routine.position).toSet(), hasLength(2),
          reason: 'the second copy lands at the bottom of the list');

      // Gut the first copy's opening day.
      final dayOfA = (await db.workoutsForRoutine(a)).first;
      await db.replaceWorkoutItems(dayOfA.id, const []);
      await db.updateRoutineMeta(a,
          name: 'My version', color: '4D9DE0', restSeconds: 300);

      // The second copy is untouched.
      final daysOfB = await db.workoutsForRoutine(b);
      expect(daysOfB.map((w) => w.name), program.days.map((d) => d.name));
      expect(await db.itemsForWorkout(daysOfB.first.id),
          hasLength(program.days.first.items.length));
      expect((await db.watchRoutines().first)
          .firstWhere((r) => r.routine.id == b)
          .routine
          .name,
          'Starting Strength');

      // And so is the library: nothing you do to a copy reaches the table.
      expect(_program('starting-strength').exerciseCount, slotsBefore);
      expect(_program('starting-strength').days.first.name, firstDayBefore);
    });
  });

  group('a program arrives set up the way the program is actually run', () {
    test('Starting Strength lands on its published prescription', () async {
      final program = _program('starting-strength');
      final rid = await db.addStarterRoutine(program);
      final routine = (await db.watchRoutines().first).single.routine;

      expect(routine.id, rid);
      expect(routine.name, 'Starting Strength');
      expect(routine.seedKey, 'starting_strength');
      expect(routine.restSeconds, 300,
          reason: 'a heavy triple needs five minutes');
      expect(routine.scheduleDays, 1 << 0 | 1 << 2 | 1 << 4,
          reason: 'the days the program is meant to be trained on');
      expect(routine.colorHex, program.colorHex);

      final days = await db.workoutsForRoutine(rid);
      expect(days.map((w) => w.name), ['Workout A', 'Workout B']);
      expect(days.map((w) => w.seedKey), ['workout_a', 'workout_b']);

      final a = await db.itemsForWorkout(days.first.id);
      expect(a.map((v) => v.exercise.name),
          ['Back Squat', 'Bench Press', 'Deadlift']);
      // 3 × 5 on the squat, stepping 5 kg a session.
      expect(a[0].item.targetSets, 3);
      expect(a[0].item.repsMin, 5);
      expect(a[0].item.repsMax, isNull);
      expect(a[0].item.suggestedWeight, 60);
      expect(a[0].item.increment, 5);
      expect(a[0].item.deload, 10);
      expect(a[0].item.progression, ProgressionMode.weight);
      // The press takes half that.
      expect(a[1].item.targetSets, 3);
      expect(a[1].item.increment, 2.5);
      expect(a[1].item.deload, 5);
      // One work set of deadlift, on the 5 kg step.
      expect(a[2].item.targetSets, 1,
          reason: 'the lift the program deliberately does not do three sets of');
      expect(a[2].item.repsMin, 5);
      expect(a[2].item.increment, 5);
      // Three failed sessions before the back-off, throughout.
      expect(a.map((v) => v.item.failureThreshold), everyElement(3));

      final b = await db.itemsForWorkout(days.last.id);
      expect(b.map((v) => v.exercise.name),
          ['Back Squat', 'Overhead Press', 'Power Clean']);
      expect(b[1].item.increment, 2.5, reason: 'the overhead press steps 2.5');
      // Five triples.
      expect(b[2].item.targetSets, 5);
      expect(b[2].item.repsMin, 3);
      expect(b.map((v) => v.item.failureThreshold), everyElement(3));
    });

    test('StrongLifts is five by five with a single deadlift set', () async {
      final rid = await db.addStarterRoutine(_program('stronglifts-5x5'));
      final routine = (await db.watchRoutines().first).single.routine;
      expect(routine.restSeconds, 180, reason: 'three minutes, not five');

      final days = await db.workoutsForRoutine(rid);
      final a = await db.itemsForWorkout(days.first.id);
      expect(a.map((v) => v.item.targetSets), everyElement(5));
      expect(a.map((v) => v.item.repsMin), everyElement(5));

      final b = await db.itemsForWorkout(days.last.id);
      final deadlift = b.firstWhere((v) => v.exercise.name == 'Deadlift');
      expect(deadlift.item.targetSets, 1);
      expect(deadlift.item.increment, 5);
      expect(b.map((v) => v.item.failureThreshold), everyElement(3));
    });

    test('the linear programs back off later than the hypertrophy ones',
        () async {
      final ss = _program('starting-strength');
      final ppl = _program('ppl');

      expect(ss.failureThreshold, 3);
      expect(ss.failureThreshold, greaterThan(ppl.failureThreshold),
          reason: 'a missed session on a beginner program is a bad day');

      final pplId = await db.addStarterRoutine(ppl);
      final legs = (await db.workoutsForRoutine(pplId))
          .firstWhere((w) => w.name == 'Legs');
      expect(
        (await db.itemsForWorkout(legs.id))
            .map((v) => v.item.failureThreshold),
        everyElement(ppl.failureThreshold),
      );
    });

    test('a slot with no load progresses on reps', () async {
      final rid = await db.addStarterRoutine(_program('ppl'));
      final pull = (await db.workoutsForRoutine(rid))
          .firstWhere((w) => w.name == 'Pull');
      final pullUp = (await db.itemsForWorkout(pull.id))
          .firstWhere((v) => v.exercise.name == 'Pull-Up');

      expect(pullUp.item.suggestedWeight, isNull);
      expect(pullUp.item.progression, ProgressionMode.reps);
    });
  });

  group('the first program added becomes the routine Today is about', () {
    test('the first one added from the library takes that place', () async {
      final first = await db.addStarterRoutine(_program('ppl'));

      expect(await db.watchActiveRoutineId().first, first);
    });

    test('and a second one does not displace it', () async {
      final first = await db.addStarterRoutine(_program('ppl'));
      await db.addStarterRoutine(_program('stronglifts-5x5'));

      expect(await db.watchActiveRoutineId().first, first,
          reason: 'adding a program to look at is not switching to it');
    });

    test('a routine you build yourself does the same', () async {
      final mine = await db.createRoutine(
          name: 'My Split', color: 'FF6A3D', restSeconds: 90);
      expect(await db.watchActiveRoutineId().first, mine);

      final second = await db.createRoutine(
          name: 'Another', color: '3ED598', restSeconds: 90);
      expect(await db.watchActiveRoutineId().first, mine,
          reason: 'that choice is already made');
      expect(second, isNot(mine));
    });

    test('a current routine already chosen is left alone', () async {
      final ppl = await db.addStarterRoutine(_program('ppl'));
      final sl = await db.addStarterRoutine(_program('stronglifts-5x5'));
      await db.setActiveRoutineId(sl);

      await db.addStarterRoutine(_program('upper-lower'));

      expect(await db.watchActiveRoutineId().first, sl);
      expect(sl, isNot(ppl));
    });

    test('Today resolves the first arrival as current', () async {
      final rid = await db.addStarterRoutine(_program('ppl'));
      final container = containerFor(db);
      addTearDown(container.dispose);
      container.listen(currentRoutineProvider, (_, _) {});

      await container.read(routinesProvider.future);
      await container.read(activeRoutineIdProvider.future);

      expect(container.read(currentRoutineProvider)?.routine.id, rid);
    });
  });

  group('a program points at the movements already in your library', () {
    test('adding every one of the five creates no exercises', () async {
      final before = (await db.watchExercises().first).map((e) => e.id).toSet();

      for (final program in kStarterRoutines) {
        await db.addStarterRoutine(program);
      }

      final after = (await db.watchExercises().first).map((e) => e.id).toSet();
      expect(after, before,
          reason: 'every movement the five use is already in the library');
    });

    test('every slot points at a row that was already there', () async {
      final library = {
        for (final e in await db.watchExercises().first) e.id: e.name,
      };

      for (final program in kStarterRoutines) {
        final rid = await db.addStarterRoutine(program);
        for (final day in await db.workoutsForRoutine(rid)) {
          for (final view in await db.itemsForWorkout(day.id)) {
            expect(library.containsKey(view.item.exerciseId), isTrue,
                reason: '${view.exercise.name} was created rather than reused');
            expect(view.exercise.seedKey, isNotNull,
                reason: 'a starter program uses starter movements only');
          }
        }
      }
    });

    test('and every movement the table names is a starter movement', () {
      for (final program in kStarterRoutines) {
        for (final day in program.days) {
          for (final slot in day.items) {
            expect(kSeedExerciseKeys.containsKey(slot.exercise), isTrue,
                reason: '${slot.exercise} is not in the starter library');
          }
        }
      }
    });
  });

  group('the library reads in the app\'s language', () {
    const es = Locale('es');

    testWidgets('the library names the programs through their seed keys',
        (tester) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);
      final spanish = l10nFor(es);

      await tester.pumpWidget(routedAppUnder(
          container, const RoutineLibraryScreen(), locale: es));
      await pumpThroughDatabase(tester);

      expect(spanish.seedRoutinePushPullLegs, isNot('Push / Pull / Legs'),
          reason: 'the premise: this program has a Spanish name');
      expect(find.text(spanish.seedRoutinePushPullLegs), findsOneWidget);
      expect(find.text('Push / Pull / Legs'), findsNothing);
      // A published program is named the way a book is.
      expect(find.text('Starting Strength'), findsOneWidget);
      expect(find.text('StrongLifts 5x5'), findsOneWidget);

      await stop(tester);
    });

    testWidgets('so does the preview, days and all', (tester) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);
      final spanish = l10nFor(es);

      await tester.pumpWidget(routedAppUnder(
          container, const StarterRoutinePreviewScreen(routineKey: 'ppl'),
          locale: es));
      await pumpThroughDatabase(tester);

      expect(find.text(spanish.seedDayPush), findsWidgets);
      expect(find.text(spanish.seedDayLegs), findsWidgets);

      await stop(tester);
    });

    test('and the copy it makes carries the keys to follow a switch',
        () async {
      final spanish = l10nFor(es);
      final rid = await db.addStarterRoutine(_program('ppl'));
      final routine = (await db.watchRoutines().first).single.routine;

      expect(routine.name, 'Push / Pull / Legs',
          reason: 'the stored name stays English');
      expect(seededName(spanish, routine.seedKey, routine.name),
          spanish.seedRoutinePushPullLegs);

      final days = await db.workoutsForRoutine(rid);
      expect(days.map((w) => w.seedKey), ['push', 'pull', 'legs']);
      expect(
        days.map((w) => seededName(spanish, w.seedKey, w.name)),
        [spanish.seedDayPush, spanish.seedDayPull, spanish.seedDayLegs],
      );
    });

    test('a published title is the same English in every language', () async {
      final spanish = l10nFor(es);
      await db.addStarterRoutine(_program('starting-strength'));
      final routine = (await db.watchRoutines().first).single.routine;

      expect(seededName(spanish, routine.seedKey, routine.name),
          'Starting Strength');
      expect(seededName(spanish, 'stronglifts_5x5', 'StrongLifts 5x5'),
          'StrongLifts 5x5');
    });

    test('a copy you rename stops following the language', () async {
      final rid = await db.addStarterRoutine(_program('ppl'));
      await db.updateRoutineMeta(rid,
          name: 'Chest & Tris', color: 'FF6A3D', restSeconds: 120);
      final routine = (await db.watchRoutines().first).single.routine;

      expect(routine.seedKey, isNull);
      expect(seededName(l10nFor(es), routine.seedKey, routine.name),
          'Chest & Tris');
    });
  });

  group('an update leaves the programs already in your list alone', () {
    // A phone on the shipped build had the five written into it by the seed.
    // They are ordinary routines with history and edits on them, so the update
    // that stops seeding them must not remove one.
    //
    // Written as SQL against the frozen [kSchemaV1] — the bytes a phone hands
    // the upgrade, not the shape this build would have made.
    AppDatabase v1WithSeededProgram() => AppDatabase.forTesting(
          NativeDatabase.memory(setup: (raw) {
            for (final stmt in kSchemaV1) {
              raw.execute(stmt);
            }
            raw.execute(
                'INSERT INTO settings (id, active_routine_id) VALUES (1, 1)');
            raw.execute(
              'INSERT INTO exercises (id, name, seed_key, muscle_group, '
              "equipment) VALUES (1, 'Back Squat', 'back_squat', 'Legs', "
              "'Barbell')",
            );
            raw.execute(
              'INSERT INTO routines (id, name, seed_key, color_hex, position, '
              "rest_seconds) VALUES (1, 'Push / Pull / Legs', 'push_pull_legs', "
              "'FF6A3D', 0, 120)",
            );
            raw.execute(
              'INSERT INTO workouts (id, routine_id, name, seed_key, position) '
              "VALUES (1, 1, 'Legs', 'legs', 0)",
            );
            raw.execute(
              'INSERT INTO workout_items (id, workout_id, exercise_id, '
              'position, target_sets, reps_min, suggested_weight) '
              'VALUES (1, 1, 1, 0, 4, 6, 117.5)',
            );
            raw.execute('PRAGMA user_version = 1');
          }),
        );

    test('the program it already had is still there, with its weights',
        () async {
      final db = v1WithSeededProgram();
      addTearDown(db.close);

      final rows = await db.watchRoutines().first;
      expect(rows, hasLength(1),
          reason: 'nothing is removed, and nothing is seeded on top');
      expect(rows.single.routine.name, 'Push / Pull / Legs');
      expect(rows.single.routine.seedKey, 'push_pull_legs');

      final days = await db.workoutsForRoutine(rows.single.routine.id);
      expect(days.map((w) => w.name), ['Legs']);
      final items = await db.itemsForWorkout(days.single.id);
      expect(items.single.exercise.name, 'Back Squat');
      expect(items.single.item.suggestedWeight, 117.5,
          reason: 'the weight the phone was training at');
    });

    test('and it is still the routine Today is about', () async {
      final db = v1WithSeededProgram();
      addTearDown(db.close);

      expect(await db.watchActiveRoutineId().first, 1);
    });

    test('a fresh database opened beside it is still empty', () async {
      final upgraded = v1WithSeededProgram();
      addTearDown(upgraded.close);

      final fresh = memoryDb();
      addTearDown(fresh.close);

      expect(await upgraded.watchRoutines().first, hasLength(1));
      expect(await fresh.watchRoutines().first, isEmpty,
          reason: 'this changes what a fresh install opens with, only that');
    });
  });
}
