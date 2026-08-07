/// The keepalive on a phone: there is nothing to keep awake.
///
/// Reached through `tab_awake.dart` — never imported directly.
///
/// A live session already runs behind a foreground service, so the isolate is
/// alive and its timers fire on schedule. Holding a tone on top of that would
/// buy nothing and cost an audio focus, a wake lock and a notification-shade
/// media entry for the length of every workout.
library;

/// Does nothing. See above.
class TabAwake {
  /// Whether this build has anything to hold. Always false here.
  static bool get supported => false;

  bool get held => false;

  void hold() {}

  void release() {}

  void dispose() {}
}
