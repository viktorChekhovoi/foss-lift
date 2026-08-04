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
/// The icon it registers is the app-wide default for every notification this
/// plugin posts: `AndroidNotificationDetails.icon` is left null in
/// `reminders.dart` and `rest_alarm.dart`, and null falls back to what was set
/// here. It has to be a *stencil* — Android discards a small icon's colour and
/// fills its alpha channel with a flat tint — which is why it is not the
/// launcher icon: that art is an opaque rounded plate, so its alpha is the
/// plate and the wordmark on it never appears. See
/// `res/drawable/ic_stat_fosslift.xml`.
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
        android: AndroidInitializationSettings('@drawable/ic_stat_fosslift'),
      ),
    );
