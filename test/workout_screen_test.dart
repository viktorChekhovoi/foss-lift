import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

/// Drives the live logging screen the way a thumb does. The tap cycle itself is
/// unit-tested in set_logging_test.dart; what this covers is that the screen
/// lays out and that a tap on the reps cell reaches the session state.
///
/// Two rules peculiar to this screen:
///   * never pumpAndSettle — a live session ticks its duration every second and
///     the rest banner counts down alongside it, so the tree is never quiet and
///     pumpAndSettle would spin until its own timeout;
///   * end every test with [stop] — the rest countdown is a timer the binding
///     checks for the moment the test body returns.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  // Disposing the container tears down drift's stream subscriptions, and drift
  // defers that cleanup onto a zero-duration timer. Doing it here rather than
  // inside the test body keeps that timer out of the binding's pending-timer
  // check, which runs the moment the body returns.
  tearDown(() {
    container.dispose();
    return db.close();
  });

  /// Starts the seeded PPL "Push" day — Bench Press, 4 sets of 6–8 @ 80 kg —
  /// and pumps the logging screen for it.
  Future<void> startPush(WidgetTester tester) async {
    // Loading the template hits real SQLite, which never completes under the
    // faked clock a widget test runs on — runAsync gives it a real one.
    await tester.runAsync(() async {
      final ppl = (await db.watchRoutines().first).first.routine;
      final push = (await db.workoutsForRoutine(ppl.id)).first;

      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      await container
          .read(activeWorkoutProvider.notifier)
          .start(workoutId: push.id, name: push.name);
    });

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.dark(), home: const WorkoutScreen()),
    ));
  }

  /// Unmounts the screen, which cancels the rest countdown. The session clock
  /// itself is a real timer (it was started inside runAsync) and is stopped by
  /// the container dispose in tearDown.
  Future<void> stop(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  /// Enough frames for a dialog to open or close. Not a settle.
  Future<void> frames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  int totalSets() => container.read(activeWorkoutProvider)!.totalSets;

  SetEntry firstSet() =>
      container.read(activeWorkoutProvider)!.exercises[0].sets[0];

  /// The reps cell of the first set of the first exercise.
  Finder firstRepsCell() => find.descendant(
        of: find.byKey(const ValueKey('0-0-Bench Press')),
        matching: find.byType(GestureDetector),
      );

  testWidgets('the screen lays out with a session in progress', (tester) async {
    await startPush(tester);

    expect(find.text('Push'), findsOneWidget);
    expect(find.text('0/${totalSets()}'), findsOneWidget);
    // The goal is on the row, not in an editable field.
    expect(find.text('80×8'), findsWidgets);

    await stop(tester);
  });

  testWidgets('one tap logs the set at its goal', (tester) async {
    await startPush(tester);
    await tester.tap(firstRepsCell());
    await tester.pump();

    expect(firstSet().logged, 8);
    expect(firstSet().missedGoal, isFalse);
    expect(find.text('1/${totalSets()}'), findsOneWidget);

    await stop(tester);
  });

  testWidgets('a second tap records falling a rep short', (tester) async {
    await startPush(tester);
    await tester.tap(firstRepsCell());
    await tester.pump();
    await tester.tap(firstRepsCell());
    await tester.pump();

    expect(firstSet().logged, 7);
    expect(firstSet().missedGoal, isTrue);
    expect(find.text('1/${totalSets()}'), findsOneWidget,
        reason: 'still one logged set');

    await stop(tester);
  });

  testWidgets('holding a set opens direct rep entry', (tester) async {
    await startPush(tester);
    await tester.longPress(firstRepsCell());
    await frames(tester);

    expect(find.text('Reps done'), findsOneWidget);
    expect(find.text('Goal 8'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '15');
    await tester.tap(find.text('Save'));
    await frames(tester);

    expect(firstSet().logged, 15, reason: 'a high count typed rather than tapped');
    expect(firstSet().missedGoal, isFalse);

    await stop(tester);
  });

  testWidgets('clearing from the dialog unlogs the set', (tester) async {
    await startPush(tester);
    await tester.tap(firstRepsCell());
    await tester.pump();
    expect(firstSet().done, isTrue);

    await tester.longPress(firstRepsCell());
    await frames(tester);
    await tester.tap(find.text('Clear'));
    await frames(tester);

    expect(firstSet().logged, isNull);
    expect(find.text('0/${totalSets()}'), findsOneWidget);

    await stop(tester);
  });

  testWidgets('the goal cannot be edited from the logging screen',
      (tester) async {
    await startPush(tester);

    // One editable field per set — the weight. Reps are tapped, not typed.
    final row = find.byKey(const ValueKey('0-0-Bench Press'));
    expect(
      find.descendant(of: row, matching: find.byType(TextField)),
      findsOneWidget,
    );
    expect(firstSet().goal, 8);

    await stop(tester);
  });

  group('an exercise that progresses on time', () {
    /// A one-day routine holding a single timed slot: 2 × 45-second planks.
    Future<void> startPlank(WidgetTester tester) async {
      await tester.runAsync(() async {
        final plank = (await db.watchExercises().first)
            .firstWhere((e) => e.name == 'Plank');
        final rid = await db.createRoutine(
            name: 'Core', color: 'FF6A3D', restSeconds: 60);
        final wid = await db.createWorkout(rid, 'Core');
        await db.replaceWorkoutItems(
          wid,
          itemCompanions(
            [
              // The library says a plank is held, which is what puts it on the
              // time axis — a workout cannot pick that for itself.
              ItemDraft(
                exerciseId: plank.id,
                name: plank.name,
                muscle: plank.muscleGroup,
                measure: plank.measure,
                sets: 2,
                holdSeconds: 45,
              ),
            ],
            workoutId: wid,
          ),
        );

        container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        await container
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: wid, name: 'Core');
      });

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.dark(), home: const WorkoutScreen()),
      ));
    }

    Finder plankCell() => find.descendant(
          of: find.byKey(const ValueKey('0-0-Plank')),
          matching: find.byType(GestureDetector),
        );

    testWidgets('the screen asks for seconds, not reps', (tester) async {
      await startPlank(tester);

      expect(find.text('SEC HELD'), findsOneWidget);
      expect(find.text('REPS DONE'), findsNothing);
      // An unloaded hold names no weight — "—×45s" would be asking a question
      // the plank does not have.
      expect(find.text('45s'), findsWidgets);

      await stop(tester);
    });

    testWidgets('one tap claims the whole hold, a second gives it back',
        (tester) async {
      await startPlank(tester);

      await tester.tap(plankCell());
      await tester.pump();
      expect(firstSet().logged, 45);
      expect(firstSet().missedGoal, isFalse);

      // No tapping a plank down one second at a time.
      await tester.tap(plankCell());
      await tester.pump();
      expect(firstSet().logged, isNull);

      await stop(tester);
    });

    testWidgets('an exact duration is typed in', (tester) async {
      await startPlank(tester);
      await tester.longPress(plankCell());
      await frames(tester);

      expect(find.text('Seconds held'), findsOneWidget);
      expect(find.text('Goal 45s'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, '32');
      await tester.tap(find.text('Save'));
      await frames(tester);

      expect(firstSet().logged, 32);
      expect(firstSet().missedGoal, isTrue, reason: 'short of the hold');

      await stop(tester);
    });
  });
}
