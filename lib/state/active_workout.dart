import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/warmup.dart';
import '../providers/db_provider.dart';
import '../services/rest_tone.dart';
import 'workout_cue.dart';

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
    List<SetEntry>? warmups,
    this.warmupCount = kDefaultWarmupSets,
    this.workingKg,
    this.warmupBarKg = 0,
    this.warmupLadder = const [],
    this.warmupRestSeconds = kWarmupRestSeconds,
  }) : warmups = warmups ?? <SetEntry>[];
  final int? exerciseId;

  /// The template slot this came from, so finishing can advance its
  /// progression. Null for an ad-hoc session, which has no target to move.
  final int? itemId;
  final String name;
  final String muscle;

  /// The working sets — the ones the template asked for and the only ones that
  /// count. Progression, volume, the verdict and the saved history all read
  /// this list and nothing else.
  final List<SetEntry> sets;

  /// The warm-up ramp shown *above* the working sets, kept apart so nothing here
  /// can distort what the working sets mean. Warm-ups are suggestions: they are
  /// never saved, never scored, and never move a target. Empty for anything
  /// without a working load to ramp toward (a plank, a bodyweight movement).
  final List<SetEntry> warmups;

  /// How many warm-up sets are asked for. Adjustable live; the ramp is
  /// regenerated from [workingKg]/[warmupBarKg]/[warmupLadder] when it changes.
  /// May exceed [warmups]`.length` when two steps want the same load.
  int warmupCount;

  /// The load this exercise is being worked at today, in kg — **one weight for
  /// the whole exercise**, not one per set.
  ///
  /// Deciding mid-session that today's squat is 100 rather than 95 is a fact
  /// about the exercise, so it is set once and the sets follow (see
  /// [ActiveWorkoutController.setWorkingWeight]). A single set may still stray
  /// from it — dropping the last one to finish it is a real thing — which is why
  /// [SetEntry.weight] survives alongside this.
  ///
  /// Starts as the template's suggestion, and is null when there is none: a
  /// bodyweight movement whose load is yours to pick, or a hold with nothing on
  /// it. The warm-up ramp climbs toward this, so changing it rebuilds the ramp.
  double? workingKg;

  /// The bar the warm-up ramp stands on — the resolved bar for a barbell lift,
  /// 0 for a machine or dumbbell where there is no empty bar to start from.
  final double warmupBarKg;

  /// The loads this exercise can actually be set to at this gym — every rung the
  /// ramp is allowed to land on. Rebuilt whenever [workingKg] moves (the ladder
  /// is capped at the working weight); the unit and rack it needs are carried on
  /// the session. See [loadLadder].
  List<LoadRung> warmupLadder;

  /// Rest after a warm-up set — shorter than [restSeconds], see
  /// [kWarmupRestSeconds].
  final int warmupRestSeconds;

  /// Rest after warm-up rung [wi]: the short [warmupRestSeconds] between rungs,
  /// but the exercise's full [restSeconds] after the last one.
  ///
  /// Between warm-ups you are changing the plates and catching your breath. After
  /// the heaviest rung the next thing you do is the working set, and the standard
  /// advice is to take that exercise's normal rest before it — warming up is not
  /// meant to be the fatigue you lift through.
  int restAfterWarmup(int wi) =>
      wi >= warmups.length - 1 ? restSeconds : warmupRestSeconds;

  /// Whether this exercise offers warm-ups at all — a weight-based slot with a
  /// working load. When false the warm-up section is not drawn.
  ///
  /// Derived rather than fixed at start: typing a load onto a bodyweight
  /// movement earns it a ramp, and taking one off takes the ramp away.
  bool get hasWarmups => !mode.timed && (workingKg ?? 0) > 0;

  /// Whether this exercise is done under a load worth naming — everything but a
  /// hold with nothing on it. What decides whether the board offers a working
  /// weight to set at all.
  bool get carriesLoad => !mode.timed || (workingKg ?? 0) > 0;

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

/// What a rest is *for* — what has to be set up before the next thing.
///
/// A rest is not one situation. Between warm-up rungs the bar changes every
/// time; after the last rung it changes again and this is the long one; between
/// working sets there is nothing to do but wait; and between exercises you are
/// walking to a different machine. The app knows which it is in, so the banner
/// may as well say.
enum RestPurpose {
  /// Another warm-up rung follows, at a different load.
  anotherWarmup,

  /// The ramp is done and the working sets are next.
  theWorkingSet,

  /// Another set of the same thing, at the same weight.
  anotherSet,

  /// This exercise is finished; a different movement is next.
  nextExercise,
}

/// [RestPurpose] plus whatever the caption needs to name. Weights stay in
/// kilograms — the view converts, like everywhere else.
typedef RestPrompt = ({RestPurpose purpose, double? weightKg, String? exercise});

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
    this.unit = 'kg',
    this.plates = const [],
    this.restLeft = 0,
    this.restPrompt,
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

  /// The display unit and the gym's plate rack, read once on the way in.
  ///
  /// They live on the session rather than being looked up again because a
  /// warm-up ramp has to be rebuildable the moment a working weight changes,
  /// and the board is not a place to be awaiting a database.
  final String unit;
  final List<PlateStack> plates;

  /// Something the session needs to say for itself — currently only that its
  /// targets were cut on the way in after a layoff.
  ///
  /// It rides on the session rather than being a snackbar because a weight that
  /// dropped is a question the user will ask again halfway through the second
  /// exercise, by which time a snackbar is long gone.
  final String? notice;

  /// Seconds left on the rest, and what the rest is for. **On the session, not
  /// on the screen.** The rest has to keep running while the logging screen is
  /// popped — that is the whole of "put the phone away and come back" — and the
  /// notification shade needs a countdown to show while the app is not even
  /// visible. A timer owned by a widget dies with the widget.
  final int restLeft;
  final RestPrompt? restPrompt;

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

  /// What the rest that starts after warm-up rung [wi] of exercise [ei] is for.
  ///
  /// Another rung means another load to put on; the last rung means the working
  /// weight, which is different again and is why this rest is the long one.
  RestPrompt restAfterWarmup(int ei, int wi) {
    final e = exercises[ei];
    if (wi < e.warmups.length - 1) {
      return (
        purpose: RestPurpose.anotherWarmup,
        weightKg: e.warmups[wi + 1].weight,
        exercise: null,
      );
    }
    return (
      purpose: RestPurpose.theWorkingSet,
      weightKg: e.nextWeight,
      exercise: null,
    );
  }

  /// What the rest that starts after working set [si] of exercise [ei] is for.
  ///
  /// The last set of an exercise is the one that ends it, so the next thing is
  /// a different movement — and that is a walk across the gym, not a wait.
  RestPrompt restAfterSet(int ei, int si) {
    final e = exercises[ei];
    final more = e.sets.skip(si + 1).any((s) => !s.done);
    if (more) {
      return (purpose: RestPurpose.anotherSet, weightKg: null, exercise: null);
    }
    // The next exercise is the next one with anything left to do — skipping
    // past any that are already finished.
    for (var i = ei + 1; i < exercises.length; i++) {
      if (exercises[i].sets.any((s) => !s.done)) {
        return (
          purpose: RestPurpose.nextExercise,
          weightKg: null,
          exercise: exercises[i].name,
        );
      }
    }
    // Nothing left anywhere: this was the last set of the session.
    return (purpose: RestPurpose.anotherSet, weightKg: null, exercise: null);
  }

  ActiveWorkout copyWith({
    int? elapsed,
    int? restLeft,
    RestPrompt? restPrompt,
    bool clearRest = false,
  }) =>
      ActiveWorkout(
        routineId: routineId,
        workoutId: workoutId,
        name: name,
        startedAt: startedAt,
        exercises: exercises,
        elapsed: elapsed ?? this.elapsed,
        unit: unit,
        plates: plates,
        restLeft: clearRest ? 0 : (restLeft ?? this.restLeft),
        restPrompt: clearRest ? null : (restPrompt ?? this.restPrompt),
        notice: notice,
        rev: rev + 1,
      );
}

class ActiveWorkoutController extends Notifier<ActiveWorkout?> {
  Timer? _timer;
  Timer? _restTimer;

  AppDatabase get _db => ref.read(databaseProvider);

  @override
  ActiveWorkout? build() {
    ref.onDispose(() {
      _timer?.cancel();
      _restTimer?.cancel();
    });
    return null;
  }

  // ---- The rest clock ------------------------------------------------------
  //
  // On the controller rather than the logging screen: the rest has to keep
  // running while the screen is popped, and the notification shade needs a
  // countdown to show while the app is not visible at all. A timer owned by a
  // widget dies with the widget.

  /// Starts the rest after a set, replacing whatever was running.
  void startRest(int seconds, RestPrompt? prompt) {
    final s = state;
    if (s == null) return;
    _restTimer?.cancel();
    state = s.copyWith(restLeft: seconds, restPrompt: prompt);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = state;
      if (now == null) return;
      if (now.restLeft <= 1) {
        stopRest();
      } else {
        state = now.copyWith(restLeft: now.restLeft - 1);
      }
    });
  }

  /// Adds [seconds] to a running rest, or takes them off. Going to or below
  /// zero ends it — see the −15s rule.
  void nudgeRest(int seconds) {
    final s = state;
    if (s == null || s.restLeft == 0) return;
    final left = s.restLeft + seconds;
    if (left <= 0) {
      stopRest();
    } else {
      state = s.copyWith(restLeft: left);
    }
  }

  /// Ends the rest. [tone] is false only where the sound would say the wrong
  /// thing — starting a hold, for instance, where it means "stop holding".
  void stopRest({bool tone = true}) {
    _restTimer?.cancel();
    _restTimer = null;
    final s = state;
    if (s == null) return;
    final wasResting = s.restLeft > 0;
    state = s.copyWith(clearRest: true);
    if (tone && wasResting) {
      ref.read(restToneProvider).play(
            enabled: ref.read(restSoundProvider).value ?? true,
          );
    }
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
    // A fresh session clears whatever the last one's summary was still holding
    // on to — the progression banner belongs to one finish only.
    ref.read(lastProgressionProvider.notifier).clear();
    final exercises = <ExerciseEntry>[];
    int? routineId;
    // Read once for the whole session: the warm-up ramp needs the gym's bar
    // and rack to know which loads a barbell lift can be built to, and the
    // unit to know what increments its dumbbells and stacks come in.
    final unit = await _db.watchWeightUnit().first;
    final stored = await _db.watchPlateSetup().first;
    final setup = resolvePlateSettings(
      unit: unit,
      kgRack: stored.kgRack,
      lbRack: stored.lbRack,
      barKg: stored.barKg,
    );
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
        // The bar this movement stands on, whatever it is loaded to today —
        // resolved here because it cannot change mid-session, unlike the ramp
        // above it.
        final warmupBar = v.exercise.weightType == WeightType.bar
            ? (v.exercise.barWeight ?? setup.barKg)
            : 0.0;
        final e = ExerciseEntry(
          exerciseId: v.exercise.id,
          itemId: v.item.id,
          name: v.exercise.name,
          muscle: v.exercise.muscleGroup,
          mode: mode,
          weightType: v.exercise.weightType,
          barKg: v.exercise.barWeight,
          restSeconds: v.item.restSeconds ?? routine.restSeconds,
          workingKg: w,
          warmupBarKg: warmupBar,
          sets: List.generate(
            v.item.targetSets,
            (_) => SetEntry(goal: goal, goalWeight: w, timed: mode.timed),
          ),
        );
        _rebuildRamp(e, unit: unit, inventory: setup.plates);
        exercises.add(e);
      }
    }
    state = ActiveWorkout(
      routineId: routineId,
      workoutId: workoutId,
      name: name,
      startedAt: DateTime.now(),
      exercises: exercises,
      elapsed: 0,
      unit: unit,
      plates: setup.plates,
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

  /// One set's own weight — the exception, for the set you have to drop to
  /// finish. The exercise's [ExerciseEntry.workingKg] is left alone: coming down
  /// for one set is not a decision about the rest of them.
  void setWeight(int ei, int si, double value) {
    final s = state;
    if (s == null) return;
    s.exercises[ei].sets[si].weight = value;
    state = s.copyWith();
  }

  /// The load this exercise is being worked at today. Every set still to come
  /// moves with it and the warm-up ramp is rebuilt to climb toward it — a ramp
  /// computed for a weight you are no longer doing is priming the wrong lift.
  ///
  /// Sets already logged keep the weight they were done at. What is in the log
  /// is what happened, not what you decided afterwards.
  void setWorkingWeight(int ei, double value) {
    final s = state;
    if (s == null) return;
    final e = s.exercises[ei];
    e.workingKg = value < 0 ? 0 : value;
    for (final set in e.sets) {
      if (!set.done) set.weight = e.workingKg!;
    }
    _rebuildRamp(e, unit: s.unit, inventory: s.plates);
    state = s.copyWith();
  }

  /// Logs the next outstanding set at its goal and starts the rest — what the
  /// shade's **Done** button does, without the app being open.
  ///
  /// It asks [nextUp] rather than being told which set, because the press came
  /// from a notification that may be a moment out of date; the session is the
  /// only thing that knows what is actually outstanding. A hold is refused: how
  /// long you held it is the measurement, and nothing here can invent it.
  void logNextAtGoal() {
    final s = state;
    if (s == null || s.restLeft > 0) return;
    final cue = nextUp(s);
    if (cue == null || cue.kind != CueKind.lift) return;

    final e = s.exercises[cue.exerciseIndex];
    final entry = cue.warmup ? e.warmups[cue.setIndex] : e.sets[cue.setIndex];
    entry.logged = entry.goal;
    state = s.copyWith();

    startRest(
      cue.warmup ? e.restAfterWarmup(cue.setIndex) : e.restSeconds,
      cue.warmup
          ? s.restAfterWarmup(cue.exerciseIndex, cue.setIndex)
          : s.restAfterSet(cue.exerciseIndex, cue.setIndex),
    );
  }

  /// Logs the next outstanding set one short of its goal — the shade's
  /// **Missed**. It lands gold rather than green, and the app is brought
  /// forward so the number can be corrected to what actually happened.
  ///
  /// No rest is started: you are about to be looking at the screen anyway, and
  /// a clock running while you correct a number is a clock you did not ask for.
  void logNextAsMissed() {
    final s = state;
    if (s == null) return;
    final cue = nextUp(s);
    if (cue == null) return;
    final seed = missedSeed(cue);
    if (seed == null) return;

    final e = s.exercises[cue.exerciseIndex];
    final entry = cue.warmup ? e.warmups[cue.setIndex] : e.sets[cue.setIndex];
    entry.logged = seed;
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

  /// Dials the warm-up ramp for one exercise up or down and rebuilds it. The
  /// count is clamped to 0..[kMaxWarmupSets].
  void setWarmupCount(int ei, int count) {
    final s = state;
    if (s == null) return;
    final e = s.exercises[ei];
    if (!e.hasWarmups) return;
    e.warmupCount =
        count < 0 ? 0 : (count > kMaxWarmupSets ? kMaxWarmupSets : count);
    _rebuildRamp(e, unit: s.unit, inventory: s.plates);
    state = s.copyWith();
  }

  /// Recomputes one exercise's warm-up ramp — the ladder of loads this gym can
  /// set, and the rungs the ramp lands on — from its current working weight and
  /// set count.
  ///
  /// **A rung already logged survives.** The plates were on the bar and you
  /// lifted it; a recompute redraws what is still ahead of you and leaves what
  /// is behind alone, which is the rule the working sets follow too. Rungs the
  /// new ramp no longer has (you asked for fewer) go with it.
  void _rebuildRamp(
    ExerciseEntry e, {
    required String unit,
    required List<PlateStack> inventory,
  }) {
    final was = [...e.warmups];
    e.warmups.clear();
    if (!e.hasWarmups) {
      e.warmupLadder = const [];
      return;
    }
    e.warmupLadder = loadLadder(
      type: e.weightType,
      unit: unit,
      maxKg: e.workingKg!,
      barKg: e.warmupBarKg,
      inventory: inventory,
    );
    final fresh = _warmupSetsFor(
        e.workingKg!, e.warmupBarKg, e.warmupLadder, e.warmupCount);
    for (var i = 0; i < fresh.length; i++) {
      e.warmups.add(i < was.length && was[i].done ? was[i] : fresh[i]);
    }
  }

  /// One tap on a warm-up set — the same cycle as a working set, but on the
  /// warm-up list and answering to nothing that counts.
  void cycleWarmup(int ei, int wi) {
    final s = state;
    if (s == null) return;
    s.exercises[ei].warmups[wi].cycle();
    state = s.copyWith();
  }

  void setWarmupWeight(int ei, int wi, double value) {
    final s = state;
    if (s == null) return;
    s.exercises[ei].warmups[wi].weight = value;
    state = s.copyWith();
  }

  /// Types a warm-up result in directly — the long-press escape hatch, mirroring
  /// [setLogged] for the warm-up list.
  void setWarmupLogged(int ei, int wi, int? value) {
    final s = state;
    if (s == null) return;
    s.exercises[ei].warmups[wi].logged =
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
    _restTimer?.cancel();
    _restTimer = null;

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
    final outcomes = <ProgressionOutcome>[];
    for (final e in s.exercises) {
      final itemId = e.itemId;
      if (itemId == null) continue;
      final moved = await _db.advanceProgression(
        itemId,
        success: e.succeeded,
        performedWeight: e.performedWeight,
      );
      // Read the slot back after advancing to see where progression left it —
      // the resulting target and the streaks — so the summary can explain it.
      final it = await _db.workoutItemById(itemId);
      if (it == null) continue; // slot deleted mid-session; nothing to say
      final mode = it.progression;
      final double? target = switch (mode) {
        ProgressionMode.weight => it.suggestedWeight,
        ProgressionMode.reps => it.repsMin.toDouble(),
        ProgressionMode.time => it.holdSeconds.toDouble(),
      };
      // A weight slot with no suggested weight is a bodyweight movement with no
      // target to move — it does not get to claim it progressed.
      if (target == null) continue;
      outcomes.add(ProgressionOutcome(
        name: e.name,
        mode: mode,
        moved: moved,
        target: target,
        successes: it.successStreak,
        failures: it.failStreak,
        successThreshold: it.successThreshold,
        failureThreshold: it.failureThreshold,
      ));
    }

    // Stash the deltas keyed by this session, for the summary to explain. Empty
    // means nothing had a target to move (an ad-hoc or all-bodyweight session),
    // and the summary shows no banner at all.
    ref.read(lastProgressionProvider.notifier).set(
          outcomes.isEmpty ? null : ProgressionReport(sessionId: id, outcomes: outcomes),
        );

    state = null;
    return id;
  }

  void discard() {
    _timer?.cancel();
    _restTimer?.cancel();
    _restTimer = null;
    state = null;
  }
}

/// Turns the pure warm-up ramp into live set rows. Each carries its suggested
/// weight and reps as its goal, exactly like a working set, so the same tap
/// cycle and weight field work on it — but it lives in [ExerciseEntry.warmups]
/// and so answers to nothing that counts.
List<SetEntry> _warmupSetsFor(
  double workingKg,
  double barKg,
  List<LoadRung> ladder,
  int count,
) =>
    [
      for (final s in computeWarmups(
        workingKg: workingKg,
        ladder: ladder,
        barKg: barKg,
        sets: count,
      ))
        SetEntry(goal: s.reps, goalWeight: s.weightKg, weight: s.weightKg),
    ];

/// Formats a weight without a trailing ".0" (e.g. 80.0 -> "80", 12.5 -> "12.5").
String fmtWeight(double w) =>
    w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toStringAsFixed(1);

/// What one exercise's progression did in the session that just finished, in
/// enough detail for the summary to say so without re-deriving anything.
///
/// [target] is the load/reps/seconds the slot now points at — where the next
/// session starts. [moved] is the signed change that got it there in the mode's
/// own unit (positive stepped up, negative backed off, zero held). The streaks
/// and thresholds are what lets a held exercise say how close it is to the next
/// move ("one more miss to a back-off").
class ProgressionOutcome {
  const ProgressionOutcome({
    required this.name,
    required this.mode,
    required this.moved,
    required this.target,
    required this.successes,
    required this.failures,
    required this.successThreshold,
    required this.failureThreshold,
  });

  final String name;
  final ProgressionMode mode;
  final double moved;
  final double target;
  final int successes;
  final int failures;
  final int successThreshold;
  final int failureThreshold;

  bool get steppedUp => moved > 1e-9;
  bool get backedOff => moved < -1e-9;
  bool get held => !steppedUp && !backedOff;
}

/// The progression changes from one finished session, tagged with its id.
///
/// The id is what keeps the banner honest: the summary shows it only for the
/// session it belongs to, so the same screen opened later from History — a
/// different id, or none — says nothing.
class ProgressionReport {
  const ProgressionReport({required this.sessionId, required this.outcomes});
  final int sessionId;
  final List<ProgressionOutcome> outcomes;
}

/// Whether the rest timer sounds when it ends. Read as `.value ?? true` — on is
/// the default, and a frame before the settings row arrives is not a reason to
/// stay quiet.
///
/// Here rather than in `providers.dart` because the rest clock is on the
/// controller below and would otherwise import the file that imports it.
final restSoundProvider = StreamProvider<bool>((ref) {
  return ref.watch(databaseProvider).watchRestSound();
});

/// The one player for the rest tone, disposed with the scope that made it. One
/// instance rather than one per rest: an `AudioPlayer` holds a platform
/// resource, and a session is dozens of rests.
final restToneProvider = Provider<RestTone>((ref) {
  final tone = RestTone();
  ref.onDispose(tone.dispose);
  return tone;
});

/// Holds the [ProgressionReport] from the last finish until the summary consumes
/// it. Written by [ActiveWorkoutController] on finish, cleared on the next start
/// and by the summary once it has been shown.
class LastProgressionController extends Notifier<ProgressionReport?> {
  @override
  ProgressionReport? build() => null;

  void set(ProgressionReport? report) => state = report;
  void clear() => state = null;
}

final lastProgressionProvider =
    NotifierProvider<LastProgressionController, ProgressionReport?>(
  LastProgressionController.new,
);

/// Whether the live logging screen is the one on screen right now. Set by
/// `WorkoutScreen` as it mounts and unmounts, and read by the resume overlay to
/// know not to float its pill over the very screen the pill leads to.
///
/// This is a lifecycle fact, not a route string: go_router pushes `/session`
/// imperatively, and an imperative push does not reliably show up in the
/// reported location, so asking "is the path /session?" gives the wrong answer
/// on a device. Asking the screen itself does not.
class WorkoutScreenVisible extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool visible) => state = visible;
}

final workoutScreenVisibleProvider =
    NotifierProvider<WorkoutScreenVisible, bool>(WorkoutScreenVisible.new);
