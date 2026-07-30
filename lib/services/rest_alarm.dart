import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'local_time_zone.dart';
import 'notification_ids.dart';

/// The rest ending, for when the app is not the thing on screen.
///
/// [RestTone] plays a wav out of the app's own isolate, which is exactly right
/// while you are looking at the board and no use at all with the phone in a
/// pocket and the screen off. Two things go wrong there, and only the second is
/// about audio: a media player is the wrong instrument for an alert, and — the
/// one that actually made rests end in silence — **the app may not be running at
/// the moment the rest runs out.** Android kills backgrounded processes, and a
/// dead process plays nothing, posts nothing, and cannot be asked to.
///
/// So the sound is handed to Android *in advance*. [scheduleAt] lays the
/// notification down for the instant the rest will end, on an alarm channel, as
/// an exact alarm that fires through Doze. Whether the app is alive then makes no
/// difference. [ring] posts the same notification immediately, for a rest that
/// ends out of order — a skip pressed from the shade.
///
/// `ActiveWorkoutController` picks between the three: the tone while the app is
/// on screen, a scheduled alarm while it is not, and an immediate ring for a rest
/// cut short from the shade. Never two of them for one rest, because "ding" twice
/// reads as two rests.
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
  static const _channelName = 'Rest finished';
  static const _channelDescription =
      'Sounds when a rest timer runs out with the app in your pocket.';

  bool _ready = false;

  bool get supported => _platformSupported;

  /// Sounds the alarm now, replacing anything still on screen and any alarm
  /// still pending.
  Future<void> ring({required String title, required String body}) async {
    if (!supported) return;
    await _guard('sound the end of the rest', () async {
      await _init();
      await _plugin.cancel(id: kRestAlarmId);
      await _plugin.show(
        id: kRestAlarmId,
        title: title,
        body: body,
        notificationDetails: _details,
      );
    });
  }

  /// Hands the sound to Android to make at [at], whether or not this app is
  /// still alive then. Replaces any alarm already pending.
  ///
  /// Returns whether Android took it. A false answer is the caller's cue that it
  /// has to make the noise itself if it is still running when the rest runs out
  /// — see `ActiveWorkoutController`.
  Future<bool> scheduleAt(
    DateTime at, {
    required String title,
    required String body,
  }) async {
    if (!supported) return false;
    var laid = false;
    await _guard('schedule the end of the rest', () async {
      await _init();
      await ensureLocalTimeZone();
      await _plugin.cancel(id: kRestAlarmId);
      final when = tz.TZDateTime.from(at, tz.local);
      // Exact, and through Doze. A rest timer is a timer: two minutes means two
      // minutes, and a ding that lands whenever Android next batches its alarms
      // is not a rest timer at all. See the manifest note on USE_EXACT_ALARM. An
      // OEM that refuses exact alarms anyway gets the inexact one rather than
      // nothing.
      try {
        await _lay(when, title, body, AndroidScheduleMode.exactAllowWhileIdle);
      } catch (e) {
        debugPrint('RestAlarm: no exact alarms here ($e) — falling back');
        await _lay(when, title, body, AndroidScheduleMode.inexactAllowWhileIdle);
      }
      laid = true;
    });
    return laid;
  }

  Future<void> _lay(
    tz.TZDateTime when,
    String title,
    String body,
    AndroidScheduleMode mode,
  ) =>
      _plugin.zonedSchedule(
        id: kRestAlarmId,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: mode,
      );

  /// Takes it down — a pending alarm, one already on screen, or both. The next
  /// rest starting, the app coming forward, and the session ending all end here.
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
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      sound: RawResourceAndroidNotificationSound('rest_done'),
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

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    // Created explicitly rather than left to the first `show`. A scheduled
    // notification is handed over now and posted later, possibly by a process
    // that no longer holds this object — the channel it names has to exist, and
    // have its sound, before then.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('rest_done'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
        ));
    _ready = true;
  }
}
