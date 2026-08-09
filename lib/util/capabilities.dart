/// What the build you are running is actually able to do.
///
/// The app ships for Android and for the browser out of one codebase, and a
/// browser cannot do several of the things a phone can: schedule a
/// notification, write a video file into app storage, read camera frames one at
/// a time, or keep a foreground service alive. None of that is a bug to be
/// worked around — it is a smaller machine, and the honest response is to not
/// offer the control at all.
///
/// **This is a capability list, not a platform check.** Screens ask "can this
/// build film a set" rather than "is this the web", which is what keeps the
/// iOS port from having to re-derive the answer at every call site, and what
/// lets a test mount a screen as if it were in a browser without a browser.
/// The services that predate it — `ReminderService.supported`,
/// `WorkoutShade.supported`, `RestAlarm.supported` — already have this shape;
/// this is the same idea moved somewhere the widgets can reach.
library;

import 'package:flutter/foundation.dart';

/// The set of abilities one build has.
@immutable
class Capabilities {
  const Capabilities({
    required this.reminders,
    required this.setVideos,
    required this.scanning,
    required this.shade,
    required this.backgroundAlerts,
    required this.localFiles,
    required this.leaveGuard,
    required this.eagerKeyboard,
  });

  /// A phone: everything the app was written for.
  static const Capabilities native = Capabilities(
    reminders: true,
    setVideos: true,
    scanning: true,
    shade: true,
    backgroundAlerts: true,
    localFiles: true,
    // The two that run the other way — see [leaveGuard] and [eagerKeyboard].
    leaveGuard: false,
    eagerKeyboard: false,
  );

  /// A browser tab. See `docs/web-build.md` for why each of these is false and
  /// what the user gets instead.
  static const Capabilities web = Capabilities(
    reminders: false,
    setVideos: false,
    scanning: false,
    shade: false,
    backgroundAlerts: false,
    localFiles: false,
    leaveGuard: true,
    eagerKeyboard: true,
  );

  /// A routine may ask to be reminded on its training days.
  ///
  /// The weekday schedule is *not* gated on this: which days a programme is
  /// trained on is part of the programme, it travels in a share code, and it is
  /// worth editing on a machine that cannot ring.
  final bool reminders;

  /// A set can be filmed, and the clip kept beside the set it was.
  final bool setVideos;

  /// A share code can be read off a camera. Pasting one always works.
  final bool scanning;

  /// The live session can be driven from outside the app.
  final bool shade;

  /// The end of a rest can be announced when the app is not on screen.
  final bool backgroundAlerts;

  /// The app has a private directory it can write files into.
  final bool localFiles;

  /// Leaving the app can be objected to before it happens.
  ///
  /// **This is the one that is true on the web and false on a phone**, which is
  /// why it reads oddly beside the others. A browser tab can be reloaded or
  /// closed out from under a live session, and `beforeunload` is a real hook to
  /// intercept that with. Android has no equivalent worth having: switching
  /// away does not end the app, the session survives in memory, and a swipe out
  /// of the recents list is not something an app is consulted about.
  final bool leaveGuard;

  /// The keyboard has to be asked for while the tap is still being handled.
  ///
  /// **The other one that is true on the web and false on a phone.** A browser
  /// only opens the keyboard from inside the gesture that asked for it, so a
  /// dialog's field taking focus once the dialog has been built and animated is
  /// asking too late — see `showAppDialog`. Android raises the keyboard for a
  /// field that takes focus whenever it takes it, and claiming it before the
  /// dialog exists would only mean a keyboard for a dialog about to be
  /// cancelled.
  final bool eagerKeyboard;
}

/// The capabilities of the build that is running.
///
/// Read [capabilitiesProvider] from a widget rather than this — a test
/// overrides the provider to mount a screen as another platform would draw it.
const Capabilities currentCapabilities =
    kIsWeb ? Capabilities.web : Capabilities.native;
