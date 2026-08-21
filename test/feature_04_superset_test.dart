// Integration tests for supersets in the live session (features/index.html#sec04): round-robin progression, rest timing, warm-ups, rendering, and restoration.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/data/warmup.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/services/workout_shade.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/state/workout_cue.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

/// One slot of a day built for these tests: which movement, how many sets, what
/// it is loaded to, its rest override, and whether it is joined to the slot
/// above it as a superset.
typedef Slot = ({
  String exercise,
  int sets,
  double? weightKg,
  int? restSeconds,
  bool joined,
});

Slot slot(
  String exercise, {
  int sets = 3,
  double? weightKg,
  int? restSeconds,
  bool joined = false,
}) => (
  exercise: exercise,
  sets: sets,
  weightKg: weightKg,
  restSeconds: restSeconds,
  joined: joined,
);

/// A one-day routine holding [slots], in order, and returns the workout id.
///
/// Built through the template editor's own drafts and `replaceWorkoutItems`, so
/// the join reaches the database by the route the builder uses rather than by a
/// hand-written companion. A slot with no [Slot.weightKg] carries no load and so
/// gets no warm-up ramp, which keeps a test about round order to the working
/// sets it is actually about.
Future<int> buildSupersetDay(
  AppDatabase db,
  List<Slot> slots, {
  int routineRest = 120,
  String routine = 'Supersets',
  String day = 'Superset Day',
}) async {
  final rid = await db.createRoutine(
    name: routine,
    color: 'FF0000',
    restSeconds: routineRest,
  );
  final wid = await db.createWorkout(rid, day);
  final drafts = <ItemDraft>[];
  for (final s in slots) {
    drafts.add(
      ItemDraft.forExercise(await exerciseNamed(db, s.exercise))
        ..sets = s.sets
        ..repsMin = 5
        ..weightKg = s.weightKg
        ..restSeconds = s.restSeconds
        ..supersetWithPrevious = s.joined,
    );
  }
  await db.replaceWorkoutItems(wid, itemCompanions(drafts, workoutId: wid));
  return wid;
}

/// Bench and Overhead Press joined, three sets each and nothing on the bar —
/// the plainest group there is, and the one with no warm-up ramps in the way.
List<Slot> pair() => [
      slot('Bench Press'),
      slot('Overhead Press', joined: true),
    ];

void main() {
  late AppDatabase db;
  ProviderContainer? container;

  setUp(() => db = memoryDb());
  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  ActiveWorkout session() => container!.read(activeWorkoutProvider)!;

  /// Starts a live session on a day made of [slots], under a plain `test()`.
  Future<ActiveWorkoutController> startDay(
    List<Slot> slots, {
    int routineRest = 120,
    bool mirrorSession = false,
  }) async {
    final wid = await buildSupersetDay(db, slots, routineRest: routineRest);
    container = containerFor(db, mirrorSession: mirrorSession);
    final ctl = container!.read(activeWorkoutProvider.notifier);
    await ctl.start(workoutId: wid, name: 'Superset Day');
    return ctl;
  }

  /// Where the session says you are: the exercise and set the mark is on, and
  /// whether it is a warm-up rung.
  ({int exercise, int set, bool warmup}) at() {
    final cue = nextUp(session())!;
    return (
      exercise: cue.exerciseIndex,
      set: cue.setIndex,
      warmup: cue.warmup,
    );
  }

  /// Walks the session by always doing what the mark names, [steps] times, and
  /// returns the rows it was sent to in order.
  ///
  /// The rest is dropped after each one: a rest running would make the cue say
  /// "resting", and what is under test here is the order of the sets rather than
  /// the clock between them.
  List<({int exercise, int set, bool warmup})> walk(
    ActiveWorkoutController ctl,
    int steps,
  ) {
    final path = <({int exercise, int set, bool warmup})>[];
    for (var i = 0; i < steps; i++) {
      final now = at();
      path.add(now);
      if (now.warmup) {
        ctl.cycleWarmup(now.exercise, now.set);
      } else {
        ctl.cycleSet(now.exercise, now.set);
      }
      ctl.stopRest(tone: false);
    }
    return path;
  }

  /// The reps cell of one board row — the tap target that logs the set.
  Finder repsCell(String row) => find.descendant(
        of: find.byKey(ValueKey(row)),
        matching: find.byKey(const ValueKey('set-result')),
      );

  /// The mark, inside one named row.
  Finder markOn(String row) => find.descendant(
        of: find.byKey(ValueKey(row)),
        matching: find.byKey(kNextSetKey),
      );

  /// Scrolls [cell] into view and taps it — the board is taller than the test
  /// viewport as soon as a ramp is drawn open.
  Future<void> tapCell(WidgetTester tester, Finder cell) async {
    await tester.ensureVisible(cell);
    await tester.pump();
    await tester.tap(cell);
  }

  /// Starts a session on [slots] and mounts the board over it.
  Future<void> pumpDay(
    WidgetTester tester,
    List<Slot> slots, {
    int routineRest = 120,
    List<Override> overrides = const [],
  }) async {
    await tester.runAsync(() async {
      final wid = await buildSupersetDay(db, slots, routineRest: routineRest);
      container = containerFor(db, overrides: overrides);
      await container!
          .read(activeWorkoutProvider.notifier)
          .start(workoutId: wid, name: 'Superset Day');
    });
    await tester.pumpWidget(appUnder(container!, const WorkoutScreen()));
    await tester.pump();
  }

  /// Puts the session down, then the tree — the rest clock belongs to the
  /// session and outlives the screen.
  Future<void> stopAll(WidgetTester tester) async {
    container?.read(activeWorkoutProvider.notifier).discard();
    await stop(tester);
  }

  group('The mark walks a superset a round at a time', () {
    test('two joined movements are walked a set of each at a time', () async {
      final ctl = await startDay(pair());

      expect(session().supersetJoins, [false, true]);
      expect(session().supersetGroupOf(0), [0, 1]);
      expect(session().supersetGroupOf(1), [0, 1]);

      expect(
        walk(ctl, 6).map((s) => (s.exercise, s.set)),
        [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2), (1, 2)],
      );
    });

    test('three joined movements round through all three first', () async {
      final ctl = await startDay([
        slot('Bench Press', sets: 2),
        slot('Overhead Press', sets: 2, joined: true),
        slot('Incline DB Press', sets: 2, joined: true),
      ]);

      expect(session().supersetGroupOf(2), [0, 1, 2]);
      expect(
        walk(ctl, 6).map((s) => (s.exercise, s.set)),
        [(0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (2, 1)],
      );
    });

    test('a movement with fewer sets drops out of the later rounds', () async {
      final ctl = await startDay([
        slot('Bench Press', sets: 3),
        slot('Overhead Press', sets: 2, joined: true),
      ]);

      expect(
        walk(ctl, 5).map((s) => (s.exercise, s.set)),
        [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2)],
        reason: 'the shorter movement holds the last round up',
      );
    });

    test('an exercise outside the group is still walked on its own', () async {
      // The group is a way of performing two slots, not a change to the third.
      final ctl = await startDay([
        slot('Bench Press', sets: 2),
        slot('Overhead Press', sets: 2, joined: true),
        slot('Triceps Pushdown', sets: 2),
      ]);

      expect(session().supersetGroupOf(2), [2]);
      expect(
        walk(ctl, 6).map((s) => (s.exercise, s.set)),
        [(0, 0), (1, 0), (0, 1), (1, 1), (2, 0), (2, 1)],
      );
    });

    testWidgets('the row marked after the first movement is in the second',
        (tester) async {
      await pumpDay(tester, pair());

      expect(markOn('0-0-Bench Press'), findsOneWidget);

      await tapCell(tester, repsCell('0-0-Bench Press'));
      await tester.pump();

      expect(markOn('1-0-Overhead Press'), findsOneWidget);
      expect(find.byKey(kNextSetKey), findsOneWidget,
          reason: 'exactly one thing on the board is ever marked');

      // And the round done, the mark is back at the top of the group.
      await tapCell(tester, repsCell('1-0-Overhead Press'));
      await tester.pump();

      expect(markOn('0-1-Bench Press'), findsOneWidget);

      await stopAll(tester);
    });
  });

  group('There is no rest inside a superset', () {
    testWidgets('logging a movement mid-round starts no clock at all',
        (tester) async {
      // Bench rests two minutes, Overhead one — so which rest the round gets is
      // an answer, not a coincidence.
      await pumpDay(tester, [
        slot('Bench Press', restSeconds: 120),
        slot('Overhead Press', restSeconds: 60, joined: true),
      ]);

      await tapCell(tester, repsCell('0-0-Bench Press'));
      await tester.pump();

      expect(session().restLeft, 0,
          reason: 'the next movement is what you do now');
      expect(find.byKey(kRestBannerKey), findsNothing);

      // The set that ends the round starts the rest, and it is that slot's.
      await tapCell(tester, repsCell('1-0-Overhead Press'));
      await tester.pump();

      expect(find.byKey(kRestBannerKey), findsOneWidget);
      expect(session().restLeft, 60);
      expect(find.text('1:00'), findsOneWidget);

      await stopAll(tester);
    });

    test('the rest that follows a row is nothing until the round closes',
        () async {
      await startDay([
        slot('Bench Press', restSeconds: 120),
        slot('Overhead Press', restSeconds: 60, joined: true),
      ]);

      final inside = session().restAfter(0, 0, warmup: false);
      expect(inside.seconds, 0);
      expect(inside.prompt, isNull,
          reason: 'a rest that does not start has nothing to say');

      final closing = session().restAfter(1, 0, warmup: false);
      expect(closing.seconds, 60,
          reason: 'the rest of the slot whose set ended the round');
      expect(closing.prompt, isNotNull);
    });

    test('an exercise on its own still rests after every set', () async {
      await startDay([slot('Triceps Pushdown', restSeconds: 90)]);

      expect(session().restAfter(0, 0, warmup: false).seconds, 90);
    });
  });

  group('The rest at the end of a round says what opens the next one', () {
    testWidgets('it names the movement back at the top of the group',
        (tester) async {
      await pumpDay(tester, pair());
      final l10n = l10nFor();

      await tapCell(tester, repsCell('0-0-Bench Press'));
      await tester.pump();
      await tapCell(tester, repsCell('1-0-Overhead Press'));
      await tester.pump();

      expect(
        find.text(l10n.sessionRestNextExercise('Bench Press')),
        findsOneWidget,
        reason: 'the next round opens on the movement at the top of the group',
      );

      await stopAll(tester);
    });

    testWidgets('and on a movement still in the round when one has run out',
        (tester) async {
      // Bench has three sets to Overhead's two, so the third round is Bench
      // alone and the rest before it says so.
      await pumpDay(tester, [
        slot('Bench Press', sets: 3),
        slot('Overhead Press', sets: 2, joined: true),
      ]);
      final l10n = l10nFor();

      for (final row in [
        '0-0-Bench Press',
        '1-0-Overhead Press',
        '0-1-Bench Press',
        '1-1-Overhead Press',
      ]) {
        await tapCell(tester, repsCell(row));
        await tester.pump();
      }

      expect(
        find.text(l10n.sessionRestNextExercise('Bench Press')),
        findsOneWidget,
      );

      await stopAll(tester);
    });
  });

  group('A superset warms up every movement before the first round', () {
    // Both members loaded, so both carry a ramp.
    final ramped = [
      slot('Bench Press', sets: 2, weightKg: 80),
      slot('Overhead Press', sets: 2, weightKg: 50, joined: true),
    ];

    test('the group\'s ramps are walked in order before any working set',
        () async {
      final ctl = await startDay(ramped);
      final rungs = session().exercises[0].warmups.length;
      expect(rungs, greaterThan(1), reason: 'the premise: there is a ramp');
      expect(session().exercises[1].warmups, hasLength(rungs));

      final path = walk(ctl, rungs * 2 + 2);

      expect(
        path.take(rungs * 2).map((s) => (s.exercise, s.warmup)),
        [
          for (var ei = 0; ei < 2; ei++)
            for (var i = 0; i < rungs; i++) (ei, true),
        ],
        reason: 'you set both movements up, then work them back to back',
      );
      expect(
        path.skip(rungs * 2).map((s) => (s.exercise, s.set, s.warmup)),
        [(0, 0, false), (1, 0, false)],
        reason: 'the first round opens once every ramp is behind you',
      );
    });

    test('rest between rungs stays the short one across the join', () async {
      await startDay(ramped);
      final last = session().exercises[0].warmups.length - 1;

      for (var wi = 0; wi < last; wi++) {
        expect(session().restAfter(0, wi, warmup: true).seconds,
            kWarmupRestSeconds);
      }
      expect(
        session().restAfter(0, last, warmup: true).seconds,
        kWarmupRestSeconds,
        reason: 'the next thing is the first rung of the movement below',
      );
      // After the last rung of the last member the working sets are next, and
      // that earns the exercise's own rest.
      expect(
        session().restAfter(1, last, warmup: true).seconds,
        session().exercises[1].restSeconds,
      );
    });

    test('a member whose sets are all logged drops out of the ramps too',
        () async {
      // `every-working-set-logged-finishes-the-exercise`, one member at a time:
      // the group's ramp walk passes a finished movement by, exactly as its
      // rounds do.
      final ctl = await startDay(ramped);
      for (var si = 0; si < session().exercises[0].sets.length; si++) {
        ctl.cycleSet(0, si);
      }
      ctl.stopRest(tone: false);
      expect(session().exercises[0].warmups.any((w) => w.done), isFalse,
          reason: 'the premise: Bench was worked without its ramp');

      final cue = nextUp(session())!;
      expect(cue.exerciseIndex, 1);
      expect(cue.warmup, isTrue,
          reason: "the group's ramps open the round, and only Overhead Press "
              'still owes one');

      // And a rung of the finished member ticked afterwards rests for nothing.
      for (var wi = 0; wi < session().exercises[0].warmups.length; wi++) {
        final rest = session().restAfter(0, wi, warmup: true);
        expect(rest.seconds, 0);
        expect(rest.prompt, isNull);
      }
    });
  });

  group('The board draws a superset as one block', () {
    final joinedThenSolo = [
      slot('Bench Press', sets: 2),
      slot('Overhead Press', sets: 2, joined: true),
      slot('Triceps Pushdown', sets: 2),
    ];

    testWidgets('one bracket, tagged, around exactly the group\'s movements',
        (tester) async {
      await pumpDay(tester, joinedThenSolo);
      final l10n = l10nFor();
      final bracket = find.byKey(const ValueKey('superset-group-0'));

      expect(bracket, findsOneWidget);
      expect(
        find.descendant(of: bracket, matching: find.text(l10n.commonSuperset)),
        findsOneWidget,
      );

      for (final row in ['0-0-Bench Press', '1-0-Overhead Press']) {
        expect(
          find.descendant(of: bracket, matching: find.byKey(ValueKey(row))),
          findsOneWidget,
          reason: '$row is a member of the group',
        );
      }
      expect(
        find.descendant(
          of: bracket,
          matching: find.byKey(const ValueKey('2-0-Triceps Pushdown')),
        ),
        findsNothing,
        reason: 'the third movement is not part of the group',
      );
      // Each row keeps its own heading: a group is a way of performing slots,
      // not a slot of its own.
      expect(find.text('Overhead Press'), findsWidgets);

      await stopAll(tester);
    });

    testWidgets('a solo exercise gets no bracket', (tester) async {
      await pumpDay(tester, joinedThenSolo);

      expect(find.byKey(const ValueKey('superset-group-2')), findsNothing);
      expect(find.byType(WorkoutScreen), findsOneWidget);

      await stopAll(tester);
    });

    testWidgets('and a day with nothing joined draws none at all',
        (tester) async {
      await pumpDay(tester, [
        slot('Bench Press', sets: 2),
        slot('Overhead Press', sets: 2),
      ]);

      expect(find.byKey(const ValueKey('superset-group-0')), findsNothing);
      expect(find.text(l10nFor().commonSuperset), findsNothing);

      await stopAll(tester);
    });
  });

  group('A session with a superset survives the app being killed', () {
    /// The session a fresh launch over the same database comes back to — the
    /// isolate that held the old one is gone, as after Android reclaims the app.
    Future<ActiveWorkout?> relaunch() async {
      // Every queued snapshot write has to have landed first.
      for (var i = 0; i < 50; i++) {
        if (await db.loadLiveSession() != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      container?.dispose();
      container = containerFor(
        db,
        mirrorSession: true,
        // The launch also drains any shade press that was waiting, which asks
        // the foreground-task plugin for its store — a platform this test has
        // no business waiting on. Nothing has been pressed; say so.
        overrides: [
          pendingShadeActionsProvider.overrideWithValue(
            PendingShadeActions(read: () async => null, write: (_) async {}),
          ),
        ],
      );
      await container!.read(liveSessionRestoreProvider.future);
      return container!.read(activeWorkoutProvider);
    }

    test('it comes back grouped, mid-round', () async {
      final ctl = await startDay(pair(), mirrorSession: true);
      ctl.cycleSet(0, 0); // the first movement of the first round
      ctl.stopRest(tone: false);

      final back = await relaunch();

      expect(back, isNotNull);
      expect(back!.supersetJoins, [false, true]);
      expect(back.supersetGroupOf(0), [0, 1]);
      expect(back.exercises[0].supersetWithPrevious, isFalse);
      expect(back.exercises[1].supersetWithPrevious, isTrue);
      // And the round carries on where it stopped rather than starting again.
      expect(at(), (exercise: 1, set: 0, warmup: false));
    });
  });
}
