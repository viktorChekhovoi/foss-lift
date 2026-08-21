// Integration tests for cardio-machine console readouts in the live session (features/index.html#sec04).

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/state/session_snapshot.dart';
import 'package:foss_lift/util/cardio_units.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

/// What somebody would type off a treadmill after twenty minutes.
const kTreadmill = (
  speedKph: 9.5,
  inclinePercent: 2.0,
  resistanceLevel: null,
  distanceKm: 3.2,
);

/// What somebody would type off a bike, where the level is the only number.
const kBike = (
  speedKph: null,
  inclinePercent: null,
  resistanceLevel: 7,
  distanceKm: null,
);

void main() {
  late AppDatabase db;
  ProviderContainer? container;
  late int wid;

  setUp(() => db = memoryDb());
  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  ActiveWorkout session() => container!.read(activeWorkoutProvider)!;
  ActiveWorkoutController control() =>
      container!.read(activeWorkoutProvider.notifier);

  /// A one-slot day of [names], each with [sets] sets, hung off the seeded
  /// Push day so nothing here has to build a routine of its own.
  Future<void> makeDay(List<String> names, {int sets = 2}) async {
    wid = await workoutIdNamed(db, 'Push');
    final drafts = <ItemDraft>[];
    for (final name in names) {
      final e = (await db.watchExercises().first).firstWhere(
        (x) => x.name == name,
      );
      drafts.add(ItemDraft.forExercise(e)..sets = sets);
    }
    await db.replaceWorkoutItems(wid, itemCompanions(drafts, workoutId: wid));
  }

  Future<void> startDay() async {
    container = containerFor(db);
    await container!
        .read(activeWorkoutProvider.notifier)
        .start(workoutId: wid, name: 'Cardio');
  }

  group('the readouts a set carries', () {
    test('a cardio-machine set opens carrying none of them', () async {
      await makeDay(['Treadmill']);
      await startDay();

      final set = session().exercises.single.sets.first;
      expect(set.console, kNoConsoleMetrics);
      expect(set.hasConsole, isFalse);
    });

    test('and takes all four when they are typed in', () async {
      await makeDay(['Treadmill']);
      await startDay();

      control().setConsole(0, 0, kTreadmill);

      final set = session().exercises.single.sets.first;
      expect(set.console.speedKph, 9.5);
      expect(set.console.inclinePercent, 2.0);
      expect(set.console.distanceKm, 3.2);
      expect(set.hasConsole, isTrue);
    });

    test('one filled readout is a complete set, and the rest stay empty',
        () async {
      await makeDay(['Stationary Bike']);
      await startDay();

      control().setConsole(0, 0, kBike);

      final set = session().exercises.single.sets.first;
      expect(set.console.resistanceLevel, 7);
      expect(set.console.speedKph, isNull);
      expect(set.hasConsole, isTrue);
    });

    test('they belong to the set, not to the exercise', () async {
      await makeDay(['Treadmill'], sets: 2);
      await startDay();

      control().setConsole(0, 0, kTreadmill);

      expect(session().exercises.single.sets[1].console, kNoConsoleMetrics,
          reason: 'the second interval took the first one\'s numbers');
    });

    test('and can be cleared again', () async {
      await makeDay(['Treadmill']);
      await startDay();

      control().setConsole(0, 0, kTreadmill);
      control().setConsole(0, 0, kNoConsoleMetrics);

      expect(session().exercises.single.sets.first.hasConsole, isFalse);
    });
  });

  group('speed and distance follow the gym\'s unit', () {
    test('a metric gym reads kilometres', () {
      expect(toDisplaySpeed(9.5, 'kg'), closeTo(9.5, 1e-9));
      expect(toDisplayDistance(3.2, 'kg'), closeTo(3.2, 1e-9));
    });

    test('a pounds gym reads miles', () {
      expect(toDisplaySpeed(16.09344, 'lb'), closeTo(10, 1e-6));
      expect(toDisplayDistance(1.609344, 'lb'), closeTo(1, 1e-6));
    });

    test('what is typed in a pounds gym is stored metric', () {
      expect(speedToKph(10, 'lb'), closeTo(16.09344, 1e-6));
      expect(distanceToKm(1, 'lb'), closeTo(1.609344, 1e-6));
      expect(speedToKph(9.5, 'kg'), closeTo(9.5, 1e-9));
    });

    test('a round trip through either unit comes back where it started', () {
      for (final unit in ['kg', 'lb']) {
        expect(speedToKph(toDisplaySpeed(12.5, unit), unit), closeTo(12.5, 1e-9));
        expect(
          distanceToKm(toDisplayDistance(5.0, unit), unit),
          closeTo(5.0, 1e-9),
        );
      }
    });

    test('incline and resistance have no unit to convert', () {
      final l10n = l10nFor();
      final metric = cardioSummary(l10n, kBike, unit: 'kg');
      final imperial = cardioSummary(l10n, kBike, unit: 'lb');
      expect(metric, imperial);
    });

    test('a summary names only what was filled in', () {
      final l10n = l10nFor();
      expect(cardioSummary(l10n, kNoConsoleMetrics, unit: 'kg'), isNull);

      final line = cardioSummary(l10n, kTreadmill, unit: 'kg')!;
      expect(line, contains('9.5'));
      expect(line, contains('2'));
      expect(line, contains('3.2'));
    });
  });

  group('the readouts are kept with the set', () {
    test('a crash snapshot carries them back', () async {
      await makeDay(['Treadmill']);
      await startDay();
      control().setConsole(0, 0, kTreadmill);

      final back = decodeSession(encodeSession(session()))!;

      expect(back.exercises.single.sets.first.console, kTreadmill);
    });

    test('a snapshot from a build that never had them still reads', () async {
      await makeDay(['Treadmill']);
      await startDay();
      final payload = encodeSession(session())
          .replaceAll('"console"', '"consoleWasNotAField"');

      final back = decodeSession(payload);

      expect(back, isNotNull, reason: 'an older snapshot must not be lost');
      expect(back!.exercises.single.sets.first.console, kNoConsoleMetrics);
    });

    test('Finish writes them beside the set', () async {
      await makeDay(['Treadmill']);
      await startDay();
      control().setConsole(0, 0, kTreadmill);
      control().setLogged(0, 0, 1200);

      final id = (await control().finish())!;

      final row = (await db.setsForSession(id)).single;
      expect(row.seconds, 1200);
      expect(row.speedKph, 9.5);
      expect(row.inclinePercent, 2.0);
      expect(row.distanceKm, 3.2);
      expect(row.resistanceLevel, isNull);
    });

    test('a set that is never logged takes its readouts with it', () async {
      await makeDay(['Treadmill'], sets: 2);
      await startDay();
      control().setConsole(0, 0, kTreadmill);
      control().setLogged(0, 0, 1200);
      // The second interval got numbers typed and was then never logged.
      control().setConsole(0, 1, kBike);

      final id = (await control().finish())!;

      expect(await db.setsForSession(id), hasLength(1));
    });
  });

  group('only a cardio machine gets the details control', () {
    Future<void> pumpBoard(WidgetTester tester) async {
      await tester.runAsync(startDay);
      await tester.pumpWidget(appUnder(container!, const WorkoutScreen()));
      await tester.pump();
    }

    Future<void> stopAll(WidgetTester tester) async {
      container?.read(activeWorkoutProvider.notifier).discard();
      await stop(tester);
    }

    testWidgets('a treadmill set offers it', (tester) async {
      await tester.runAsync(() => makeDay(['Treadmill']));
      await pumpBoard(tester);

      expect(find.byKey(kConsoleToggleKey), findsWidgets);

      await stopAll(tester);
    });

    testWidgets('a bench press set does not', (tester) async {
      await tester.runAsync(() => makeDay(['Bench Press']));
      await pumpBoard(tester);

      expect(find.byKey(kConsoleToggleKey), findsNothing);

      await stopAll(tester);
    });

    testWidgets('and neither does a burpee, which is Cardio without a console',
        (tester) async {
      await tester.runAsync(() => makeDay(['Burpee']));
      await pumpBoard(tester);

      expect(find.byKey(kConsoleToggleKey), findsNothing);

      await stopAll(tester);
    });

    testWidgets('the fields are folded away until the control is tapped',
        (tester) async {
      await tester.runAsync(() => makeDay(['Treadmill'], sets: 1));
      await pumpBoard(tester);

      expect(find.byKey(kConsoleFieldsKey), findsNothing);

      await tester.tap(find.byKey(kConsoleToggleKey).first);
      await frames(tester);

      expect(find.byKey(kConsoleFieldsKey), findsOneWidget);

      await stopAll(tester);
    });

    testWidgets('and the open panel fits at the largest text the app renders',
        (tester) async {
      await tester.runAsync(() => makeDay(['Treadmill'], sets: 1));
      await tester.runAsync(startDay);
      await tester.pumpWidget(
        appUnder(container!, const WorkoutScreen(), textScale: 2.0),
      );
      await tester.pump();

      final overflows = await overflowsDuring(() async {
        await tester.tap(find.byKey(kConsoleToggleKey).first);
        await frames(tester);
      });

      expect(overflows, isEmpty, reason: overflows.join('\n'));

      await stopAll(tester);
    });

    testWidgets('a row carrying a readout says so while it is folded away',
        (tester) async {
      await tester.runAsync(() => makeDay(['Treadmill'], sets: 1));
      await pumpBoard(tester);
      container!.read(activeWorkoutProvider.notifier).setConsole(0, 0, kTreadmill);
      await tester.pump();

      // Shut, but not silent: the summary of what was typed stands in for the
      // fields, so a folded row never looks like a row with nothing in it.
      expect(find.byKey(kConsoleFieldsKey), findsNothing);
      expect(find.byKey(kConsoleSummaryKey), findsOneWidget);

      await stopAll(tester);
    });
  });
}
