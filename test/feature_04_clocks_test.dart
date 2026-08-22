// Integration tests for live-session clocks and browser tab keepalive (features/index.html#sec04 and #sec19).

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/services/rest_alarm.dart';
import 'package:foss_lift/services/rest_buzz.dart';
import 'package:foss_lift/services/rest_tone.dart';
import 'package:foss_lift/state/active_workout.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

/// A clock the test moves by hand.
class _FakeClock {
  DateTime _now = DateTime(2026, 3, 1, 9);

  DateTime call() => _now;

  /// Everything that happened while the app was not looking.
  void skip(Duration d) => _now = _now.add(d);
}

/// A [RestTone] that counts rather than plays.
///
/// The player it is handed throws from everything, so a tone that somehow got
/// past the override would be a failure rather than a silence.
class _CountingTone extends RestTone {
  _CountingTone() : super(player: _NoPlayer());
  int played = 0;
  @override
  Future<void> play() async => played++;
}

class _NoPlayer implements AudioPlayer {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('the tone reached the player while switched off');
}

/// Long enough for at least one real 1-second tick to land.
Future<void> oneTick() =>
    Future<void>.delayed(const Duration(milliseconds: 1200));

void main() {
  late AppDatabase db;
  late _FakeClock clock;
  late _CountingTone tone;
  ProviderContainer? container;

  setUp(() {
    db = memoryDb();
    clock = _FakeClock();
    tone = _CountingTone();
  });
  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  Future<ActiveWorkoutController> startPush({
    List<Override> extra = const [],
  }) async {
    container = containerFor(
      db,
      overrides: [
        clockProvider.overrideWithValue(clock.call),
        restToneProvider.overrideWithValue(tone),
        // The rest ending asks where the phone is and reaches for a notification
        // channel and a vibrator. None of the three exists under a plain `test()`,
        // and none is what this file is about — see feature_04_live_session_test
        // for the tests that are.
        appOnScreenProvider.overrideWithValue(() => true),
        restAlarmProvider.overrideWithValue(
          RestAlarm(platformSupported: false),
        ),
        restBuzzProvider.overrideWithValue(RestBuzz(platformSupported: false)),
        ...extra,
      ],
    );
    final ctl = container!.read(activeWorkoutProvider.notifier);
    await ctl.start(workoutId: await workoutIdNamed(db, 'Push'), name: 'Push');
    return ctl;
  }

  ActiveWorkout session() => container!.read(activeWorkoutProvider)!;

  group('a rest knows when it is due, not how often it was asked', () {
    test(
      'a rest whose time passed unwatched is over the moment it is',
      () async {
        final ctl = await startPush();
        ctl.startRest(90, null);
        expect(session().restLeft, 90);

        // Three minutes go by with the app getting no ticks at all — a tab
        // throttled to one a minute, or a laptop lid closed.
        clock.skip(const Duration(minutes: 3));
        await oneTick();

        expect(
          session().restLeft,
          0,
          reason:
              'the rest was due two minutes ago; it does not still have '
              'time on it because nobody was counting',
        );
      },
    );

    test('and it says so exactly once, however long the gap was', () async {
      final ctl = await startPush();
      ctl.startRest(90, null);
      expect(tone.played, 0);

      clock.skip(const Duration(minutes: 3));
      await oneTick();
      await oneTick();

      expect(
        tone.played,
        1,
        reason:
            'one rest ended, so one ding — not one per second nobody '
            'counted, and not a second one on the next tick',
      );
    });

    test('a rest still running after the gap keeps the right time', () async {
      final ctl = await startPush();
      ctl.startRest(180, null);

      clock.skip(const Duration(seconds: 60));
      await oneTick();

      // Not an exact equality: a real tick has landed on top of the skip, so
      // the true remainder is 120 less whatever that tick was worth.
      expect(session().restLeft, inInclusiveRange(117, 120));
      expect(tone.played, 0);
    });

    test('nudging a rest moves when it is due', () async {
      final ctl = await startPush();
      ctl.startRest(90, null);

      ctl.nudgeRest(60);
      expect(session().restLeft, 150);

      clock.skip(const Duration(seconds: 100));
      await oneTick();

      expect(
        session().restLeft,
        inInclusiveRange(47, 50),
        reason:
            'the extra minute has to survive the gap too — a nudge that '
            'only changed the displayed number would lose it',
      );
    });

    test('taking a rest to zero by hand still ends it', () async {
      final ctl = await startPush();
      ctl.startRest(20, null);

      ctl.nudgeRest(-30);

      expect(session().restLeft, 0);
      expect(tone.played, 1);
    });
  });

  group('the session clock is the time of day, not a count of ticks', () {
    test('elapsed follows real time across a gap', () async {
      await startPush();
      expect(session().elapsed, 0);

      clock.skip(const Duration(minutes: 20));
      await oneTick();

      expect(
        session().elapsed,
        inInclusiveRange(1200, 1202),
        reason: 'twenty minutes passed whether or not the app ran for them',
      );
    });

    test('what Finish writes down is that real length', () async {
      final ctl = await startPush();
      ctl.logNextAtGoal();

      clock.skip(const Duration(minutes: 42));
      await oneTick();
      final id = await ctl.finish();

      final saved = await (db.select(
        db.sessions,
      )..where((t) => t.id.equals(id!))).getSingle();
      expect(
        saved.durationSeconds,
        inInclusiveRange(2520, 2522),
        reason:
            'the history is what the workout actually took; a stalled '
            'counter would file it as minutes long',
      );
    });
  });

  group('a browser is asked not to slow the tab down', () {
    test('nothing holds the tab awake before a workout starts', () async {
      final keeper = _RecordingKeeper();
      container = containerFor(
        db,
        overrides: [
          clockProvider.overrideWithValue(clock.call),
          tabAwakeProvider.overrideWithValue(keeper),
        ],
      );
      container!.read(tabAwakeSyncProvider);
      expect(keeper.holding, isFalse);
    });

    test('a running workout holds it, and finishing lets go', () async {
      final keeper = _RecordingKeeper();
      final ctl = await startPush(
        extra: [tabAwakeProvider.overrideWithValue(keeper)],
      );
      container!.read(tabAwakeSyncProvider);
      expect(keeper.holding, isTrue);

      await ctl.finish();
      container!.read(tabAwakeSyncProvider);
      expect(
        keeper.holding,
        isFalse,
        reason: 'nothing is held between workouts',
      );
    });

    test('and so does throwing the workout away', () async {
      final keeper = _RecordingKeeper();
      final ctl = await startPush(
        extra: [tabAwakeProvider.overrideWithValue(keeper)],
      );
      container!.read(tabAwakeSyncProvider);
      expect(keeper.holding, isTrue);

      await ctl.discard();
      container!.read(tabAwakeSyncProvider);
      expect(keeper.holding, isFalse);
    });

    test('a phone holds nothing — there is nothing to hold it against', () {
      // The keepalive is a browser workaround. On a phone the foreground
      // service already keeps the isolate running, and a silent tone would be
      // a speaker icon and a wake lock bought for nothing.
      expect(TabAwake.supported, isFalse);
    });
  });
}

/// A [TabAwake] that records rather than making a sound.
///
/// The real one on this platform is a no-op — there is no tab — so the
/// lifecycle has to be observed through a stand-in. What is being asserted is
/// that the app asks at the right moments, which is the part that is the same
/// on every platform.
class _RecordingKeeper extends TabAwake {
  bool holding = false;

  @override
  bool get held => holding;

  @override
  void hold() => holding = true;

  @override
  void release() => holding = false;
}
