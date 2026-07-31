import '../data/exercise_stats.dart';
import '../l10n/app_localizations.dart';
import 'units.dart';
import 'format.dart';

/// The speeds a clip plays at.
///
/// Slow motion is the whole reason the player is not just a play button: a
/// sticking point goes past at full speed and is obvious at a quarter of it.
/// Nothing above 1× — this is for inspecting a rep, not for skipping one.
const List<double> kPlaybackSpeeds = [1.0, 0.5, 0.25];

/// The next speed on the toggle, wrapping back to full at the end.
///
/// A cycle rather than a menu: three values, and the control is on top of a
/// video the user is watching. A speed that is not one of the three — which
/// nothing produces, but a restored player could — resolves to full.
double nextPlaybackSpeed(double current) {
  final i = kPlaybackSpeeds.indexOf(current);
  if (i < 0) return kPlaybackSpeeds.first;
  return kPlaybackSpeeds[(i + 1) % kPlaybackSpeeds.length];
}

/// How a speed is written on the toggle: "1×", "0.5×", "0.25×" — and "0,5×"
/// in a language that writes the decimal that way.
String fmtPlaybackSpeed(double speed) => '${fmtUpTo(speed, 2)}×';

/// What a clip is, in one line: `12 Mar · set 3 · 100 kg × 5`.
///
/// The reel is a flat list of one movement over months, so every row has to say
/// *which* set it was without the user opening it. The date comes first because
/// that is what the list is ordered by and what somebody is scanning for.
///
/// A held set reads its duration instead of a rep count (`set 2 · 45s`), and a
/// set done under no load drops the weight entirely rather than claiming "0 kg".
///
/// Takes [l10n] rather than a `BuildContext`: this runs for every row of the
/// reel and for every set of the recap, and the widget that is already holding
/// the localisations passes them down.
String clipLabel(AppLocalizations l10n, ExerciseSetEntry set, String unit) =>
    clipLabelOf(
      l10n,
      date: set.date,
      setNumber: set.setNumber,
      weightKg: set.weightKg,
      reps: set.reps,
      seconds: set.seconds,
      unit: unit,
    );

/// [clipLabel] over loose values, for the session recap — which holds drift
/// rows rather than the flattened history entries the reel is built from. One
/// implementation, two callers: the label has to read identically in both
/// places or the same clip appears to be two different things.
///
/// Four whole messages rather than one frame with an effort spliced into it:
/// the load, the reps and the hold are the part that changes shape, and a
/// language that inflects around them cannot be handed a finished fragment.
String clipLabelOf(
  AppLocalizations l10n, {
  required DateTime date,
  required int setNumber,
  required double weightKg,
  required int reps,
  int? seconds,
  required String unit,
}) {
  final load = weightKg == 0
      ? null
      : l10n.unitWeightShort(
          fmtWeight(toDisplayWeight(weightKg, unit)), unitSuffix(l10n, unit));
  if (seconds != null) {
    final held = l10n.unitSecondsShort('$seconds');
    return load == null
        ? l10n.clipLabelHold(date, setNumber, held)
        : l10n.clipLabelLoadedHold(date, setNumber, load, held);
  }
  return load == null
      ? l10n.clipLabelReps(date, setNumber, reps)
      : l10n.clipLabelLoadedReps(date, setNumber, load, reps);
}

