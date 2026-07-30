// Integration tests for the part of feature 04 that talks to Android: the shade
// as an ordinary notification, and the rest ding handed over as an alarm. The
// entries are the "The notification shade" and "The rest sound" groups of
// features/index.html#sec04 — `ordinary-notification-no-service`,
// `android-counts-rest-down-itself`, `shade-stops-keeping-up-if-killed`,
// `asks-post-notifications-or-invisible`, `refusal-not-error`,
// `buttons-route-they-do-not-raise`, `ding-handed-android-advance` and
// `exact-alarm-for-rest-only`.
//
// This is the one file with the notification plugin's method channel mocked, so
// the rest alarm's scheduling mode is asserted here too rather than in a second
// file that would have to set the same platform up again. What crossed the
// channel is the assertion: it is the only place from which "ongoing", "the
// countdown is Android's" and "no exact alarm was asked for" are visible at all.
//
// ## The seam these tests assume
//
// `WorkoutShade` drops `flutter_foreground_task` and posts through
// `flutter_local_notifications`. Every argument is optional and defaults to the
// real thing, the shape `RestAlarm` and `ReminderService` already use:
//
// ```dart
// WorkoutShade({
//   FlutterLocalNotificationsPlugin? plugin,    // the real singleton
//   bool? platformSupported,                    // !kIsWeb && Platform.isAndroid
//   Future<bool> Function()? requestPermission, // the real POST_NOTIFICATIONS ask
// });
// bool get supported;
// bool get running;
// Future<void> show(WorkoutCue cue, {required String unit});
// Future<void> hide();
// ```
//
// * `show` posts **one** notification on a fixed id, on a silent LOW channel,
//   `ongoing`, not auto-cancelling, alerting once, carrying `shadeButtons(cue)`
//   as `AndroidNotificationAction`s — and, while a rest runs, a chronometer
//   counting down to the instant the rest ends.
// * `hide` cancels that id. There is no service to ask about, so it cancels
//   unconditionally.
// * There is no foreground service anywhere in it, and no `WorkoutShade.drainPoke`
//   — a press is written into `PendingShadeActions` and drained from there.
// * A tap on the notification *body* is an activity intent and does raise the
//   app, so `WorkoutShade` takes an `onTapped` as well and the app routes it to
//   the board. `services/notifications.dart` holds the plugin seam that reaches
//   it: `notificationTapped`, which is what the plugin calls, and
//   `launchedByLiveWorkoutTap`, for the tap that arrived before any of this Dart
//   was running.
//
// `RestAlarm.scheduleAt` keeps its signature and hands the alarm over with
// `AndroidScheduleMode.inexactAllowWhileIdle` only: the exact attempt and its
// fallback are both gone, because Play grants the exact-alarm permission to
// alarm clocks and calendars and not to a workout tracker.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/services/notification_ids.dart';
import 'package:foss_lift/services/notifications.dart';
import 'package:foss_lift/services/rest_alarm.dart';
import 'package:foss_lift/services/workout_shade.dart';
import 'package:foss_lift/state/workout_cue.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

/// The channel the notification plugin talks down. Mocked so a test can see
/// whether anything was *posted*, and with what — the difference between "asked
/// and refused" and "asked and drawn", and the only place the chronometer and
/// the button flags are visible.
const _plugin = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  ProviderContainer? container;

  /// Every call that reached the platform, arguments and all.
  late List<MethodCall> calls;

  /// The same calls by name, plus every permission ask, in the order they
  /// happened — so "asks before posting" is one assertion about order rather
  /// than two separate facts.
  late List<String> steps;

  List<MethodCall> callsTo(String method) =>
      calls.where((c) => c.method == method).toList();

  /// The `platformSpecifics` map of the last notification posted: the Android
  /// side of what the shade asked for.
  Map<Object?, Object?> lastPosted() =>
      (callsTo('show').last.arguments as Map)['platformSpecifics'] as Map;

  setUp(() {
    db = memoryDb();
    calls = [];
    steps = [];
    // The plugin picks its implementation off the target platform, and the
    // runner is not a phone. Both halves are needed: the override chooses the
    // Android code path, `registerWith` gives it something to run.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_plugin, (call) async {
          calls.add(call);
          steps.add(call.method);
          return switch (call.method) {
            'initialize' => true,
            'requestNotificationsPermission' => true,
            _ => null,
          };
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_plugin, null);
    debugDefaultTargetPlatformOverride = null;
    container?.dispose();
    container = null;
    await db.close();
  });

  /// A shade that believes it is on Android — the only platform with one — and
  /// whose permission dialog answers [granted].
  WorkoutShade shadeThatIsAnswered(bool granted) => WorkoutShade(
    plugin: FlutterLocalNotificationsPlugin(),
    platformSupported: true,
    requestPermission: () async {
      steps.add('ask');
      return granted;
    },
  );

  /// A live Push session, and the cue the shade would be asked to draw.
  Future<WorkoutCue> livePush() async {
    container = containerFor(db);
    final ctl = container!.read(activeWorkoutProvider.notifier);
    await ctl.start(workoutId: await workoutIdNamed(db, 'Push'), name: 'Push');
    final session = container!.read(activeWorkoutProvider)!;
    return nextUp(session, restLeft: session.restLeft)!;
  }

  /// Puts the running session into a rest, and returns the cue for it — what
  /// the shade draws while a countdown is going.
  WorkoutCue restingCue(int seconds) {
    final ctl = container!.read(activeWorkoutProvider.notifier);
    ctl.startRest(seconds, null);
    final session = container!.read(activeWorkoutProvider)!;
    return nextUp(session, restLeft: session.restLeft)!;
  }

  /// A session that is resting, in one step.
  Future<WorkoutCue> restingPush(int seconds) async {
    await livePush();
    return restingCue(seconds);
  }

  group('It asks to post notifications, or it is invisible', () {
    test('the ask comes before the notification, not after it', () async {
      // Declaring the permission in the manifest is not holding it: without the
      // grant the notification is posted, reports success and is drawn nowhere.
      final shade = shadeThatIsAnswered(true);

      await shade.show(await livePush(), unit: 'kg');

      expect(steps, contains('ask'));
      expect(steps, contains('show'));
      expect(
        steps.indexOf('ask'),
        lessThan(steps.indexOf('show')),
        reason: 'a notification posted before the grant is drawn nowhere',
      );
      expect(shade.running, isTrue);
    });

    test('a refusal posts nothing, and is not an error', () async {
      final shade = shadeThatIsAnswered(false);
      final cue = await livePush();

      await expectLater(shade.show(cue, unit: 'kg'), completes);

      expect(steps, contains('ask'));
      expect(
        callsTo('show'),
        isEmpty,
        reason: 'refused means no shade, not a notification drawn nowhere',
      );
      expect(shade.running, isFalse);
    });

    test('and the workout carries on exactly as before', () async {
      // Nothing interrupts the session to say the shade is missing: the app on
      // screen is unaffected.
      final shade = shadeThatIsAnswered(false);
      await shade.show(await livePush(), unit: 'kg');

      final ctl = container!.read(activeWorkoutProvider.notifier);
      ctl.cycleSet(0, 0);
      final session = container!.read(activeWorkoutProvider)!;
      expect(session.exercises[0].sets[0].logged, isNotNull);
      expect(session.doneSets, 1);
    });

    test('it asks once, not once a session', () async {
      // Android stops showing the dialog after a refusal anyway, and the switch
      // that turns it back on is the phone's, not the app's.
      final shade = shadeThatIsAnswered(false);
      final cue = await livePush();

      await shade.show(cue, unit: 'kg');
      await shade.hide();
      await shade.show(cue, unit: 'kg');
      await shade.show(cue, unit: 'kg');

      expect(
        steps.where((s) => s == 'ask').length,
        1,
        reason: 'the app asks once and does not badger',
      );
    });
  });

  group('It is an ordinary notification, with no foreground service', () {
    test('nothing starts a service, whatever the session is doing', () async {
      // Play will not have a foreground service without a declaration and a
      // demo video for the type, which is more than a rest timer is worth.
      final shade = shadeThatIsAnswered(true);

      await shade.show(await livePush(), unit: 'kg');
      await shade.show(restingCue(90), unit: 'kg');
      await shade.hide();

      expect(
        steps.where((s) => s.toLowerCase().contains('foregroundservice')),
        isEmpty,
        reason: 'the app claims no privilege to stay alive behind the shade',
      );
    });

    test('it is furniture: silent, LOW, ongoing and not swipe-away', () async {
      final shade = shadeThatIsAnswered(true);

      await shade.show(await livePush(), unit: 'kg');

      expect(lastPosted()['ongoing'], isTrue);
      expect(lastPosted()['autoCancel'], isFalse);
      expect(lastPosted()['silent'], isTrue);
      expect(lastPosted()['onlyAlertOnce'], isTrue);
      expect(
        lastPosted()['importance'],
        Importance.low.value,
        reason: 'a workout in progress is not an alert',
      );
    });

    test('and it says the set, in the unit on the phone', () async {
      final shade = shadeThatIsAnswered(true);
      final cue = await livePush();

      await shade.show(cue, unit: 'lb');

      final args = callsTo('show').last.arguments as Map;
      expect(args['title'], shadeTitle(cue));
      expect(args['body'], shadeText(cue, 'lb'));
    });

    test('one shade, not one per change of the session', () async {
      final shade = shadeThatIsAnswered(true);
      final cue = await livePush();

      await shade.show(cue, unit: 'kg');
      await shade.show(cue, unit: 'kg');

      final ids = callsTo(
        'show',
      ).map((c) => (c.arguments as Map)['id']).toSet();
      expect(
        ids,
        hasLength(1),
        reason: 'a second id would stack a second shade beside the first',
      );
    });

    test('finishing takes it down', () async {
      final shade = shadeThatIsAnswered(true);
      await shade.show(await livePush(), unit: 'kg');
      final posted = (callsTo('show').last.arguments as Map)['id'];

      await shade.hide();

      expect(
        callsTo('cancel').map((c) => (c.arguments as Map)['id']),
        contains(posted),
        reason: 'a shade left up outlives the session it describes',
      );
      expect(shade.running, isFalse);
    });

    test('a shade the app has no memory of is still taken down', () async {
      // `shade-stops-keeping-up-if-killed`: Android is free to reclaim the
      // isolate and leave the notification standing. The shade the next launch
      // builds never posted it, and there is no service left to ask — so it
      // cancels the id regardless, or a finished workout keeps a dead countdown
      // in the shade for good.
      final fresh = shadeThatIsAnswered(true);

      await fresh.hide();

      expect(callsTo('cancel'), hasLength(1));
      expect(steps, isNot(contains('ask')), reason: 'taking down asks nothing');
    });

    test('off Android it is a no-op, not a crash', () async {
      final shade = WorkoutShade(
        plugin: FlutterLocalNotificationsPlugin(),
        platformSupported: false,
        requestPermission: () async => true,
      );
      final cue = await livePush();

      await expectLater(shade.show(cue, unit: 'kg'), completes);
      await expectLater(shade.hide(), completes);

      expect(shade.supported, isFalse);
      expect(calls, isEmpty);
    });
  });

  group('Android counts the rest down, the app does not', () {
    test('a rest is posted as a chronometer running to its end', () async {
      final shade = shadeThatIsAnswered(true);
      final cue = await restingPush(90);
      final endsAt = DateTime.now().add(const Duration(seconds: 90));

      await shade.show(cue, unit: 'kg');

      expect(lastPosted()['usesChronometer'], isTrue);
      expect(lastPosted()['chronometerCountDown'], isTrue);
      expect(
        lastPosted()['showWhen'],
        isTrue,
        reason: 'the countdown lives where Android puts a timestamp',
      );
      expect(
        lastPosted()['when'],
        closeTo(endsAt.millisecondsSinceEpoch, 2000),
        reason: 'it counts down to the instant the rest ends',
      );
    });

    test('and the bold line carries no number of its own', () async {
      // A number in the title has to be rewritten every second by a process
      // Android is free to freeze, and a frozen countdown is worse than none.
      final shade = shadeThatIsAnswered(true);

      await shade.show(await restingPush(90), unit: 'kg');

      expect((callsTo('show').last.arguments as Map)['title'], 'Rest');
    });

    test('a set to do has no chronometer on it', () async {
      final shade = shadeThatIsAnswered(true);

      await shade.show(await livePush(), unit: 'kg');

      expect(lastPosted()['usesChronometer'], isFalse);
      expect(lastPosted()['showWhen'], isFalse);
    });

    test('and a press does not dismiss the shade', () async {
      // Every button is on a notification that has to survive being pressed:
      // −15s twice in a row is the ordinary case, and a shade that vanished on
      // the first press would take the rest's controls with it.
      final shade = shadeThatIsAnswered(true);

      await shade.show(await restingPush(90), unit: 'kg');

      final actions = (lastPosted()['actions'] as List).cast<Map>();
      expect(actions.map((a) => a['id']), [
        WorkoutShade.restSubAction,
        WorkoutShade.restAddAction,
        WorkoutShade.restSkipAction,
      ]);
      expect(actions.map((a) => a['cancelNotification']), everyElement(isFalse));
      expect(
        actions.map((a) => a['showsUserInterface']),
        everyElement(isFalse),
        reason: 'a button is a broadcast; it may not start an activity',
      );
    });
  });

  group('Tapping the shade itself raises the app at the board', () {
    // `buttons-route-they-do-not-raise`: the buttons cannot raise the phone, but
    // the notification body can, because that one is an activity intent. Where it
    // raises the app *to* is this app's decision, and the board is the only
    // sensible answer for a notification whose whole subject is the live session.

    test('a tap on the body opens the board', () async {
      var opened = 0;
      final shade = WorkoutShade(
        plugin: FlutterLocalNotificationsPlugin(),
        platformSupported: true,
        requestPermission: () async => true,
        onTapped: () => opened++,
      );

      await shade.show(await livePush(), unit: 'kg');
      notificationTapped(
        const NotificationResponse(
          id: kLiveWorkoutId,
          notificationResponseType: NotificationResponseType.selectedNotification,
        ),
      );

      expect(opened, 1);
    });

    test('a button press is not a tap, and does not open it twice', () async {
      // The presses have their own path — the record — and it is the one that
      // decides whether the board is raised. A press arriving here as well would
      // route the app on a −15s.
      var opened = 0;
      final shade = WorkoutShade(
        plugin: FlutterLocalNotificationsPlugin(),
        platformSupported: true,
        requestPermission: () async => true,
        onTapped: () => opened++,
      );

      await shade.show(await livePush(), unit: 'kg');
      notificationTapped(
        const NotificationResponse(
          id: kLiveWorkoutId,
          actionId: WorkoutShade.restSkipAction,
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
        ),
      );

      expect(opened, 0);
    });

    test('and neither is a tap on some other notification', () async {
      // The rest ding is the other one this app posts, and tapping it means "I
      // have read this", not "take me to the board".
      var opened = 0;
      final shade = WorkoutShade(
        plugin: FlutterLocalNotificationsPlugin(),
        platformSupported: true,
        requestPermission: () async => true,
        onTapped: () => opened++,
      );

      await shade.show(await livePush(), unit: 'kg');
      notificationTapped(
        const NotificationResponse(
          id: kRestAlarmId,
          notificationResponseType: NotificationResponseType.selectedNotification,
        ),
      );

      expect(opened, 0);
    });

    test('a tap that started the app cold is answered too', () async {
      // A tap on a shade left behind by a killed app launches the app, and the
      // callback above is registered far too late to hear about it — the intent
      // was delivered before any of this Dart ran. So the launch goes and asks.
      calls.clear();

      expect(
        await launchedByLiveWorkoutTap(FlutterLocalNotificationsPlugin()),
        isFalse,
        reason: 'nothing launched this test runner',
      );
      expect(callsTo('getNotificationAppLaunchDetails'), hasLength(1));
    });
  });

  group('The scheduled rest ding asks for no alarm privilege', () {
    // `exact-alarm-for-rest-only`: Play grants USE_EXACT_ALARM to alarm clocks
    // and calendars, and SCHEDULE_EXACT_ALARM costs a trip to a system settings
    // toggle on Android 14+. So the ding handed over in advance is inexact, and
    // an app that is still alive at the end of the rest rings on the second
    // instead.
    RestAlarm alarm() => RestAlarm(
      plugin: FlutterLocalNotificationsPlugin(),
      platformSupported: true,
    );

    test('it is handed over inexactly, and taken', () async {
      final laid = await alarm().scheduleAt(
        DateTime.now().add(const Duration(seconds: 90)),
        title: 'Rest done',
        body: 'Bench Press · 80 kg × 8',
      );

      expect(laid, isTrue);
      final scheduled = callsTo('zonedSchedule');
      expect(scheduled, hasLength(1));
      final specifics =
          (scheduled.single.arguments as Map)['platformSpecifics'] as Map;
      expect(
        specifics['scheduleMode'],
        AndroidScheduleMode.inexactAllowWhileIdle.name,
        reason: 'an exact alarm is a permission this app will not ship',
      );
    });

    test('and nothing ever asks for the exact-alarm permission', () async {
      final a = alarm();
      await a.scheduleAt(
        DateTime.now().add(const Duration(seconds: 90)),
        title: 'Rest done',
        body: 'Bench Press · 80 kg × 8',
      );
      await a.ring(title: 'Rest done', body: 'Bench Press · 80 kg × 8');
      await a.clear();

      expect(steps, isNot(contains('requestExactAlarmsPermission')));
    });

    test('ringing cancels the pending one first, so there is one ding', () async {
      // The two share an id, which is what makes "the live app rings first"
      // safe: the ring replaces the alarm rather than arriving beside it.
      final a = alarm();
      await a.scheduleAt(
        DateTime.now().add(const Duration(seconds: 90)),
        title: 'Rest done',
        body: 'Bench Press · 80 kg × 8',
      );
      steps.clear();

      await a.ring(title: 'Rest done', body: 'Bench Press · 80 kg × 8');

      expect(steps.indexOf('cancel'), lessThan(steps.indexOf('show')));
      final cancelled = (callsTo('cancel').last.arguments as Map)['id'];
      final shown = (callsTo('show').last.arguments as Map)['id'];
      expect(
        cancelled,
        shown,
        reason: 'one id for the rest, so the ding replaces the alarm',
      );
    });
  });
}
