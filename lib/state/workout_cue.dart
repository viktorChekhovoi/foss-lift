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
///
/// [exercise] is the canonical English name and [exerciseSeedKey] the movement's
/// seed key, exactly as [ExerciseEntry] carries them: whatever renders the cue
/// resolves the pair with `seededName`, so the notification names a starter
/// movement in the app's language rather than in the one it was seeded in.
///
/// [setIndex] and [setCount] are the position *within the list this set belongs
/// to* — the warm-up rungs for a rung, the working sets for a working set.
/// Four identical sets of bench read identically from a pocket without them.
typedef WorkoutCue = ({
  CueKind kind,
  String exercise,
  String? exerciseSeedKey,
  bool warmup,
  int exerciseIndex,
  int setIndex,
  int setCount,
  double? weightKg,
  int? reps,
  int? seconds,
  int? restLeft,
});

/// The next set of [session] that has not been logged, warm-ups first.
///
/// **The exercise you are working comes before the one the template lists
/// first.** Somebody who starts on the third movement because the bench is busy
/// is on the third movement, and a cue pinned to the untouched first one is
/// wrong for as long as they stay there — so [_inProgress] is asked before
/// template order is. Template order is what answers when nothing is in
/// progress: at the start of a session, and again each time the exercise you
/// were on runs out of work.
///
/// Returns null when the session is done. **Warm-ups come before the working
/// sets of the same exercise** and never across exercises: a ramp primes the
/// movement it belongs to, so an unlogged rung on exercise three is not what
/// you owe while you are still on exercise one.
///
/// **A superset is walked across its movements, not down them** — see
/// [_outstandingInGroup]. The unit of progress is the group rather than the
/// exercise, which is why both loops below are over groups; a group of one is an
/// ordinary exercise and comes out exactly where it always did.
WorkoutCue? nextUp(ActiveWorkout session, {int restLeft = 0}) {
  final groups = session.supersetGroupList;
  final working = _inProgress(session);
  if (working != null) {
    final here = _outstandingInGroup(
      session,
      session.supersetGroupOf(working),
      restLeft,
    );
    if (here != null) return here;
  }
  for (final group in groups) {
    final cue = _outstandingInGroup(session, group, restLeft);
    if (cue != null) return cue;
  }
  return (
    kind: CueKind.finished,
    exercise: '',
    exerciseSeedKey: null,
    warmup: false,
    exerciseIndex: -1,
    setIndex: -1,
    setCount: 0,
    weightKg: null,
    reps: null,
    seconds: null,
    restLeft: null,
  );
}

/// The exercise being worked right now: the one whose most recently logged set
/// is the most recent in the session — a rung of its ramp counts, since ramping
/// is working the movement — and which still has working sets outstanding. Null
/// when nothing is under way.
///
/// **Recency, not position.** The two agree every time somebody works down the
/// board and part company when they go back up it to a movement they had
/// skipped past: that movement is where they are now, and the one they left is
/// not. What orders them is [SetEntry.loggedOrder], the session's own count of
/// which set was logged after which.
int? _inProgress(ActiveWorkout session) {
  int? at;
  var latest = 0;
  for (var ei = 0; ei < session.exercises.length; ei++) {
    final e = session.exercises[ei];
    if (!e.sets.any((s) => !s.done)) continue;
    for (final s in [...e.sets, ...e.warmups]) {
      final when = s.loggedOrder;
      if (when != null && when > latest) {
        latest = when;
        at = ei;
      }
    }
  }
  return at;
}

/// The first thing a superset [group] still owes: every member's ramp, in
/// member order, then the working sets a round at a time. Null when the group
/// owes nothing.
///
/// **The ramps come before the first round.** You set both movements up and then
/// work them back to back — warming the second one up between the first round
/// and the second is not how anybody trains a pair, and it would put a rest in
/// the middle of a round.
///
/// **Then it is rounds, not columns**: set one of each movement, set two of
/// each, and so on. A movement with fewer sets than the one beside it simply
/// owes nothing in the later rounds and drops out of them, rather than holding
/// the round open or being caught up at the end.
///
/// A group of one is the ordinary case and short-circuits to [_outstandingIn],
/// so nothing about a day without supersets goes near the round arithmetic.
WorkoutCue? _outstandingInGroup(
  ActiveWorkout session,
  List<int> group,
  int restLeft,
) {
  if (group.length == 1) return _outstandingIn(session, group.first, restLeft);
  for (final ei in group) {
    final rung = _outstandingWarmupIn(session, ei, restLeft);
    if (rung != null) return rung;
  }
  var rounds = 0;
  for (final ei in group) {
    final sets = session.exercises[ei].sets.length;
    if (sets > rounds) rounds = sets;
  }
  for (var round = 0; round < rounds; round++) {
    for (final ei in group) {
      final e = session.exercises[ei];
      if (round >= e.sets.length) continue;
      final s = e.sets[round];
      if (s.done) continue;
      return _cue(session, e, ei, round,
          warmup: false, entry: s, count: e.sets.length, restLeft: restLeft);
    }
  }
  return null;
}

/// The first rung of exercise [ei]'s ramp still owed, on the same terms as
/// [_outstandingIn]: only while the movement's working sets are outstanding,
/// because a rung left unticked after the work is done is a rung nobody is
/// going back for.
WorkoutCue? _outstandingWarmupIn(ActiveWorkout session, int ei, int restLeft) {
  final e = session.exercises[ei];
  if (!e.sets.any((s) => !s.done)) return null;
  for (var wi = 0; wi < e.warmups.length; wi++) {
    final w = e.warmups[wi];
    if (!w.done) {
      return _cue(session, e, ei, wi,
          warmup: true,
          entry: w,
          count: e.warmups.length,
          restLeft: restLeft);
    }
  }
  return null;
}

/// The first thing exercise [ei] still owes: a rung of its ramp, then its
/// working sets. Null when it owes nothing. The ramp comes first, on the terms
/// [_outstandingWarmupIn] sets.
WorkoutCue? _outstandingIn(ActiveWorkout session, int ei, int restLeft) {
  final e = session.exercises[ei];
  final rung = _outstandingWarmupIn(session, ei, restLeft);
  if (rung != null) return rung;
  for (var si = 0; si < e.sets.length; si++) {
    final s = e.sets[si];
    if (!s.done) {
      return _cue(session, e, ei, si,
          warmup: false,
          entry: s,
          count: e.sets.length,
          restLeft: restLeft);
    }
  }
  return null;
}

WorkoutCue _cue(
  ActiveWorkout session,
  ExerciseEntry e,
  int ei,
  int si, {
  required bool warmup,
  required SetEntry entry,
  required int count,
  required int restLeft,
}) =>
    (
      // Resting outranks what comes next: it is the thing with a clock on it.
      kind: restLeft > 0
          ? CueKind.resting
          : (entry.timed ? CueKind.hold : CueKind.lift),
      exercise: e.name,
      exerciseSeedKey: e.seedKey,
      warmup: warmup,
      exerciseIndex: ei,
      setIndex: si,
      setCount: count,
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
