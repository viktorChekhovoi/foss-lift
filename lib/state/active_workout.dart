import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/db_provider.dart';

/// One editable set row during a live workout. Weights are in kilograms; the
/// UI converts to the display unit.
class SetEntry {
  SetEntry({
    required this.weight,
    required this.reps,
    this.prevWeight,
    this.prevReps,
    this.done = false,
  });
  double weight; // kg
  int reps;
  final double? prevWeight; // kg, from the routine's suggested weight
  final int? prevReps;
  bool done;
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
  double get volume => exercises.fold(
        0.0,
        (a, e) =>
            a + e.sets.where((s) => s.done).fold(0.0, (b, s) => b + s.weight * s.reps),
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
        // Prefill with the top of the rep range (the goal), or the fixed count.
        final reps = v.item.repsMax ?? v.item.repsMin;
        final w = v.item.suggestedWeight;
        exercises.add(ExerciseEntry(
          exerciseId: v.exercise.id,
          name: v.exercise.name,
          muscle: v.exercise.muscleGroup,
          restSeconds: v.item.restSeconds ?? routine.restSeconds,
          sets: List.generate(
            v.item.targetSets,
            (_) => SetEntry(
              weight: w ?? 0,
              reps: reps,
              prevWeight: w,
              prevReps: reps,
            ),
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

  void toggleDone(int ei, int si) {
    final s = state;
    if (s == null) return;
    final set = s.exercises[ei].sets[si];
    set.done = !set.done;
    state = s.copyWith();
  }

  void setWeight(int ei, int si, double value) {
    final s = state;
    if (s == null) return;
    s.exercises[ei].sets[si].weight = value;
    state = s.copyWith();
  }

  void setReps(int ei, int si, int value) {
    final s = state;
    if (s == null) return;
    s.exercises[ei].sets[si].reps = value;
    state = s.copyWith();
  }

  void addSet(int ei) {
    final s = state;
    if (s == null) return;
    final sets = s.exercises[ei].sets;
    final last = sets.isNotEmpty ? sets.last : null;
    sets.add(SetEntry(weight: last?.weight ?? 0, reps: last?.reps ?? 10));
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
          reps: Value(set.reps),
          done: const Value(true),
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
