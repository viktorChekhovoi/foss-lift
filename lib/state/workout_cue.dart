/// What the session wants you to do at this moment, in one value.
///
/// The workout board never needed this: it draws the whole session at once and
/// lets your eye pick the row. A notification has one line, so something has to
/// decide *which* set is the next one — walking the warm-up rungs before an
/// exercise's working sets, skipping what is already logged, and moving on to
/// the next movement when one runs out.
///
/// That decision is the part most likely to be wrong, so it lives here as pure
/// arithmetic over [ActiveWorkout] rather than inside whatever draws it. It is
/// also the part that survives whatever the shade ends up being built with.
library;

import 'active_workout.dart';

/// Which of the four things is happening.
enum CueKind {
  /// A rest is running. What comes after it is still described, because "rest,
  /// then squat 100" is more use than "rest".
  resting,

  /// Ready to lift a counted set.
  lift,

  /// Ready to start a held set — a plank, a carry, a hang.
  hold,

  /// Nothing is left to do; every set is logged.
  finished,
}

/// One thing to do, addressed well enough to log it without the app.
///
/// [exercise] and [warmup] say where you are; [weightKg], [reps] and [seconds]
/// say what the set is. A counted set has [reps]; a held one has [seconds];
/// neither has both. [restLeft] is only set while [kind] is [CueKind.resting].
typedef WorkoutCue = ({
  CueKind kind,
  String exercise,
  bool warmup,
  int exerciseIndex,
  int setIndex,
  double? weightKg,
  int? reps,
  int? seconds,
  int? restLeft,
});

/// The next set of [session] that has not been logged, warm-ups first.
///
/// Returns null when the session is done. **Warm-ups come before the working
/// sets of the same exercise** and never across exercises: a ramp primes the
/// movement it belongs to, so an unlogged rung on exercise three is not what
/// you owe while you are still on exercise one.
WorkoutCue? nextUp(ActiveWorkout session, {int restLeft = 0}) {
  for (var ei = 0; ei < session.exercises.length; ei++) {
    final e = session.exercises[ei];

    // The ramp for this exercise, but only while its working sets are still
    // outstanding — a rung left unticked after the work is done is a rung
    // nobody is going back for.
    final workLeft = e.sets.any((s) => !s.done);
    if (workLeft) {
      for (var wi = 0; wi < e.warmups.length; wi++) {
        final w = e.warmups[wi];
        if (!w.done) {
          return _cue(session, e, ei, wi,
              warmup: true, entry: w, restLeft: restLeft);
        }
      }
    }

    for (var si = 0; si < e.sets.length; si++) {
      final s = e.sets[si];
      if (!s.done) {
        return _cue(session, e, ei, si,
            warmup: false, entry: s, restLeft: restLeft);
      }
    }
  }
  return (
    kind: CueKind.finished,
    exercise: '',
    warmup: false,
    exerciseIndex: -1,
    setIndex: -1,
    weightKg: null,
    reps: null,
    seconds: null,
    restLeft: null,
  );
}

WorkoutCue _cue(
  ActiveWorkout session,
  ExerciseEntry e,
  int ei,
  int si, {
  required bool warmup,
  required SetEntry entry,
  required int restLeft,
}) =>
    (
      // Resting outranks what comes next: it is the thing with a clock on it.
      kind: restLeft > 0
          ? CueKind.resting
          : (entry.timed ? CueKind.hold : CueKind.lift),
      exercise: e.name,
      warmup: warmup,
      exerciseIndex: ei,
      setIndex: si,
      // A bodyweight movement has no weight worth naming; a machine or bar has.
      weightKg: entry.weight > 0 ? entry.weight : null,
      reps: entry.timed ? null : entry.goal,
      seconds: entry.timed ? entry.goal : null,
      restLeft: restLeft > 0 ? restLeft : null,
    );

/// What "Missed" seeds the set to: one short of the goal.
///
/// Not zero, and not blank. Somebody tapping Missed got *most* of the set —
/// that is why they are reaching for a button rather than the app — so the
/// number is already close to right and lands gold rather than green. Never
/// below zero, and a held set is left alone: how long you held it is not a
/// number anything can guess.
int? missedSeed(WorkoutCue cue) {
  if (cue.reps == null) return null;
  final short = cue.reps! - 1;
  return short < 0 ? 0 : short;
}
