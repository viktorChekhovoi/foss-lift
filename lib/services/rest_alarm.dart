import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The rest ending, for when the app is not the thing on screen.
///
/// [RestTone] plays a wav out of the app's own isolate, which is exactly right
/// while you are looking at the board and no use at all with the phone in a
/// pocket and the screen off: whatever the process is still allowed to do at
/// that moment, an audio route is not something to bet the one useful event of
/// a rest timer on. A notification is: Android sounds it, at alarm volume, on
/// its own channel, whether or not this app is running.
///
/// So the two are a pair rather than a fallback — see
/// `ActiveWorkoutController.stopRest`, which picks one on the way past. On
/// screen: the tone, and nothing in the shade. Off screen: this, and no tone.
/// Never both, because "ding" twice for one rest reads as two rests.
///
/// **It is the same sound.** The channel plays `res/raw/rest_done.wav`, which
/// `tool/make_rest_tone.dart` writes alongside the Flutter asset — one
/// generator, two copies, so the rest cannot end with one noise in your hand
/// and a different one in your pocket.
///
/// Android only, like every other notification here. Off it, every method is a
/// no-op rather than a crash — the shape `ReminderService` uses. See issue #33.
class RestAlarm {
  /// [platformSupported] defaults to the real check; a test overrides it
  /// because the runner is not Android and there is no channel to post to.
  RestAlarm({
    FlutterLocalNotificationsPlugin? plugin,
    bool? platformSupported,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _platformSupported =
            platformSupported ?? (!kIsWeb && Platform.isAndroid);

  final FlutterLocalNotificationsPlugin _plugin;
  final bool _platformSupported;

  static const _channelId = 'rest_done';
  static const _channelName = 'Rest finished';
  static const _channelDescription =
      'Sounds when a rest timer runs out with the app in your pocket.';

  /// One id, reused. A second rest replaces the first notification rather than
  /// stacking beside it — there is only ever one rest.
  static const _id = 91;

  bool _ready = false;

  bool get supported => _platformSupported;

  /// Sounds the alarm, replacing any still on screen.
  ///
  /// Never throws. A denied notification permission, an OEM that will not
  /// create the channel, a platform channel that is not there — none of it is
  /// worth interrupting a workout over, and the timer is still counting on the
  /// screen the user can go and look at.
  Future<void> ring({required String title, required String body}) async {
    if (!supported) return;
    try {
      await _init();
      await _plugin.show(
        id: _id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            // Max, and a heads-up: this is the one notification in the app that
            // is an *alert* rather than furniture. The live-workout shade next
            // to it is deliberately silent and LOW.
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            sound: RawResourceAndroidNotificationSound('rest_done'),
            // The alarm stream, so it is heard over a phone on vibrate and at
            // the volume somebody set for being woken up — and so it follows
            // Do-Not-Disturb's alarm rules rather than overriding anything.
            audioAttributesUsage: AudioAttributesUsage.alarm,
            enableVibration: true,
            // It has said its piece. A rest that ended two minutes ago is not
            // news, and a notification you have to swipe away after every set
            // is a notification you turn off.
            timeoutAfter: 30000,
            autoCancel: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('RestAlarm: could not sound the end of the rest ($e)');
    }
  }

  /// Takes it down — the next rest starting, or the session ending.
  Future<void> clear() async {
    if (!supported) return;
    try {
      await _plugin.cancel(id: _id);
    } catch (e) {
      debugPrint('RestAlarm: could not clear the notification ($e)');
    }
  }

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }
}
