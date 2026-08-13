// Integration tests for features/index.html#sec04 — reconfiguring an exercise
// slot from the live board: `slot-settings-open-from-the-board`,
// `board-settings-are-saved-to-the-workout`, `board-takes-the-change-where-it-can`
// and `no-settings-on-an-exercise-with-no-slot`.
//
// The sheet is the builder's own, so what it puts in the slot is already covered
// by section 03. What is particular here is the pair of consequences: the slot is
// written (so next week opens on it) and the running board takes the change
// without disturbing a set that is already logged.
//
// Timer discipline is the harness's — see feature_04_template_drift_test.dart.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

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
  ExerciseEntry only() => session().exercises.single;

  /// A day of one bench-press slot: [sets] sets of 8 at [kg].
  Future<void> makeDay({int sets = 4, double kg = 80, int reps = 8}) async {
    wid = await workoutIdNamed(db, 'Push');
    final e = (await db.watchExercises().first).firstWhere(
      (x) => x.name == 'Bench Press',
    );
    final draft = ItemDraft.forExercise(e)
      ..sets = sets
      ..repsMin = reps
      ..weightKg = kg;
    await db.replaceWorkoutItems(wid, itemCompanions([draft], workoutId: wid));
  }

  Future<void> startDay() async {
    container = containerFor(db);
    await container!
        .read(activeWorkoutProvider.notifier)
        .start(workoutId: wid, name: 'Push');
  }

  /// Rewrites the day's one slot the way the sheet does — the slot updated in
  /// place, its id kept — and tells the board to take it.
  Future<void> reconfigure(void Function(ItemDraft d) edit) async {
    final view = (await db.itemsForWorkout(wid)).single;
    final draft = ItemDraft.fromView(view);
    edit(draft);
    await db.updateWorkoutItem(view.item.id, itemUpdate(draft));
    await control().reconfigure(0);
  }

  group('what you change is saved to the workout', () {
    test('the slot itself is rewritten, keeping its id', () async {
      await makeDay();
      await startDay();
      final before = (await db.itemsForWorkout(wid)).single.item.id;

      await reconfigure((d) => d
        ..sets = 5
        ..repsMin = 6);

      final after = (await db.itemsForWorkout(wid)).single.item;
      expect(after.id, before, reason: 'a new slot would lose the streaks');
      expect(after.targetSets, 5);
      expect(after.repsMin, 6);
    });

    test('a progression rate changed on the board is what the slot progresses by',
        () async {
      await makeDay(sets: 1);
      await startDay();

      await reconfigure((d) => d..increment = 5);
      // A clean session: the one set logged at its goal.
      control().setLogged(0, 0, 8);
      await control().finish();

      final item = (await db.itemsForWorkout(wid)).single.item;
      expect(item.increment, 5);
      expect(item.suggestedWeight, 85,
          reason: 'the session stepped by the rate set during it');
    });
  });

  group('the board takes the change where it safely can', () {
    test('rest moves at once', () async {
      await makeDay();
      await startDay();

      await reconfigure((d) => d..restSeconds = 150);

      expect(only().restSeconds, 150);
    });

    test('the working weight moves, and the sets still to come with it',
        () async {
      await makeDay(kg: 80);
      await startDay();

      await reconfigure((d) => d..weightKg = 90);

      expect(only().workingKg, 90);
      expect(only().sets.map((s) => s.weight), everyElement(90));
    });

    test('the rule the session is judged by moves with it', () async {
      // A 3 × 6–8 slot started as an ordinary weight slot, switched to the
      // advanced axis from the board mid-session: this session is already
      // judged against the rep goal inside the range rather than against the
      // top of it, which is the number it opened on.
      wid = await workoutIdNamed(db, 'Push');
      final e = (await db.watchExercises().first)
          .firstWhere((x) => x.name == 'Bench Press');
      await db.replaceWorkoutItems(
        wid,
        itemCompanions([
          ItemDraft.forExercise(e)
            ..sets = 3
            ..repsMin = 6
            ..repsMax = 8
            ..weightKg = 80
        ], workoutId: wid),
      );
      await startDay();
      expect(only().sets.map((s) => s.goal), everyElement(8),
          reason: 'the top of the range, until the rule changes');

      await reconfigure((d) => d..setAdvanced(true));

      expect(only().sets.map((s) => s.goal), everyElement(6),
          reason: 'the goal starts at the bottom of the range');

      // Six on every set: short of the top, and exactly what the goal asked.
      control().setLogged(0, 0, 6);
      control().setLogged(0, 1, 6);
      control().setLogged(0, 2, 6);
      expect(only().verdict, SessionVerdict.success,
          reason: 'the board took the new rule, not just the new rates');

      await control().finish();
      final item = (await db.itemsForWorkout(wid)).single.item;
      expect(item.repsTarget, 7, reason: 'the goal climbed');
      expect(item.suggestedWeight, 80, reason: 'and the load waited');
      expect(item.failStreak, 0);
      expect(item.successStreak, 0);
    });

    test('a set already logged keeps what it was done at', () async {
      await makeDay(sets: 3, kg: 80);
      await startDay();
      control().setLogged(0, 0, 8);

      await reconfigure((d) => d..weightKg = 90);

      expect(only().sets.first.weight, 80, reason: 'history was rewritten');
      expect(only().sets.first.logged, 8);
      expect(only().sets[1].weight, 90);
    });

    test('the rep goal of every set still to come moves', () async {
      await makeDay(sets: 3, reps: 8);
      await startDay();
      control().setLogged(0, 0, 8);

      await reconfigure((d) => d..repsMin = 5);

      expect(only().sets.first.goal, 8, reason: 'the logged set kept its goal');
      expect(only().sets[1].goal, 5);
      expect(only().sets[2].goal, 5);
    });

    test('asking for more sets adds them on the end', () async {
      await makeDay(sets: 3);
      await startDay();
      control().setLogged(0, 0, 8);

      await reconfigure((d) => d..sets = 5);

      expect(only().sets, hasLength(5));
      expect(only().sets.first.logged, 8);
      expect(only().sets.skip(1).every((s) => !s.done), isTrue);
    });

    test('asking for fewer drops the ones nobody has logged', () async {
      await makeDay(sets: 5);
      await startDay();
      control().setLogged(0, 0, 8);

      await reconfigure((d) => d..sets = 2);

      expect(only().sets, hasLength(2));
      expect(only().sets.first.logged, 8);
    });

    test('and never below the sets already done', () async {
      await makeDay(sets: 5);
      await startDay();
      for (var i = 0; i < 4; i++) {
        control().setLogged(0, i, 8);
      }

      await reconfigure((d) => d..sets = 2);

      expect(only().sets, hasLength(4),
          reason: 'a session that went further than planned lost a set');
      expect(only().sets.every((s) => s.done), isTrue);
    });

    test('a console readout survives, logged or not', () async {
      // A treadmill day, so the sets carry readouts at all.
      wid = await workoutIdNamed(db, 'Push');
      final e = (await db.watchExercises().first).firstWhere(
        (x) => x.name == 'Treadmill',
      );
      await db.replaceWorkoutItems(
        wid,
        itemCompanions([ItemDraft.forExercise(e)..sets = 2], workoutId: wid),
      );
      await startDay();
      const typed = (
        speedKph: 9.5,
        inclinePercent: 2.0,
        resistanceLevel: null,
        distanceKm: 3.2,
      );
      control().setConsole(0, 0, typed);
      control().setLogged(0, 0, 600);
      // The second interval: numbers typed, not logged yet.
      control().setConsole(0, 1, typed);

      await reconfigure((d) => d..restSeconds = 150);

      expect(only().sets.first.console, typed, reason: 'the logged set lost it');
      expect(only().sets[1].console, typed, reason: 'the unlogged set lost it');
    });

    test('a slot the session is not carrying is left alone', () async {
      await makeDay();
      await startDay();
      // Index past the end of the board — nothing to reconfigure, and no throw.
      await control().reconfigure(5);

      expect(only().sets, hasLength(4));
    });
  });

  group('the control on the board', () {
    Future<void> pumpBoard(WidgetTester tester) async {
      await tester.runAsync(startDay);
      await tester.pumpWidget(appUnder(container!, const WorkoutScreen()));
      await tester.pump();
    }

    Future<void> stopAll(WidgetTester tester) async {
      container?.read(activeWorkoutProvider.notifier).discard();
      await stop(tester);
    }

    testWidgets('sits beside the exercise name', (tester) async {
      await tester.runAsync(makeDay);
      await pumpBoard(tester);

      expect(find.byKey(kSlotSettingsKey), findsOneWidget);

      await stopAll(tester);
    });

    testWidgets('and opens the builder\'s own sheet', (tester) async {
      await tester.runAsync(makeDay);
      await pumpBoard(tester);

      await tester.tap(find.byKey(kSlotSettingsKey));
      await frames(tester);

      // The progression rates are the part of the sheet this feature exists for.
      expect(find.byKey(kStepUpFieldKey), findsOneWidget);

      await stopAll(tester);
    });

    testWidgets('without the superset join, which the session refuses',
        (tester) async {
      await tester.runAsync(makeDay);
      await pumpBoard(tester);

      await tester.tap(find.byKey(kSlotSettingsKey));
      await frames(tester);

      expect(find.byKey(kSupersetCheckKey), findsNothing);

      await stopAll(tester);
    });

    testWidgets('and is absent on an exercise with no slot behind it',
        (tester) async {
      await tester.runAsync(() async {
        container = containerFor(db);
        // An ad-hoc session: no workout, so no slot under anything on the board.
        await container!
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: null, name: 'Quick session');
      });
      await tester.pumpWidget(appUnder(container!, const WorkoutScreen()));
      await tester.pump();

      expect(find.byKey(kSlotSettingsKey), findsNothing);

      await stopAll(tester);
    });
  });
}
