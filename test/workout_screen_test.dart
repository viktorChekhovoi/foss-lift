import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/theme/app_theme.dart';

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

    expect(firstSet().reps, 8);
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

    expect(firstSet().reps, 7);
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

    expect(firstSet().reps, 15, reason: 'a high count typed rather than tapped');
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

    expect(firstSet().reps, isNull);
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
    expect(firstSet().goalReps, 8);

    await stop(tester);
  });
}
