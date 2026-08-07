import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The vibration at the end of a rest.
///
/// **It is the vibrator, not touch feedback, and that is the whole point.** The
/// shipped build asked for `HapticFeedback.heavyImpact`, which is not a heavy
/// anything on Android: Flutter maps it to `HapticFeedbackConstants.CONTEXT_CLICK`,
/// a tick shorter than the one a keypress gets, and every haptic-feedback
/// constant is routed through the view — so the phone's *touch feedback* switch
/// silences all of it. Between a tick nobody notices and a switch half the
/// phones in the world have off, the rest timer could not reach the one place it
/// has to: a phone in a bag, face down, three metres away. This drives the
/// vibrator directly instead.
///
/// **As an alarm.** The usage is what decides whether a vibration survives the
/// phone being silenced, and a rest ending is the same kind of event as an alarm
/// going off — so it plays with the ringer on silent, and is suppressed only by
/// a Do-Not-Disturb that suppresses alarms too. Nothing here overrides a user
/// who has said no.
///
/// **Where the tone is, not where the board is.** The buzz used to belong to
/// `WorkoutScreen`, which meant it existed only while the board was mounted.
/// `ActiveWorkoutController` makes it now, beside the tone, at the instant the
/// clock reaches zero — see `active_workout.dart`. What keeps this isolate alive
/// to reach that line with the phone away is the live session's foreground
/// service, the same thing that lets the tone sound at all.
///
/// Android only, like every other platform service here. Off it, every method is
/// a no-op rather than a crash — the shape [RestAlarm] and `ReminderService`
/// use. See issue #33.
class RestBuzz {
  /// [platformSupported] defaults to the real check; a test overrides it because
  /// the runner is not Android and there is no vibrator to drive.
  RestBuzz({MethodChannel? channel, bool? platformSupported})
      : _channel = channel ?? const MethodChannel(channelName),
        _platformSupported =
            platformSupported ?? (!kIsWeb && Platform.isAndroid);

  final MethodChannel _channel;
  final bool _platformSupported;

  /// The channel `MainActivity` answers on. An app-private name, since this is
  /// the app's own code on both ends rather than a plugin.
  static const channelName = 'com.fosslift.foss_lift/buzz';

  /// Waveform timings in milliseconds, alternating wait and buzz, starting with
  /// a wait of none.
  ///
  /// Two long pulses rather than one: a single buzz is what every notification
  /// on the phone makes, and the point is to be told apart from one across a
  /// room. Each is long enough to be felt through a bag — a tick is 10–40 ms,
  /// which is what nobody felt — and the pair is over in a second and a bit, so
  /// it announces the rest rather than becoming one.
  static const pattern = <int>[0, 400, 200, 400];

  bool get supported => _platformSupported;

  /// Buzzes now, once. Never repeats: a repeating vibration is one that has to
  /// be told to stop, and there is no guarantee this isolate is alive to tell
  /// it.
  Future<void> buzz() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('buzz', {
        'pattern': pattern,
        'usage': 'alarm',
      });
    } catch (e) {
      // A phone with no vibrator, an OEM that refuses, a channel that is not
      // there because the activity has gone. None of it is worth interrupting a
      // workout over — the tone has already sounded and the notification is
      // already posted.
      debugPrint('RestBuzz: could not buzz ($e)');
    }
  }
}
