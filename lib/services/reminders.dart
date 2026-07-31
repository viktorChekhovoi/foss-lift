import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/schedule.dart';
import 'local_time_zone.dart';
import 'notification_ids.dart';
import 'notifications.dart';

/// One routine's reminder, with the words already chosen for it.
///
/// [reminder] says *when* — the schedule arithmetic stays where it is. [title]
/// and [body] are what the notification reads, resolved by the caller: the
/// title is the routine's name as the app renders it, which for a routine the
/// app shipped is a translation rather than the stored English.
typedef ReminderPost = ({RoutineReminder reminder, String title, String body});

/// Schedules the local notifications that remind you a training day is on.
///
/// Local in the strict sense: the notification is laid down on the device by
/// the device, there is no server anywhere in it, and nothing about the routine
/// leaves the phone. That is the only kind of reminder this app can have.
///
/// The service holds no state worth persisting. Every call to [sync] cancels
/// what was pending and lays the next reminder for each routine down again —
/// cheap, and it means a schedule edit, a finished session and a fresh launch
/// all converge on the same answer without anyone tracking which is which.
///
/// It holds no words either. A reminder names its routine, and a routine the
/// app shipped is named from the string catalogue rather than from the `name`
/// column — so the caller resolves the language and hands the finished text
/// over as [ReminderPost]s. There is no `BuildContext` here to look one up
/// from, and a remembered `AppLocalizations` would post yesterday's language
/// after a switch.
class ReminderService {
  ReminderService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'workout_reminders';

  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;
  Future<void> _queue = Future<void>.value();

  /// Android is the only platform this app ships on, and the only one with a
  /// notification story worth having here. Everywhere else — desktop, and the
  /// test runner — every method below is a no-op rather than a crash.
  bool get supported => Platform.isAndroid;

  /// Prepares the time-zone database and the plugin. Safe to call repeatedly;
  /// only the first call does anything.
  Future<void> init() async {
    if (_ready || !supported) return;
    await ensureLocalTimeZone();
    await initNotifications(_plugin);
    _ready = true;
  }

  /// Asks for the notification permission Android 13+ requires. Returns whether
  /// it was granted; false on every platform that cannot be asked.
  ///
  /// Called when the user turns a reminder on, which is the moment the request
  /// makes sense — the system prompt then arrives with the reason for it still
  /// on screen.
  Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Whether notifications are currently allowed at all.
  Future<bool> permitted() async {
    if (!supported) return false;
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? false;
  }

  /// Re-lays every routine's next reminder.
  ///
  /// Serialised behind a queue: the caller is a provider that can emit twice in
  /// quick succession (a routine edit is also a change to the reminder list),
  /// and two overlapping runs would have one cancelling what the other had just
  /// scheduled.
  Future<void> sync(
    List<ReminderPost> posts, {
    required NotificationChannelCopy channel,
    DateTime? now,
  }) {
    if (!supported) return Future<void>.value();
    final at = now ?? DateTime.now();
    _queue = _queue
        .then((_) => _sync(posts, channel, at))
        // A failure to schedule must not poison the queue for every later
        // sync; the next change to a routine gets a clean run at it.
        .catchError((Object e) =>
            debugPrint('ReminderService: could not schedule reminders ($e)'));
    return _queue;
  }

  Future<void> _sync(
    List<ReminderPost> posts,
    NotificationChannelCopy channel,
    DateTime now,
  ) async {
    await init();
    if (!_ready) return;

    // Only pending reminders. One already on screen is the user's to dismiss —
    // and the rest alarm is pending too, laid down by a session in progress, so
    // cancelling everything would take the end of somebody's rest with it. See
    // `notification_ids.dart`.
    for (final pending in await _plugin.pendingNotificationRequests()) {
      if (isReminderId(pending.id)) await _plugin.cancel(id: pending.id);
    }

    for (final post in posts) {
      final at = post.reminder.nextFireAt(now);
      if (at == null) continue;
      await _plugin.zonedSchedule(
        // The routine's own id, so re-syncing replaces its reminder rather than
        // stacking a second one beside it.
        id: post.reminder.routineId,
        title: post.title,
        body: post.body,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        // Inexact on purpose. An exact alarm needs a permission Android 14
        // makes the user grant by hand, and a reminder to go to the gym does
        // not need to land on the second.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
