import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_ids.dart';

/// The plugin's `initialize`, and the callbacks that have to come with it.
///
/// **Not any one service's call to make.** `ReminderService`, `RestAlarm` and
/// `WorkoutShade` all have to initialize the plugin before they can post
/// anything, they share one plugin instance, and `initialize` is not additive:
/// the callbacks it keeps are the last ones it was handed. Three services each
/// passing their own arguments meant whichever happened to go last decided
/// whether a tap on the live workout reached the app at all — and the order is
/// whatever the user did, since each service initializes when it is first needed.
///
/// So the arguments live here, every service comes through this, and the order
/// stops mattering. Calling it repeatedly is the expected thing and costs a
/// platform call: it re-registers the same two callbacks.
///
/// [onLiveWorkoutTap] is remembered when given and left alone when not, so the
/// two services with no interest in taps do not have to know one exists.
///
/// [onBackgroundResponse] is the opposite case and is why only one caller passes
/// one: Android stores the *handle* of that function and keeps it across launches,
/// and a later `initialize` without one leaves what is stored alone. It is the
/// Dart-side callback above that is overwritten, which is the whole reason this
/// function exists. It must be a top-level or static function — a handle is taken
/// of it, and a closure has none.
Future<void> initNotifications(
  FlutterLocalNotificationsPlugin plugin, {
  void Function()? onLiveWorkoutTap,
  DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse,
}) async {
  if (onLiveWorkoutTap != null) _onLiveWorkoutTap = onLiveWorkoutTap;
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
    onDidReceiveNotificationResponse: notificationTapped,
    onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
  );
}

/// What a tap on the live workout does, once something has said. Null in a test
/// runner and in the isolate Android starts for a button press, neither of which
/// has an app to raise.
void Function()? _onLiveWorkoutTap;

/// What the plugin calls when a notification is tapped with the app alive.
///
/// Only the live workout's body means anything here. **A button press does not
/// come through this**, and must not be answered as though it did: presses take
/// the record — see [shadeActionInBackground] — and which of them raises the
/// board is `applyShadeAction`'s decision, not every press's. A tap on the rest
/// ding means "I have read this" and wants nothing.
void notificationTapped(NotificationResponse response) {
  if (!isLiveWorkoutTap(response)) return;
  _onLiveWorkoutTap?.call();
}

/// Whether [response] is a tap on the body of the live workout, as opposed to a
/// press on one of its buttons or a tap on some other notification.
bool isLiveWorkoutTap(NotificationResponse response) =>
    response.id == kLiveWorkoutId &&
    response.actionId == null &&
    response.notificationResponseType ==
        NotificationResponseType.selectedNotification;

/// Whether *this launch* is a tap on the live workout in the shade.
///
/// A tap on a shade left standing by a killed app starts the app cold, and
/// [notificationTapped] never hears about it: the intent was delivered and acted
/// on before any of this Dart was running, so there was no callback to call. The
/// launch has to go and ask instead — see `liveSessionRestoreProvider`, which is
/// also where the session it wants to show gets rebuilt.
Future<bool> launchedByLiveWorkoutTap(
  FlutterLocalNotificationsPlugin plugin,
) async {
  try {
    final launch = await plugin.getNotificationAppLaunchDetails();
    return launch != null &&
        launch.didNotificationLaunchApp &&
        launch.notificationResponse != null &&
        isLiveWorkoutTap(launch.notificationResponse!);
  } catch (e) {
    // Nothing here is worth failing a launch over: the app opens where it
    // otherwise would, and the resume bar is on every screen.
    debugPrint('Notifications: could not ask what launched the app ($e)');
    return false;
  }
}
