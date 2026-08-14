/// How long a training day will take, worked out from the template alone.
///
/// Deliberately free of drift and Flutter, like the other rule modules
/// ([progression], [plates], [layoff], [warmup]): it reads a list of
/// [WorkoutItem] rows and the routine's default rest, and hands back a
/// duration. Nothing here touches the database or a screen.
///
/// **What the estimate is made of.** A workout is a sequence of efforts with
/// rest between them, so that is what is counted:
///
/// - **Working sets** — [WorkoutItemTarget.setCount] of them, each costing
///   [kSecondsPerRep] per planned rep (a range is planned at its top end, the
///   same goal a live set is given) plus [kSetSetupSeconds] of getting into
///   position. A held slot costs its [WorkoutItem.holdSeconds] instead.
/// - **Warm-up rungs** — a weight slot with a load gets the setting's worth of
///   rungs in front of its working sets ([kDefaultWarmupSets] until it is
///   changed), priced through [warmupReps] at the fractions the ramp aims for.
///   See "the rungs are assumed" below.
/// - **Rest** — the slot's own [WorkoutItem.restSeconds], or the routine's
///   default where it has none; [kWarmupRestSeconds] between warm-up rungs, and
///   the full rest after the last rung because the working set is next
///   (`ExerciseEntry.restAfterWarmup`). The very last set of the day is followed
///   by nothing — you are finished. **A superset gets one rest per round rather
///   than one per set**, because its movements are performed back to back; the
///   rest is the closing movement's, exactly as the live session takes it.
///
/// **Where the numbers come from.** [kSecondsPerRep] is three seconds, which is
/// the middle of the tempo strength programs actually prescribe: roughly one
/// second up and two down (a 2-0-1 tempo), the cadence NSCA guidance describes
/// for a controlled repetition. [kSetSetupSeconds] is the ten seconds either
/// side of the set that no rep counts — walking in, unracking, racking. Both are
/// coarse on purpose: the output is rounded to five minutes by
/// [estimateMinutes], and a per-rep figure argued to the half-second would not
/// move it.
///
/// **The rungs are assumed, not solved.** The real ramp depends on the plate
/// rack and the bar (see [computeWarmups]), and can come back shorter than
/// asked for when the ladder is coarse. Resolving that here would drag the gym's
/// inventory into a figure printed on a card, so the estimate prices the count
/// that was asked for at the fractions the ramp aims for. It errs high on a
/// coarse ladder, by well under one rounding step.
///
/// **It is not read from history.** [Sessions.durationSeconds] is wall-clock
/// from Start to Finish with no pause anywhere in the app, so a session left
/// running while you walk home records an hour that was never trained, and no
/// stored column tells that apart from a genuinely long day. Blending that in
/// would make the figure worse, not better — and a template-only estimate is
/// also the one a day you have never trained can carry.
library;

import 'dart:math' as math;

import 'database.dart';
import 'superset.dart';
import 'warmup.dart';

/// Seconds of work per planned rep. See the library doc for the tempo this
/// comes from.
const kSecondsPerRep = 3;

/// Seconds a set costs beyond its reps — walking in, unracking, racking.
const kSetSetupSeconds = 10;

/// How coarse the figure on screen is, in minutes. The estimate is an estimate;
/// showing it to the minute would claim a precision it does not have.
const kEstimateGranularityMinutes = 5;

/// What one set costs: the work itself plus the fixed setup around it. Either
/// [reps] at [kSecondsPerRep] each, or a [holdSeconds] hold.
int setSeconds({int reps = 0, int holdSeconds = 0}) =>
    kSetSetupSeconds + (holdSeconds > 0 ? holdSeconds : reps * kSecondsPerRep);

/// How long [items] will take, resting [routineRestSeconds] where a slot has no
/// rest of its own and opening each ramp with [warmupSets] rungs — the setting a
/// session seeds from, so the card and the session agree. [Duration.zero] when
/// there is nothing to do.
Duration estimateWorkoutDuration({
  required List<WorkoutItem> items,
  required int routineRestSeconds,
  int warmupSets = kDefaultWarmupSets,
}) {
  // The day flattened into what it actually is: an effort, then the rest that
  // follows it. Built in order so the trailing rest — the one you never take —
  // can be dropped at the end without special-casing the last exercise.
  final segments = <({int work, int rest})>[];

  // Slot by slot for an ordinary exercise, and round by round for a superset —
  // see `data/superset.dart`. A group of one is an ordinary exercise, so the two
  // cases share the arithmetic below rather than the loop above it.
  final groups = supersetGroups(
    normaliseJoins([for (final item in items) item.supersetWithPrevious]),
  );

  int restFor(WorkoutItem item) => item.restSeconds ?? routineRestSeconds;

  int workFor(WorkoutItem item) => item.progression.timed
      ? setSeconds(holdSeconds: item.holdSeconds)
      : setSeconds(reps: item.repsMax ?? item.repsMin);

  for (final group in groups) {
    // The ramps, movement by movement, before the first round opens — as the
    // live session walks them. Between rungs it is the short rest, and after a
    // movement's last rung its own rest, because working sets are what follow.
    for (final at in group) {
      final item = items[at];
      final rungs = warmupRungsFor(item, sets: warmupSets);
      for (var i = 0; i < rungs; i++) {
        segments.add((
          work: setSeconds(reps: warmupReps(_rungFraction(i, rungs))),
          rest: i == rungs - 1 ? restFor(item) : kWarmupRestSeconds,
        ));
      }
    }
    var rounds = 0;
    for (final at in group) {
      if (items[at].setCount > rounds) rounds = items[at].setCount;
    }
    for (var round = 0; round < rounds; round++) {
      // Everything in the round is done back to back and the rest comes at the
      // end of it, which is what makes a superset day shorter than the same
      // exercises listed one after another.
      final owing = [for (final at in group) if (round < items[at].setCount) at];
      for (final at in owing) {
        segments.add((
          work: workFor(items[at]),
          rest: at == owing.last ? restFor(items[at]) : 0,
        ));
      }
    }
  }

  if (segments.isEmpty) return Duration.zero;
  final total = segments.fold(0, (sum, s) => sum + s.work + s.rest);
  return Duration(seconds: total - segments.last.rest);
}

/// How many warm-up rungs a slot is priced for — [sets] of them, on the same
/// test the live session makes (`ExerciseEntry.hasWarmups`): a counted slot
/// carrying a load.
int warmupRungsFor(WorkoutItem item, {int sets = kDefaultWarmupSets}) =>
    !item.progression.timed && (item.suggestedWeight ?? 0) > 0 ? sets : 0;

/// The fraction of the working weight rung [i] of [count] aims for — evenly
/// from [kWarmupStartFraction] to [kWarmupTopFraction], and mid-range when
/// there is only one, exactly as [computeWarmups] places them.
double _rungFraction(int i, int count) {
  const start = kWarmupStartFraction;
  const top = kWarmupTopFraction;
  if (count <= 1) return (start + top) / 2;
  return start + (top - start) * i / (count - 1);
}

/// [d] as the number of minutes to show: rounded to
/// [kEstimateGranularityMinutes], and never rounded away to nothing — a day
/// with work in it takes some time, whatever the arithmetic says.
int estimateMinutes(Duration d) {
  if (d <= Duration.zero) return 0;
  const step = kEstimateGranularityMinutes;
  return math.max(step, ((d.inSeconds / 60) / step).round() * step);
}
