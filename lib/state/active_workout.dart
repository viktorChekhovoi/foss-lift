import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/db_provider.dart';

/// One set row during a live workout. Weights are in kilograms; the UI converts
/// to the display unit.
///
/// The goal is fixed by the template and cannot be edited from the logging
/// screen — it is what you set out to do, and rewriting it after the fact would
/// erase the only thing worth recording about a set you missed. What you
/// actually did lives in [reps] (null until the set is logged) and [weight]
/// (editable, because sometimes you have to deload mid-session).
class SetEntry {
  SetEntry({
    required this.goalReps,
    this.goalWeight,
    double? weight,
    this.reps,
  }) : weight = weight ?? goalWeight ?? 0;

  /// The rep target from the template. Immutable.
  final int goalReps;

  /// The weight the template suggests, in kg. Null when it suggests none.
  final double? goalWeight;

  /// The weight actually used, in kg.
  double weight;

  /// Reps actually completed. Null means the set has not been logged yet; 0 is
  /// a logged set where nothing was managed at all.
  int? reps;

  bool get done => reps != null;

  /// A logged set that came up short — fewer reps than the goal, or a weight
  /// below the suggested one. Deloading to finish a set is still a miss.
  bool get missedGoal =>
      done && (reps! < goalReps || weight < (goalWeight ?? 0) - 1e-9);

  /// The tap cycle: untouched → the goal → one rep fewer → … → 0 → untouched.
  ///
  /// The first tap claims the goal, which is the common case and costs one tap.
  /// Every tap after that is you admitting you fell a rep short.
  void cycle() {
    final r = reps;
    if (r == null) {
      reps = goalReps;
    } else if (r > 0) {
      reps = r - 1;
    } else {
      reps = null;
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
    this.restSeconds = 90,
  });
  final int? exerciseId;
  final String name;
  final String muscle;
  final List<SetEntry> sets;

  /// Rest to start after a completed set (resolved from the routine/item).
  final int restSeconds;
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
    this.rev = 0,
  });

  final int? routineId;

  /// The template being performed, or null for an ad-hoc session.
  final int? workoutId;
  final String name;
  final DateTime startedAt;
  final List<ExerciseEntry> exercises;
  final int elapsed; // seconds
  final int rev;

  int get totalSets => exercises.fold(0, (a, e) => a + e.sets.length);
  int get doneSets =>
      exercises.fold(0, (a, e) => a + e.sets.where((s) => s.done).length);
  int get missedSets =>
      exercises.fold(0, (a, e) => a + e.sets.where((s) => s.missedGoal).length);
  double get volume => exercises.fold(
        0.0,
        (a, e) => a +
            e.sets
                .where((s) => s.done)
                .fold(0.0, (b, s) => b + s.weight * s.reps!),
      );

  ActiveWorkout copyWith({int? elapsed}) => ActiveWorkout(
        routineId: routineId,
        workoutId: workoutId,
        name: name,
        startedAt: startedAt,
        exercises: exercises,
        elapsed: elapsed ?? this.elapsed,
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
  Future<void> start({int? workoutId, required String name}) async {
    final exercises = <ExerciseEntry>[];
    int? routineId;
    if (workoutId != null) {
      final workout = await _db.workoutById(workoutId);
      routineId = workout.routineId;
      final routine = await _db.routineById(routineId);
      final items = await _db.itemsForWorkout(workoutId);
      for (final v in items) {
        // The goal is the top of the rep range, or the fixed count.
        final reps = v.item.repsMax ?? v.item.repsMin;
        final w = v.item.suggestedWeight;
        exercises.add(ExerciseEntry(
          exerciseId: v.exercise.id,
          name: v.exercise.name,
          muscle: v.exercise.muscleGroup,
          restSeconds: v.item.restSeconds ?? routine.restSeconds,
          sets: List.generate(
            v.item.targetSets,
            (_) => SetEntry(goalReps: reps, goalWeight: w),
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

  /// Types a rep count in directly (the long-press escape hatch). A null
  /// [value] unlogs the set; anything else is clamped to zero or more.
  void setReps(int ei, int si, int? value) {
    final s = state;
    if (s == null) return;
    s.exercises[ei].sets[si].reps = value == null ? null : (value < 0 ? 0 : value);
    state = s.copyWith();
  }

  /// Persists the session with only its completed sets. Returns the new
  /// session id, or null if there was nothing to save.
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
          reps: Value(set.reps!),
          done: const Value(true),
          // What it was aiming at, so a later reading of this set can tell a
          // hit from a miss without consulting a template that may have moved.
          goalReps: Value(set.goalReps),
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
