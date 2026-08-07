/// Stopping a browser from slowing the app's clocks down while a workout runs.
///
/// ## The problem
///
/// Chrome throttles a hidden tab's timers to one a second immediately, and —
/// once the tab has been hidden more than five minutes **and silent for at
/// least thirty seconds** — to roughly one a *minute*. The session's clocks
/// tick once a second, so the second of those is what hurts: a rest that ends
/// while the tab is behind another one is noticed up to a minute late.
///
/// The wall-clock rewrite in `active_workout.dart` means nothing is *lost* to
/// that any more — the countdown and the recorded duration come back correct
/// the moment a tick lands. What it cannot fix is the lateness of the ding
/// itself, and that is what this is for.
///
/// ## The fix, and what it costs
///
/// The "silent for thirty seconds" clause is the way out: a tab producing audio
/// is exempt. So for the length of a live workout the app holds a tone far
/// below anything audible, and the browser leaves its timers alone.
///
/// **It cannot be actual silence.** The exemption is for *audible* output and
/// the browser decides by level, so a gain of zero buys nothing. The gain here
/// is small enough to be inaudible on any real output and large enough to
/// count.
///
/// **The tab will show the speaker mark**, for the whole workout. That is not
/// a side effect to be engineered away — it is the mechanism. It also means
/// muting the tab silences the rest tone, since it is the same output.
///
/// **It does not work on iOS Safari**, which suspends a page's audio the moment
/// the page is not what is on screen. There is no workaround; see
/// `docs/web-build.md`. This is why `Capabilities.backgroundAlerts` stays false
/// on the web — the off-screen ding is a phone promise either way.
///
/// **It is held only while a workout is live**, which is what makes the trade
/// acceptable: a bounded hour with a speaker icon, not a permanent one.
library;

export 'tab_awake_native.dart'
    if (dart.library.js_interop) 'tab_awake_web.dart';
