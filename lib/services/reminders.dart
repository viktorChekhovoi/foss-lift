import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/schedule.dart';

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
class ReminderService {
  ReminderService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'workout_reminders';
  static const _channelName = 'Workout reminders';
  static const _channelDescription =
      'Nudges on the days a routine is scheduled to be trained.';

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
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (e) {
      // An unknown zone name leaves `tz.local` at UTC, which would fire
      // reminders at the wrong hour. Better a wrong hour than a crash on
      // launch, but say so where a bug report can pick it up.
      debugPrint('ReminderService: could not resolve the local time zone ($e)');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
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
  Future<void> sync(List<RoutineReminder> routines, {DateTime? now}) {
    if (!supported) return Future<void>.value();
    final at = now ?? DateTime.now();
    _queue = _queue
        .then((_) => _sync(routines, at))
        // A failure to schedule must not poison the queue for every later
        // sync; the next change to a routine gets a clean run at it.
        .catchError((Object e) =>
            debugPrint('ReminderService: could not schedule reminders ($e)'));
    return _queue;
  }

  Future<void> _sync(List<RoutineReminder> routines, DateTime now) async {
    await init();
    if (!_ready) return;

    // Only pending ones: a reminder already on screen is the user's to dismiss.
    await _plugin.cancelAllPendingNotifications();

    for (final r in routines) {
      final at = r.nextFireAt(now);
      if (at == null) continue;
      await _plugin.zonedSchedule(
        // The routine's own id, so re-syncing replaces its reminder rather than
        // stacking a second one beside it.
        id: r.routineId,
        title: r.name,
        body: 'Training day — time to lift.',
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
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
