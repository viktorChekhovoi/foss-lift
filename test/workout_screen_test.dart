import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/data/warmup.dart';
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
      child: MaterialApp(theme: AppTheme.build(kDefaultPalette), home: const WorkoutScreen()),
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

  group('what actually goes on the bar', () {
    /// The bench press row's weight field — the one thing on a set row that is
    /// typed rather than tapped.
    Finder benchWeight() => find.descendant(
          of: find.byKey(const ValueKey('0-0-Bench Press')),
          matching: find.byType(TextField),
        );

    testWidgets('a barbell exercise is broken down per side', (tester) async {
      await startPush(tester);

      // 80 kg on a 20 kg bar: 30 a side, and the standard rack makes that
      // with a 25 and a 5.
      expect(find.text('30 KG/SIDE · 25 + 5 · BAR 20'), findsOneWidget);

      await stop(tester);
    });

    testWidgets('nothing but a bar gets one', (tester) async {
      await startPush(tester);
      // The list builds lazily, so the exercises under the fold have to be
      // scrolled to before they can be asked anything.
      for (var i = 0; i < 5; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pump();
      }
      expect(find.text('Triceps Pushdown'), findsOneWidget,
          reason: 'the bottom of the day is on screen');

      // The pushdown is 35 kg on a stack and the DB press is 30 in one hand.
      // Neither has sides, and 7.5 and 5 a side is what the app would say if
      // it thought they did.
      expect(find.textContaining('7.5 KG/SIDE'), findsNothing);
      expect(find.textContaining('5 KG/SIDE'), findsNothing);

      await stop(tester);
    });

    testWidgets('a weight the plates cannot make is flagged, with the '
        'nearest one that can', (tester) async {
      await startPush(tester);

      await tester.enterText(benchWeight(), '81');
      await tester.pump();

      expect(find.textContaining('NEAREST YOU CAN LOAD: 80 KG'), findsOneWidget);

      await stop(tester);
    });
  });

  group('warm-ups', () {
    ExerciseEntry bench() =>
        container.read(activeWorkoutProvider)!.exercises[0];

    /// The reps cell of a warm-up row of the first exercise. Only present once
    /// the group is expanded.
    Finder warmupCell(int wi) => find.descendant(
          of: find.byKey(ValueKey('w0-$wi-Bench Press')),
          matching: find.byType(GestureDetector),
        );

    testWidgets('a weight-based exercise gets them by default, out of the '
        'working count', (tester) async {
      await startPush(tester);

      // Bench is 80 kg on a bar: it gets the default ramp.
      expect(bench().hasWarmups, isTrue);
      expect(bench().warmupCount, kDefaultWarmupSets);
      expect(bench().warmups, isNotEmpty);
      // Warm-ups are not working sets: the headline count and volume ignore
      // them entirely.
      expect(bench().sets.length, 4, reason: 'four working sets, no more');
      expect(find.text('0/${totalSets()}'), findsOneWidget);
      expect(container.read(activeWorkoutProvider)!.volume, 0);

      await stop(tester);
    });

    testWidgets('the ramp is collapsed until the header is tapped',
        (tester) async {
      await startPush(tester);

      // The label is there, but the rows are not until it is opened.
      expect(find.text('WARM-UP'), findsWidgets);
      expect(warmupCell(0), findsNothing);

      await tester.tap(find.text('WARM-UP').first);
      await tester.pump();

      expect(warmupCell(0), findsOneWidget,
          reason: 'the ramp is revealed on expand');
      // The disclaimer rides with the opened ramp.
      expect(find.textContaining('not medical advice'), findsOneWidget);

      await stop(tester);
    });

    testWidgets('logging a warm-up moves nothing that counts', (tester) async {
      await startPush(tester);
      await tester.tap(find.text('WARM-UP').first);
      await tester.pump();

      await tester.tap(warmupCell(0));
      await tester.pump();

      expect(bench().warmups[0].done, isTrue, reason: 'the warm-up is logged');
      // ...but the working session is untouched by it.
      expect(container.read(activeWorkoutProvider)!.doneSets, 0);
      expect(container.read(activeWorkoutProvider)!.volume, 0);
      expect(bench().succeeded, isFalse);
      expect(bench().performedWeight, isNull);

      await stop(tester);
    });

    testWidgets('the count is adjustable and rebuilds the ramp',
        (tester) async {
      await startPush(tester);
      await tester.tap(find.text('WARM-UP').first);
      await tester.pump();

      final before = bench().warmups.length;
      // Drop it to zero.
      for (var i = 0; i < kDefaultWarmupSets; i++) {
        await tester.tap(find.text('−').first);
        await tester.pump();
      }
      expect(bench().warmupCount, 0);
      expect(bench().warmups, isEmpty);

      // And back up by one.
      await tester.tap(find.text('+').first);
      await tester.pump();
      expect(bench().warmupCount, 1);
      expect(bench().warmups, isNotEmpty);
      expect(bench().warmups.length, lessThanOrEqualTo(before));

      await stop(tester);
    });

    testWidgets('finishing saves working sets only, never a warm-up',
        (tester) async {
      await startPush(tester);
      await tester.tap(find.text('WARM-UP').first);
      await tester.pump();

      // Log one warm-up and one working set.
      await tester.tap(warmupCell(0));
      await tester.pump();
      await tester.tap(firstRepsCell());
      await tester.pump();

      // Finishing writes to real SQLite — needs a real clock.
      late final int id;
      await tester.runAsync(() async {
        id = (await container.read(activeWorkoutProvider.notifier).finish())!;
      });
      final saved = await tester.runAsync(() => db.setsForSession(id));

      expect(saved!.length, 1,
          reason: 'only the one working set was persisted');
      expect(saved.first.exerciseName, 'Bench Press');

      await stop(tester);
    });
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
        child: MaterialApp(theme: AppTheme.build(kDefaultPalette), home: const WorkoutScreen()),
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
