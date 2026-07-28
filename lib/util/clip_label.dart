import 'package:intl/intl.dart';

import '../data/exercise_stats.dart';
import 'units.dart';

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

/// How a speed is written on the toggle: "1×", "0.5×", "0.25×".
String fmtPlaybackSpeed(double speed) {
  final s = speed.toStringAsFixed(2);
  final trimmed = s
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return '$trimmed×';
}

/// What a clip is, in one line: `12 Mar · set 3 · 100 kg × 5`.
///
/// The reel is a flat list of one movement over months, so every row has to say
/// *which* set it was without the user opening it. The date comes first because
/// that is what the list is ordered by and what somebody is scanning for.
///
/// A held set reads its duration instead of a rep count (`set 2 · 45s`), and a
/// set done under no load drops the weight entirely rather than claiming "0 kg".
String clipLabel(ExerciseSetEntry set, String unit) => clipLabelOf(
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
String clipLabelOf({
  required DateTime date,
  required int setNumber,
  required double weightKg,
  required int reps,
  int? seconds,
  required String unit,
}) {
  final load = weightKg == 0
      ? null
      : '${fmtWeightShort(toDisplayWeight(weightKg, unit))} ${unitLabel(unit)}';
  final String effort;
  if (seconds != null) {
    effort = load == null ? '${seconds}s' : '$load × ${seconds}s';
  } else {
    effort = load == null ? '$reps reps' : '$load × $reps';
  }
  return '${DateFormat('d MMM').format(date)} · set $setNumber · $effort';
}

/// A weight with no trailing `.0` — 100.0 → "100", 102.5 → "102.5".
String fmtWeightShort(double w) =>
    w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toStringAsFixed(1);
