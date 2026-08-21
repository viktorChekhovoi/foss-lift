/// Rules for reducing targets after an extended absence.
library;

import 'progression.dart';

/// Days away from a workout before returning to it earns a back-off.
///
/// Default absence threshold in days.
const kDefaultLayoffDays = 14;

/// Percentage removed for each threshold period.
const kDefaultLayoffPercent = 10;

/// Maximum threshold periods that can contribute to a cut.
const kMaxLayoffPeriods = 3;

/// Maximum percentage a layoff can remove.
const kMaxLayoffCutPercent = 90;

/// A proposed back-off after a gap: how long you were away, how many whole
/// threshold-periods that came to, and the resulting cut as a percentage.
typedef LayoffDeload = ({int gapDays, int periods, int percent});

/// The rules as the user has them set: the gap that triggers a back-off, and
/// how deep a cut each period away is worth.
typedef LayoffSettings = ({int days, int percent});

/// Whole calendar days between [from] and [to], independent of DST.
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Computes the back-off for an absence, or null when no cut applies.
LayoffDeload? layoffDeload({
  required int gapDays,
  required int thresholdDays,
  required int percentPerPeriod,
}) {
  if (thresholdDays <= 0 || percentPerPeriod <= 0) return null;
  if (gapDays < thresholdDays) return null;

  var periods = gapDays ~/ thresholdDays;
  if (periods > kMaxLayoffPeriods) periods = kMaxLayoffPeriods;
  var percent = periods * percentPerPeriod;
  if (percent > kMaxLayoffCutPercent) percent = kMaxLayoffCutPercent;
  return (gapDays: gapDays, periods: periods, percent: percent);
}

/// Applies a layoff reduction, rounding down to the mode's increments and respecting both the mode floor and an optional bar floor.
double deloadedTarget(
  double current,
  int percent,
  ProgressionMode mode, {
  double floorKg = 0,
}) {
  final cut = current * (100 - percent) / 100;
  final landed = switch (mode) {
    ProgressionMode.weight => (cut * 2).floorToDouble() / 2,
    ProgressionMode.reps || ProgressionMode.time => cut.floorToDouble(),
  };
  final floor = floorKg > mode.floor ? floorKg : mode.floor;
  return landed < floor ? floor : landed;
}
