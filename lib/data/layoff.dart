/// Coming back from time off: how long a gap has to be before the working
/// target should regress, and how far it should drop.
///
/// Kept apart from `progression.dart` because it answers a different question.
/// Progression judges what you did; a layoff judges what you did *not* do — it
/// reads the calendar, not the session. Like the rest of the rules it is free
/// of drift and Flutter so it can be read and tested on its own.
library;

import 'progression.dart';

/// Days away from a workout before returning to it earns a back-off.
///
/// Two weeks: long enough that a holiday or a bad flu clears it, short enough
/// that the strength genuinely is not where you left it.
const kDefaultLayoffDays = 14;

/// How much a target is cut for each whole period away, as a percentage.
const kDefaultLayoffPercent = 10;

/// The most periods that can stack. Three at the default rate is a 30% cut,
/// which is about as far as an automatic decision should go — past that the
/// programme is not a layoff away from the truth, it is stale, and the user
/// should be setting the weights themselves.
const kMaxLayoffPeriods = 3;

/// The furthest a layoff may cut a target, whatever the settings say. A rule
/// that can drive a working weight to nothing is a rule with a bug in it.
const kMaxLayoffCutPercent = 90;

/// A proposed back-off after a gap: how long you were away, how many whole
/// threshold-periods that came to, and the resulting cut as a percentage.
typedef LayoffDeload = ({int gapDays, int periods, int percent});

/// The rules as the user has them set: the gap that triggers a back-off, and
/// how deep a cut each period away is worth.
typedef LayoffSettings = ({int days, int percent});

/// Whole days from [from] to [to], counted on the calendar rather than in
/// elapsed hours.
///
/// Normalised through UTC so the two clock changes a year cannot make a day
/// 23 or 25 hours long and round a gap the wrong way: "last trained Tuesday,
/// today is Thursday" is two days in March as much as in June.
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// The back-off a [gapDays]-long absence earns, or null for none.
///
/// Null covers all three ways there is nothing to do: the feature switched off
/// ([thresholdDays] of zero), a cut of nothing configured, and — the common
/// case — a gap that simply is not long enough to matter yet.
///
/// The cut scales with the gap in whole periods, so at the defaults two weeks
/// off is 10% and two months off is 30% (the [kMaxLayoffPeriods] cap), not the
/// 40% the arithmetic alone would give.
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

/// [current] cut by [percent], landed on a value the mode can actually be
/// trained at and never taken below its floor.
///
/// Rounded *down* in every mode: a back-off that quietly gives back a kilo of
/// the cut it just announced is not the back-off the user agreed to. Weight
/// lands on half kilos, because 2.5 kg is the smallest plate pair most gyms
/// own and 78.3 kg is not a weight anybody can load.
double deloadedTarget(double current, int percent, ProgressionMode mode) {
  final cut = current * (100 - percent) / 100;
  final landed = switch (mode) {
    ProgressionMode.weight => (cut * 2).floorToDouble() / 2,
    ProgressionMode.reps || ProgressionMode.time => cut.floorToDouble(),
  };
  return landed < mode.floor ? mode.floor : landed;
}
