/// The progression rules: which number goes up when a session goes well, by
/// how much, and how many sessions it takes.
///
/// Deliberately free of drift and Flutter. Progression is the one part of the
/// app where a quiet arithmetic bug silently rewrites your training for months,
/// so the arithmetic lives on its own where it can be read and tested without a
/// database in the way.
library;

/// The axis an exercise advances along. A per-exercise choice, because the
/// three cases genuinely differ: a squat gets heavier, a pull-up gets more
/// reps, a plank gets longer.
enum ProgressionMode {
  /// Add load at a fixed rep target. The squat/bench case.
  weight,

  /// Add reps at a fixed load. The pull-up case.
  reps,

  /// Hold longer. The plank case — sets are measured in seconds, not reps.
  time;

  /// True when sets are measured in seconds held rather than reps done.
  bool get timed => this == ProgressionMode.time;

  /// How far the target moves on a step up, in this mode's own unit (kg for
  /// [weight], reps for [reps], seconds for [time]).
  ///
  /// One clean session earns a step; see [defaultSuccessThreshold].
  double get defaultIncrement => switch (this) {
        ProgressionMode.weight => 2.5,
        ProgressionMode.reps => 1,
        ProgressionMode.time => 5,
      };

  /// Twice the step up. A back-off has to land somewhere you can actually
  /// train from, and undoing only the last increment puts you straight back
  /// at the weight that just beat you.
  double get defaultDeload => defaultIncrement * 2;

  /// The lowest a target may be driven by repeated back-offs. Zero load is a
  /// legitimate place to end up (the bodyweight movement you were adding a
  /// belt to); zero reps or zero seconds is not a set.
  double get floor => switch (this) {
        ProgressionMode.weight => 0,
        ProgressionMode.reps => 1,
        ProgressionMode.time => 5,
      };
}

/// One clean session earns a step up: the common case is a programme that adds
/// weight every time you finish the sets it asked for.
const defaultSuccessThreshold = 1;

/// Two misses in a row earn a back-off. One bad session is a bad night's sleep;
/// two is the weight.
const defaultFailureThreshold = 2;

/// The consecutive-outcome counters after a session, and how far the target
/// should move as a result. A [delta] of zero means hold and keep counting.
typedef ProgressionStep = ({int successes, int failures, double delta});

/// Folds one session's outcome into an exercise's progression counters.
///
/// Consecutive means consecutive: a success zeroes the failure count and a
/// failure zeroes the success count, so "three good sessions" cannot be
/// assembled out of three good sessions spread across a bad month. When a
/// threshold is reached the target moves and *both* counters reset — the next
/// step has to be earned from scratch rather than firing again every session.
ProgressionStep stepProgression({
  required bool success,
  required int successes,
  required int failures,
  required int successThreshold,
  required int failureThreshold,
  required double increment,
  required double deload,
}) {
  if (success) {
    final n = successes + 1;
    if (n >= successThreshold) {
      return (successes: 0, failures: 0, delta: increment);
    }
    return (successes: n, failures: 0, delta: 0);
  }
  final n = failures + 1;
  if (n >= failureThreshold) {
    return (successes: 0, failures: 0, delta: -deload);
  }
  return (successes: 0, failures: n, delta: 0);
}

/// Moves a target by [delta], never below the mode's [ProgressionMode.floor].
double advanceTarget(double current, double delta, ProgressionMode mode) {
  final next = current + delta;
  return next < mode.floor ? mode.floor : next;
}
