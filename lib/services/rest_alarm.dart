import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_ids.dart';
import 'notifications.dart';

/// The rest ending, as something to look at when the phone comes out.
///
/// **It makes no sound, and that is the point.** It used to: the notification
/// carried `res/raw/rest_done.wav` on a high-importance channel, and the tone
/// was the on-screen alternative to it. A notification channel's loudness,
/// though, belongs to the phone's alarm slider — nothing an app posts can turn
/// it down — so the rest-alert volume could not reach the one case a rest timer
/// exists for, a phone in a pocket. It does not have to be a channel sound:
/// [RestTone] plays out of the app's own isolate, the live session already runs
/// behind a foreground service, and an app with one running may play audio while
/// it is in the background. So `ActiveWorkoutController` sounds the tone either
/// way and posts this alongside it off screen — the picture, not the noise. It
/// still buzzes, because a buzz is not a volume.
///
/// **Posted when the rest ends, not handed over in advance.** It used to be
/// scheduled the moment an off-screen rest started, because the countdown is a
/// timer in this process and a process Android has killed plays nothing. Two
/// things changed that. The foreground service keeps the session alive to the
/// end of its own rest, so there is normally something here to post. And a
/// scheduled alarm could only be inexact — Play grants the exact-alarm
/// permission to alarm clocks and calendars and not to a workout tracker — so
/// the fallback would arrive late, which for a rest timer is its own kind of
/// wrong. See the manifest note and issue #70.
///
/// What that costs is the rest that ends while the app is not running at all: a
/// force-stop, or a reclaim the service did not prevent. That one is silent, and
/// always was — nothing was ever handed to Android to ring on its own. The
/// workout itself is not lost; the crash snapshot brings it back.
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

  bool get supported => _platformSupported;

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
    if (!supported) return;
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
