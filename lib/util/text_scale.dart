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

import '../l10n/app_localizations.dart';

/// The largest text the app will render at, however the two settings combine.
/// Every screen is swept at this scale; see `features/index.html#sec15`.
const double kMaxTextScale = 2.0;

/// The smallest. Below this the set rows stop being readable across a gym.
const double kMinTextScale = 0.85;

/// One step the in-app control offers: a multiplier of the phone's own scale,
/// and the catalogue entry that names it.
///
/// The label is looked up rather than stored, because a step is a number and
/// the word for it changes with the language.
/// The four steps span the whole range, ends included: [smaller] is
/// [kMinTextScale] and [largest] is [kMaxTextScale], which are the two values
/// the pinch stops at. So the chips are named stops on one scale rather than a
/// second, narrower control beside the gesture — pinch all the way out and you
/// land on Largest rather than somewhere past the last chip.
enum TextScaleChoice {
  smaller(kMinTextScale),
  standard(1.0),
  larger(1.3),
  largest(kMaxTextScale);

  const TextScaleChoice(this.scale);

  /// What the chosen step multiplies the phone's text scale by.
  final double scale;

  String label(AppLocalizations l10n) => switch (this) {
        TextScaleChoice.smaller => l10n.textScaleSmaller,
        TextScaleChoice.standard => l10n.textScaleDefault,
        TextScaleChoice.larger => l10n.textScaleLarger,
        TextScaleChoice.largest => l10n.textScaleLargest,
      };
}

/// What the in-app control offers, in the order the chips are laid out.
///
/// Four steps rather than a slider: a slider invites hunting for a value, and
/// the difference between 1.12 and 1.15 is not a decision anybody wants to make
/// about their workout log.
const List<TextScaleChoice> kTextScaleChoices = TextScaleChoice.values;

/// The nudge itself, held inside the same range the product is.
///
/// The chips can only pick values that are already in range; a pinch is
/// continuous and has no stops on it, so it is clamped as it goes rather than
/// left to be caught by [resolveTextScale] afterwards — otherwise a gesture that
/// had run well past the ceiling would have to be dragged all the way back
/// before the text moved again.
double clampTextNudge(double nudge) =>
    nudge.clamp(kMinTextScale, kMaxTextScale);

/// The scale to actually render at: the phone's, nudged by the user's, held
/// inside the range the layouts are checked against.
double resolveTextScale({required double system, required double chosen}) {
  final combined = system * chosen;
  if (combined < kMinTextScale) return kMinTextScale;
  if (combined > kMaxTextScale) return kMaxTextScale;
  return combined;
}
