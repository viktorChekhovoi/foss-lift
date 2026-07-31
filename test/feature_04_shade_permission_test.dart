// Integration tests for the "It asks to post notifications, or it is
// invisible" section of features/index.html#sec04.
//
// Split out of `feature_04_live_session_test.dart` on purpose: the seam these
// tests need does not exist yet, so this file does not compile until the green
// phase adds it, and keeping it here leaves the rest of feature 04 runnable in
// the meantime. Fold it back in once the seam lands if that reads better.
//
// ## The seam these tests assume
//
// `WorkoutShade` gains two constructor arguments, both optional and both
// defaulting to the real thing — the same shape `ReminderService` already uses
// for its plugin:
//
// ```dart
// WorkoutShade({
//   bool? platformSupported,
//   Future<bool> Function()? requestPermission,
// });
// ```
//
// * `platformSupported` overrides the `!kIsWeb && Platform.isAndroid` that
//   `supported` reports. Defaults to that expression, so nothing in the app
//   passes it; a test does, because the runner is not Android and every method
//   is otherwise a no-op.
// * `requestPermission` asks for `POST_NOTIFICATIONS` and returns whether it
//   was granted. Defaults to the real call —
//   `(await FlutterForegroundTask.requestNotificationPermission()) ==
//   NotificationPermission.granted`.
//
// And `show()` gains the behaviour the spec describes: on a supported platform
// it asks **once**, before it ever starts the service, and a refusal returns
// quietly — no service, no throw, and no second ask for the life of the
// object.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/services/workout_shade.dart';
import 'package:foss_lift/state/workout_cue.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

/// The channel the foreground-service plugin talks down. Mocked so a test can
/// see whether the service was *reached*, which is the difference between
/// "asked and refused" and "asked and started".
const _plugin = MethodChannel('flutter_foreground_task/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  ProviderContainer? container;

  /// Every call that reached the platform, plus every permission ask, in the
  /// order they happened — so "asks before starting" is an assertion about
  /// order rather than two separate facts.
  late List<String> calls;

  setUp(() {
    db = memoryDb();
    calls = [];
    // The plugin refuses to start a service it thinks is already running, and
    // waits five seconds for the platform to confirm one that is not there.
    FlutterForegroundTask.skipServiceResponseCheck = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_plugin, (call) async {
          calls.add(call.method);
          return call.method == 'isRunningService' ? false : null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_plugin, null);
    FlutterForegroundTask.resetStatic();
    container?.dispose();
    container = null;
    await db.close();
  });

  /// A shade that believes it is on Android — the only platform with a shade —
  /// and whose permission dialog answers [granted].
  WorkoutShade shadeThatIsAnswered(bool granted, List<String> calls) =>
      WorkoutShade(
        platformSupported: true,
        requestPermission: () async {
          calls.add('ask');
          return granted;
        },
      );

  /// A live Push session, as the words the shade would be asked to post.
  ///
  /// The shade holds no vocabulary of its own — the caller resolves the
  /// language and hands the finished text over, which is what the provider
  /// layer does with the session's cue.
  Future<ShadeCopy> livePush() async {
    container = containerFor(db);
    final ctl = container!.read(activeWorkoutProvider.notifier);
    await ctl.start(workoutId: await workoutIdNamed(db, 'Push'), name: 'Push');
    final session = container!.read(activeWorkoutProvider)!;
    return shadeCopy(
        l10nFor(), nextUp(session, restLeft: session.restLeft)!, 'kg')!;
  }

  group('It asks to post notifications, or it is invisible', () {
    test('the ask comes before the service, not after it', () async {
      // Declaring the permission in the manifest is not holding it: without the
      // grant the service starts, reports success and draws nothing.
      final shade = shadeThatIsAnswered(true, calls);

      await shade.show(await livePush());

      expect(calls, contains('ask'));
      expect(calls, contains('startService'));
      expect(
        calls.indexOf('ask'),
        lessThan(calls.indexOf('startService')),
        reason: 'a service started before the grant draws nothing',
      );
    });

    test('a refusal starts nothing, and is not an error', () async {
      final shade = shadeThatIsAnswered(false, calls);
      final copy = await livePush();

      await expectLater(shade.show(copy), completes);

      expect(calls, contains('ask'));
      expect(
        calls,
        isNot(contains('startService')),
        reason: 'refused means no shade, not a service drawing nothing',
      );
      expect(shade.running, isFalse);
    });

    test('and the workout carries on exactly as before', () async {
      // Nothing interrupts the session to say the shade is missing: the app on
      // screen is unaffected.
      final shade = shadeThatIsAnswered(false, calls);
      await shade.show(await livePush());

      final ctl = container!.read(activeWorkoutProvider.notifier);
      ctl.cycleSet(0, 0);
      final session = container!.read(activeWorkoutProvider)!;
      expect(session.exercises[0].sets[0].logged, isNotNull);
      expect(session.doneSets, 1);
    });

    test('it asks once, not once a session', () async {
      // Android stops showing the dialog after a refusal anyway, and the switch
      // that turns it back on is the phone's, not the app's.
      final shade = shadeThatIsAnswered(false, calls);
      final copy = await livePush();

      await shade.show(copy);
      await shade.hide();
      await shade.show(copy);
      await shade.show(copy);

      expect(
        calls.where((c) => c == 'ask').length,
        1,
        reason: 'the app asks once and does not badger',
      );
    });
  });

  group('A shade Android still has up is the one that gets used', () {
    // The service runs its handler in an engine of its own, so Android can tear
    // down the app's isolate and leave the notification standing. The shade the
    // next launch builds has no memory of it, and asking Android is the only
    // way it can find out — without that, a finished workout keeps a rest
    // counting down in the shade for good.

    /// Android answering that the service is up, as it does after the app's own
    /// isolate has been and gone.
    void serviceAlreadyRunning() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_plugin, (call) async {
            calls.add(call.method);
            return call.method == 'isRunningService' ? true : null;
          });
    }

    test('a fresh shade updates it rather than starting a second', () async {
      serviceAlreadyRunning();
      final shade = shadeThatIsAnswered(true, calls);

      await shade.show(await livePush());

      expect(calls, contains('updateService'));
      expect(
        calls,
        isNot(contains('startService')),
        reason:
            'the plugin refuses a second service, and the shade '
            'then never updates again',
      );
    });

    test('and finishing takes it down', () async {
      serviceAlreadyRunning();
      final shade = shadeThatIsAnswered(true, calls);

      await shade.hide();

      expect(
        calls,
        contains('stopService'),
        reason: 'a shade left up outlives the session it describes',
      );
    });
  });
}
