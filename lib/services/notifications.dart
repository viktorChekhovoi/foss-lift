import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The notification plugin's one `initialize` call.
///
/// **Not any one service's call to make.** `ReminderService` and `RestAlarm`
/// both have to initialize the plugin before they can post anything, they share
/// one plugin instance, and `initialize` is not additive: what it keeps is the
/// last set of arguments it was handed. Two services each passing their own
/// meant whichever happened to go last decided what the plugin was configured
/// with — and the order is whatever the user did, since each initializes when it
/// is first needed rather than on launch.
///
/// Nothing else calls `plugin.initialize`. Calling this repeatedly is the
/// expected thing and costs a platform call.
///
/// The live workout is not here: it is a foreground service with a notification
/// of its own, posted by `flutter_foreground_task` rather than by this plugin.
/// See `workout_shade.dart`.
/// What a notification channel calls itself in the phone's own settings.
///
/// Handed to a service rather than held by one: a channel's name and
/// description are user-facing text, and no service here has a `BuildContext`
/// to resolve the language from — the reminder is laid down by a provider, the
/// rest alarm by a timer, the live workout by a foreground service in an
/// isolate of its own. Every one of them takes its words finished.
typedef NotificationChannelCopy = ({String name, String description});

Future<void> initNotifications(FlutterLocalNotificationsPlugin plugin) =>
    plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
