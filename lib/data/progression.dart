/// Pure progression rules for weight, reps, and timed holds.
library;

/// The axis an exercise advances along. A per-exercise choice, because the
/// three cases genuinely differ: a squat gets heavier, a pull-up gets more
/// reps, a plank gets longer.
enum ProgressionMode {
  /// Add load at a fixed rep target.
  weight,

  /// Add reps at a fixed load.
  reps,

  /// Increase hold duration.
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

  /// Default amount to subtract on a deload.
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

/// The role a slot has in a GZCL program. Null on an ordinary slot.
enum GzclTier { t1, t2, t3 }

/// One base prescription in a configurable GZCL T1/T2 failure ladder.
class GzclStage {
  const GzclStage({required this.sets, required this.reps});

  final int sets;
  final int reps;

  @override
  bool operator ==(Object other) =>
      other is GzclStage && other.sets == sets && other.reps == reps;

  @override
  int get hashCode => Object.hash(sets, reps);
}

const gzclpT1Stages = [
  GzclStage(sets: 5, reps: 3),
  GzclStage(sets: 6, reps: 2),
  GzclStage(sets: 10, reps: 1),
];

const gzclpT2Stages = [
  GzclStage(sets: 3, reps: 10),
  GzclStage(sets: 3, reps: 8),
  GzclStage(sets: 3, reps: 6),
];

const defaultGzclT3AmrapTarget = 25;

String? encodeGzclStages(List<GzclStage> stages) => stages.isEmpty
    ? null
    : stages.map((stage) => '${stage.sets}x${stage.reps}').join(';');

List<GzclStage> decodeGzclStages(String? encoded) {
  if (encoded == null || encoded.isEmpty) return const [];
  final stages = <GzclStage>[];
  for (final part in encoded.split(';')) {
    final fields = part.split('x');
    if (fields.length != 2) continue;
    final sets = int.tryParse(fields[0]);
    final reps = int.tryParse(fields[1]);
    if (sets == null || reps == null || sets < 1 || reps < 1) continue;
    stages.add(GzclStage(sets: sets, reps: reps));
  }
  return stages;
}

/// A step up and a back-off, in the units of whatever they move.
typedef ProgressionRates = ({double increment, double deload});

/// Axis used to store progression rates. Names are persisted in the database.
enum RateAxis { weight, reps, time, advanced }

/// The rates kept for the axes a slot is not on, as the column holds them:
/// `weight:2.5:5;reps:1:2`.
///
/// Empty comes back as null rather than as an empty string, so "nothing kept"
/// is one value in the database instead of two.
String? encodeSparedRates(Map<RateAxis, ProgressionRates> rates) =>
    rates.isEmpty
    ? null
    : [
        for (final e in rates.entries)
          '${e.key.name}:${e.value.increment}:${e.value.deload}',
      ].join(';');

/// Decodes stored rates, ignoring malformed or unknown entries.
Map<RateAxis, ProgressionRates> decodeSparedRates(String? encoded) {
  final out = <RateAxis, ProgressionRates>{};
  if (encoded == null || encoded.isEmpty) return out;
  for (final part in encoded.split(';')) {
    final fields = part.split(':');
    if (fields.length != 3) continue;
    final axis = RateAxis.values.asNameMap()[fields[0]];
    final increment = double.tryParse(fields[1]);
    final deload = double.tryParse(fields[2]);
    if (axis == null || increment == null || deload == null) continue;
    out[axis] = (increment: increment, deload: deload);
  }
  return out;
}

/// How an exercise is measured and which progression axes it permits.
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

/// Whether a session met its target.
enum SessionVerdict {
  /// Every planned set logged, none short. Feeds the success streak.
  success,

  /// A set skipped, or one that came up short of what was asked.
  miss,
}

/// Number of consecutive successes required for a step up.
const defaultSuccessThreshold = 1;

/// Number of consecutive misses required for a deload.
const defaultFailureThreshold = 2;

/// The consecutive-outcome counters after a session, and how far the target
/// should move as a result. A [delta] of zero means hold and keep counting.
typedef ProgressionStep = ({int successes, int failures, double delta});

/// What advancing one slot actually moved: how far, in [axis]'s own unit.
///
/// The axis is reported rather than assumed because a slot taking reps and
/// weight in turn has two, and which of them a session paid out on is the whole
/// content of "what happened" — see `AppDatabase.advanceProgression`.
typedef ProgressionMove = ({double moved, ProgressionMode axis});

/// Folds one session outcome into progression counters.
ProgressionStep stepProgression({
  required SessionVerdict verdict,
  required int successes,
  required int failures,
  required int successThreshold,
  required int failureThreshold,
  required double increment,
  required double deload,
}) {
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

/// Where a cycle stands after a session, and what that did to the weight its
/// percentages are of. A [delta] of zero means the weight holds.
typedef CycleStep = ({int position, int misses, double delta});

/// Folds one session's outcome into a slot running a cycle.
///
/// A cycle progresses on two clocks and they are not the same clock. The weeks
/// move every session — that is what a cycle is, and skipping a day does not
/// skip its week, because the week belongs to the slot rather than to the
/// calendar. The *weight* those weeks are percentages of moves once, on the
/// session that brings the cycle round, because moving it mid-cycle would
/// change what every remaining week's percentage is taken from.
///
/// The verdict of a cycle is the misses in it, counted rather than streaked:
/// a bad week in the middle is still a bad week when the cycle closes three
/// sessions later, which a consecutive count would have forgiven. None at all
/// earns [increment]; [failureThreshold] of them costs [deload]; between the
/// two the weight holds, which is what a single bad night's sleep should cost.
///
/// [weeks] of zero is a cycle nobody has written yet — nothing to advance and
/// nothing to earn, rather than a division by nothing.
CycleStep stepCycle({
  required SessionVerdict verdict,
  required int position,
  required int misses,
  required int weeks,
  required int failureThreshold,
  required double increment,
  required double deload,
}) {
  final counted = misses + (verdict == SessionVerdict.miss ? 1 : 0);
  if (weeks <= 0) return (position: 0, misses: counted, delta: 0);

  final next = (position + 1) % weeks;
  if (next != 0) return (position: next, misses: counted, delta: 0);

  final delta = counted == 0
      ? increment
      : (counted >= failureThreshold ? -deload : 0.0);
  // A new cycle starts with fresh position and miss counts.
  return (position: 0, misses: 0, delta: delta);
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
