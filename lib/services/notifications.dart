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
Future<void> initNotifications(FlutterLocalNotificationsPlugin plugin) =>
    plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
