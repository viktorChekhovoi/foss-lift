// Integration tests for the finished-rest state in the live session (features/index.html#sec04).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/state/active_workout.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

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

  /// The reps cell of one board row — the target that logs the set.
  Finder repsCell(String row) => find.descendant(
        of: find.byKey(ValueKey(row)),
        matching: find.byKey(const ValueKey('set-result')),
      );

  /// Scrolls [cell] into view and taps it: the board is taller than the test
  /// viewport once every ramp is drawn.
  Future<void> tapCell(WidgetTester tester, Finder cell) async {
    await tester.ensureVisible(cell);
    await tester.pump();
    await tester.tap(cell);
  }

  /// The sentence the bar is showing, whatever it is — its first line, above
  /// the clock and the controls.
  ///
  /// Read rather than matched against a literal: what the finished bar says is
  /// the catalogue's business, and these tests are about *whether* it says
  /// something and *when* it stops.
  String bannerLine(WidgetTester tester) => tester
      .widgetList<Text>(find.descendant(
        of: find.byKey(kRestBannerKey),
        matching: find.byType(Text),
      ))
      .first
      .data!;

  /// Puts the session down, then the tree — the rest clock belongs to the
  /// session, so unmounting the screen does not stop it.
  Future<void> stopAll(WidgetTester tester) async {
    container?.read(activeWorkoutProvider.notifier).discard();
    await stop(tester);
  }

  /// Ticks off every rung of exercise [ei]'s ramp and clears the rest that
  /// leaves running, so the next thing owed is a working set.
  void clearRamp(ActiveWorkoutController ctl, [int ei = 0]) {
    for (var wi = 0; wi < session().exercises[ei].warmups.length; wi++) {
      ctl.cycleWarmup(ei, wi);
    }
    ctl.stopRest(tone: false);
  }

  /// The seeded Push day, mounted and ready to tap, with Bench's ramp already
  /// behind you: the set after the one logged below is then the next *working*
  /// set rather than a rung.
  Future<void> pumpPushScreen(WidgetTester tester) async {
    await tester.runAsync(() async {
      final wid = await workoutIdNamed(db, 'Push');
      container = containerFor(db);
      await container!
          .read(activeWorkoutProvider.notifier)
          .start(workoutId: wid, name: 'Push');
    });
    clearRamp(container!.read(activeWorkoutProvider.notifier));
    await tester.pumpWidget(appUnder(container!, const WorkoutScreen()));
    await tester.pump();
  }

  /// Logs Bench's first working set and returns the line the running rest
  /// shows, with the bar up and counting.
  Future<String> restOnBench(WidgetTester tester) async {
    await tapCell(tester, repsCell('0-0-Bench Press'));
    await tester.pump();
    expect(find.byKey(kRestBannerKey), findsOneWidget);
    return bannerLine(tester);
  }

  /// Asserts the bar is in the state a finished rest leaves: still there, no
  /// longer counting, and naming the set it was leading to.
  void expectFinishedBanner(WidgetTester tester, String whileResting) {
    expect(
      find.byKey(kRestBannerKey),
      findsOneWidget,
      reason: 'a bar that vanishes at zero answers "did it go off?" by '
          'removing the evidence',
    );
    expect(session().restLeft, 0, reason: 'the rest is over');
    final line = bannerLine(tester);
    expect(
      line,
      isNot(whileResting),
      reason: 'the bar stops saying "rest" and starts saying what is up',
    );
    expect(
      line,
      contains('Bench Press'),
      reason: 'it names what the rest was for all along',
    );
  }

  group('A rest that has ended says the next set is up, and waits', () {
    testWidgets('the bar stays at zero, naming what comes next',
        (tester) async {
      await pumpPushScreen(tester);
      final resting = await restOnBench(tester);

      // The 120s rest, run out.
      await tester.pump(const Duration(seconds: 121));
      expectFinishedBanner(tester, resting);

      // And it waits: nothing dismisses it on its own.
      await tester.pump(const Duration(seconds: 30));
      expect(find.byKey(kRestBannerKey), findsOneWidget);

      await stopAll(tester);
    });

    testWidgets('Skip lands in the same place', (tester) async {
      await pumpPushScreen(tester);
      final resting = await restOnBench(tester);

      await tester.tap(find.text('Skip'));
      await tester.pump();

      expectFinishedBanner(tester, resting);
      await stopAll(tester);
    });

    testWidgets('and so does −15s taking the last seconds off', (tester) async {
      await pumpPushScreen(tester);
      final resting = await restOnBench(tester);

      // Down to single figures, where the button's only honest reading is
      // "skip" — and skipping is the same finished state.
      await tester.pump(const Duration(seconds: 112));
      expect(find.text('0:08'), findsOneWidget);
      await tester.tap(find.text('−15s'));
      await tester.pump();

      expectFinishedBanner(tester, resting);
      await stopAll(tester);
    });

    testWidgets('a fresh rest replaces it rather than stacking on it',
        (tester) async {
      await pumpPushScreen(tester);
      final resting = await restOnBench(tester);
      await tester.pump(const Duration(seconds: 121));
      expectFinishedBanner(tester, resting);

      // The set the finished bar was leading to.
      await tapCell(tester, repsCell('0-1-Bench Press'));
      await tester.pump();

      expect(
        find.byKey(kRestBannerKey),
        findsOneWidget,
        reason: 'a bar may say one thing at a time',
      );
      expect(find.text('2:00'), findsOneWidget,
          reason: 'the new rest is running');
      await stopAll(tester);
    });

    testWidgets('logging the set it was leading to takes the finished line '
        'away', (tester) async {
      await pumpPushScreen(tester);
      final resting = await restOnBench(tester);
      await tester.pump(const Duration(seconds: 121));
      expectFinishedBanner(tester, resting);
      final finished = bannerLine(tester);

      await tapCell(tester, repsCell('0-1-Bench Press'));
      await tester.pump();

      expect(
        bannerLine(tester),
        isNot(finished),
        reason: 'the set it was waiting on has been logged',
      );
      expect(bannerLine(tester), resting,
          reason: 'what is on screen is an ordinary running rest again');
      await stopAll(tester);
    });

    testWidgets('un-logging that set clears it outright', (tester) async {
      await pumpPushScreen(tester);
      final resting = await restOnBench(tester);
      await tester.pump(const Duration(seconds: 121));
      expectFinishedBanner(tester, resting);

      // The set that started the rest, taken back to untouched: the rest it
      // left behind is a rest for a set that no longer happened.
      final cell = repsCell('0-0-Bench Press');
      await tester.ensureVisible(cell);
      await tester.pump();
      for (var i = 0; i < 60 && session().exercises[0].sets[0].done; i++) {
        await tester.tap(cell);
        await tester.pump();
      }
      expect(session().exercises[0].sets[0].done, isFalse);

      expect(find.byKey(kRestBannerKey), findsNothing);
      await stopAll(tester);
    });
  });
}
