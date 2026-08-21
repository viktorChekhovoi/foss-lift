/// Combines the system and in-app text scales, clamped to the tested range.

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
