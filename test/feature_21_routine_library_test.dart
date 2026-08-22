// Integration tests for the built-in routine library and adding programs (features/index.html#sec21).

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
import 'package:foss_lift/util/target_label.dart';
import 'package:foss_lift/widgets/routine_add_menu.dart';
import 'package:foss_lift/widgets/routine_card.dart';

import 'support/harness.dart';
import 'support/schema_v1.dart';

/// The order the library lists its programs in: least experience first, with
/// the established library order retained inside each level.
const _kLibraryOrder = [
  'gzclp',
  'fitness-basic-beginner',
  'starting-strength',
  'stronglifts-5x5',
  'bodyweightfitness-recommended',
  'dumbbell-stopgap',
  '531-beginners',
  'tsa-beginner',
  'ppl-6-day',
  '531-classic',
  '531-bbb',
  '531-fsl',
  'candito-linear-control',
  'candito-linear-hypertrophy',
  'tsa-intermediate-2',
  'sheiko-29-32',
];

const _kExperienceByProgram = {
  'gzclp': 'beginner',
  'fitness-basic-beginner': 'beginner',
  'starting-strength': 'beginner',
  'stronglifts-5x5': 'beginner',
  'bodyweightfitness-recommended': 'beginner',
  'dumbbell-stopgap': 'beginner',
  '531-beginners': 'beginner',
  'tsa-beginner': 'beginner',
  'ppl-6-day': 'intermediate',
  '531-classic': 'intermediate',
  '531-bbb': 'intermediate',
  '531-fsl': 'intermediate',
  'candito-linear-control': 'intermediate',
  'candito-linear-hypertrophy': 'intermediate',
  'tsa-intermediate-2': 'intermediate',
  'sheiko-29-32': 'advanced',
};

/// Keys of the unpublished, Foss Lift-authored templates which the community
/// programs replace. Keeping this list explicit prevents a cosmetically renamed
/// homebrew routine from remaining in the library beside its replacement.
const _kRetiredHomebrewKeys = {
  'ppl',
  'upper-lower',
  'full-body-3x',
  'two-day-full-body',
  'bodyweight-basics',
  'dumbbell-full-body',
  'interval-conditioning',
};

const _kRetiredHomebrewNames = {
  'Push / Pull / Legs',
  'Upper / Lower',
  'Full Body 3×',
  'Two-Day Full Body',
  'Bodyweight Basics',
  'Dumbbell Full Body',
  'Interval Conditioning',
};

/// The languages a shipped program has to read in.
const _kLocales = [
  Locale('uk'),
  Locale('es'),
  Locale('pt'),
  Locale('pt', 'BR'),
];

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
  await tester.pumpWidget(
    routedAppUnder(
      container,
      const RoutinesScreen(),
      scaffold: true,
      alsoRoutes: ['routines/library', 'routine/new', 'scan'],
    ),
  );
  await pumpThroughDatabase(tester);
}

/// A tall, phone-wide viewport, so a list of training days is on screen rather
/// than below the fold.
void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  group('your routine list holds only what you put there', () {
    test('a fresh database holds no routines and nothing current', () async {
      expect(
        await db.watchRoutines().first,
        isEmpty,
        reason: 'five programs nobody chose is five rows to wade past',
      );
      expect(
        await db.watchActiveRoutineId().first,
        isNull,
        reason: 'nothing has been added, so nothing can be current',
      );
    });

    test('the movements are seeded exactly as before', () async {
      final names = (await db.watchExercises().first).map((e) => e.name);

      expect(
        names,
        containsAll(kSeedExerciseKeys.keys),
        reason: 'the starter library is a property of an empty database',
      );
      expect(
        (await db.watchExercises().first)
            .where((e) => e.seedKey != null)
            .map((e) => e.seedKey),
        containsAll(kSeedExerciseKeys.values),
      );
    });

    test('so are the racked bars, in both units', () async {
      for (final unit in const ['kg', 'lb']) {
        expect(
          (await db.barsFor(unit)).map((b) => b.name),
          containsAll(kSeedBarKeys.keys),
          reason: '$unit lost its bars',
        );
      }
    });

    test('and the settings row is there, unanswered', () async {
      expect(
        await db.watchUnitChosen().first,
        isFalse,
        reason: 'the unit question is still to be asked',
      );
      expect(
        await db.defaultWarmupSets(),
        kDefaultWarmupSets,
        reason: 'the row exists and carries its defaults',
      );
    });

    testWidgets('the routine list draws no cards, and says so in one line', (
      tester,
    ) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        routedAppUnder(
          container,
          const RoutinesScreen(),
          scaffold: true,
          alsoRoutes: ['routines/library'],
        ),
      );
      await pumpThroughDatabase(tester);

      final l10n = l10nFor();
      expect(
        find.byType(RoutineCard),
        findsNothing,
        reason: 'a fresh install opens on an empty list',
      );
      expect(
        find.text(l10n.todayNoRoutinesTitle),
        findsOneWidget,
        reason: 'an empty list says it is empty, in one line',
      );
      expect(
        find.byKey(kRoutinesAddKey),
        findsOneWidget,
        reason: 'the + in the corner is the way out of an empty list',
      );
      // The three ways in are behind that button now, not laid out under the
      // list where every routine added pushed them further down.
      expect(find.text(l10n.routineLibraryTitle), findsNothing);
      expect(find.text(l10n.routinesNewRoutine), findsNothing);
      expect(find.text(l10n.routinesImport), findsNothing);

      await stop(tester);
    });

    testWidgets('and Today offers to build one rather than five rows', (
      tester,
    ) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        routedAppUnder(container, const TodayScreen(), scaffold: true),
      );
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
      expect(
        find.text(l10n.routinesImport),
        findsOneWidget,
        reason: 'one question with three answers, on one sheet',
      );

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

    testWidgets('the import row asks scan or paste, and then scans', (
      tester,
    ) async {
      _tallPhone(tester);
      final l10n = l10nFor();
      await _pumpRoutines(tester, db);

      await tester.tap(find.byKey(kRoutinesAddKey));
      await pumpThroughDatabase(tester);
      await tester.tap(find.text(l10n.routinesImport));
      await pumpThroughDatabase(tester);

      expect(find.text(l10n.themeScanQr), findsOneWidget);
      expect(
        find.text(l10n.themePasteCode),
        findsOneWidget,
        reason: 'the second question is which way the code arrives',
      );
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

  group('GZCLP carries the canonical tier prescriptions', () {
    test('the four rotating days assign each main lift to T1 and T2', () async {
      final program = _program('gzclp');
      expect(program.days.map((day) => day.name), ['A1', 'B1', 'A2', 'B2']);
      expect(
        program.days
            .expand((day) => day.items)
            .where((slot) => slot.gzclTier == GzclTier.t1)
            .map((slot) => slot.exercise),
        ['Back Squat', 'Overhead Press', 'Bench Press', 'Deadlift'],
      );
      expect(
        program.days
            .expand((day) => day.items)
            .where((slot) => slot.gzclTier == GzclTier.t2)
            .map((slot) => slot.exercise),
        ['Bench Press', 'Deadlift', 'Back Squat', 'Overhead Press'],
      );
      expect(
        program.days
            .expand((day) => day.items)
            .where((slot) => slot.gzclTier == GzclTier.t1)
            .map((slot) => slot.gzclStages),
        everyElement(gzclpT1Stages),
      );
      expect(
        program.days
            .expand((day) => day.items)
            .where((slot) => slot.gzclTier == GzclTier.t2)
            .map((slot) => slot.gzclStages),
        everyElement(gzclpT2Stages),
      );

      final rid = await db.addStarterRoutine(program);
      final days = await db.workoutsForRoutine(rid);
      for (final day in days) {
        final slots = await db.itemsForWorkout(day.id);
        expect(slots.map((slot) => slot.item.gzclTier), [
          GzclTier.t1,
          GzclTier.t2,
          GzclTier.t3,
        ]);
        final t3 = slots.last.item;
        final sets = decodeCustomSets(t3.customSets);
        expect(t3.gzclAmrapTarget, defaultGzclT3AmrapTarget);
        expect(sets.map((set) => set.reps), [15, 15, 15]);
        expect(sets.map((set) => set.amrap), [false, false, true]);
      }
    });

    testWidgets('the preview describes the three jobs without tier shorthand', (
      tester,
    ) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        routedAppUnder(
          container,
          const StarterRoutinePreviewScreen(routineKey: 'gzclp'),
        ),
      );
      await pumpThroughDatabase(tester);

      final description = seededDescription(
        l10nFor(),
        _program('gzclp').seedKey,
        _program('gzclp').description,
      )!;
      expect(find.text(description), findsOneWidget);
      expect(
        description.toLowerCase(),
        allOf(contains('heavy'), contains('secondary'), contains('assistance')),
        reason: 'the preview explains what each kind of work does',
      );
      expect(
        description,
        isNot(matches(RegExp(r'\bT[123]\b'))),
        reason: 'a new lifter should not need GZCL tier vocabulary',
      );

      await stop(tester);
    });
  });

  group('ready-made routines browse by experience level', () {
    test('all sixteen carry a level and are grouped beginner to advanced', () {
      expect(kStarterRoutines.map((p) => p.key), _kLibraryOrder);
      expect(
        {for (final p in kStarterRoutines) p.key: p.experienceLevel.name},
        _kExperienceByProgram,
        reason: 'every ready-made routine has one deliberate experience level',
      );
    });

    testWidgets('each card shows its experience label', (tester) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        routedAppUnder(container, const RoutineLibraryScreen()),
      );
      await pumpThroughDatabase(tester);

      for (final program in kStarterRoutines) {
        final card = find.byKey(ValueKey('starter-${program.key}'));
        final label = switch (_kExperienceByProgram[program.key]) {
          'beginner' => 'Beginner',
          'intermediate' => 'Intermediate',
          'advanced' => 'Advanced',
          _ => throw StateError('${program.key} has no expected level'),
        };
        expect(
          find.descendant(of: card, matching: find.text(label)),
          findsOneWidget,
          reason: '${program.key} does not show $label on its card',
        );
      }

      await stop(tester);
    });

    testWidgets('filters combine, toggle independently, and clear to all', (
      tester,
    ) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        routedAppUnder(container, const RoutineLibraryScreen()),
      );
      await pumpThroughDatabase(tester);

      Finder card(String key) => find.byKey(ValueKey('starter-$key'));
      final beginner = find.byKey(const ValueKey('experience-filter-beginner'));
      final intermediate = find.byKey(
        const ValueKey('experience-filter-intermediate'),
      );
      final advanced = find.byKey(const ValueKey('experience-filter-advanced'));

      expect(beginner, findsOneWidget);
      expect(intermediate, findsOneWidget);
      expect(advanced, findsOneWidget);
      expect(card('gzclp'), findsOneWidget);
      expect(card('ppl-6-day'), findsOneWidget);
      expect(card('sheiko-29-32'), findsOneWidget);

      await tester.tap(beginner);
      await tester.pumpAndSettle();
      expect(card('gzclp'), findsOneWidget);
      expect(card('ppl-6-day'), findsNothing);
      expect(card('sheiko-29-32'), findsNothing);

      await tester.tap(intermediate);
      await tester.pumpAndSettle();
      expect(card('gzclp'), findsOneWidget);
      expect(card('ppl-6-day'), findsOneWidget);
      expect(card('sheiko-29-32'), findsNothing);

      await tester.tap(beginner);
      await tester.pumpAndSettle();
      expect(card('gzclp'), findsNothing);
      expect(card('ppl-6-day'), findsOneWidget);
      expect(card('sheiko-29-32'), findsNothing);

      await tester.tap(intermediate);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('starter-gzclp')),
        findsOneWidget,
        reason: 'clearing every selection restores the complete library',
      );
      expect(card('ppl-6-day'), findsOneWidget);
      expect(card('sheiko-29-32'), findsOneWidget);

      await tester.tap(advanced);
      await tester.pumpAndSettle();
      expect(card('gzclp'), findsNothing);
      expect(card('ppl-6-day'), findsNothing);
      expect(card('sheiko-29-32'), findsOneWidget);

      await stop(tester);
    });
  });

  group('the library holds the programs the app ships', () {
    test('sixteen published templates, each with its own key', () {
      expect(kStarterRoutines, hasLength(_kLibraryOrder.length));
      expect(
        kStarterRoutines.map((p) => p.key).toSet(),
        hasLength(_kLibraryOrder.length),
        reason: 'a duplicate key makes one of them unreachable',
      );
      expect(
        kStarterRoutines.map((p) => p.key),
        _kLibraryOrder,
        reason: 'beginner programs come first without scrambling each level',
      );
    });

    test('the retired homebrew programs are gone, not merely renamed', () {
      expect(
        kStarterRoutines.map((p) => p.key),
        isNot(contains(anyOf(_kRetiredHomebrewKeys))),
      );
      expect(
        kStarterRoutines.map((p) => p.name),
        isNot(contains(anyOf(_kRetiredHomebrewNames))),
      );
      expect(
        kStarterRoutines.map((p) => p.name),
        containsAll(const [
          'Push/Pull/Legs',
          'Basic Beginner Routine',
          'Bodyweight Routine',
          'Dumbbell Beginner Routine',
        ]),
      );
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
        expect(
          p.seedKey,
          kSeedRoutineKeys[p.name],
          reason: '${p.key} is a shipped row and follows the language',
        );
      }
    });

    testWidgets('all five are listed, named as the app names them', (
      tester,
    ) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);
      final l10n = l10nFor();

      await tester.pumpWidget(
        routedAppUnder(container, const RoutineLibraryScreen()),
      );
      await pumpThroughDatabase(tester);

      expect(find.text(l10n.routineLibraryTitle), findsWidgets);
      for (final p in kStarterRoutines) {
        expect(
          find.byKey(ValueKey('starter-${p.key}')),
          findsOneWidget,
          reason: '${p.key} is missing from the library',
        );
        expect(
          find.text(seededName(l10n, p.seedKey, p.name)),
          findsOneWidget,
          reason: '${p.key} is not named the way the app names it',
        );
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

  group('community programs keep their published structure', () {
    test('Push/Pull/Legs is the six-day alternating rotation', () {
      final program = _program('ppl-6-day');
      expect(program.name, 'Push/Pull/Legs');
      expect(program.days, hasLength(6));
      expect(program.days.map((d) => d.name), const [
        'Pull A',
        'Push A',
        'Legs A',
        'Pull B',
        'Push B',
        'Legs B',
      ]);
      expect(program.days[0].items.first.exercise, 'Deadlift');
      expect(program.days[3].items.first.exercise, 'Barbell Row');
      expect(program.days[1].items.first.exercise, 'Bench Press');
      expect(program.days[4].items.first.exercise, 'Overhead Press');
      expect(program.days[2].items.first.exercise, 'Back Squat');
      expect(program.days[5].items.first.exercise, 'Back Squat');
      for (final day in program.days) {
        expect(day.items.first.customSets.last.amrap, isTrue);
      }
    });

    test('the beginner routine alternates its two three-lift days', () {
      final program = _program('fitness-basic-beginner');
      expect(program.name, 'Basic Beginner Routine');
      expect(program.days, hasLength(2));
      expect(program.days.map((d) => d.items.length), everyElement(3));
      expect(program.days[0].items.map((s) => s.exercise), const [
        'Barbell Row',
        'Bench Press',
        'Back Squat',
      ]);
      expect(program.days[1].items.map((s) => s.exercise), const [
        'Chin-Up',
        'Overhead Press',
        'Deadlift',
      ]);
      for (final slot in program.days.expand((d) => d.items)) {
        expect((slot.sets, slot.repsMin), (3, 5));
        expect(slot.customSets.last.amrap, isTrue);
      }
    });

    test('the Recommended Routine keeps three pairs and its core triplet', () {
      final program = _program('bodyweightfitness-recommended');
      expect(program.name, 'Bodyweight Routine');
      expect(program.days, hasLength(3));
      for (final day in program.days) {
        expect(day.items, hasLength(9));
        expect(day.items.map((s) => s.exercise), const [
          'Pull-Up',
          'Air Squat',
          'Chest Dip',
          'Nordic Curl',
          'Inverted Row',
          'Push-Up',
          'Ab Wheel Rollout',
          'Pallof Press',
          'Back Extension',
        ]);
        expect(day.items.map((s) => s.supersetWithPrevious), const [
          false,
          true,
          false,
          true,
          false,
          true,
          false,
          true,
          true,
        ]);
      }
    });

    test('the dumbbell beginner routine alternates its two full-body days', () {
      final program = _program('dumbbell-stopgap');
      expect(program.name, 'Dumbbell Beginner Routine');
      expect(program.days, hasLength(2));
      expect(program.days[0].items.map((s) => s.exercise), const [
        'Bulgarian Split Squat',
        'Dumbbell Floor Press',
        'Dumbbell Romanian Deadlift',
        'Plank',
      ]);
      expect(program.days[1].items.map((s) => s.exercise), const [
        'Bulgarian Split Squat',
        'Dumbbell Shoulder Press',
        'Dumbbell Row',
        'Plank',
      ]);
      for (final slot in program.days.expand((d) => d.items)) {
        expect(slot.sets, 3);
        if (slot.exercise != 'Plank') {
          expect((slot.repsMin, slot.repsMax), (1, 10));
          expect(slot.addWeightAtTopOfRange, isTrue);
        }
      }
    });
  });

  // ------------------------------------------------------------- Candito

  group('two of the programs are Candito linear progression', () {
    List<StarterRoutine> candito() =>
        kStarterRoutines.where((r) => r.key.startsWith('candito-')).toList();

    /// The slots of the day named [day] in the program keyed [key].
    List<StarterSlot> dayOf(String key, String day) =>
        _program(key).days.firstWhere((d) => d.name == day).items;

    test('both are there, four days each, on the same two heavy days', () {
      expect(candito(), hasLength(2));
      for (final p in candito()) {
        expect(p.days, hasLength(4));
        expect(p.days.map((d) => d.name).take(2), [
          'Heavy Lower',
          'Heavy Upper',
        ]);
      }
      // Literally the same slots, so a change to one cannot drift from the
      // other — the variants differ in their other two days and nowhere else.
      expect(
        dayOf('candito-linear-control', 'Heavy Lower'),
        same(dayOf('candito-linear-hypertrophy', 'Heavy Lower')),
      );
      expect(
        dayOf('candito-linear-control', 'Heavy Upper'),
        same(dayOf('candito-linear-hypertrophy', 'Heavy Upper')),
      );
    });

    test('the heavy days are the prescription Candito writes', () {
      final lower = dayOf('candito-linear-control', 'Heavy Lower');
      expect(lower[0].exercise, 'Back Squat');
      expect((lower[0].sets, lower[0].repsMin), (3, 6));
      expect(lower[1].exercise, 'Deadlift');
      expect((lower[1].sets, lower[1].repsMin), (2, 6));

      final upper = dayOf('candito-linear-control', 'Heavy Upper');
      expect(upper[0].exercise, 'Bench Press');
      expect((upper[0].sets, upper[0].repsMin), (3, 6));
    });

    test('the control day is six sets of four of the paused lifts', () {
      final day = dayOf('candito-linear-control', 'Control Lower');
      expect(day.first.exercise, 'Pause Squat');
      expect((day.first.sets, day.first.repsMin), (6, 4));

      final upper = dayOf('candito-linear-control', 'Control Upper');
      expect(upper.first.exercise, 'Paused Bench Press');
      expect((upper.first.sets, upper.first.repsMin), (6, 4));
    });

    test('the hypertrophy day is five sets of eight of a variation', () {
      for (final day in ['Variation Lower', 'Variation Upper']) {
        final first = dayOf('candito-linear-hypertrophy', day).first;
        expect(
          (first.sets, first.repsMin),
          (5, 8),
          reason: '$day does not open on 5 × 8',
        );
      }
    });

    test('a missed lift is reset on the next session, not the one after', () {
      for (final p in candito()) {
        expect(
          p.failureThreshold,
          1,
          reason: '${p.key} waits for a second miss',
        );
      }
    });

    test('the main work drops 7.5 kg on the lift that missed', () async {
      await db.seedWeightUnit('kg');
      final rid = await db.addStarterRoutine(
        _program('candito-linear-control'),
      );
      final days = await db.workoutsForRoutine(rid);
      final heavy = await db.itemsForWorkout(days.first.id);

      expect(heavy.first.exercise.name, 'Back Squat');
      expect(heavy.first.item.increment, 5);
      expect(heavy.first.item.deload, 7.5);
      expect(heavy.first.item.failureThreshold, 1);
    });

    test(
      'the overhead press and the chin-up wait three clean sessions',
      () async {
        await db.seedWeightUnit('kg');
        final rid = await db.addStarterRoutine(
          _program('candito-linear-control'),
        );
        final days = await db.workoutsForRoutine(rid);
        final upper = await db.itemsForWorkout(days[1].id);
        final slow = {
          for (final v in upper) v.exercise.name: v.item.successThreshold,
        };

        expect(slow['Overhead Press'], 3);
        expect(slow['Chin-Up'], 3);
        expect(
          slow['Bench Press'],
          1,
          reason: 'the bench moves every week, which is the program',
        );
      },
    );

    test('the three paused lifts are in the starter library', () async {
      final library = {
        for (final e in await db.watchExercises().first) e.name: e,
      };
      for (final name in [
        'Pause Squat',
        'Paused Bench Press',
        'Pause Deadlift',
      ]) {
        expect(library[name], isNotNull, reason: '$name is not seeded');
        expect(library[name]!.isCustom, isFalse);
        expect(
          library[name]!.seedKey,
          isNotNull,
          reason: '$name has to follow the language',
        );
      }
    });
  });

  // -------------------------------------------------------------- Sheiko

  group('two of the programs are the TSA RPE approaches', () {
    test('both are explicit nine-week programs with effort prescriptions', () {
      for (final key in ['tsa-beginner', 'tsa-intermediate-2']) {
        final program = _program(key);
        expect(program.days.first.name, contains('W1'));
        expect(program.days.last.name, contains('W9'));
        expect(
          program.days.map((d) => d.name).toSet(),
          hasLength(program.days.length),
        );
        final slots = program.days.expand((d) => d.items).toList();
        expect(slots.where((s) => s.targetRpe != null), isNotEmpty);
        expect(
          slots.map((s) => s.exercise),
          containsAll(['Back Squat', 'Bench Press', 'Deadlift']),
        );
      }
    });

    test('their opening squat carries sets, reps, and RPE', () {
      for (final key in ['tsa-beginner', 'tsa-intermediate-2']) {
        final squat = _program(
          key,
        ).days.first.items.firstWhere((s) => s.exercise == 'Back Squat');
        expect(squat.sets, greaterThan(0));
        expect(squat.repsMin, greaterThan(0));
        expect(squat.targetRpe, inInclusiveRange(60, 100));
      }
    });
  });

  group('one of the programs is Sheiko #29–32', () {
    StarterRoutine sheiko() => _program('sheiko-29-32');

    /// The slots of the session named [day].
    List<StarterSlot> session(String day) {
      final match = sheiko().days.where((d) => d.name == day);
      expect(match, hasLength(1), reason: 'Sheiko has no session called $day');
      return match.single.items;
    }

    /// Every slot of the program whose sets are written out as percentages.
    Iterable<StarterSlot> percentageSlots() => sheiko().days
        .expand((d) => d.items)
        .where((s) => s.customSets.isNotEmpty);

    test('it is in the library, named as the program is named', () {
      expect(sheiko().name, 'Sheiko #29–32');
      expect(
        sheiko().seedKey,
        kSeedRoutineKeys['Sheiko #29–32'],
        reason: 'a shipped row follows the language',
      );
      expect(sheiko().description, isNotEmpty);
    });

    test('it arrives as forty-eight sessions in order', () {
      final days = sheiko().days;
      expect(days, hasLength(48));
      expect(days.first.name, '#29 · W1 · Mon');
      expect(days.last.name, '#32 · W4 · Meet');
      expect(
        days.map((d) => d.name).toSet(),
        hasLength(48),
        reason:
            'two sessions sharing a name are two sessions you cannot '
            'tell apart on Today',
      );
    });

    test('and not as a rotation — no session is empty', () {
      for (final day in sheiko().days) {
        expect(day.items, isNotEmpty, reason: '${day.name} prescribes nothing');
      }
      expect(
        sheiko().exerciseCount,
        sheiko().days.fold<int>(0, (sum, d) => sum + d.items.length),
      );
    });

    test('the first session runs bench, squat, bench, fly, good morning', () {
      expect(session('#29 · W1 · Mon').map((s) => s.exercise), const [
        'Bench Press',
        'Back Squat',
        'Bench Press',
        'Dumbbell Fly',
        'Good Morning',
      ]);
    });

    test('a lift that comes round twice in a session is two slots', () {
      final day = session('#29 · W1 · Mon');
      final benches = day.where((s) => s.exercise == 'Bench Press').toList();
      expect(benches, hasLength(2));
      expect(
        benches[0],
        isNot(same(benches[1])),
        reason: 'the second bench is not the first with more sets on it',
      );
      expect(
        benches[0].customSets.map((r) => (r.reps, r.percent)),
        isNot(benches[1].customSets.map((r) => (r.reps, r.percent))),
        reason: 'the second bench is at its own percentages',
      );
    });

    /// The working half of [session]'s first squat: the rows at 70%, which is
    /// where these two sessions put their irregular ladder. The lighter rows
    /// above them are the ramp up to it.
    List<int> workingReps(String day) {
      final squat = session(day).firstWhere((s) => s.exercise == 'Back Squat');
      return [
        for (final row in squat.customSets)
          if (row.percent == 70) row.reps,
      ];
    }

    test("#31 W1 Mon's squat keeps the rep order it is written in", () {
      expect(workingReps('#31 · W1 · Mon'), const [2, 4, 6, 8, 7, 5, 3]);
    });

    test("and so does #31 W3 Mon's", () {
      expect(workingReps('#31 · W3 · Mon'), const [5, 8, 3, 6, 2, 7, 4]);
    });

    test('every percentage slot carries a max and a written-out week', () {
      expect(percentageSlots(), isNotEmpty);
      for (final slot in percentageSlots()) {
        expect(
          slot.weightKg,
          isNotNull,
          reason: '${slot.exercise} has percentages of nothing',
        );
        expect(
          slot.customSets.every((r) => r.percent > 0),
          isTrue,
          reason: '${slot.exercise} has a row at no percentage',
        );
      }
    });

    test('none of them steps, and none of them backs off', () {
      for (final slot in percentageSlots()) {
        expect(
          slot.increment,
          0,
          reason: '${slot.exercise} adds to a max the program already moves',
        );
        expect(slot.deload, 0, reason: '${slot.exercise} backs a max off');
      }
    });

    test('and the copy carries those zeroes onto the slots', () async {
      await db.seedWeightUnit('kg');
      final rid = await db.addStarterRoutine(sheiko());
      final days = await db.workoutsForRoutine(rid);
      expect(days, hasLength(48));

      var written = 0;
      for (final day in days) {
        for (final v in await db.itemsForWorkout(day.id)) {
          if (!v.item.scheme.isWrittenOut) continue;
          written++;
          expect(v.item.increment, 0, reason: v.exercise.name);
          expect(v.item.deload, 0, reason: v.exercise.name);
          expect(v.item.suggestedWeight, isNotNull, reason: v.exercise.name);
        }
      }
      expect(
        written,
        greaterThan(100),
        reason: 'the competition lifts are written out set by set',
      );
    });

    test('the max test finishes above the max it opened at', () {
      final meet = session('#32 · W4 · Meet');
      final tops = meet
          .expand((s) => s.customSets)
          .map((r) => r.percent)
          .toList();
      expect(tops, isNotEmpty);
      expect(
        tops.reduce((a, b) => a > b ? a : b),
        greaterThan(100),
        reason: 'the meet session finishes on a single above the max',
      );
    });

    test('a 100 kg bench max makes an 80% row 80 kg', () {
      final slot = percentageSlots().firstWhere(
        (s) =>
            s.exercise == 'Bench Press' &&
            s.customSets.any((r) => r.percent == 80),
        orElse: () => throw StateError('no bench row at 80%'),
      );
      final targets = resolveSetTargets(
        scheme: SetScheme.custom,
        sets: slot.customSets.length,
        goalReps: 0,
        topWeightKg: 100,
        unit: 'kg',
        custom: slot.customSets,
      );
      final at80 = [
        for (var i = 0; i < slot.customSets.length; i++)
          if (slot.customSets[i].percent == 80) targets[i].weightKg,
      ];
      expect(at80, everyElement(80.0));
    });

    test('the accessories carry sets and reps and no weight', () {
      final accessories = sheiko().days
          .expand((d) => d.items)
          .where(
            (s) => const [
              'Dumbbell Fly',
              'Good Morning',
              'Crunch',
            ].contains(s.exercise),
          );

      expect(accessories, isNotEmpty);
      for (final slot in accessories) {
        expect(
          slot.customSets,
          isEmpty,
          reason:
              '${slot.exercise} was given a percentage the source '
              'deliberately left to the lifter',
        );
        expect(slot.weightKg, isNull, reason: slot.exercise);
        expect(slot.sets, greaterThan(0), reason: slot.exercise);
        expect(slot.repsMin, greaterThan(0), reason: slot.exercise);
      }
    });

    test('its variations train off the competition lift', () {
      final bases = {
        for (final slot in percentageSlots())
          slot.exercise: percentageBaseFor(slot.exercise),
      };
      expect(
        bases['Front Squat'],
        'Back Squat',
        reason: 'the front squats are percentages of the squat',
      );
      for (final entry in bases.entries) {
        expect(
          entry.value,
          isIn(const ['Back Squat', 'Bench Press', 'Deadlift']),
          reason: '${entry.key} asks for a max of its own',
        );
      }
    });

    test('every movement it names is in the starter library', () async {
      final library = (await db.watchExercises().first)
          .map((e) => e.name)
          .toSet();
      for (final day in sheiko().days) {
        for (final slot in day.items) {
          expect(
            library,
            contains(slot.exercise),
            reason: '${day.name} names ${slot.exercise}',
          );
        }
      }
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
              expect(
                row,
                isNotNull,
                reason:
                    '${slot.exercise} is not in the starter library, so '
                    '$key would land one slot short',
              );
              return (slot, row!);
            }(),
      ];
    }

    test('the bodyweight program asks for no load at all', () async {
      final slots = await slotsOf('bodyweight-basics');
      expect(slots, hasLength(greaterThan(8)));
      for (final (slot, row) in slots) {
        expect(
          slot.weightKg,
          isNull,
          reason: '${slot.exercise} carries a weight in a bodyweight program',
        );
        expect(
          row.equipment,
          'Bodyweight',
          reason: '${slot.exercise} needs equipment',
        );
      }
      expect(_program('bodyweight-basics').days, hasLength(3));
    });

    test('the dumbbell program uses dumbbells and nothing else', () async {
      final slots = await slotsOf('dumbbell-full-body');
      expect(slots, hasLength(greaterThan(8)));
      for (final (slot, row) in slots) {
        expect(
          row.equipment,
          'Dumbbell',
          reason: '${slot.exercise} is not a dumbbell movement',
        );
        expect(
          slot.weightKg,
          isNotNull,
          reason: '${slot.exercise} opens at no load',
        );
      }
      expect(
        _program('dumbbell-full-body').days.length,
        inInclusiveRange(3, 4),
      );
    });

    test(
      'the two-day program covers a squat, a hinge, a press and a pull',
      () async {
        final program = _program('two-day-full-body');
        expect(program.days, hasLength(2));
        for (final day in program.days) {
          expect(
            day.items,
            hasLength(greaterThanOrEqualTo(4)),
            reason: 'a whole body in one session',
          );
        }
      },
    );
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
          expect(
            slot.holdSeconds,
            isNotNull,
            reason:
                '${slot.exercise} is a conditioning slot with no work '
                'period on it',
          );
          expect(
            slot.repsMin,
            0,
            reason: '${slot.exercise} cannot be counted and held at once',
          );
          final row = library[slot.exercise];
          expect(
            row,
            isNotNull,
            reason:
                '${slot.exercise} is not in the '
                'starter library',
          );
          expect(
            row!.measure,
            ExerciseMeasure.time,
            reason:
                '${slot.exercise} is counted, so it would ignore the '
                'work period the program gives it',
          );
        }
      }
    });

    // Every program, not one of them: the conversion is done where a copy is
    // written rather than per program, but "the 5/3/1 one is right" is the
    // claim a reader of a single-program test would take away, and the
    // catalogue entry is about all of them.
    for (final program in kStarterRoutines) {
      test(
        'a pounds phone gets numbers a pounds gym loads — ${program.key}',
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
                expect(
                  (lb - lb.roundToDouble()).abs(),
                  lessThan(1e-6),
                  reason: '$lb lb is not a number anybody types',
                );
                expect(
                  lb.round() % kPoundStep.round(),
                  0,
                  reason: '$lb lb is not a pair of plates anybody racks',
                );
              }
            }
          }
        },
      );
    }

    test('a kilogram phone gets the numbers as they were written', () async {
      await db.seedWeightUnit('kg');
      final program = _program('ppl-6-day');
      final rid = await db.addStarterRoutine(program);

      final days = await db.workoutsForRoutine(rid);
      for (final (i, day) in days.indexed) {
        final items = await db.itemsForWorkout(day.id);
        for (final (j, view) in items.indexed) {
          expect(
            view.item.suggestedWeight,
            program.days[i].items[j].weightKg,
            reason: 'nothing to convert, so nothing to round',
          );
        }
      }
    });

    test(
      'the copy lands on the clock, with the work period it prescribes',
      () async {
        final program = _program('interval-conditioning');
        final rid = await db.addStarterRoutine(program);

        final days = await db.workoutsForRoutine(rid);
        expect(days, hasLength(program.days.length));
        for (final (i, day) in days.indexed) {
          final items = await db.itemsForWorkout(day.id);
          expect(
            items,
            hasLength(program.days[i].items.length),
            reason: '${day.name} lost a slot, so a movement is misnamed',
          );
          for (final (j, view) in items.indexed) {
            final slot = program.days[i].items[j];
            expect(view.item.progression, ProgressionMode.time);
            expect(view.item.holdSeconds, slot.holdSeconds);
            expect(view.item.targetSets, slot.sets);
          }
        }
      },
    );

    testWidgets('the preview shows the seconds where a rep count would be', (
      tester,
    ) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);
      final l10n = l10nFor();

      await tester.pumpWidget(
        routedAppUnder(
          container,
          const StarterRoutinePreviewScreen(
            routineKey: 'interval-conditioning',
          ),
        ),
      );
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
    test('descriptions are short factual labels, not promotional copy', () {
      final slop = RegExp(
        r"\b(designed to|whether you(?:'re| are)|journey|unlock|unleash|"
        r'elevate|transform|comprehensive|robust|seamless|tailored)\b',
        caseSensitive: false,
      );
      for (final program in kStarterRoutines) {
        expect(program.description.length, lessThanOrEqualTo(320));
        expect(program.description, isNot(matches(slop)), reason: program.key);
        expect(
          RegExp(r'[.!?]').allMatches(program.description),
          hasLength(lessThanOrEqualTo(3)),
          reason: '${program.key} is a blurb, not an essay',
        );
      }
    });

    test('community descriptions identify schedule and equipment', () {
      final requirements = <String, List<RegExp>>{
        'ppl-6-day': [
          RegExp(r'six[- ]day|6[- ]day', caseSensitive: false),
          RegExp(r'barbell|gym', caseSensitive: false),
        ],
        'fitness-basic-beginner': [
          RegExp(r'three (?:days|times)|3[- ]day', caseSensitive: false),
          RegExp(r'barbell|rack|gym', caseSensitive: false),
        ],
        'bodyweightfitness-recommended': [
          RegExp(r'three (?:days|times)|3[- ]day', caseSensitive: false),
          RegExp(r'bodyweight', caseSensitive: false),
          RegExp(r'hang|pull-up bar|row', caseSensitive: false),
        ],
        'dumbbell-stopgap': [
          RegExp(r'two|alternat', caseSensitive: false),
          RegExp(r'dumbbell', caseSensitive: false),
        ],
      };
      for (final entry in requirements.entries) {
        final description = _program(entry.key).description;
        for (final fact in entry.value) {
          expect(description, matches(fact), reason: '${entry.key}: $fact');
        }
      }
    });

    test('every program carries a description, in every language', () {
      for (final program in kStarterRoutines) {
        expect(
          program.description.trim(),
          isNotEmpty,
          reason: '${program.key} says nothing about itself',
        );
        expect(
          program.description.length,
          lessThanOrEqualTo(kMaxDescriptionLength),
          reason: '${program.key} would fail the insert',
        );
        expect(
          seededDescription(l10nFor(), program.seedKey, program.description),
          program.description,
          reason: '${program.key}: the English is the canonical text',
        );
        for (final locale in _kLocales) {
          final shown = seededDescription(
            l10nFor(locale),
            program.seedKey,
            program.description,
          );
          expect(shown, isNotNull);
          expect(
            shown,
            isNot(program.description),
            reason: '${program.key} is untranslated in $locale',
          );
        }
      }
    });

    testWidgets('the preview opens with it', (tester) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        routedAppUnder(
          container,
          const StarterRoutinePreviewScreen(routineKey: 'ppl-6-day'),
        ),
      );
      await pumpThroughDatabase(tester);

      expect(find.text(_program('ppl-6-day').description), findsOneWidget);

      await stop(tester);
    });

    testWidgets('in the app\'s language', (tester) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);
      const es = Locale('es');
      final program = _program('bodyweightfitness-recommended');

      await tester.pumpWidget(
        routedAppUnder(
          container,
          const StarterRoutinePreviewScreen(
            routineKey: 'bodyweightfitness-recommended',
          ),
          locale: es,
        ),
      );
      await pumpThroughDatabase(tester);

      expect(
        find.text(
          seededDescription(l10nFor(es), program.seedKey, program.description)!,
        ),
        findsOneWidget,
      );
      expect(find.text(program.description), findsNothing);

      await stop(tester);
    });

    test('and the copy keeps it', () async {
      final program = _program('dumbbell-stopgap');
      await db.addStarterRoutine(program);
      final routine = (await db.watchRoutines().first).single.routine;

      expect(
        routine.description,
        program.description,
        reason: 'the copy still explains itself a month later',
      );
      expect(
        seededDescription(
          l10nFor(const Locale('uk')),
          routine.seedKey,
          routine.description,
        ),
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
      await tester.pumpWidget(
        routedAppUnder(container, StarterRoutinePreviewScreen(routineKey: key)),
      );
      await pumpThroughDatabase(tester);
    }

    testWidgets('it lists every training day and every exercise in it', (
      tester,
    ) async {
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
            find.text(
              seededName(l10n, kSeedExerciseKeys[slot.exercise], slot.exercise),
            ),
            findsWidgets,
            reason: '${slot.exercise} is not shown under ${day.name}',
          );
        }
      }
      expect(
        find.text(l10n.routineLibraryAdd),
        findsOneWidget,
        reason: 'add is on the preview screen',
      );
      expect(find.byKey(const ValueKey('add-starter-routine')), findsOneWidget);

      await stop(tester);
    });

    testWidgets('the three-day split shows all three of its days', (
      tester,
    ) async {
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

    testWidgets('a cycled slot lists the week it opens on', (tester) async {
      await pumpPreview(tester, '531-classic');
      final l10n = l10nFor();

      // Week one of the main lift, written out the way every other screen
      // writes it: a cycle has no one set count to multiply.
      expect(
        find.text(rowsTargetLabel(l10n, k531Main.first)),
        findsWidgets,
        reason: 'the main lift reads as the week it opens on',
      );
      expect(
        find.text(l10n.targetSetsReps(0, '0')),
        findsNothing,
        reason: 'a cycled slot has no set count of its own to show',
      );

      await stop(tester);
    });

    testWidgets('so does a cycled supplemental slot', (tester) async {
      await pumpPreview(tester, '531-bbb');
      final l10n = l10nFor();

      expect(
        find.text(rowsTargetLabel(l10n, k531BigVolume.first)),
        findsWidgets,
      );
      expect(find.text(l10n.targetSetsReps(0, '0')), findsNothing);

      await stop(tester);
    });

    testWidgets('backing out adds nothing', (tester) async {
      await pumpPreview(tester, 'ppl-6-day');
      await stop(tester);

      // Through `runAsync`: a drift future completes on the real event loop, and
      // awaiting one in a widget test's fake zone waits for a pump that is not
      // coming.
      final after = (await tester.runAsync(
        () async => (
          routines: await db.watchRoutines().first,
          current: await db.watchActiveRoutineId().first,
        ),
      ))!;
      expect(
        after.routines,
        isEmpty,
        reason: 'looking at a program is not taking it',
      );
      expect(after.current, isNull);
    });
  });

  group('an added program is a copy, and it is yours', () {
    testWidgets('the add button on the preview writes the routine', (
      tester,
    ) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        routedAppUnder(
          container,
          const StarterRoutinePreviewScreen(routineKey: 'starting-strength'),
        ),
      );
      await pumpThroughDatabase(tester);

      await tester.tap(find.byKey(const ValueKey('add-starter-routine')));
      await pumpThroughDatabase(tester);

      final rows = (await tester.runAsync(() => db.watchRoutines().first))!;
      expect(rows, hasLength(1));
      expect(rows.single.routine.name, 'Starting Strength');
      expect(rows.single.workoutCount, 2);

      await stop(tester);
    });

    test(
      'the copy is an ordinary routine — rename it, gut it, delete it',
      () async {
        final rid = await db.addStarterRoutine(_program('ppl-6-day'));

        await db.updateRoutineMeta(
          rid,
          name: 'Chest & Tris',
          color: '3ED598',
          restSeconds: 75,
        );
        final mine = (await db.watchRoutines().first).single.routine;
        expect(mine.name, 'Chest & Tris');
        expect(mine.restSeconds, 75);

        await db.deleteRoutine(rid);
        expect(await db.watchRoutines().first, isEmpty);
      },
    );

    test(
      'adding the same program twice gives two independent routines',
      () async {
        final program = _program('starting-strength');
        final slotsBefore = program.exerciseCount;
        final firstDayBefore = program.days.first.name;

        final a = await db.addStarterRoutine(program);
        final b = await db.addStarterRoutine(program);

        expect(a, isNot(b), reason: 'a second copy is not refused');
        final rows = await db.watchRoutines().first;
        expect(rows.map((r) => r.routine.id), containsAll([a, b]));
        expect(
          rows.map((r) => r.routine.position).toSet(),
          hasLength(2),
          reason: 'the second copy lands at the bottom of the list',
        );

        // Gut the first copy's opening day.
        final dayOfA = (await db.workoutsForRoutine(a)).first;
        await db.replaceWorkoutItems(dayOfA.id, const []);
        await db.updateRoutineMeta(
          a,
          name: 'My version',
          color: '4D9DE0',
          restSeconds: 300,
        );

        // The second copy is untouched.
        final daysOfB = await db.workoutsForRoutine(b);
        expect(daysOfB.map((w) => w.name), program.days.map((d) => d.name));
        expect(
          await db.itemsForWorkout(daysOfB.first.id),
          hasLength(program.days.first.items.length),
        );
        expect(
          (await db.watchRoutines().first)
              .firstWhere((r) => r.routine.id == b)
              .routine
              .name,
          'Starting Strength',
        );

        // And so is the library: nothing you do to a copy reaches the table.
        expect(_program('starting-strength').exerciseCount, slotsBefore);
        expect(_program('starting-strength').days.first.name, firstDayBefore);
      },
    );
  });

  group('a program arrives set up the way the program is actually run', () {
    test('Starting Strength lands on its published prescription', () async {
      final program = _program('starting-strength');
      final rid = await db.addStarterRoutine(program);
      final routine = (await db.watchRoutines().first).single.routine;

      expect(routine.id, rid);
      expect(routine.name, 'Starting Strength');
      expect(routine.seedKey, 'starting_strength');
      expect(
        routine.restSeconds,
        300,
        reason: 'a heavy triple needs five minutes',
      );
      expect(
        routine.scheduleDays,
        1 << 0 | 1 << 2 | 1 << 4,
        reason: 'the days the program is meant to be trained on',
      );
      expect(routine.colorHex, program.colorHex);

      final days = await db.workoutsForRoutine(rid);
      expect(days.map((w) => w.name), ['Workout A', 'Workout B']);
      expect(days.map((w) => w.seedKey), ['workout_a', 'workout_b']);

      final a = await db.itemsForWorkout(days.first.id);
      expect(a.map((v) => v.exercise.name), [
        'Back Squat',
        'Bench Press',
        'Deadlift',
      ]);
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
      expect(
        a[2].item.targetSets,
        1,
        reason: 'the lift the program deliberately does not do three sets of',
      );
      expect(a[2].item.repsMin, 5);
      expect(a[2].item.increment, 5);
      // Three failed sessions before the back-off, throughout.
      expect(a.map((v) => v.item.failureThreshold), everyElement(3));

      final b = await db.itemsForWorkout(days.last.id);
      expect(b.map((v) => v.exercise.name), [
        'Back Squat',
        'Overhead Press',
        'Power Clean',
      ]);
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

    test(
      'the linear programs back off later than the hypertrophy ones',
      () async {
        final ss = _program('starting-strength');
        final ppl = _program('ppl');

        expect(ss.failureThreshold, 3);
        expect(
          ss.failureThreshold,
          greaterThan(ppl.failureThreshold),
          reason: 'a missed session on a beginner program is a bad day',
        );

        final pplId = await db.addStarterRoutine(ppl);
        final legs = (await db.workoutsForRoutine(
          pplId,
        )).firstWhere((w) => w.name == 'Legs');
        expect(
          (await db.itemsForWorkout(
            legs.id,
          )).map((v) => v.item.failureThreshold),
          everyElement(ppl.failureThreshold),
        );
      },
    );

    test('a slot with no load progresses on reps', () async {
      final rid = await db.addStarterRoutine(_program('ppl'));
      final pull = (await db.workoutsForRoutine(
        rid,
      )).firstWhere((w) => w.name == 'Pull');
      final pullUp = (await db.itemsForWorkout(
        pull.id,
      )).firstWhere((v) => v.exercise.name == 'Pull-Up');

      expect(pullUp.item.suggestedWeight, isNull);
      expect(pullUp.item.progression, ProgressionMode.reps);
    });
  });

  group('the first program added becomes the routine Today is about', () {
    test('the first one added from the library takes that place', () async {
      final first = await db.addStarterRoutine(_program('ppl-6-day'));

      expect(await db.watchActiveRoutineId().first, first);
    });

    test('and a second one does not displace it', () async {
      final first = await db.addStarterRoutine(_program('ppl-6-day'));
      await db.addStarterRoutine(_program('stronglifts-5x5'));

      expect(
        await db.watchActiveRoutineId().first,
        first,
        reason: 'adding a program to look at is not switching to it',
      );
    });

    test('a routine you build yourself does the same', () async {
      final mine = await db.createRoutine(
        name: 'My Split',
        color: 'FF6A3D',
        restSeconds: 90,
      );
      expect(await db.watchActiveRoutineId().first, mine);

      final second = await db.createRoutine(
        name: 'Another',
        color: '3ED598',
        restSeconds: 90,
      );
      expect(
        await db.watchActiveRoutineId().first,
        mine,
        reason: 'that choice is already made',
      );
      expect(second, isNot(mine));
    });

    test('a current routine already chosen is left alone', () async {
      final ppl = await db.addStarterRoutine(_program('ppl-6-day'));
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
      expect(
        after,
        before,
        reason: 'every movement the five use is already in the library',
      );
    });

    test('every slot points at a row that was already there', () async {
      final library = {
        for (final e in await db.watchExercises().first) e.id: e.name,
      };

      for (final program in kStarterRoutines) {
        final rid = await db.addStarterRoutine(program);
        for (final day in await db.workoutsForRoutine(rid)) {
          for (final view in await db.itemsForWorkout(day.id)) {
            expect(
              library.containsKey(view.item.exerciseId),
              isTrue,
              reason: '${view.exercise.name} was created rather than reused',
            );
            expect(
              view.exercise.seedKey,
              isNotNull,
              reason: 'a starter program uses starter movements only',
            );
          }
        }
      }
    });

    test('and every movement the table names is a starter movement', () {
      for (final program in kStarterRoutines) {
        for (final day in program.days) {
          for (final slot in day.items) {
            expect(
              kSeedExerciseKeys.containsKey(slot.exercise),
              isTrue,
              reason: '${slot.exercise} is not in the starter library',
            );
          }
        }
      }
    });
  });

  group('the library reads in the app\'s language', () {
    const es = Locale('es');

    testWidgets('the library names the programs through their seed keys', (
      tester,
    ) async {
      _tallPhone(tester);
      final container = containerFor(db);
      addTearDown(container.dispose);
      final spanish = l10nFor(es);

      await tester.pumpWidget(
        routedAppUnder(container, const RoutineLibraryScreen(), locale: es),
      );
      await pumpThroughDatabase(tester);

      expect(
        spanish.seedRoutinePpl,
        isNot('Push/Pull/Legs'),
        reason: 'the premise: this program has a Spanish name',
      );
      expect(find.text(spanish.seedRoutinePpl), findsOneWidget);
      expect(find.text('Push/Pull/Legs'), findsNothing);
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

      await tester.pumpWidget(
        routedAppUnder(
          container,
          const StarterRoutinePreviewScreen(routineKey: 'ppl-6-day'),
          locale: es,
        ),
      );
      await pumpThroughDatabase(tester);

      expect(find.text(spanish.seedDayPushA), findsWidgets);
      expect(find.text(spanish.seedDayLegsA), findsWidgets);

      await stop(tester);
    });

    test('and the copy it makes carries the keys to follow a switch', () async {
      final spanish = l10nFor(es);
      final rid = await db.addStarterRoutine(_program('ppl'));
      final routine = (await db.watchRoutines().first).single.routine;

      expect(
        routine.name,
        'Push / Pull / Legs',
        reason: 'the stored name stays English',
      );
      expect(
        seededName(spanish, routine.seedKey, routine.name),
        spanish.seedRoutinePushPullLegs,
      );

      final days = await db.workoutsForRoutine(rid);
      expect(days.map((w) => w.seedKey), ['push', 'pull', 'legs']);
      expect(days.map((w) => seededName(spanish, w.seedKey, w.name)), [
        spanish.seedDayPush,
        spanish.seedDayPull,
        spanish.seedDayLegs,
      ]);
    });

    test('a published title is the same English in every language', () async {
      final spanish = l10nFor(es);
      await db.addStarterRoutine(_program('starting-strength'));
      final routine = (await db.watchRoutines().first).single.routine;

      expect(
        seededName(spanish, routine.seedKey, routine.name),
        'Starting Strength',
      );
      expect(
        seededName(spanish, 'stronglifts_5x5', 'StrongLifts 5x5'),
        'StrongLifts 5x5',
      );
    });

    test('a copy you rename stops following the language', () async {
      final rid = await db.addStarterRoutine(_program('ppl-6-day'));
      await db.updateRoutineMeta(
        rid,
        name: 'Chest & Tris',
        color: 'FF6A3D',
        restSeconds: 120,
      );
      final routine = (await db.watchRoutines().first).single.routine;

      expect(routine.seedKey, isNull);
      expect(
        seededName(l10nFor(es), routine.seedKey, routine.name),
        'Chest & Tris',
      );
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
      NativeDatabase.memory(
        setup: (raw) {
          for (final stmt in kSchemaV1) {
            raw.execute(stmt);
          }
          raw.execute(
            'INSERT INTO settings (id, active_routine_id) VALUES (1, 1)',
          );
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
        },
      ),
    );

    test(
      'the program it already had is still there, with its weights',
      () async {
        final db = v1WithSeededProgram();
        addTearDown(db.close);

        final rows = await db.watchRoutines().first;
        expect(
          rows,
          hasLength(1),
          reason: 'nothing is removed, and nothing is seeded on top',
        );
        expect(rows.single.routine.name, 'Push / Pull / Legs');
        expect(rows.single.routine.seedKey, 'push_pull_legs');

        final days = await db.workoutsForRoutine(rows.single.routine.id);
        expect(days.map((w) => w.name), ['Legs']);
        final items = await db.itemsForWorkout(days.single.id);
        expect(items.single.exercise.name, 'Back Squat');
        expect(
          items.single.item.suggestedWeight,
          117.5,
          reason: 'the weight the phone was training at',
        );
      },
    );

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
      expect(
        await fresh.watchRoutines().first,
        isEmpty,
        reason: 'this changes what a fresh install opens with, only that',
      );
    });
  });
}
