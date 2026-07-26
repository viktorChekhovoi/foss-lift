// Integration tests for features/10-history-and-stats.md — the post-session
// recap, the history list, running lifetime totals, and the per-exercise 1RM /
// chart maths. Driven through the real public surface: the AppDatabase history
// and aggregate queries, the pure stats functions, the finish→recap controller
// path, and the summary/history widgets where the behaviour is a screen one.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/summary_screen.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/util/format.dart';

import 'support/harness.dart';

void main() {
  // -------------------------------------------------------------------------
  // Local helpers — no duplication of the shared harness.
  // -------------------------------------------------------------------------

  /// One logged set row, ready for [AppDatabase.saveSession]. `sessionId` is a
  /// placeholder — saveSession replaces it. Done by default; a timed set carries
  /// seconds and leaves reps at zero, exactly as the live session records it.
  SessionSetsCompanion setRow(
    String exercise,
    int n, {
    double weight = 0,
    int reps = 0,
    bool done = true,
    int? seconds,
  }) =>
      SessionSetsCompanion.insert(
        sessionId: 0,
        exerciseName: exercise,
        setNumber: n,
        weight: Value(weight),
        reps: Value(reps),
        done: Value(done),
        seconds: Value(seconds),
      );

  /// Persists one finished session directly, the fast path for building history.
  Future<int> saveOne(
    AppDatabase db, {
    required String name,
    required DateTime at,
    int? routineId,
    int? workoutId,
    double storedVolume = 0,
    List<SessionSetsCompanion> sets = const [],
  }) =>
      db.saveSession(
        routineId: routineId,
        workoutId: workoutId,
        name: name,
        startedAt: at,
        endedAt: at.add(const Duration(minutes: 30)),
        durationSeconds: 1800,
        totalVolume: storedVolume,
        sets: sets,
      );

  /// The seeded PPL workout ids, by day name ("Push", "Pull", "Legs").
  Future<Map<String, int>> pplWorkouts(AppDatabase db) async {
    final routines = await db.watchRoutines().first;
    final ppl = routines.first.routine; // position 0 = Push / Pull / Legs
    final workouts = await db.workoutsForRoutine(ppl.id);
    return {for (final w in workouts) w.name: w.id};
  }

  /// Drives the live controller through a clean session of [workoutId] (every
  /// set logged at its goal) and finishes it, returning the new session id.
  Future<int> finishClean(container, int workoutId, String name) async {
    final notifier = container.read(activeWorkoutProvider.notifier);
    await notifier.start(workoutId: workoutId, name: name);
    final s = container.read(activeWorkoutProvider)!;
    for (var ei = 0; ei < s.exercises.length; ei++) {
      for (var si = 0; si < s.exercises[ei].sets.length; si++) {
        notifier.cycleSet(ei, si); // first tap claims the goal → logged, clean
      }
    }
    return (await notifier.finish())!;
  }

  /// Pumps a non-live tree until [finder] matches, letting the summary's
  /// SQLite-backed FutureProvider resolve through real async between frames.
  Future<void> pumpUntil(WidgetTester tester, Finder finder,
      {int tries = 30}) async {
    for (var i = 0; i < tries; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
  }

  // =========================================================================
  // Per-exercise chart maths (pure — features/10 "1RM / chart maths").
  // =========================================================================

  group('estimatedOneRepMax (Epley)', () {
    test('a single rep is already a one-rep max — weight untouched', () {
      expect(estimatedOneRepMax(100, 1), 100);
    });

    test('zero reps has no estimate', () {
      expect(estimatedOneRepMax(100, 0), 0);
    });

    test('a logged-but-not-performed set (negative reps) estimates nothing', () {
      expect(estimatedOneRepMax(100, -3), 0);
    });

    test('multi-rep set uses w·(1 + reps/30)', () {
      expect(estimatedOneRepMax(100, 5), closeTo(116.667, 0.001));
      expect(estimatedOneRepMax(60, 10), closeTo(80, 0.001));
    });
  });

  group('progressPoints', () {
    ExerciseSetEntry entry({
      required int sessionId,
      required DateTime date,
      int setNumber = 1,
      double weightKg = 0,
      int reps = 0,
      int? seconds,
      bool done = true,
    }) =>
        ExerciseSetEntry(
          sessionId: sessionId,
          date: date,
          sessionName: 'S$sessionId',
          setNumber: setNumber,
          weightKg: weightKg,
          reps: reps,
          seconds: seconds,
          done: done,
        );

    test('no sets yields no points', () {
      expect(progressPoints(const []), isEmpty);
    });

    test('skipped sets do not count; an all-skipped session contributes nothing',
        () {
      final points = progressPoints([
        entry(sessionId: 1, date: DateTime(2026, 1, 1), weightKg: 100, reps: 5),
        entry(
            sessionId: 1,
            date: DateTime(2026, 1, 1),
            setNumber: 2,
            weightKg: 120,
            reps: 5,
            done: false),
        entry(
            sessionId: 2,
            date: DateTime(2026, 1, 2),
            weightKg: 90,
            reps: 5,
            done: false),
      ]);
      expect(points, hasLength(1));
      // The 120 kg set was skipped, so the session's top weight is the 100.
      expect(points.single.topWeightKg, 100);
    });

    test('one point per session, oldest first — same day stays two points', () {
      final day = DateTime(2026, 3, 10);
      final points = progressPoints([
        entry(sessionId: 2, date: day.add(const Duration(hours: 18)), weightKg: 105, reps: 5),
        entry(sessionId: 1, date: day.add(const Duration(hours: 8)), weightKg: 100, reps: 5),
      ]);
      expect(points, hasLength(2));
      // Sorted oldest-first: session 1 (morning) then session 2 (evening).
      expect(points.first.topWeightKg, 100);
      expect(points.last.topWeightKg, 105);
    });

    test('top weight is the heaviest completed set; reps-at-top breaks ties on reps',
        () {
      final points = progressPoints([
        entry(sessionId: 1, date: DateTime(2026, 1, 1), weightKg: 100, reps: 5),
        entry(sessionId: 1, date: DateTime(2026, 1, 1), setNumber: 2, weightKg: 100, reps: 8),
        entry(sessionId: 1, date: DateTime(2026, 1, 1), setNumber: 3, weightKg: 90, reps: 12),
      ]);
      final p = points.single;
      expect(p.topWeightKg, 100);
      expect(p.repsAtTop, 8); // most reps at the top weight
    });

    test('est1RM credits an extra rep, not only more load', () {
      final points = progressPoints([
        // A heavy single sets the top weight…
        entry(sessionId: 1, date: DateTime(2026, 1, 1), weightKg: 105, reps: 1),
        // …but 100×5 is the better estimated 1RM (116.67 > 105).
        entry(sessionId: 1, date: DateTime(2026, 1, 1), setNumber: 2, weightKg: 100, reps: 5),
      ]);
      final p = points.single;
      expect(p.topWeightKg, 105);
      expect(p.repsAtTop, 1);
      expect(p.est1RMKg, closeTo(116.667, 0.001));
    });

    test('a timed movement keeps the longest completed hold', () {
      final points = progressPoints([
        entry(sessionId: 1, date: DateTime(2026, 1, 1), seconds: 40),
        entry(sessionId: 1, date: DateTime(2026, 1, 1), setNumber: 2, seconds: 60),
      ]);
      expect(points.single.bestSeconds, 60);
    });
  });

  // =========================================================================
  // fmtTotal (features/10 formatting, util/format.dart).
  // =========================================================================

  group('fmtTotal', () {
    test('small values are grouped digits', () {
      expect(fmtTotal(999), '999');
      expect(fmtTotal(1500), '1,500');
    });

    test('five figures and up collapse to k, dropping a bare .0', () {
      expect(fmtTotal(12000), '12k');
      expect(fmtTotal(12500), '12.5k');
    });

    test('seven figures collapse to M', () {
      expect(fmtTotal(1500000), '1.5M');
      expect(fmtTotal(2000000), '2M');
    });
  });

  // =========================================================================
  // Lifetime totals — summed from the logged sets, never a stored tally.
  // =========================================================================

  group('Lifetime totals', () {
    late AppDatabase db;
    late dynamic container;

    setUp(() {
      db = memoryDb();
      container = containerFor(db);
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('sum volume, reps and sets over every completed set of old history', () async {
      await saveOne(db, name: 'A', at: DateTime(2026, 1, 1), sets: [
        setRow('Bench Press', 1, weight: 100, reps: 5),
        setRow('Bench Press', 2, weight: 100, reps: 5),
        setRow('Bench Press', 3, weight: 100, reps: 5),
      ]);
      await saveOne(db, name: 'B', at: DateTime(2026, 1, 3), sets: [
        setRow('Back Squat', 1, weight: 140, reps: 5),
        setRow('Back Squat', 2, weight: 140, reps: 5),
      ]);

      final totals = await db.watchLifetimeTotals().first;
      expect(totals.volumeKg, closeTo(100 * 5 * 3 + 140 * 5 * 2, 1e-9)); // 2900
      expect(totals.reps, 25);
      expect(totals.sets, 5);
    });

    test('the totals ignore the stored per-session tally', () async {
      // A session whose stored totalVolume is wildly wrong: the lifetime figure
      // must come from the sets beneath it, not the cached number.
      await saveOne(db,
          name: 'A',
          at: DateTime(2026, 1, 1),
          storedVolume: 999999,
          sets: [setRow('Bench Press', 1, weight: 50, reps: 10)]);

      final totals = await db.watchLifetimeTotals().first;
      expect(totals.volumeKg, closeTo(500, 1e-9));
    });

    test('only completed sets are counted', () async {
      await saveOne(db, name: 'A', at: DateTime(2026, 1, 1), sets: [
        setRow('Bench Press', 1, weight: 100, reps: 5),
        setRow('Bench Press', 2, weight: 100, reps: 5, done: false),
      ]);

      final totals = await db.watchLifetimeTotals().first;
      expect(totals.reps, 5);
      expect(totals.sets, 1);
      expect(totals.volumeKg, closeTo(500, 1e-9));
    });

    test('timed sets do not inflate rep or volume totals', () async {
      await saveOne(db, name: 'A', at: DateTime(2026, 1, 1), sets: [
        setRow('Bench Press', 1, weight: 100, reps: 5),
        // A 60-second plank: seconds held, zero reps, zero load.
        setRow('Plank', 2, seconds: 60),
      ]);

      final totals = await db.watchLifetimeTotals().first;
      // The plank counts as a set, but adds nothing to reps or volume.
      expect(totals.sets, 2);
      expect(totals.reps, 5);
      expect(totals.volumeKg, closeTo(500, 1e-9));
    });

    test('empty history is all zeros', () async {
      final totals = await db.watchLifetimeTotals().first;
      expect(totals.volumeKg, 0);
      expect(totals.reps, 0);
      expect(totals.sets, 0);
    });
  });

  // =========================================================================
  // Session history — every finished session, newest first.
  // =========================================================================

  group('Session history', () {
    late AppDatabase db;
    late dynamic container;

    setUp(() {
      db = memoryDb();
      container = containerFor(db);
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('lists every finished session, newest first', () async {
      await saveOne(db, name: 'Oldest', at: DateTime(2026, 1, 1));
      await saveOne(db, name: 'Newest', at: DateTime(2026, 1, 10));
      await saveOne(db, name: 'Middle', at: DateTime(2026, 1, 5));

      final history = await db.watchHistory().first;
      expect(history.map((s) => s.name).toList(),
          ['Newest', 'Middle', 'Oldest']);
    });

    test('the session count matches the finished sessions', () async {
      await saveOne(db, name: 'A', at: DateTime(2026, 1, 1));
      await saveOne(db, name: 'B', at: DateTime(2026, 1, 2));
      expect(await db.watchSessionCount().first, 2);
    });
  });

  // =========================================================================
  // Deleting a template never erases the history of having trained it.
  // =========================================================================

  group('Deleting templates preserves history', () {
    late AppDatabase db;
    late dynamic container;

    setUp(() {
      db = memoryDb();
      container = containerFor(db);
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('deleting the routine keeps its sessions, sets and lifetime totals',
        () async {
      final routines = await db.watchRoutines().first;
      final ppl = routines.first.routine;
      final workouts = await db.workoutsForRoutine(ppl.id);
      final push = workouts.first;

      final id = await saveOne(db,
          name: 'Push',
          at: DateTime(2026, 1, 1),
          routineId: ppl.id,
          workoutId: push.id,
          sets: [setRow('Bench Press', 1, weight: 100, reps: 5)]);

      await db.deleteRoutine(ppl.id);

      // The session, its sets and the totals all survive the template's death.
      final history = await db.watchHistory().first;
      expect(history.map((s) => s.id), contains(id));
      expect(await db.setsForSession(id), hasLength(1));
      expect((await db.watchLifetimeTotals().first).volumeKg, closeTo(500, 1e-9));
    });

    test('deleting just the workout keeps its sessions', () async {
      final routines = await db.watchRoutines().first;
      final ppl = routines.first.routine;
      final workouts = await db.workoutsForRoutine(ppl.id);
      final push = workouts.first;

      final id = await saveOne(db,
          name: 'Push',
          at: DateTime(2026, 1, 1),
          routineId: ppl.id,
          workoutId: push.id,
          sets: [setRow('Bench Press', 1, weight: 100, reps: 5)]);

      await db.deleteWorkout(push.id);

      final history = await db.watchHistory().first;
      expect(history.map((s) => s.id), contains(id));
      expect(await db.setsForSession(id), hasLength(1));
    });
  });

  // =========================================================================
  // The progression banner belongs to the session just finished.
  // =========================================================================

  group('Post-session progression report', () {
    late AppDatabase db;
    late dynamic container;

    setUp(() {
      db = memoryDb();
      container = containerFor(db);
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('finishing tags the report with that session id and reports its slots',
        () async {
      final push = (await pplWorkouts(db))['Push']!;
      final id = await finishClean(container, push, 'Push');

      final report = container.read(lastProgressionProvider);
      expect(report, isNotNull);
      expect(report!.sessionId, id);
      expect(report.outcomes.map((o) => o.name), contains('Bench Press'));
    });

    test('a starting a fresh session clears the previous report', () async {
      final workouts = await pplWorkouts(db);
      await finishClean(container, workouts['Push']!, 'Push');
      expect(container.read(lastProgressionProvider), isNotNull);

      // Beginning the next session clears the banner the last one left behind.
      await container
          .read(activeWorkoutProvider.notifier)
          .start(workoutId: workouts['Pull']!, name: 'Pull');
      expect(container.read(lastProgressionProvider), isNull);
      container.read(activeWorkoutProvider.notifier).discard();
    });

    test('bodyweight slots with no target are omitted from the report', () async {
      // A weight-progression slot carrying no suggested weight is a bodyweight
      // movement with nothing to move — build one alongside a real weighted lift.
      final exs = await db.watchExercises().first;
      int idOf(String n) => exs.firstWhere((e) => e.name == n).id;
      final rid =
          await db.createRoutine(name: 'T', color: 'FF0000', restSeconds: 90);
      final wid = await db.createWorkout(rid, 'Day');
      await db.replaceWorkoutItems(wid, [
        WorkoutItemsCompanion.insert(
          workoutId: wid,
          exerciseId: idOf('Bench Press'),
          progression: const Value(ProgressionMode.weight),
          suggestedWeight: const Value(80),
          targetSets: const Value(2),
          repsMin: const Value(5),
        ),
        WorkoutItemsCompanion.insert(
          workoutId: wid,
          exerciseId: idOf('Push-Up'),
          progression: const Value(ProgressionMode.weight),
          suggestedWeight: const Value(null), // bodyweight: no target to move
          targetSets: const Value(2),
          repsMin: const Value(10),
        ),
      ]);

      await finishClean(container, wid, 'T');

      final names =
          container.read(lastProgressionProvider)!.outcomes.map((o) => o.name);
      expect(names, isNot(contains('Push-Up'))); // omitted — no target
      expect(names, contains('Bench Press')); // a weighted slot is reported
    });
  });

  // =========================================================================
  // The recap screen (widget) — headline, tiles, progression, grouped sets;
  // and the read-only reopen from History.
  // =========================================================================

  group('Recap screen', () {
    late AppDatabase db;
    late dynamic container;

    setUp(() {
      db = memoryDb();
      container = containerFor(db);
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    testWidgets('a just-finished session shows the celebration recap', (tester) async {
      late int id;
      await tester.runAsync(() async {
        final push = (await pplWorkouts(db))['Push']!;
        id = await finishClean(container, push, 'Push');
      });

      await tester.pumpWidget(
          appUnder(container, SummaryScreen(sessionId: id)));
      await pumpUntil(tester, find.text('Workout logged'));

      // Headline + session name.
      expect(find.text('Workout logged'), findsOneWidget);
      expect(find.text('Push'), findsOneWidget);
      // Stat tiles.
      expect(find.text('DURATION'), findsOneWidget);
      expect(find.text('SETS DONE'), findsOneWidget);
      expect(find.text('EXERCISES'), findsOneWidget);
      // Progression section, populated from the finished session.
      expect(find.text('PROGRESSION'), findsOneWidget);
      // The end-of-session button heads home rather than popping.
      expect(find.text('Done'), findsOneWidget);

      // The logged-sets section sits below the fold; scroll it into view.
      await tester.scrollUntilVisible(find.text('SESSION'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('SESSION'), findsOneWidget);
      // Logged sets grouped by exercise.
      expect(find.text('Bench Press'), findsWidgets);

      await stop(tester);
    });

    testWidgets('reopened from History it is read-only: Back, no banner',
        (tester) async {
      late int id;
      await tester.runAsync(() async {
        final push = (await pplWorkouts(db))['Push']!;
        id = await finishClean(container, push, 'Push');
      });

      await tester.pumpWidget(appUnder(
          container, SummaryScreen(sessionId: id, fromHistory: true)));
      await pumpUntil(tester, find.text('Back'));

      // The plain header, the back button, and none of the celebration.
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Push'), findsOneWidget);
      expect(find.text('Workout logged'), findsNothing);
      // No progression banner when reopened from History — even though the
      // report is still stashed, fromHistory never reads it.
      expect(find.text('PROGRESSION'), findsNothing);

      await stop(tester);
    });

    testWidgets('the banner is read once: consuming it clears the stash',
        (tester) async {
      late int id;
      await tester.runAsync(() async {
        final push = (await pplWorkouts(db))['Push']!;
        id = await finishClean(container, push, 'Push');
      });
      expect(container.read(lastProgressionProvider), isNotNull);

      // Opening the just-finished recap shows the banner and consumes it.
      await tester
          .pumpWidget(appUnder(container, SummaryScreen(sessionId: id)));
      await pumpUntil(tester, find.text('PROGRESSION'));
      expect(find.text('PROGRESSION'), findsOneWidget);
      // The microtask clear runs on the following frames.
      await pumpUntil(
          tester, find.byType(SizedBox), tries: 3); // let microtasks flush
      expect(container.read(lastProgressionProvider), isNull);

      // Reopening the SAME session as a recap now finds nothing to show.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester
          .pumpWidget(appUnder(container, SummaryScreen(sessionId: id)));
      await pumpUntil(tester, find.text('Workout logged'));
      expect(find.text('PROGRESSION'), findsNothing);

      await stop(tester);
    });
  });
}
