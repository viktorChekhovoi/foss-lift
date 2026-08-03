// Integration tests for how the end of a rest reaches you off screen — the "The
// rest sound" group of features/index.html#sec04, and
// `ding-posted-when-rest-ends` and `no-alarm-privilege-asked-for` in particular.
//
// This is the one file with the notification plugin's method channel mocked, so
// what crossed the channel is the assertion. It is the only place from which
// "nothing was scheduled" and "no alarm permission was ever asked for" are
// visible at all: everywhere else the alarm is a recording double, which can say
// that a ding happened but not what was asked of the platform.
//
// The behaviour these describe is a trade. Play grants `USE_EXACT_ALARM` to
// alarm clocks and calendars and not to a workout tracker, so there is no exact
// alarm to hand the end of a rest to — and an inexact one would arrive late,
// which for a rest timer is its own kind of broken. So nothing is scheduled at
// all: the app rings at the moment its own countdown reaches zero, and what
// keeps it alive to do that is the live session's foreground service. See
// `feature_04_session_continuity_test.dart` for the half that drives a real rest
// to its end.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/services/notifications.dart';
import 'package:foss_lift/services/rest_alarm.dart';

import 'support/harness.dart';

/// The channel the notification plugin talks down.
const _plugin = MethodChannel('dexterous.com/flutter/local_notifications');

/// The channel labels the live session hands over, read from the catalogue
/// rather than typed out again — the alarm holds no words of its own.
final NotificationChannelCopy _channel = (
  name: l10nFor().restAlarmChannelName,
  description: l10nFor().restAlarmChannelDescription,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every call that reached the platform, arguments and all.
  late List<MethodCall> calls;

  /// The same calls by name, in the order they happened.
  late List<String> steps;

  List<MethodCall> callsTo(String method) =>
      calls.where((c) => c.method == method).toList();

  setUp(() {
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
          return call.method == 'initialize' ? true : null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_plugin, null);
    debugDefaultTargetPlatformOverride = null;
  });

  RestAlarm alarm() => RestAlarm(
    plugin: FlutterLocalNotificationsPlugin(),
    platformSupported: true,
  );

  group('The ding is posted when the rest ends, and never scheduled', () {
    test('ringing posts it now', () async {
      await alarm().ring(
          channel: _channel,
          title: 'Rest done',
          body: 'Bench Press · 80 kg × 8');

      final shown = callsTo('show');
      expect(shown, hasLength(1));
      final args = shown.single.arguments as Map;
      expect(args['title'], 'Rest done');
      expect(
        args['body'],
        contains('Bench Press'),
        reason: '"rest done" alone makes you open the app to find out what for',
      );
    });

    test('and nothing is ever handed to Android in advance', () async {
      // The scheduled ding is gone with the exact-alarm permission it would have
      // needed to be worth having. What replaces it is the foreground service
      // keeping the session alive to ring for itself.
      final a = alarm();
      await a.ring(
          channel: _channel,
          title: 'Rest done',
          body: 'Bench Press · 80 kg × 8');
      await a.clear();

      expect(callsTo('zonedSchedule'), isEmpty);
      expect(callsTo('periodicallyShow'), isEmpty);
    });

    test('and no alarm permission is ever asked for', () async {
      final a = alarm();
      await a.ring(
          channel: _channel,
          title: 'Rest done',
          body: 'Bench Press · 80 kg × 8');
      await a.clear();

      expect(steps, isNot(contains('requestExactAlarmsPermission')));
    });

    test('a second ding replaces the first rather than stacking', () async {
      // One id for the rest, so two rests ending close together cannot leave two
      // notifications to swipe away.
      final a = alarm();
      await a.ring(
          channel: _channel,
          title: 'Rest done',
          body: 'Bench Press · 80 kg × 8');
      steps.clear();

      await a.ring(
          channel: _channel,
          title: 'Rest done',
          body: 'Overhead Press · 50 kg × 8');

      expect(steps.indexOf('cancel'), lessThan(steps.indexOf('show')));
      final cancelled = (callsTo('cancel').last.arguments as Map)['id'];
      final shown = (callsTo('show').last.arguments as Map)['id'];
      expect(cancelled, shown);
    });

    test('clearing takes it down', () async {
      await alarm().clear();

      expect(callsTo('cancel'), hasLength(1));
    });

    test('off Android it is a no-op, not a crash', () async {
      final off = RestAlarm(
        plugin: FlutterLocalNotificationsPlugin(),
        platformSupported: false,
      );

      await expectLater(
          off.ring(
              channel: _channel,
              title: 'Rest done',
              body: 'x'),
          completes);
      await expectLater(off.clear(), completes);

      expect(calls, isEmpty);
    });
  });

  group('Off screen the sound is joined by a notification, not replaced by one',
      () {
    // `off-screen-ding-notification-instead`. The tone has already been made by
    // the app itself, so a channel that rang as well would be two dings for one
    // rest. What is left for the notification is the picture: high importance,
    // a buzz, and the words for what is next.

    /// The arguments of the channel created with [id].
    Map channelCreated(String id) => callsTo('createNotificationChannel')
        .map((c) => c.arguments as Map)
        .firstWhere((a) => a['id'] == id,
            orElse: () => fail('no channel "$id" was created'));

    /// The Android half of the last notification posted.
    Map posted() =>
        (callsTo('show').last.arguments as Map)['platformSpecifics'] as Map;

    Future<void> ring({RestAlarm? on}) => (on ?? alarm()).ring(
          channel: _channel,
          title: 'Rest done',
          body: 'Bench Press · 80 kg × 8',
        );

    test('it is posted on the one rest channel there is', () async {
      await ring();

      expect(posted()['channelId'], RestAlarm.channelId);
      final created = callsTo('createNotificationChannel')
          .map((c) => (c.arguments as Map)['id'])
          .toSet();
      expect(created, {RestAlarm.channelId},
          reason: 'one channel: the second one existed only to be the quiet '
              'version of a channel that rang');
    });

    test('and that channel makes no sound of its own', () async {
      await ring();

      final channel = channelCreated(RestAlarm.channelId);
      expect(channel['playSound'], isFalse);
      expect(channel['sound'], isNull,
          reason: 'the app has already played the wav itself');
      expect(channel['importance'], Importance.max.value,
          reason: 'a rest ending is an alert, not furniture');
      expect(channel['enableVibration'], isTrue);
      expect(channel['audioAttributesUsage'], AudioAttributesUsage.alarm.value);
    });

    test('the notification asks for no sound, but it does buzz', () async {
      await ring();

      expect(posted()['playSound'], isFalse);
      expect(posted()['sound'], isNull);
      expect(posted()['enableVibration'], isTrue,
          reason: 'a phone in a pocket is felt before it is read');

      final args = callsTo('show').last.arguments as Map;
      expect(args['title'], 'Rest done');
      expect(args['body'], contains('Bench Press'),
          reason: 'it names what the rest is over for');
    });

    test('and two rests in a row stay on the same channel', () async {
      final a = alarm();
      await ring(on: a);
      final first = posted()['channelId'];

      await ring(on: a);

      expect(posted()['channelId'], first);
    });
  });
}
