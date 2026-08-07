// Integration tests for the buzz at the end of a rest — the
// `rest-end-is-felt-as-well-as-heard` entry of features/index.html#sec04, from
// the platform's side.
//
// This is the one file with the vibrator's method channel mocked, so what
// crossed the channel is the assertion. Everywhere else the buzz is a recording
// double, which can say that a rest buzzed but not what the phone was asked to
// do — and what the phone is asked to do is the whole of the bug this replaced.
// The shipped build asked for touch-feedback haptics, which Android renders as a
// faint tick and suppresses outright when the phone's touch-feedback switch is
// off. A rest timer that cannot reach a phone in a bag has failed at the one
// thing it is for.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/services/rest_buzz.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every call that reached the platform, arguments and all.
  late List<MethodCall> calls;

  /// What the mocked platform does when asked — a phone that vibrates, unless a
  /// test replaces it with one that cannot.
  late Future<Object?> Function(MethodCall) answer;

  const channel = MethodChannel(RestBuzz.channelName);

  setUp(() {
    calls = [];
    answer = (_) async => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return answer(call);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  RestBuzz buzzer({bool supported = true}) =>
      RestBuzz(platformSupported: supported);

  Map args() => calls.single.arguments as Map;

  group('The end of a rest is felt as well as heard', () {
    test('it drives the vibrator rather than asking for touch feedback',
        () async {
      await buzzer().buzz();

      expect(calls.map((c) => c.method), ['buzz']);
      // The old buzz went down SystemChannels.platform as
      // `HapticFeedback.vibrate`, which is the phone's button feedback: off on
      // plenty of phones, and mapped to one of Android's faintest constants
      // even where it is on.
      expect(args()['pattern'], RestBuzz.pattern);
    });

    test('as an alarm, so a silenced phone still buzzes', () async {
      await buzzer().buzz();

      expect(args()['usage'], 'alarm',
          reason: 'a rest ending in a gym bag is exactly what a phone on '
              'silent still wakes you for');
    });

    test('and the pattern is felt through a bag, not ticked at a thumb',
        () async {
      final pattern = RestBuzz.pattern;

      // Waveform timings: wait, buzz, wait, buzz — so the odd entries are the
      // buzzing and the even ones the gaps.
      expect(pattern.length.isEven, isTrue);
      final buzzes = [
        for (var i = 1; i < pattern.length; i += 2) pattern[i],
      ];
      expect(buzzes, hasLength(greaterThan(1)),
          reason: 'one pulse reads as a notification; two read as a timer');
      expect(buzzes.every((ms) => ms >= 300), isTrue,
          reason: 'a tick is 10–40 ms and is what nobody felt');
      expect(pattern.reduce((a, b) => a + b), lessThan(3000),
          reason: 'it announces a rest; it does not become one');
    });

    test('it ends by itself — nothing has to be told to stop', () async {
      await buzzer().buzz();

      expect(args()['repeat'], isNot(isTrue),
          reason: 'a repeating vibration outlives the app that started it');
    });

    test('off Android it is a no-op, not a crash', () async {
      await expectLater(buzzer(supported: false).buzz(), completes);

      expect(calls, isEmpty);
    });

    test('and a phone with no vibrator does not take the rest down with it',
        () async {
      answer = (_) async =>
          throw PlatformException(code: 'unavailable', message: 'no vibrator');

      await expectLater(buzzer().buzz(), completes);
    });

    test('nor does a platform with nothing on the other end of the channel',
        () async {
      answer = (_) async => throw MissingPluginException('no handler');

      await expectLater(buzzer().buzz(), completes);
    });

    test('the real thing is Android-only', () {
      // Written the way `RestAlarm` is: every method a no-op off Android rather
      // than a crash, so the iOS port lands without this file in the way. The
      // host is what decides, not the widget binding's notion of a target
      // platform — a test runner is a Linux machine with no vibrator on it.
      expect(RestBuzz().supported, Platform.isAndroid);
    }, skip: kIsWeb);
  });
}
