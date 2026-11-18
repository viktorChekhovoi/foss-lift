import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_ids.dart';
import 'notifications.dart';

/// iOS delivers a scheduled rest cue even when Dart is suspended. Android's foreground service plays the in-app tone and clears legacy completion cards.
class RestAlarm {
  /// Tests can override platform availability before exercising a notification channel.
  RestAlarm({FlutterLocalNotificationsPlugin? plugin, bool? platformSupported})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
      _platformSupported =
          platformSupported ??
          (!kIsWeb &&
              (Platform.isAndroid ||
                  defaultTargetPlatform == TargetPlatform.iOS));

  final FlutterLocalNotificationsPlugin _plugin;
  final bool _platformSupported;

  /// **A channel's sound is fixed when Android first creates it**, and no later
  /// call can change it. This one is created silent, so it stays silent through
  /// every change to the code posting to it — which is the property wanted, the
  /// sound being the tone's job. The id was changed freely before the first
  /// release, when the only phones holding an earlier `rest_done` or
  /// `rest_alarm` channel were development installs. It is not free now: a new
  /// id is a new channel, and the one the user has already tuned would be
  /// abandoned with their settings still on it.
  static const channelId = 'rest_end';

  /// The channel labels [_init] last registered, or null before the first post.
  /// A language switch changes them, and Android takes a channel's name and
  /// description from the most recent call, so the row in the phone's
  /// notification settings follows the app.
  NotificationChannelCopy? _channelCopy;

  bool get schedulesAhead =>
      supported && !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get supported => _platformSupported;

  Future<void> _pending = Future<void>.value();
  Future<void> get settled => _pending;
  int _revision = 0;
  bool _iosInitialized = false;

  /// Reuses one notification ID for the current deadline. Serialize native writes so a slow permission answer or add cannot revive a skipped or replaced rest.
  Future<bool> schedule(
    DateTime deadline, {
    required String title,
    required String body,
    bool restoring = false,
  }) {
    final revision = ++_revision;
    final result = _pending.then((_) async {
      if (revision != _revision) return false;
      try {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        if (ios == null) return false;
        final stamp = deadline.millisecondsSinceEpoch.toString();
        if (restoring) {
          // A pending notification survives the process. Leave it armed across a cold launch, including when it fires during restoration.
          final pending = await ios.pendingNotificationRequests();
          final alreadyArmed = pending.any(
            (request) => request.id == kRestAlarmId && request.payload == stamp,
          );
          if (alreadyArmed || !deadline.isAfter(DateTime.now())) return true;
        }
        await ios.cancel(id: kRestAlarmId);
        if (!_iosInitialized) {
          await initNotifications(_plugin);
          _iosInitialized = true;
        }
        if (revision != _revision) return false;
        final allowed = await ios.requestPermissions(alert: true, sound: true);
        if (allowed != true || revision != _revision) return false;

        // Apple's calendar trigger has one-second precision. Round up so a fractional deadline never rings early.
        final seconds =
            (deadline.microsecondsSinceEpoch / Duration.microsecondsPerSecond)
                .ceil();
        await ios.zonedSchedule(
          id: kRestAlarmId,
          scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(
            tz.UTC,
            seconds * Duration.millisecondsPerSecond,
          ),
          title: title,
          body: body,
          payload: stamp,
          notificationDetails: const DarwinNotificationDetails(
            sound: 'rest_done.wav',
            presentSound: true,
            presentAlert: false,
            presentBanner: false,
            presentList: false,
            presentBadge: false,
          ),
        );
        return true;
      } catch (error) {
        debugPrint(
          'RestAlarm: could not schedule the iPhone rest alert ($error)',
        );
        return false;
      }
    });
    _pending = result.then((_) {});
    return result;
  }

  /// Puts the end of the rest on screen now, replacing anything still there.
  ///
  /// Silent — the tone has already sounded, and a channel ringing as well would
  /// be two dings for one rest.
  ///
  /// Every string arrives finished: this runs off a timer with no widget tree
  /// under it, so `ActiveWorkoutController` resolves the language and composes
  /// the two lines before calling.
  Future<void> ring({
    required NotificationChannelCopy channel,
    required String title,
    required String body,
  }) async {
    if (!supported || schedulesAhead) return;
    await _guard('post the end of the rest', () async {
      await _init(channel);
      // One id for the rest, so a second one replaces the first rather than
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
    Future<void> cancel() => _guard(
      'clear the notification',
      () => _plugin.cancel(id: kRestAlarmId),
    );
    if (schedulesAhead) {
      _revision++;
      _pending = _pending.then((_) => cancel());
      await _pending;
    } else {
      await cancel();
    }
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

  /// Max, a heads-up, the alarm category and a buzz — everything an alert has
  /// except a noise. The alarm attributes still matter with the sound gone: they
  /// are what puts the buzz under Do-Not-Disturb's alarm rules rather than
  /// letting it through as an ordinary interruption.
  static NotificationDetails _details(NotificationChannelCopy channel) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          playSound: false,
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
    // Created explicitly rather than left to the first `show`, because whether a
    // channel makes a sound is what the first creation of it decides, and this
    // one must not.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(AndroidNotificationChannel(
          channelId,
          channel.name,
          description: channel.description,
          importance: Importance.max,
          playSound: false,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
        ));
    _channelCopy = channel;
  }
}
