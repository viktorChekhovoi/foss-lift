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

/// How a movement is measured — a property of the exercise itself, not of any
/// program built on it. A squat is counted; a plank is held.
///
/// This is what decides which progression axes an exercise may use at all.
/// Offering to progress a deadlift by time, or a plank by reps, is offering a
/// choice with no right answer in it.
enum ExerciseMeasure {
  /// Counted in repetitions. Progresses on load or on reps.
  reps,

  /// Held for a duration. Progresses on time.
  time;

  /// The axes this measure permits, in the order they should be offered.
  List<ProgressionMode> get modes => switch (this) {
        ExerciseMeasure.reps => const [
            ProgressionMode.weight,
            ProgressionMode.reps,
          ],
        ExerciseMeasure.time => const [ProgressionMode.time],
      };

  /// The axis to start on: load for anything counted, time for anything held.
  ProgressionMode get defaultMode => modes.first;

  /// Forces [mode] into something this measure allows. Used when reading a
  /// stored slot back, so an exercise that changed measure cannot leave a
  /// workout logging reps against a hold.
  ProgressionMode coerce(ProgressionMode mode) =>
      modes.contains(mode) ? mode : defaultMode;
}

/// What one session did to the target it was judged against.
///
/// Two of the three answers are as old as the app: you did what was asked, or
/// you did not. [hold] exists for the slot that climbs a rep range before its
/// load moves, where "eight, seven, seven out of six-to-eight" is honestly
/// neither — the session was trained as prescribed and the top of the range was
/// not reached, and the program's answer to that is to come back and do it
/// again at the same weight.
enum SessionVerdict {
  /// Every planned set logged, none short. Feeds the success streak.
  success,

  /// Trained, inside the range, short of the top. Feeds neither streak.
  hold,

  /// A set skipped, or one that came up short of what was asked.
  miss,
}

/// One clean session earns a step up: the common case is a program that adds
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
///
/// [SessionVerdict.hold] is the exception that breaks neither rule: it returns
/// the counters exactly as they arrived. A session spent working up through a
/// rep range is not a good session and not a bad one, so it must not zero the
/// streak on either side of it — three weeks of climbing 6 to 8 would otherwise
/// spend a clean session that was already banked, or forgive a miss that is
/// still owed.
ProgressionStep stepProgression({
  required SessionVerdict verdict,
  required int successes,
  required int failures,
  required int successThreshold,
  required int failureThreshold,
  required double increment,
  required double deload,
}) {
  if (verdict == SessionVerdict.hold) {
    return (successes: successes, failures: failures, delta: 0);
  }
  if (verdict == SessionVerdict.success) {
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

/// Moves a target by [delta], never below the floor that applies to it.
///
/// The floor is the mode's own [ProgressionMode.floor], or [floorKg] where that
/// is higher — the empty bar of a barbell lift, which is the lightest thing it
/// can be loaded to. A bar-loaded target driven under its own bar by repeated
/// back-offs describes a session nobody can train, so the ladder stops on the
/// bar instead.
///
/// [floorKg] also applies on the way *up*, which is what corrects a target that
/// is already under its bar: whatever it says now, where it lands is a weight
/// that can be put on the bar.
double advanceTarget(
  double current,
  double delta,
  ProgressionMode mode, {
  double floorKg = 0,
}) {
  final floor = floorKg > mode.floor ? floorKg : mode.floor;
  final next = current + delta;
  return next < floor ? floor : next;
}
