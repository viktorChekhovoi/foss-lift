import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_ids.dart';
import 'notifications.dart';

/// The rest ending, for when the app is not the thing on screen.
///
/// [RestTone] plays a wav out of the app's own isolate, which is exactly right
/// while you are looking at the board and no use at all with the phone in a
/// pocket and the screen off: a media player is the wrong instrument for an
/// alert, and it is not what the phone's alarm volume and Do-Not-Disturb rules
/// apply to. So off screen the same sound is a notification instead, on a
/// high-importance channel at alarm volume.
///
/// **Posted when the rest ends, not handed over in advance.** It used to be
/// scheduled the moment an off-screen rest started, because the countdown is a
/// timer in this process and a process Android has killed plays nothing. Two
/// things changed that. The foreground service keeps the session alive to the
/// end of its own rest, so there is normally something here to ring. And a
/// scheduled alarm could only be inexact — Play grants the exact-alarm
/// permission to alarm clocks and calendars and not to a workout tracker — so
/// the fallback would arrive late, which for a rest timer is its own kind of
/// wrong. See the manifest note and issue #70.
///
/// What that costs is the rest that ends while the app is not running at all: a
/// force-stop, or a reclaim the service did not prevent. That one is silent. The
/// workout itself is not lost — the crash snapshot brings it back.
///
/// `ActiveWorkoutController` picks between the two: the tone while the app is on
/// screen, this while it is not. Never both, because "ding" twice reads as two
/// rests.
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

  /// **A channel's sound is fixed when Android first creates it**, and no later
  /// call can change it — which is how a channel that was once silent stays
  /// silent through every fix to the code posting to it. Nothing has shipped, so
  /// the id is simply a new one; anything still holding the old `rest_done`
  /// channel is a development install and can lose it.
  static const _channelId = 'rest_alarm';

  /// The channel labels [_init] last registered, or null before the first ring.
  /// A language switch changes them, and Android takes a channel's name and
  /// description from the most recent call — so the row in the phone's
  /// notification settings follows the app.
  NotificationChannelCopy? _channelCopy;

  bool get supported => _platformSupported;

  /// Sounds the alarm now, replacing anything still on screen.
  ///
  /// Every string arrives finished: this runs off a timer with no widget tree
  /// under it, so `ActiveWorkoutController` resolves the language and composes
  /// the two lines before calling.
  Future<void> ring({
    required NotificationChannelCopy channel,
    required String title,
    required String body,
  }) async {
    if (!supported) return;
    await _guard('sound the end of the rest', () async {
      await _init(channel);
      // One id for the rest, so a second ding replaces the first rather than
      // stacking beside it.
      await _plugin.cancel(id: kRestAlarmId);
      await _plugin.show(
        id: kRestAlarmId,
        title: title,
        body: body,
        notificationDetails: _details(channel),
      );
    });
  }

  /// Takes it down. The next rest starting, the app coming forward, and the
  /// session ending all end here — a rest that ended two minutes ago is not news.
  Future<void> clear() async {
    if (!supported) return;
    await _guard(
        'clear the notification', () => _plugin.cancel(id: kRestAlarmId));
  }

  /// Nothing this class does is worth interrupting a workout over: a denied
  /// notification permission, an OEM that will not create the channel, a
  /// platform channel that is not there. The timer is still counting on the
  /// screen the user can go and look at.
  Future<void> _guard(String what, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      debugPrint('RestAlarm: could not $what ($e)');
    }
  }

  /// Max, a heads-up, and the alarm stream. This is the one notification in the
  /// app that is an *alert* rather than furniture — the live-workout shade beside
  /// it is deliberately silent and LOW.
  static NotificationDetails _details(NotificationChannelCopy channel) =>
      NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      sound: const RawResourceAndroidNotificationSound('rest_done'),
      // The alarm stream, so it is heard over a phone on vibrate and at the
      // volume somebody set for being woken up — and so it follows
      // Do-Not-Disturb's alarm rules rather than overriding anything.
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      // It has said its piece. A rest that ended two minutes ago is not news,
      // and a notification you have to swipe away after every set is a
      // notification you turn off.
      timeoutAfter: 30000,
      autoCancel: true,
    ),
  );

  Future<void> _init(NotificationChannelCopy channel) async {
    if (_channelCopy == channel) return;
    await initNotifications(_plugin);
    // Created explicitly rather than left to the first `show`. A scheduled
    // notification is handed over now and posted later, possibly by a process
    // that no longer holds this object — the channel it names has to exist, and
    // have its sound, before then.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(AndroidNotificationChannel(
          _channelId,
          channel.name,
          description: channel.description,
          importance: Importance.max,
          sound: const RawResourceAndroidNotificationSound('rest_done'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
        ));
    _channelCopy = channel;
  }
}
