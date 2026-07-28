/// How big the app's text ends up, given the phone's setting and the user's.
///
/// **The phone comes first.** Android's text size is system-wide, discoverable
/// and the control people already know; the app follows it by default and adds
/// nothing of its own. The in-app nudge exists for the gap that leaves —
/// wanting *this* app larger without enlarging everything else, or smaller to
/// fit more of a workout on screen — so it multiplies the system scale rather
/// than replacing it.
///
/// **And the product is clamped.** Two multiplied scales reach sizes nobody has
/// looked at: the phone at 2.0 and the app at 1.3 is 2.6, well past the largest
/// layout anyone has checked. A control that can produce a layout nobody has
/// seen is not an accessibility feature, so the ceiling is [kMaxTextScale] —
/// the largest scale the feature tests sweep every screen at — and the floor is
/// [kMinTextScale], below which the numbers stop being readable at arm's
/// length mid-set.
library;

/// The largest text the app will render at, however the two settings combine.
/// Every screen is swept at this scale; see `features/15-text-size.md`.
const double kMaxTextScale = 2.0;

/// The smallest. Below this the set rows stop being readable across a gym.
const double kMinTextScale = 0.85;

/// What the in-app control offers, as label → multiplier of the phone's own.
///
/// Four steps rather than a slider: a slider invites hunting for a value, and
/// the difference between 1.12 and 1.15 is not a decision anybody wants to make
/// about their workout log.
const Map<String, double> kTextScaleChoices = {
  'Smaller': 0.9,
  'Default': 1.0,
  'Larger': 1.15,
  'Largest': 1.3,
};

/// The scale to actually render at: the phone's, nudged by the user's, held
/// inside the range the layouts are checked against.
double resolveTextScale({required double system, required double chosen}) {
  final combined = system * chosen;
  if (combined < kMinTextScale) return kMinTextScale;
  if (combined > kMaxTextScale) return kMaxTextScale;
  return combined;
}
