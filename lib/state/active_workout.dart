import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/db_provider.dart';

/// One set row during a live workout. Weights are in kilograms; the UI converts
/// to the display unit.
///
/// A set is measured either in reps done or, when [timed], in seconds held —
/// [goal] and [logged] carry whichever it is. They are one pair rather than two
/// because everything around them (did you hit it, what colour is the row, does
/// it count as a success) is the same question either way.
///
/// The goal is fixed by the template and cannot be edited from the logging
/// screen — it is what you set out to do, and rewriting it after the fact would
/// erase the only thing worth recording about a set you missed. What you
/// actually did lives in [logged] (null until the set is logged) and [weight]
/// (editable, because sometimes you have to deload mid-session).
class SetEntry {
  SetEntry({
    required this.goal,
    this.goalWeight,
    this.timed = false,
    double? weight,
    this.logged,
  }) : weight = weight ?? goalWeight ?? 0;

  /// The target from the template — reps, or seconds when [timed]. Immutable.
  final int goal;

  /// True when this set is held for time rather than counted in reps.
  final bool timed;

  /// The weight the template suggests, in kg. Null when it suggests none.
  final double? goalWeight;

  /// The weight actually used, in kg.
  double weight;

  /// What was actually achieved — reps done, or seconds held when [timed].
  /// Null means the set has not been logged yet; 0 is a logged set where
  /// nothing was managed at all.
  int? logged;

  bool get done => logged != null;

  /// A logged set that came up short — under the goal, or at a weight below
  /// the suggested one. Deloading to finish a set is still a miss.
  bool get missedGoal =>
      done && (logged! < goal || weight < (goalWeight ?? 0) - 1e-9);

  /// The tap cycle: untouched → the goal → one rep fewer → … → 0 → untouched.
  ///
  /// The first tap claims the goal, which is the common case and costs one tap.
  /// Every tap after that is you admitting you fell a rep short.
  ///
  /// A timed set has no useful middle — nobody taps a plank down one second at
  /// a time — so it toggles between the goal and untouched, and leaves an
  /// exact duration to the type-in dialog.
  void cycle() {
    final v = logged;
    if (v == null) {
      logged = goal;
    } else if (!timed && v > 0) {
      logged = v - 1;
    } else {
      logged = null;
    }
  }
}

/// One exercise (with its sets) during a live workout.
class ExerciseEntry {
  ExerciseEntry({
    required this.exerciseId,
    required this.name,
    required this.muscle,
    required this.sets,
    this.itemId,
    this.mode = ProgressionMode.weight,
    this.weightType = WeightType.machine,
    this.barKg,
    this.restSeconds = 90,
  });
  final int? exerciseId;

  /// The template slot this came from, so finishing can advance its
  /// progression. Null for an ad-hoc session, which has no target to move.
  final int? itemId;
  final String name;
  final String muscle;
  final List<SetEntry> sets;

  /// The axis this exercise advances along, carried from the template.
  final ProgressionMode mode;

  /// How the load is arranged, carried from the library — see [WeightType].
  /// What decides whether the screen can say what goes on the bar.
  final WeightType weightType;

  /// This exercise's own bar, in kg, or null for the gym's default.
  final double? barKg;

  /// The load the next set will be done at: the first set still unlogged, or
  /// the last one when they are all in.
  ///
  /// What a plate breakdown should describe — the bar you are about to load,
  /// not the one you loaded first. Null only when there are no sets at all.
  double? get nextWeight {
    if (sets.isEmpty) return null;
    for (final s in sets) {
      if (!s.done) return s.weight;
    }
    return sets.last.weight;
  }

  /// Rest to start after a completed set (resolved from the routine/item).
  final int restSeconds;

  /// Whether this counts as a clean session for progression: every planned set
  /// logged, and none of them short.
  ///
  /// Skipping a set is a miss. The programme asked for four and got three —
  /// that is not the performance the next step up should be built on.
  bool get succeeded =>
      sets.isNotEmpty && sets.every((s) => s.done && !s.missedGoal);

  /// The load actually carried through the whole exercise: the *lightest* of
  /// the logged sets, or null if none were.
  ///
  /// The lightest, because that is the weight you held for every set. Putting
  /// an extra plate on one set and leaving the rest alone is a heavy single,
  /// not a new working weight — so 100/105/110 counts as 100, and 105/105/105
  /// counts as 105.
  double? get performedWeight {
    double? lightest;
    for (final s in sets) {
      if (!s.done) continue;
      if (lightest == null || s.weight < lightest) lightest = s.weight;
    }
    return lightest;
  }
}

/// Immutable-ish snapshot of the in-progress session. `rev` is bumped on every
/// mutation so Riverpod always sees a new value and rebuilds listeners, even
/// though the nested lists are edited in place.
class ActiveWorkout {
  ActiveWorkout({
    required this.routineId,
    required this.workoutId,
    required this.name,
    required this.startedAt,
    required this.exercises,
    required this.elapsed,
    this.notice,
    this.rev = 0,
  });

  final int? routineId;

  /// The template being performed, or null for an ad-hoc session.
  final int? workoutId;
  final String name;
  final DateTime startedAt;
  final List<ExerciseEntry> exercises;
  final int elapsed; // seconds

  /// Something the session needs to say for itself — currently only that its
  /// targets were cut on the way in after a layoff.
  ///
  /// It rides on the session rather than being a snackbar because a weight that
  /// dropped is a question the user will ask again halfway through the second
  /// exercise, by which time a snackbar is long gone.
  final String? notice;
  final int rev;

  int get totalSets => exercises.fold(0, (a, e) => a + e.sets.length);
  int get doneSets =>
      exercises.fold(0, (a, e) => a + e.sets.where((s) => s.done).length);
  int get missedSets =>
      exercises.fold(0, (a, e) => a + e.sets.where((s) => s.missedGoal).length);
  /// Load moved, in kg. Timed sets contribute nothing — a 60-second plank is
  /// not sixty reps of anything.
  double get volume => exercises.fold(
        0.0,
        (a, e) => a +
            e.sets.where((s) => s.done).fold(
                0.0, (b, s) => b + (s.timed ? 0 : s.weight * s.logged!)),
      );

  ActiveWorkout copyWith({int? elapsed}) => ActiveWorkout(
        routineId: routineId,
        workoutId: workoutId,
        name: name,
        startedAt: startedAt,
        exercises: exercises,
        elapsed: elapsed ?? this.elapsed,
        notice: notice,
        rev: rev + 1,
      );
}

class ActiveWorkoutController extends Notifier<ActiveWorkout?> {
  Timer? _timer;

  AppDatabase get _db => ref.read(databaseProvider);

  @override
  ActiveWorkout? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  /// Begins a live session from a workout template. Passing a null [workoutId]
  /// starts an empty ad-hoc session.
  ///
  /// [notice] is shown for the length of the session — see [ActiveWorkout.notice].
  /// The template is read *after* the caller has had its chance to change it,
  /// which is what lets a layoff deload land before the first set is drawn.
  Future<void> start({
    int? workoutId,
    required String name,
    String? notice,
  }) async {
    final exercises = <ExerciseEntry>[];
    int? routineId;
    if (workoutId != null) {
      final workout = await _db.workoutById(workoutId);
      routineId = workout.routineId;
      final routine = await _db.routineById(routineId);
      final items = await _db.itemsForWorkout(workoutId);
      for (final v in items) {
        final mode = v.item.progression;
        // The goal is the hold for a timed exercise, and otherwise the top of
        // the rep range or the fixed count. A to-failure set carries no upper
        // bound, so its goal is `repsMin` — the number you have to beat for
        // the set to count, which is exactly what "to failure" is asking.
        final goal =
            mode.timed ? v.item.holdSeconds : (v.item.repsMax ?? v.item.repsMin);
        final w = v.item.suggestedWeight;
        exercises.add(ExerciseEntry(
          exerciseId: v.exercise.id,
          itemId: v.item.id,
          name: v.exercise.name,
          muscle: v.exercise.muscleGroup,
          mode: mode,
          weightType: v.exercise.weightType,
          barKg: v.exercise.barWeight,
          restSeconds: v.item.restSeconds ?? routine.restSeconds,
          sets: List.generate(
            v.item.targetSets,
            (_) => SetEntry(goal: goal, goalWeight: w, timed: mode.timed),
          ),
        ));
      }
    }
    state = ActiveWorkout(
      routineId: routineId,
      workoutId: workoutId,
      name: name,
      startedAt: DateTime.now(),
      exercises: exercises,
      elapsed: 0,
      notice: notice,
    );
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = state;
      if (s != null) state = s.copyWith(elapsed: s.elapsed + 1);
    });
  }

  /// One tap on a set: see [SetEntry.cycle].
  void cycleSet(int ei, int si) {
    final s = state;
    if (s == null) return;
    s.exercises[ei].sets[si].cycle();
    state = s.copyWith();
  }

  void setWeight(int ei, int si, double value) {
    final s = state;
    if (s == null) return;
    s.exercises[ei].sets[si].weight = value;
    state = s.copyWith();
  }

  /// Types a result in directly — reps done, or seconds held on a timed set
  /// (the long-press escape hatch). A null [value] unlogs the set; anything
  /// else is clamped to zero or more.
  void setLogged(int ei, int si, int? value) {
    final s = state;
    if (s == null) return;
    s.exercises[ei].sets[si].logged =
        value == null ? null : (value < 0 ? 0 : value);
    state = s.copyWith();
  }

  /// Persists the session with only its completed sets, then advances each
  /// exercise's progression. Returns the new session id, or null if there was
  /// nothing to save.
  Future<int?> finish() async {
    final s = state;
    if (s == null) return null;
    _timer?.cancel();

    final rows = <SessionSetsCompanion>[];
    for (final e in s.exercises) {
      var n = 1;
      for (final set in e.sets) {
        if (!set.done) continue;
        rows.add(SessionSetsCompanion.insert(
          sessionId: 0, // replaced inside saveSession
          exerciseName: e.name,
          setNumber: n++,
          exerciseId: Value(e.exerciseId),
          weight: Value(set.weight),
          reps: Value(set.timed ? 0 : set.logged!),
          seconds: Value(set.timed ? set.logged! : null),
          done: const Value(true),
          // What it was aiming at, so a later reading of this set can tell a
          // hit from a miss without consulting a template that may have moved.
          goalReps: Value(set.timed ? 0 : set.goal),
          goalSeconds: Value(set.timed ? set.goal : null),
          goalWeight: Value(set.goalWeight),
        ));
      }
    }

    final id = await _db.saveSession(
      routineId: s.routineId,
      workoutId: s.workoutId,
      name: s.name,
      startedAt: s.startedAt,
      endedAt: DateTime.now(),
      durationSeconds: s.elapsed,
      totalVolume: s.volume,
      sets: rows,
    );

    // Progression moves only once the session it is based on is safely on
    // disk. A template that stepped up without the history to justify it is
    // harder to explain than one that lags a crash behind.
    for (final e in s.exercises) {
      final itemId = e.itemId;
      if (itemId != null) {
        await _db.advanceProgression(
          itemId,
          success: e.succeeded,
          performedWeight: e.performedWeight,
        );
      }
    }

    state = null;
    return id;
  }

  void discard() {
    _timer?.cancel();
    state = null;
  }
}

/// Formats a weight without a trailing ".0" (e.g. 80.0 -> "80", 12.5 -> "12.5").
String fmtWeight(double w) =>
    w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toStringAsFixed(1);
