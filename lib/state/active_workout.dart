import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/superset.dart';
import '../data/warmup.dart';
import '../l10n/app_localizations.dart';
import '../providers/db_provider.dart';
import '../providers/providers.dart' show appLocalizationsProvider;
import '../services/rest_alarm.dart';
import '../services/rest_buzz.dart';
import '../services/rest_tone.dart';
import '../services/set_video_store.dart';
import '../services/workout_shade.dart'
    show pendingShadeActionsProvider, restIsOverLine;
import '../util/cardio_units.dart';
import '../util/units.dart';
import 'session_mirror.dart';
import 'workout_cue.dart';

/// One set row during a live workout. Weights are stored in kilograms; the UI converts them to the display unit. The template goal is immutable, while [logged] and [weight] record what happened.
class SetEntry {
  SetEntry({
    required this.goal,
    this.goalWeight,
    this.timed = false,
    double? weight,
    int? goalMin,
    this.amrap = false,
    this.targetRpe,
    this.actualRpe,
    this.logged,
    this.loggedOrder,
    this.videoPath,
    this.console = kNoConsoleMetrics,
  }) : weight = weight ?? goalWeight ?? 0,
       goalMin = goalMin ?? goal;

  /// The target from the template — reps, or seconds when [timed]. Immutable.
  final int goal;

  /// Minimum result required for this set to count as complete.
  final int goalMin;

  /// Whether the set has no upper rep limit.
  final bool amrap;

  /// True when this set is held for time rather than counted in reps.
  final bool timed;

  /// Prescribed and recorded effort in tenths (80 is RPE 8).
  final int? targetRpe;
  int? actualRpe;

  /// The weight the template suggests, in kg. Null when it suggests none.
  final double? goalWeight;

  /// The weight actually used, in kg.
  double weight;

  /// Reps completed or seconds held. Null means the set is not logged.
  int? logged;

  /// Log order within this session; null for an unlogged set. This is a counter, not a wall-clock timestamp.
  int? loggedOrder;

  /// Clip path relative to the app support directory, if recorded.
  String? videoPath;

  /// Optional metrics recorded by a cardio console for this set.
  ConsoleMetrics console;

  /// Whether any readout has been filled in on this set.
  bool get hasConsole => hasConsoleMetrics(console);

  bool get done => logged != null;

  /// A logged set that came up short — under the goal's floor, or at a weight
  /// below the suggested one. Deloading to finish a set is still a miss.
  bool get missedGoal => done && (logged! < goalMin || underWeight);

  /// A logged set done at less than the load it was set. Split out from
  /// [missedGoal] because the two failures read differently on the board:
  /// coming down in weight to finish the set is a miss whatever the reps did.
  bool get underWeight => done && weight < (goalWeight ?? 0) - 1e-9;

  /// Cycles the quick-log value. Timed sets toggle between goal and untouched; rep sets count down from the goal.
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

/// One exercise and its sets during a live workout.
class ExerciseEntry {
  ExerciseEntry({
    required this.exerciseId,
    required this.name,
    required this.muscle,
    required this.sets,
    this.seedKey,
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
    this.scheme = SetScheme.flat,
    this.schemePercent = kDefaultSchemePercent,
    this.customSets = const [],
    this.cycle = const [],
    this.cycleNames = const [],
    this.cyclePosition = 0,
    this.goalReps = 0,
    this.targetRpe,
    this.floorKg = 0,
    this.supersetWithPrevious = false,
    this.cardioMachine = false,
    this.unit = 'kg',
  }) : warmups = warmups ?? <SetEntry>[];
  final int? exerciseId;

  /// The unit *this* movement is read and typed in — the app's, or the one it
  /// was pinned to, resolved once at start like everything else the session
  /// snapshots. See `unitForExercise`.
  ///
  /// The board reads this rather than [ActiveWorkout.unit], which stays what a
  /// figure spanning the whole session is in.
  final String unit;

  /// Whether this movement is done on a console that reports speed, incline,
  /// resistance and distance — carried from the library at start, because it is
  /// a fact about the movement and the session is a snapshot of one. What
  /// decides whether the board offers the readouts on this exercise's rows at
  /// all. See `isCardioMachine`.
  final bool cardioMachine;

  /// Whether this exercise is trained in the same round as the one above it —
  /// carried straight from the slot. What makes a run of exercises a superset;
  /// see `data/superset.dart` and [ActiveWorkout.supersetGroupOf].
  final bool supersetWithPrevious;

  /// The template slot this came from, so finishing can advance its
  /// progression. Null for an ad-hoc session, which has no target to move.
  final int? itemId;

  /// The canonical English name. Screens render `seededName(l10n, seedKey,
  /// name)` — see `util/seed_names.dart`.
  final String name;

  /// The movement's seed key, carried through the session so the board, the
  /// shade and the rows written on Finish all name it in the app's language.
  final String? seedKey;

  final String muscle;

  /// The working sets — the ones the template asked for and the only ones that
  /// count. Progression, volume, the verdict and the saved history all read
  /// this list and nothing else.
  final List<SetEntry> sets;

  bool get usesRpe => sets.any((s) => s.targetRpe != null);

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

  // -- The set scheme ------------------------------------------------------
  // Carried rather than resolved once at start, because [workingKg] is
  // editable: moving it has to move the whole ladder, keeping the proportions,
  // and that means recomputing rather than scaling the numbers already there.

  /// How the sets differ from one another — see `data/set_scheme.dart`.
  final SetScheme scheme;
  final int schemePercent;
  final List<CustomSet> customSets;

  /// The weeks a cycle rotates through, and which of them this session is —
  /// see `data/set_scheme.dart`. Empty on every slot that is not on a cycle.
  final List<List<CustomSet>> cycle;
  final int cyclePosition;

  /// What those weeks are called, where anybody has named them.
  final List<String> cycleNames;

  /// Which week of how many this session is, counting from one, for the line
  /// under the exercise. Zero when there is no cycle to say anything about.
  int get cycleWeek => cycle.isEmpty ? 0 : (cyclePosition % cycle.length) + 1;
  int get cycleWeeks => cycle.length;

  /// Whether this exercise's sets are percentages of its working weight rather
  /// than of nothing — which is what makes that weight a training max on the
  /// board. Both written-out schemes, and only where there are rows.
  bool get runsPercentages => scheme == SetScheme.cycle
      ? cycle.isNotEmpty
      : (scheme == SetScheme.custom && customSets.isNotEmpty);

  /// What that week is called, or the empty string where it goes by its number.
  String get cycleWeekName => cycle.isEmpty
      ? ''
      : cycleNameAt(cycleNames, cyclePosition % cycle.length);

  /// The slot's own rep target, which every scheme but a custom one repeats.
  final int goalReps;
  final int? targetRpe;

  /// The lightest this exercise may be loaded to — the empty bar, or 0.
  final double floorKg;

  /// What each set is aiming at, given [workingKg] as the top of the ladder.
  List<SetTarget> targetsAt(double? topKg, String unit) => resolveSetTargets(
    scheme: scheme,
    sets: sets.length,
    goalReps: goalReps,
    topWeightKg: topKg,
    unit: unit,
    percent: schemePercent,
    custom: customSets,
    cycle: cycle,
    cyclePosition: cyclePosition,
    floorKg: floorKg,
    targetRpe: targetRpe,
  );

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
  ///
  /// **Not final.** It is the one number the builder can move under a running
  /// session — see [ActiveWorkoutController._takeTemplateChanges]. Rest names no
  /// row, so taking a new one re-files nothing; every other template edit waits
  /// for the next session.
  int restSeconds;

  /// Whether this counts as a clean session for progression: every planned set
  /// logged, and none of them short.
  ///
  /// Skipping a set is a miss. The program asked for four and got three —
  /// that is not the performance the next step up should be built on.
  bool get succeeded =>
      sets.isNotEmpty && sets.every((s) => s.done && !s.missedGoal);

  /// What this session did to the target — the whole exercise's answer, which is
  /// what progression is advanced with.
  ///
  /// Two-valued on every slot, the one taking reps and weight in turn included:
  /// there the goal each set carries is wherever the climb has got to inside the
  /// range, so "did you make it" is the same question it is anywhere else.
  SessionVerdict get verdict =>
      succeeded ? SessionVerdict.success : SessionVerdict.miss;

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

  /// The load this session actually carried, or null if it carried none.
  ///
  /// What a slot that arrived with no target at all takes as one — see
  /// `AppDatabase.advanceProgression`. It is [performedWeight] when sets were
  /// logged, on the same argument that makes the lightest set the load
  /// everywhere else, and otherwise [workingKg]: a weight set up on the board
  /// and then not lifted is still the decision that this exercise is loaded now.
  ///
  /// Zero is no load rather than a load of nothing. Every set of a push-up
  /// reports a weight of zero, and "the session carried 0 kg" must not
  /// establish a target on a movement nobody put a number on.
  double? get sessionLoadKg {
    final lifted = performedWeight;
    if (lifted != null && lifted > 0) return lifted;
    final chosen = workingKg;
    return chosen != null && chosen > 0 ? chosen : null;
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
///
/// [exercise] is the canonical English name and [exerciseSeedKey] its seed key,
/// carried as a pair the way every other name in the session is: the rest bar
/// renders `seededName(l10n, exerciseSeedKey, exercise)`, so "Set up Bench
/// Press, rest, then lift" names the movement in the language on screen.
typedef RestPrompt = ({
  RestPurpose purpose,
  double? weightKg,
  String? exercise,
  String? exerciseSeedKey,
});

/// Which row of the board a rest belongs to: the set whose logging started it.
///
/// A rest with no identity can only be stopped wholesale, which is right for
/// the case that matters — clearing the row you have just logged — and wrong
/// for the rarer one, where clearing some earlier set you had already moved on
/// from would take a countdown you were still taking.
typedef RestSetRef = ({int exercise, int set, bool warmup});

/// The one thing a session has to say for itself: its targets were cut on the
/// way in after a layoff, by [percent], after [days] away.
///
/// **Facts, not a sentence.** The notice is on screen for the length of a
/// workout, which is long enough to outlive a language switch — so the session
/// carries the two numbers and `WorkoutScreen` composes the line from the
/// catalogue every time it draws it.
typedef LayoffNotice = ({int percent, int days});

/// Immutable-ish snapshot of the in-progress session. `rev` is bumped on every
/// mutation so Riverpod always sees a new value and rebuilds listeners, even
/// though the nested lists are edited in place.
class ActiveWorkout {
  ActiveWorkout({
    this.seedKey,
    required this.routineId,
    required this.workoutId,
    required this.name,
    required this.startedAt,
    required this.exercises,
    required this.elapsed,
    this.unit = 'kg',
    this.plates = const [],
    this.barKg = kDefaultBarKg,
    this.warmupSets = kDefaultWarmupSets,
    this.restLeft = 0,
    this.restPrompt,
    this.restFor,
    this.restDone = false,
    this.notice,
    this.rev = 0,
  });

  final int? routineId;

  /// The template being performed, or null for an ad-hoc session.
  final int? workoutId;

  /// The training day's canonical English name — see [seedKey].
  final String name;

  /// The day's seed key, or null. Carried so the board, the shade and the
  /// session row written on Finish all name the day in the app's language.
  final String? seedKey;

  final DateTime startedAt;
  final List<ExerciseEntry> exercises;
  final int elapsed; // seconds

  /// The display unit and the gym's plate rack, read once on the way in.
  ///
  /// They live on the session rather than being looked up again because a
  /// warm-up ramp has to be rebuildable the moment a working weight changes,
  /// and the board is not a place to be awaiting a database.
  ///
  /// **This is the app-wide unit**, and what belongs in it is a figure that
  /// spans the session — the volume on the summary, a total. A weight belonging
  /// to one movement is read in [ExerciseEntry.unit], which is this unless that
  /// movement was pinned to another.
  final String unit;
  final List<PlateStack> plates;

  /// The bar every barbell lift in this session stands on, and how deep a
  /// warm-up ramp opens — read once on the way in, beside [unit] and [plates].
  ///
  /// They are on the session for the same reason those two are, and for one
  /// more: an exercise added to the template mid-session is built from these
  /// rather than from the settings as they stand now, so a rack emptied or a
  /// stepper moved halfway through cannot produce a ramp unlike the ones
  /// already on the board.
  final double barKg;
  final int warmupSets;

  /// Something the session needs to say for itself — currently only that its
  /// targets were cut on the way in after a layoff.
  ///
  /// It rides on the session rather than being a snackbar because a weight that
  /// dropped is a question the user will ask again halfway through the second
  /// exercise, by which time a snackbar is long gone.
  final LayoffNotice? notice;

  /// Seconds left on the rest, and what the rest is for. **On the session, not
  /// on the screen.** The rest has to keep running while the logging screen is
  /// popped — that is the whole of "put the phone away and come back" — and the
  /// notification shade needs a countdown to show while the app is not even
  /// visible. A timer owned by a widget dies with the widget.
  final int restLeft;
  final RestPrompt? restPrompt;

  /// The set this rest is for — see [RestSetRef]. Null for a rest nobody
  /// attributed, which is stopped by anything that stops a rest.
  final RestSetRef? restFor;

  /// The rest reached its end and nothing has moved on from it yet.
  ///
  /// [restLeft] is 0 and [restPrompt]/[restFor] are still the finished rest's,
  /// which is what lets the bar go on naming what the rest was for. It is not
  /// a rest — nothing is counting — so everything that asks "am I resting?"
  /// keeps asking [restLeft].
  final bool restDone;

  final int rev;

  /// The unit to say a cue's weight in: the unit of the movement it is about.
  ///
  /// The shade and the rest notification each name one exercise's next set, so
  /// they follow that exercise rather than the session — a pounds-pinned bench
  /// must not arrive in the pocket in kilograms. Falls back to the session's for
  /// a cue with no exercise behind it any more.
  String unitForCue(WorkoutCue cue) =>
      cue.exerciseIndex >= 0 && cue.exerciseIndex < exercises.length
      ? exercises[cue.exerciseIndex].unit
      : unit;

  int get totalSets => exercises.fold(0, (a, e) => a + e.sets.length);
  int get doneSets =>
      exercises.fold(0, (a, e) => a + e.sets.where((s) => s.done).length);
  int get missedSets =>
      exercises.fold(0, (a, e) => a + e.sets.where((s) => s.missedGoal).length);

  /// Load moved, in kg. Timed sets contribute nothing — a 60-second plank is
  /// not sixty reps of anything.
  double get volume => exercises.fold(
    0.0,
    (a, e) =>
        a +
        e.sets
            .where((s) => s.done)
            .fold(0.0, (b, s) => b + (s.timed ? 0 : s.weight * s.logged!)),
  );

  /// Records where [entry] falls in the order this session's sets were logged
  /// in — see [SetEntry.loggedOrder]. A no-op unless the edit changed whether
  /// the set is logged at all: correcting the count on a set you are already
  /// resting on is not you moving to it again.
  ///
  /// **Derived from the sets rather than from a counter beside them.** The
  /// stamps travel in the crash snapshot with the sets that carry them, so a
  /// session rebuilt after the process died hands out the next number from
  /// where it left off without a cursor having to be written down as well.
  void restamp(SetEntry entry, {required bool wasDone}) {
    if (entry.done == wasDone) return;
    entry.loggedOrder = entry.done ? _nextLogOrder : null;
  }

  /// One past the highest stamp handed out so far.
  int get _nextLogOrder {
    var top = 0;
    for (final e in exercises) {
      for (final s in e.sets) {
        if ((s.loggedOrder ?? 0) > top) top = s.loggedOrder!;
      }
      for (final s in e.warmups) {
        if ((s.loggedOrder ?? 0) > top) top = s.loggedOrder!;
      }
    }
    return top + 1;
  }

  // ---- Supersets -----------------------------------------------------------
  //
  // A superset is a run of consecutive exercises trained back to back: a set of
  // each, then the rest, then round again. The template says so with a join
  // between neighbours, and `data/superset.dart` turns those joins into groups.
  // Everything here is that arithmetic applied to the live board.

  /// One flag per exercise: joined to the one above it, or not. Normalised, so
  /// the first exercise is never joined to a movement that is not there.
  List<bool> get supersetJoins =>
      normaliseJoins([for (final e in exercises) e.supersetWithPrevious]);

  /// The exercises trained in the same round as [ei], in board order — `[ei]`
  /// alone for an exercise that stands on its own, which is nearly all of them.
  List<int> supersetGroupOf(int ei) => supersetGroupAt(supersetJoins, ei);

  /// The board's exercises as the groups they are performed in.
  List<List<int>> get supersetGroupList => supersetGroups(supersetJoins);

  /// The rest that follows logging one row of the board — how long, and what it
  /// is for.
  ///
  /// **Zero seconds means no rest at all**, which is what a superset is: you
  /// have just finished a set of one movement and the next movement of the group
  /// is what you do now, so there is no clock to start and nothing for a banner
  /// to say. The rest arrives at the end of the round, once every movement in
  /// the group has had its set, and it is the rest of the slot that closed the
  /// round.
  ///
  /// An exercise standing on its own takes the answer it always took, by the
  /// same arithmetic it always used — a group of one is not routed through the
  /// round logic, so nothing about an ordinary day depends on any of this.
  ({int seconds, RestPrompt? prompt}) restAfter(
    int ei,
    int index, {
    required bool warmup,
  }) {
    final e = exercises[ei];
    // A movement whose working sets are all logged is finished, and a ramp
    // belongs to work that is still ahead of you. Ticking a leftover rung
    // afterwards squares the board up; it is not the start of anything, so
    // there is nothing to rest for. Ahead of the group logic on purpose: it is
    // as true of a superset member as of an exercise on its own.
    if (warmup && e.sets.isNotEmpty && e.sets.every((s) => s.done)) {
      return (seconds: 0, prompt: null);
    }
    final group = supersetGroupOf(ei);
    if (group.length == 1) {
      return (
        seconds: warmup ? e.restAfterWarmup(index) : e.restSeconds,
        prompt: warmup ? restAfterWarmup(ei, index) : restAfterSet(ei, index),
      );
    }
    final next = _afterInGroup(group, ei, index, warmup: warmup);
    if (next == null) {
      // The group has nothing left: what follows is whatever comes after it,
      // which is the same question an ordinary exercise's last set asks.
      return (seconds: e.restSeconds, prompt: _nextExerciseAfter(group.last));
    }
    // Still inside the round — another movement of the group owes this very set
    // — so there is no rest and nothing for a banner to say.
    if (!warmup && !next.warmup && next.index == index) {
      return (seconds: 0, prompt: null);
    }
    return (
      seconds: warmup
          // Setting up the next rung is the same job whichever movement's rung
          // it is, so the short rest holds across the join. The exercise's own
          // rest is due once the ramps are behind you and the work is next.
          ? (next.warmup ? e.warmupRestSeconds : e.restSeconds)
          : e.restSeconds,
      prompt: _groupPrompt(next, ei, index, fromWarmup: warmup),
    );
  }

  /// The row of [group] that follows [ei]/[index] — **by the plan, not by what
  /// is logged**.
  ///
  /// What a rest is for is decided by what comes next in the round, and a row
  /// ticked out of order does not rewrite what follows the row you have just
  /// done. Null when the group has nothing after this one.
  ({int exercise, int index, bool warmup})? _afterInGroup(
    List<int> group,
    int ei,
    int index, {
    required bool warmup,
  }) {
    final rest = group.skip(group.indexOf(ei) + 1);
    if (warmup) {
      if (index < exercises[ei].warmups.length - 1) {
        return (exercise: ei, index: index + 1, warmup: true);
      }
      // The ramps are walked movement by movement before the round opens.
      for (final at in rest) {
        if (exercises[at].warmups.isNotEmpty) {
          return (exercise: at, index: 0, warmup: true);
        }
      }
      for (final at in group) {
        if (exercises[at].sets.isNotEmpty) {
          return (exercise: at, index: 0, warmup: false);
        }
      }
      return null;
    }
    // The round runs across the group before it comes back round.
    for (final at in rest) {
      if (index < exercises[at].sets.length) {
        return (exercise: at, index: index, warmup: false);
      }
    }
    for (final at in group) {
      if (index + 1 < exercises[at].sets.length) {
        return (exercise: at, index: index + 1, warmup: false);
      }
    }
    return null;
  }

  /// What a group's rest is for, named from the row that follows it: a round
  /// comes back to the movement at the top of the group, which is not "the next
  /// exercise" in any sense position alone can express.
  RestPrompt _groupPrompt(
    ({int exercise, int index, bool warmup}) next,
    int ei,
    int index, {
    required bool fromWarmup,
  }) {
    if (next.exercise != ei) {
      final it = exercises[next.exercise];
      return (
        purpose: RestPurpose.nextExercise,
        weightKg: null,
        exercise: it.name,
        exerciseSeedKey: it.seedKey,
      );
    }
    final e = exercises[ei];
    if (next.warmup) {
      return (
        purpose: RestPurpose.anotherWarmup,
        weightKg: e.warmups[next.index].weight,
        exercise: null,
        exerciseSeedKey: null,
      );
    }
    final coming = e.sets[next.index].weight;
    if (fromWarmup) {
      return (
        purpose: RestPurpose.theWorkingSet,
        weightKg: coming,
        exercise: null,
        exerciseSeedKey: null,
      );
    }
    // Another set of the same movement. The weight is worth naming only when it
    // moved — a back-off or a ramp — exactly as it is outside a group.
    return (coming - e.sets[index].weight).abs() > 1e-9
        ? (
            purpose: RestPurpose.anotherSet,
            weightKg: coming,
            exercise: null,
            exerciseSeedKey: null,
          )
        : _justRest;
  }

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
        exerciseSeedKey: null,
      );
    }
    return (
      purpose: RestPurpose.theWorkingSet,
      weightKg: e.nextWeight,
      exercise: null,
      exerciseSeedKey: null,
    );
  }

  /// What the rest that starts after working set [si] of exercise [ei] is for.
  ///
  /// The last set of an exercise is the one that ends it, so the next thing is
  /// a different movement — and that is a walk across the gym, not a wait.
  RestPrompt restAfterSet(int ei, int si) {
    final e = exercises[ei];
    final next = e.sets.skip(si + 1).where((s) => !s.done).firstOrNull;
    if (next != null) {
      // Usually nothing: another set of the same thing at the same weight. On a
      // back-off or a ramp it is a different bar, and a rest bar that says
      // "just rest" while the plates have to change is the one case this line
      // exists to prevent.
      final changed = (next.weight - e.sets[si].weight).abs() > 1e-9;
      return changed
          ? (
              purpose: RestPurpose.anotherSet,
              weightKg: next.weight,
              exercise: null,
              exerciseSeedKey: null,
            )
          : _justRest;
    }
    return _nextExerciseAfter(ei);
  }

  /// The movement that follows the exercise at [ei] on the board: the next one
  /// with anything left to do, skipping past any already finished. [_justRest]
  /// when there is nothing left anywhere — this was the last set of the session.
  RestPrompt _nextExerciseAfter(int ei) {
    for (var i = ei + 1; i < exercises.length; i++) {
      if (exercises[i].sets.any((s) => !s.done)) {
        return (
          purpose: RestPurpose.nextExercise,
          weightKg: null,
          exercise: exercises[i].name,
          exerciseSeedKey: exercises[i].seedKey,
        );
      }
    }
    return _justRest;
  }

  /// A rest with nothing to set up: another set of the same thing at the same
  /// weight, or the end of the session.
  static const _justRest = (
    purpose: RestPurpose.anotherSet,
    weightKg: null,
    exercise: null,
    exerciseSeedKey: null,
  );

  ActiveWorkout copyWith({
    int? elapsed,
    int? restLeft,
    RestPrompt? restPrompt,
    RestSetRef? restFor,
    bool? restDone,
    bool clearRest = false,
  }) => ActiveWorkout(
    routineId: routineId,
    workoutId: workoutId,
    name: name,
    seedKey: seedKey,
    startedAt: startedAt,
    exercises: exercises,
    elapsed: elapsed ?? this.elapsed,
    unit: unit,
    plates: plates,
    barKg: barKg,
    warmupSets: warmupSets,
    restLeft: clearRest ? 0 : (restLeft ?? this.restLeft),
    restPrompt: clearRest ? null : (restPrompt ?? this.restPrompt),
    restFor: clearRest ? null : (restFor ?? this.restFor),
    restDone: clearRest ? false : (restDone ?? this.restDone),
    notice: notice,
    rev: rev + 1,
  );
}

class ActiveWorkoutController extends Notifier<ActiveWorkout?>
    with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _restTimer;

  /// The moment the running rest is due to end, or null when nothing is
  /// resting.
  ///
  /// **This, not `restLeft`, is what a rest actually is.** `restLeft` is the
  /// number the board and the shade read, recomputed from here on every tick;
  /// it stays on the state (and so in the crash snapshot) because that is what
  /// everything downstream already consumes and what an installed build's
  /// snapshot already carries. Deriving it rather than decrementing it is the
  /// difference between a rest that survives a gap and one that loses it.
  DateTime? _restEndsAt;

  /// Where the session clock was, and when — [ActiveWorkout.elapsed] is the
  /// first plus the time since the second.
  ///
  /// An offset rather than simply `now - startedAt`, because a session restored
  /// from a snapshot arrives with an `elapsed` the decoder has already aged and
  /// that is the number to carry on from.
  DateTime? _elapsedAnchor;
  int _elapsedBase = 0;

  AppDatabase get _db => ref.read(databaseProvider);

  /// The clock both of the above are read against — see [clockProvider].
  DateTime get _now => ref.read(clockProvider)();

  @override
  ActiveWorkout? build() {
    final binding = _binding;
    binding?.addObserver(this);
    ref.onDispose(() {
      binding?.removeObserver(this);
      _timer?.cancel();
      _restTimer?.cancel();
      _gone = true;
      _stopWatchingTemplate();
    });
    return null;
  }

  /// The binding, or null where there is none — a pure-Dart test that never
  /// started one. Nothing here needs it badly enough to fail over.
  WidgetsBinding? get _binding {
    try {
      return WidgetsBinding.instance;
    } catch (_) {
      return null;
    }
  }

  // ---- The rest clock ------------------------------------------------------
  //
  // On the controller rather than the logging screen: the rest has to keep
  // running while the screen is popped, and the notification shade needs a
  // countdown to show while the app is not visible at all. A timer owned by a
  // widget dies with the widget.

  /// Starts the rest after a set, replacing whatever was running.
  ///
  /// [forSet] is the row that started it — see [RestSetRef]. It is what lets
  /// un-logging *that* set take the rest with it while un-logging some other
  /// one leaves it alone.
  void startRest(int seconds, RestPrompt? prompt, {RestSetRef? forSet}) {
    final s = state;
    if (s == null) return;
    _restTimer?.cancel();
    // Through a cleared rest rather than straight onto the running one: the
    // prompt and the set are the old rest's, and a new rest that inherited
    // either would describe the set before it.
    _restEndsAt = _now.add(Duration(seconds: seconds));
    _commit(
      s
          .copyWith(clearRest: true)
          .copyWith(restLeft: seconds, restPrompt: prompt, restFor: forSet),
    );
    // Anything left over from the last rest — the ding for a rest this one
    // replaces is a ding for a rest that is over.
    ref.read(restAlarmProvider).clear();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) => _syncRest());
  }

  /// Puts [ActiveWorkout.restLeft] where the clock says it should be, and ends
  /// the rest if its moment has been and gone.
  ///
  /// Called from a 1-second timer, but nothing here assumes it was called on
  /// time or at all. A browser slows a hidden tab's timers to one a minute, a
  /// laptop lid loses however long it was shut, and a busy phone simply skips
  /// ticks — in every case the next call arrives late and this works out where
  /// the rest really stands rather than taking one second off.
  ///
  /// The rest ends **once**, on the first call after its moment, however many
  /// seconds were missed: [_endRest] cancels this timer, so there is no second
  /// pass to ring again.
  void _syncRest() {
    final s = state;
    final endsAt = _restEndsAt;
    if (s == null || endsAt == null) return;
    // Rounded up, so a rest with a fraction of a second on it still reads as
    // one rather than as zero-but-not-finished.
    final left = (endsAt.difference(_now).inMilliseconds / 1000).ceil();
    if (left <= 0) {
      _endRest();
      return;
    }
    if (left == s.restLeft) return;
    // Not committed: the snapshot ages its own clock on the way back in, so a
    // write a second would buy nothing. See [_commit].
    state = s.copyWith(restLeft: left);
  }

  /// Adds [seconds] to a running rest, or takes them off. Going to or below
  /// zero ends it — see the −15s rule.
  void nudgeRest(int seconds) {
    final s = state;
    if (s == null || s.restLeft == 0) return;
    final left = s.restLeft + seconds;
    if (left <= 0) {
      _endRest();
    } else {
      // The deadline is the rest; moving only the number would put the two out
      // of step and the next tick would undo the nudge.
      _restEndsAt = _now.add(Duration(seconds: left));
      _commit(s.copyWith(restLeft: left));
    }
  }

  /// Ends the rest by hand. [tone] is false only where the sound would say the
  /// wrong thing — starting a hold, where it means "stop holding".
  ///
  /// **Skipping does sound.** It used not to, from the shade, on the argument
  /// that somebody pressing Skip knows the rest is over. What that produced was a
  /// button with no feedback at all on the one screen that is in a pocket.
  void stopRest({bool tone = true}) => _endRest(announce: tone);

  /// Ends the rest.
  ///
  /// A rest that **finished** ([announce], which is every way of reaching zero
  /// that means "that is the rest done") leaves the bar behind saying so — see
  /// [ActiveWorkout.restDone]. A rest that was merely **abandoned** — a hold
  /// starting under it, the set that started it taken back to untouched — is
  /// cleared outright, because there is no finished rest to report. That is
  /// also what takes a bar left over from a finished rest away: the second call
  /// finds nothing running and clears.
  void _endRest({bool announce = true}) {
    _restTimer?.cancel();
    _restTimer = null;
    _restEndsAt = null;
    final s = state;
    if (s == null) return;
    if (s.restLeft > 0 && announce) {
      // The prompt and the set it was for stay: they are what the bar has left
      // to say, and what an un-log of that set is matched against.
      _commit(s.copyWith(restLeft: 0, restDone: true));
      _sayTheRestIsOver();
      return;
    }
    _commit(s.copyWith(clearRest: true));
    ref.read(restAlarmProvider).clear();
  }

  /// The one event this app makes a noise for.
  ///
  /// **The sound is always the tone**, on screen and in a pocket, because the
  /// tone is the only route with a volume in it. A notification channel's
  /// loudness belongs to the phone's alarm slider and nothing an app posts can
  /// move it, so a rest alert that rang from a channel could not be turned down
  /// — which is what made the setting worth nothing to somebody whose phone is
  /// in a pocket, the one case a rest timer is for. It does not have to ring
  /// from a channel: the live session already runs behind a foreground service,
  /// an app with one running may play audio while it is in the background, and
  /// so the same player sounds the same asset at the same gain either way.
  ///
  /// **The buzz goes with it, wherever the phone is.** It used to belong to the
  /// board, which meant it happened only while the board was mounted and, being
  /// touch feedback, often not even then — see [RestBuzz]. It is made here for
  /// the same reason the tone is: a phone in a bag is what a rest timer is for,
  /// and neither the screen nor the notification can be relied on to reach it.
  ///
  /// **What the pocket adds is the notification, not the noise** — something to
  /// look at when the phone comes out, silent because the sound has already been
  /// made. On screen it is left off entirely: the countdown is already in front
  /// of you.
  ///
  /// **Both are made here, at the moment the rest ends.** Nothing is handed to
  /// Android in advance: what keeps this isolate alive to reach this line is the
  /// foreground service — see [RestAlarm], and `workout_shade.dart` for the
  /// service itself. A rest that ends with the app not running at all is silent,
  /// and always was.
  /// **The words are resolved here, at the moment of ringing**, and handed to
  /// [RestAlarm] finished — see that class. Read rather than remembered: a rest
  /// can outlive a language switch, and a catalogue cached when the session
  /// started would announce the set in the language it started in.
  void _sayTheRestIsOver() {
    final alarm = ref.read(restAlarmProvider);
    ref.read(restToneProvider).play();
    ref.read(restBuzzProvider).buzz();
    if (ref.read(appOnScreenProvider)()) {
      alarm.clear();
      return;
    }
    final l10n = ref.read(appLocalizationsProvider);
    alarm.ring(
      channel: (
        name: l10n.restAlarmChannelName,
        description: l10n.restAlarmChannelDescription,
      ),
      title: l10n.restAlarmTitle,
      body: _whatComesNext(l10n),
    );
  }

  /// What the rest is over *for*. A notification that says only "rest done"
  /// makes you open the app to find out what for.
  String _whatComesNext(AppLocalizations l10n) {
    final s = state;
    if (s == null) return l10n.restAlarmBackToIt;
    final cue = nextUp(s);
    return restIsOverLine(l10n, cue, cue == null ? s.unit : s.unitForCue(cue));
  }

  // ---- The crash snapshot --------------------------------------------------
  //
  // See [SessionMirror]. The session is still held in memory and still writes its
  // history only on Finish; the mirror is a copy beside it so that Android killing
  // the process does not lose a workout.

  SessionMirror? get _mirror => ref.read(sessionMirrorProvider);

  /// Publishes a mutation and mirrors the session.
  ///
  /// Everything that changes the session goes through here. The per-second ticks
  /// do not: both clocks are rebuilt from the wall clock on the way back in, so
  /// writing them sixty times a minute would buy nothing.
  void _commit(ActiveWorkout next) {
    state = next;
    _mirror?.save(next);
  }

  /// Drops the snapshot — the session was finished or thrown away — and any
  /// shade press still waiting to be applied to it.
  ///
  /// The press goes with the session it was made in. Kept, a Missed pressed as
  /// the last set went in would be waiting for the next launch and would land on
  /// the first set of the next workout instead.
  void _forget() {
    _mirror?.clear();
    ref.read(pendingShadeActionsProvider).clear();
  }

  /// Rebuilds the session the last run left behind, if there was one.
  ///
  /// Called once on launch — see `main.dart`. Does nothing when a session is
  /// already live, so it cannot tread on one, and drops a snapshot it cannot
  /// read rather than leaving it to fail again on the next launch.
  Future<void> restore() async {
    if (state != null) return;
    final mirror = _mirror;
    if (mirror == null) return;
    final was = await mirror.load();
    if (was == null) {
      // Either there was nothing, or there was something unreadable. Dropping it
      // is right for both: nothing is a no-op, and a snapshot that cannot be read
      // would only fail again on the next launch.
      _forget();
      return;
    }
    state = was;
    _startClock();
    if (was.workoutId case final id?) _watchTemplate(id);
    // A rest with time left on it goes back on the clock. One that ran out while
    // the app was dead is simply over — and its alarm has already sounded, which
    // is why nothing is cleared here.
    if (was.restLeft > 0) {
      startRest(was.restLeft, was.restPrompt, forSet: was.restFor);
    }
  }

  /// The session's own clock, which runs for as long as the session does.
  ///
  /// Anchored where the session currently stands rather than started from zero,
  /// so a restored session carries on from the elapsed the snapshot decoder
  /// already aged instead of losing it.
  void _startClock() {
    _timer?.cancel();
    _elapsedBase = state?.elapsed ?? 0;
    _elapsedAnchor = _now;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _syncElapsed());
  }

  /// Puts [ActiveWorkout.elapsed] where the clock says it should be.
  ///
  /// The same rule as [_syncRest], and it matters for more than the number on
  /// screen: this is what Finish files the workout's length under, so a clock
  /// that lost a gap would write a workout down as shorter than it was and
  /// leave the history wrong for good.
  void _syncElapsed() {
    final s = state;
    final anchor = _elapsedAnchor;
    if (s == null || anchor == null) return;
    final elapsed = _elapsedBase + _now.difference(anchor).inSeconds;
    if (elapsed != s.elapsed) state = s.copyWith(elapsed: elapsed);
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
    LayoffNotice? notice,
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
    // How deep every ramp opens. Read once, like the rack: changing the setting
    // mid-session must not grow a ramp somebody is halfway up, and a stepper
    // moved during the session is a decision about today. None is an answer —
    // the app stops suggesting warm-ups altogether — and so is a day that has
    // switched its own ramps off, which is read below with the workout.
    var warmupSets = await _db.defaultWarmupSets();
    final setup = resolvePlateSettings(
      unit: unit,
      kgRack: stored.kgRack,
      lbRack: stored.lbRack,
      barKg: stored.barKg,
    );
    String? seedKey;
    if (workoutId != null) {
      final workout = await _db.workoutById(workoutId);
      routineId = workout.routineId;
      seedKey = workout.seedKey;
      // The day's own switch, and it wins over the app-wide count: a movement
      // added to this session later gets no ramp either, because the session
      // carries the number rather than re-asking.
      if (!workout.warmupsEnabled) warmupSets = 0;
      final routine = await _db.routineById(routineId);
      final items = await _db.itemsForWorkout(workoutId);
      for (final v in items) {
        exercises.add(
          _entryFor(
            v,
            unit: unit,
            plates: setup.plates,
            barKg: setup.barKg,
            warmupSets: warmupSets,
            defaultRestSeconds: routine.restSeconds,
          ),
        );
      }
    }
    _commit(
      ActiveWorkout(
        routineId: routineId,
        workoutId: workoutId,
        name: name,
        seedKey: seedKey,
        startedAt: DateTime.now(),
        exercises: exercises,
        elapsed: 0,
        unit: unit,
        plates: setup.plates,
        barKg: setup.barKg,
        warmupSets: warmupSets,
        notice: notice,
      ),
    );
    _startClock();
    if (workoutId != null) _watchTemplate(workoutId);
  }

  /// One template slot, turned into a live exercise with its sets and its ramp.
  ///
  /// The gym's numbers are passed in rather than read here, because the two
  /// callers have different ideas of "now": [start] has just read them, and
  /// [_takeTemplateChanges] must use the ones the session froze on the way in
  /// — see [ActiveWorkout.barKg].
  ExerciseEntry _entryFor(
    WorkoutItemView v, {
    required String unit,
    required List<PlateStack> plates,
    required double barKg,
    required int warmupSets,
    required int defaultRestSeconds,
    int? warmupCount,
  }) {
    final mode = v.item.progression;
    // What this one movement counts in, which is the session's unit unless it
    // has been pinned to another. Everything below reads it rather than the
    // argument: the targets, the ramp and the grid they land on all describe
    // the same bar, and reading half of them in one unit is how a set row and
    // its header end up disagreeing.
    final exUnit = unitForExercise(unit, v.exercise.unitOverride);
    // The goal is the hold for a timed exercise, and otherwise whatever the
    // slot's own target works out to — see [WorkoutItemTarget.goalReps], which
    // is where the four kinds of rep target are read in order.
    final goal = mode.timed ? v.item.holdSeconds : v.item.goalReps;
    final w = v.item.suggestedWeight;
    // The bar this movement stands on, whatever it is loaded to today —
    // resolved here because it cannot change mid-session, unlike the ramp
    // above it.
    final warmupBar = v.exercise.weightType == WeightType.bar
        ? (v.exercise.barWeight ?? barKg)
        : 0.0;
    // What each set actually opens at. Flat is every set at [w], which is
    // what it was before there were schemes; a back-off or a ramp is a
    // ladder off it — see `data/set_scheme.dart`.
    final targets = resolveSetTargets(
      scheme: v.item.scheme,
      // The week's own row count on a cycle, the stored count everywhere else
      // — see [WorkoutItemTarget.setCount].
      sets: v.item.setCount,
      goalReps: goal,
      topWeightKg: w,
      unit: exUnit,
      percent: v.item.schemePercent,
      custom: decodeCustomSets(v.item.customSets),
      cycle: v.item.cycleWeeks,
      cyclePosition: v.item.cyclePosition,
      floorKg: warmupBar,
      targetRpe: v.item.targetRpe,
    );
    final e = ExerciseEntry(
      exerciseId: v.exercise.id,
      itemId: v.item.id,
      name: v.exercise.name,
      seedKey: v.exercise.seedKey,
      muscle: v.exercise.muscleGroup,
      mode: mode,
      weightType: v.exercise.weightType,
      barKg: v.exercise.barWeight,
      restSeconds: v.item.restSeconds ?? defaultRestSeconds,
      // The same grid the set rows above landed on: the working weight and
      // the sets under it are one load, not two readings of it.
      workingKg: resolveTopWeight(
        topWeightKg: w,
        unit: exUnit,
        floorKg: warmupBar,
      ),
      warmupBarKg: warmupBar,
      unit: exUnit,
      // The movement's own ramp depth over the session's, unless the session's
      // is none — see [warmupCountFor]. A count passed in outranks both: it is
      // the stepper on the board, which is a decision about today.
      warmupCount:
          warmupCount ?? warmupCountFor(warmupSets, v.exercise.warmupSets),
      scheme: v.item.scheme,
      schemePercent: v.item.schemePercent,
      customSets: decodeCustomSets(v.item.customSets),
      cycle: v.item.cycleWeeks,
      cycleNames: v.item.cycleWeekNameList,
      cyclePosition: v.item.cyclePosition,
      goalReps: goal,
      floorKg: warmupBar,
      supersetWithPrevious: v.item.supersetWithPrevious,
      cardioMachine: v.exercise.isCardioMachine,
      sets: [
        for (final (setIndex, t) in targets.indexed)
          SetEntry(
            // A hold is counted in seconds and no scheme touches that; the
            // weight on it still ramps like anything else.
            goal: mode.timed ? goal : t.reps,
            goalMin: mode.timed ? null : t.minReps,
            amrap:
                !mode.timed &&
                (t.amrap ||
                    (v.item.gzclTier == GzclTier.t1 &&
                        setIndex == targets.length - 1)),
            goalWeight: t.weightKg,
            timed: mode.timed,
            targetRpe: t.targetRpe,
          ),
      ],
    );
    _rebuildRamp(e, inventory: plates);
    return e;
  }

  // ---- Template drift ------------------------------------------------------
  //
  // The session is a snapshot on purpose: it is what lets the board be edited
  // instantly and a crash mid-workout leave no half-written rows. The one edit
  // it takes while it runs is a movement added to the day, and it takes it at
  // the tail and nowhere else — every set the session holds is identified by its
  // position in the list, so a movement arriving in the middle would silently
  // re-file the sets already logged under the wrong exercise. Everything else —
  // a removal, a reorder, a rename, a slot re-configured — waits for the next
  // session.

  /// Told when the slot table changes, for as long as the app runs — see
  /// [_stopWatchingTemplate] for why it is not dropped sooner.
  ///
  /// **A bare update notification, not a query stream.** `watchItemsForWorkout`
  /// would do the same job in one line, but drift shares one query stream
  /// between every subscriber to the same query — so the session would be
  /// sitting on the identical stream the workout screens read through
  /// `workoutItemsProvider`, and whichever of the two subscribed first would
  /// decide when the other saw its first row. This is the session's own
  /// subscription to nothing but the news that something changed; the read that
  /// follows is its own.
  StreamSubscription<Set<TableUpdate>>? _templateWatch;

  /// The provider has been disposed and [state] can no longer be touched.
  bool _gone = false;

  /// **Both tables, because a rest lives on either of them.** A slot names its
  /// own rest or falls back to the routine's default, so a session watching only
  /// the slots would miss the stepper in the routine builder — which is the one
  /// most people reach for, since it sets the rest for the whole day at once.
  void _watchTemplate(int workoutId) {
    _stopWatchingTemplate();
    _templateWatch = _db
        .tableUpdates(
          TableUpdateQuery.onAllTables([_db.workoutItems, _db.routines]),
        )
        .listen((_) => unawaited(_rereadTemplate(workoutId)));
  }

  /// Reads the day back and hands it to [_takeTemplateChanges].
  ///
  /// [_gone] is checked either side of the read: the notification arrives from a
  /// stream that outlives the session, and the trip to the database gives the
  /// provider itself time to be disposed underneath it.
  Future<void> _rereadTemplate(int workoutId) async {
    if (_gone || state?.workoutId != workoutId) return;
    final items = await _db.itemsForWorkout(workoutId);
    if (_gone) return;
    await _takeTemplateChanges(items);
  }

  /// Drops the subscription — on the way into the next session, and when the
  /// provider itself goes.
  ///
  /// **Not when a session is abandoned.** Cancelling a drift stream schedules
  /// work of its own, and Abort is a tap that has to be over by the next frame.
  /// A subscription that outlives its session costs one callback that finds no
  /// session and returns.
  void _stopWatchingTemplate() {
    unawaited(_templateWatch?.cancel());
    _templateWatch = null;
  }

  /// Takes from [items] the two things a running session may safely take: the
  /// rest of a slot it is already carrying, and a movement put on the end of the
  /// day.
  ///
  /// **Rest is the only number here that moves.** Sets, targets and order are
  /// held by position on the board, so changing one under a session would re-file
  /// work somebody has already logged; a rest names no row, starts nothing and
  /// ends nothing, so the worst it can do is make the next countdown the length
  /// the user has just asked for — which is the whole point. A rest already
  /// running is left alone: it belongs to the set that started it.
  Future<void> _takeTemplateChanges(List<WorkoutItemView> items) async {
    final before = state;
    final workoutId = before?.workoutId;
    if (before == null || workoutId == null) return;
    // The rest a slot falls back on when it names none of its own — read the
    // same way [start] reads it.
    final routine = await _db.routineById(
      (await _db.workoutById(workoutId)).routineId,
    );
    // That was a trip to the database, and the session may have been finished,
    // thrown away or replaced while it ran — so the work below is done against
    // the session as it stands now.
    if (_gone) return;
    final s = state;
    if (s == null || s.workoutId != before.workoutId) return;
    final paired = _pairWithTemplate(s, items);

    var moved = false;
    for (final at in paired.matched.entries) {
      final rest = at.value.item.restSeconds ?? routine.restSeconds;
      if (s.exercises[at.key].restSeconds != rest) {
        s.exercises[at.key].restSeconds = rest;
        moved = true;
      }
    }
    for (final v in paired.extra) {
      s.exercises.add(
        _entryFor(
          v,
          // The session's own numbers, not the settings as they stand now: a
          // rack emptied or a stepper moved halfway through must not produce a
          // ramp unlike the ones already on the board.
          unit: s.unit,
          plates: s.plates,
          barKg: s.barKg,
          warmupSets: s.warmupSets,
          defaultRestSeconds: routine.restSeconds,
        ),
      );
      moved = true;
    }
    if (moved) _commit(s.copyWith());
  }

  /// The template lined up against the board: which row each slot the session is
  /// already carrying corresponds to, and the slots left over, in template order.
  ///
  /// **Movements counted off, not item ids compared.** Saving the workout editor
  /// deletes and reinserts every row, so every item id changes on any save at
  /// all — and an id diff would read a plain reorder as five additions and
  /// append the whole day to itself. What a slot is, to a session, is which
  /// movement it holds; so the template's movements are counted off against the
  /// ones the session is already carrying, in board order, and whatever is left
  /// over is what somebody added. A removal leaves nothing over, and neither
  /// does a reorder, a rename or a slot re-configured.
  ///
  /// The pairing a reorder produces is by movement rather than by position,
  /// which is the honest answer available: three slots of the same movement
  /// re-timed and re-ordered in one save hand their rests out in board order.
  ({Map<int, WorkoutItemView> matched, List<WorkoutItemView> extra})
  _pairWithTemplate(ActiveWorkout s, List<WorkoutItemView> items) {
    final held = <int, List<int>>{};
    for (var ei = 0; ei < s.exercises.length; ei++) {
      if (s.exercises[ei].exerciseId case final id?) {
        (held[id] ??= <int>[]).add(ei);
      }
    }
    final matched = <int, WorkoutItemView>{};
    final extra = <WorkoutItemView>[];
    for (final v in items) {
      final rows = held[v.exercise.id];
      if (rows == null || rows.isEmpty) {
        extra.add(v);
      } else {
        matched[rows.removeAt(0)] = v;
      }
    }
    return (matched: matched, extra: extra);
  }

  /// One edit to one row of the board — a working set, or a warm-up rung when
  /// [warmup].
  ///
  /// Everything that can change whether a set is logged goes through here, so
  /// the order of logging is recorded once rather than at each of the four
  /// places a row can be touched from.
  void _editEntry(
    int ei,
    int index, {
    required bool warmup,
    required void Function(SetEntry entry) edit,
  }) {
    final s = state;
    if (s == null) return;
    final e = s.exercises[ei];
    final entry = warmup ? e.warmups[index] : e.sets[index];
    final wasDone = entry.done;
    edit(entry);
    s.restamp(entry, wasDone: wasDone);
    _commit(s.copyWith());
  }

  /// One tap on a set: see [SetEntry.cycle].
  void cycleSet(int ei, int si) =>
      _editEntry(ei, si, warmup: false, edit: (e) => e.cycle());

  /// Hangs a freshly recorded clip on a set, replacing any clip it already had
  /// — one clip per set, so re-filming a set means the old take goes.
  ///
  /// The file is already on disk; this is only the pointer. Deleting the
  /// replaced file happens here rather than being left to the sweep, so
  /// re-filming a set five times does not sit on five files for a day.
  Future<void> attachVideo(int ei, int si, String relativePath) async {
    final s = state;
    if (s == null) return;
    final set = s.exercises[ei].sets[si];
    final replaced = set.videoPath;
    set.videoPath = relativePath;
    _commit(s.copyWith());
    if (replaced != null) {
      await ref.read(setVideoStoreProvider).delete(replaced);
    }
  }

  /// Drops the clip on a set, leaving the set itself untouched — a bad take is
  /// not a set that did not happen.
  Future<void> removeVideo(int ei, int si) async {
    final s = state;
    if (s == null) return;
    final set = s.exercises[ei].sets[si];
    final gone = set.videoPath;
    if (gone == null) return;
    set.videoPath = null;
    _commit(s.copyWith());
    await ref.read(setVideoStoreProvider).delete(gone);
  }

  /// Every clip this session is holding, saved or not.
  Iterable<String> get _clipPaths sync* {
    for (final e in state?.exercises ?? const <ExerciseEntry>[]) {
      for (final set in e.sets) {
        if (set.videoPath case final path?) yield path;
      }
    }
  }

  /// One set's own weight — the exception, for the set you have to drop to
  /// finish. The exercise's [ExerciseEntry.workingKg] is left alone: coming down
  /// for one set is not a decision about the rest of them.
  void setWeight(int ei, int si, double value) =>
      _editEntry(ei, si, warmup: false, edit: (e) => e.weight = value);

  /// Records optional set effort without logging or unlogging the set.
  void setRpe(int ei, int si, int? value) {
    final s = state;
    if (s == null || ei < 0 || ei >= s.exercises.length) return;
    final sets = s.exercises[ei].sets;
    if (si < 0 || si >= sets.length) return;
    sets[si].actualRpe = value?.clamp(60, 100);
    _commit(s.copyWith());
  }

  /// The load this exercise is being worked at today. Every set still to come
  /// moves with it and the warm-up ramp is rebuilt to climb toward it — a ramp
  /// computed for a weight you are no longer doing is priming the wrong lift.
  ///
  /// Sets already logged keep the weight they were done at. What is in the log
  /// is what happened, not what you decided afterwards.
  ///
  /// The number is put on the step the gym counts by before anything follows
  /// it, through the same resolver the set weights go through — see
  /// [resolveTopWeight]. A single set may still be moved to anything at all
  /// ([setWeight]); it is the *exercise's* weight that has to agree with the
  /// rows it produced.
  void setWorkingWeight(int ei, double value) {
    final s = state;
    if (s == null) return;
    final e = s.exercises[ei];
    e.workingKg = resolveTopWeight(
      topWeightKg: value < 0 ? 0 : value,
      unit: e.unit,
      floorKg: e.floorKg,
    );
    // Through the scheme, not straight onto every row: on a back-off or a ramp
    // the sets are a ladder, and moving its top has to move the rungs with it
    // rather than flatten them all onto the new number.
    final targets = e.targetsAt(e.workingKg, e.unit);
    for (var i = 0; i < e.sets.length; i++) {
      if (!e.sets[i].done) e.sets[i].weight = targets[i].weightKg ?? 0;
    }
    _rebuildRamp(e, inventory: s.plates);
    _commit(s.copyWith());
  }

  /// Writes what the console said on one set of a cardio machine.
  ///
  /// All four readouts at once, because that is how the panel that types them
  /// works: a field left blank is a null being written, so handing back
  /// [kNoConsoleMetrics] is how a set's numbers are cleared again.
  ///
  /// Not routed through [_editEntry]: nothing here can change whether a set is
  /// logged, so there is no logging order to restamp and no rest to start or
  /// take back. Typing the speed you ran at is not logging the set.
  void setConsole(int ei, int si, ConsoleMetrics metrics) {
    final s = state;
    if (s == null) return;
    if (ei < 0 || ei >= s.exercises.length) return;
    final sets = s.exercises[ei].sets;
    if (si < 0 || si >= sets.length) return;
    sets[si].console = metrics;
    _commit(s.copyWith());
  }

  /// Takes the workout's slot for the exercise at [ei] as it now stands, after
  /// the settings sheet on the board has written it.
  ///
  /// **Not [_takeTemplateChanges].** That one watches the tables and is
  /// deliberately conservative — it takes a rest and appends at the tail, and
  /// refuses everything else, because it cannot tell a reconfigured slot from a
  /// deleted one plus a new one, and guessing wrong re-files logged sets under
  /// the wrong movement. This is the other case: the sheet was opened *from* a
  /// row of the board, so which exercise changed is known rather than inferred,
  /// and the whole change can be taken safely.
  ///
  /// What the board takes: the rest, the working weight and every set still to
  /// come. What it will not touch is a set already logged — it keeps the weight
  /// and the goal it was done at, exactly as it does when only the weight is
  /// edited — and the slot cannot be cut below the sets already done, so a
  /// session that went further than planned never loses one.
  ///
  /// A silent no-op for an index off the board, and for an exercise with no slot
  /// behind it: there is nothing to read back.
  Future<void> reconfigure(int ei) async {
    final before = state;
    if (before == null || ei < 0 || ei >= before.exercises.length) return;
    final itemId = before.exercises[ei].itemId;
    final workoutId = before.workoutId;
    if (itemId == null || workoutId == null) return;

    final views = await _db.itemsForWorkout(workoutId);
    final view = views.where((v) => v.item.id == itemId).firstOrNull;
    if (view == null || _gone) return;
    final routine = await _db.routineById(
      (await _db.workoutById(workoutId)).routineId,
    );
    if (_gone) return;

    // Those were trips to the database, so the board is looked at again rather
    // than trusted from before them — the session may have been finished, thrown
    // away or replaced while they ran.
    final s = state;
    if (s == null || s.workoutId != workoutId) return;
    if (ei >= s.exercises.length) return;
    final old = s.exercises[ei];
    if (old.itemId != itemId) return;

    final fresh = _entryFor(
      view,
      // The session's own numbers, not the settings as they stand now — the
      // same reason [_takeTemplateChanges] passes these.
      unit: s.unit,
      plates: s.plates,
      barKg: s.barKg,
      warmupSets: s.warmupSets,
      // The stepper on the board is a decision about today and outranks both
      // the app-wide default and the movement's own count.
      warmupCount: old.warmupCount,
      defaultRestSeconds: routine.restSeconds,
    );
    _carryLoggedWork(from: old, to: fresh);
    s.exercises[ei] = fresh;
    _commit(s.copyWith());
  }

  /// Moves everything already done from [from] onto [to], which is the same slot
  /// rebuilt from a template that has changed under it.
  ///
  /// A logged set is moved whole — its weight, its result and its goal — because
  /// what it says is what happened, and a target rewritten after the fact would
  /// turn a set that was hit into one that was missed. Sets past the end of the
  /// new list are appended rather than dropped: asking for three sets after
  /// doing four is a decision about what is left to do, not permission to erase
  /// the fourth.
  void _carryLoggedWork({
    required ExerciseEntry from,
    required ExerciseEntry to,
  }) {
    for (var i = 0; i < from.sets.length; i++) {
      if (!from.sets[i].done) {
        // A set nobody has logged is rebuilt to the new target — but what the
        // console said is not a target, it is something typed off a machine.
        // Losing it because the rest time changed would be losing data.
        if (i < to.sets.length) to.sets[i].console = from.sets[i].console;
        continue;
      }
      if (i < to.sets.length) {
        to.sets[i] = from.sets[i];
      } else {
        to.sets.add(from.sets[i]);
      }
    }
    // The ramp is regenerated from the working weight, so a rung already done
    // is carried the same way [_rebuildRamp] carries one.
    for (var i = 0; i < to.warmups.length && i < from.warmups.length; i++) {
      if (from.warmups[i].done) to.warmups[i] = from.warmups[i];
    }
  }

  /// Logs the next outstanding set at its goal and starts the rest — what the
  /// shade's **Done** button does.
  void logNextAtGoal() => _logNext(short: false);

  /// Logs the next outstanding set one short of its goal — the shade's
  /// **Missed**. It lands gold rather than green, and the app comes forward so
  /// the number can be corrected to what actually happened.
  ///
  /// The rest starts either way. You have just finished a set; that the number
  /// wants correcting does not make the rest between sets any shorter, and a
  /// board you came back to with no clock running is a board where you have to
  /// start the clock by hand.
  void logNextAsMissed() => _logNext(short: true);

  /// Logs the next outstanding set and starts its rest.
  ///
  /// It asks [nextUp] rather than being told which set, because the press came
  /// from a notification that may be a moment out of date; the session is the
  /// only thing that knows what is actually outstanding. A hold is refused: how
  /// long you held it is the measurement, and nothing here can invent it. So is
  /// a press that arrives during a rest, which is a set already logged.
  void _logNext({required bool short}) {
    final s = state;
    if (s == null || s.restLeft > 0) return;
    final cue = nextUp(s);
    if (cue == null || cue.kind != CueKind.lift) return;

    final e = s.exercises[cue.exerciseIndex];
    final entry = cue.warmup ? e.warmups[cue.setIndex] : e.sets[cue.setIndex];
    final logged = short ? missedSeed(cue) : entry.goal;
    if (logged == null) return;
    entry.logged = logged;
    s.restamp(entry, wasDone: false);

    final rest = s.restAfter(
      cue.exerciseIndex,
      cue.setIndex,
      warmup: cue.warmup,
    );
    if (rest.seconds == 0) {
      // Mid-superset: no clock to start, so the logged set is published on its
      // own. The next movement of the group is already the marked one.
      _commit(s.copyWith());
      return;
    }
    // The sets are edited in place, so starting the rest publishes the logged set
    // with it — one new state, one snapshot.
    startRest(
      rest.seconds,
      rest.prompt,
      forSet: (
        exercise: cue.exerciseIndex,
        set: cue.setIndex,
        warmup: cue.warmup,
      ),
    );
  }

  /// Types a result in directly — reps done, or seconds held on a timed set
  /// (the long-press escape hatch). A null [value] unlogs the set; anything
  /// else is clamped to zero or more.
  void setLogged(int ei, int si, int? value) =>
      _editEntry(ei, si, warmup: false, edit: (e) => e.logged = _clamp(value));

  /// A typed-in result: null unlogs the set, anything else is zero or more.
  static int? _clamp(int? value) =>
      value == null ? null : (value < 0 ? 0 : value);

  /// Dials the warm-up ramp for one exercise up or down and rebuilds it. The
  /// count is clamped to 0..[kMaxWarmupSets].
  void setWarmupCount(int ei, int count) {
    final s = state;
    if (s == null) return;
    final e = s.exercises[ei];
    if (!e.hasWarmups) return;
    e.warmupCount = count < 0
        ? 0
        : (count > kMaxWarmupSets ? kMaxWarmupSets : count);
    _rebuildRamp(e, inventory: s.plates);
    _commit(s.copyWith());
  }

  /// Recomputes one exercise's warm-up ramp — the ladder of loads this gym can
  /// set, and the rungs the ramp lands on — from its current working weight and
  /// set count.
  ///
  /// **A rung already logged survives.** The plates were on the bar and you
  /// lifted it; a recompute redraws what is still ahead of you and leaves what
  /// is behind alone, which is the rule the working sets follow too. Rungs the
  /// new ramp no longer has (you asked for fewer) go with it.
  /// The unit is the exercise's own ([ExerciseEntry.unit]) rather than the
  /// session's: the rack a dumbbell movement climbs goes up in 5 lb steps at a
  /// gym that counts its dumbbells in pounds, whatever the rest of the app is
  /// reading. The plates and the bar stay the session's — they are the iron in
  /// one gym.
  void _rebuildRamp(ExerciseEntry e, {required List<PlateStack> inventory}) {
    final was = [...e.warmups];
    e.warmups.clear();
    if (!e.hasWarmups) {
      e.warmupLadder = const [];
      return;
    }
    e.warmupLadder = loadLadder(
      type: e.weightType,
      unit: e.unit,
      maxKg: e.workingKg!,
      barKg: e.warmupBarKg,
      inventory: inventory,
    );
    final fresh = _warmupSetsFor(
      e.workingKg!,
      e.warmupBarKg,
      e.warmupLadder,
      e.warmupCount,
    );
    for (var i = 0; i < fresh.length; i++) {
      e.warmups.add(i < was.length && was[i].done ? was[i] : fresh[i]);
    }
  }

  /// One tap on a warm-up set — the same cycle as a working set, but on the
  /// warm-up list and answering to nothing that counts.
  void cycleWarmup(int ei, int wi) =>
      _editEntry(ei, wi, warmup: true, edit: (e) => e.cycle());

  void setWarmupWeight(int ei, int wi, double value) =>
      _editEntry(ei, wi, warmup: true, edit: (e) => e.weight = value);

  /// Types a warm-up result in directly — the long-press escape hatch, mirroring
  /// [setLogged] for the warm-up list.
  void setWarmupLogged(int ei, int wi, int? value) =>
      _editEntry(ei, wi, warmup: true, edit: (e) => e.logged = _clamp(value));

  /// Persists the session with only its completed sets, then advances each
  /// exercise's progression. Returns the new session id, or null if there was
  /// nothing to save.
  Future<int?> finish() async {
    if (state == null) return null;
    // Before the clock is stopped and before the length is read off it: the
    // last tick may be up to a second old, and on a build whose ticks were
    // being throttled it can be a great deal older than that. What gets filed
    // is the time the workout took, not the time of the most recent tick.
    _syncElapsed();
    final s = state;
    if (s == null) return null;
    _timer?.cancel();
    _elapsedAnchor = null;
    _restTimer?.cancel();
    _restTimer = null;
    _restEndsAt = null;
    ref.read(restAlarmProvider).clear();
    // Before a row is written: advancing progression edits the very slots this
    // is watching, and a session on its way out has no use for the answer.
    _stopWatchingTemplate();

    final rows = <SessionSetsCompanion>[];
    // Clips filmed against a set that was never logged. The set is not saved,
    // so nothing would point at them — they go with the rest of the session
    // rather than waiting a day for the sweep.
    final unsaved = <String>[];
    for (final e in s.exercises) {
      var n = 1;
      for (final set in e.sets) {
        if (!set.done) {
          if (set.videoPath case final path?) unsaved.add(path);
          continue;
        }
        rows.add(
          SessionSetsCompanion.insert(
            sessionId: 0, // replaced inside saveSession
            exerciseName: e.name,
            exerciseSeedKey: Value(e.seedKey),
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
            videoPath: Value(set.videoPath),
            // What the console said, where anybody wrote it down. Null
            // throughout on everything that is not a cardio machine, and on
            // most sets that are.
            speedKph: Value(set.console.speedKph),
            inclinePercent: Value(set.console.inclinePercent),
            resistanceLevel: Value(set.console.resistanceLevel),
            distanceKm: Value(set.console.distanceKm),
            actualRpe: Value(set.actualRpe),
          ),
        );
      }
    }

    final id = await _db.saveSession(
      routineId: s.routineId,
      workoutId: s.workoutId,
      name: s.name,
      seedKey: s.seedKey,
      startedAt: s.startedAt,
      endedAt: DateTime.now(),
      durationSeconds: s.elapsed,
      totalVolume: s.volume,
      sets: rows,
    );

    // The session is on disk under its own name now, so the snapshot has nothing
    // left to protect — and leaving it would have the next launch restore a
    // workout that is already in the history.
    _forget();

    // Only now that the rows are on disk: a clip whose set was saved is
    // referenced, and a clip whose set was not is rubbish. Deleting before the
    // write would risk taking a file the write then points at.
    await ref.read(setVideoStoreProvider).deleteAll(unsaved);

    // Progression moves only once the session it is based on is safely on
    // disk. A template that stepped up without the history to justify it is
    // harder to explain than one that lags a crash behind.
    final outcomes = <ProgressionOutcome>[];
    for (final e in s.exercises) {
      final itemId = e.itemId;
      if (itemId == null) continue;
      if (e.usesRpe) continue;
      final move = await _db.advanceProgression(
        itemId,
        verdict: e.verdict,
        performedWeight: e.performedWeight,
        // What this session carried, for a slot that arrived with no target at
        // all. Typing a weight onto a slot the builder never gave one is how a
        // target gets established, and it must not leave the exercise off the
        // recap.
        sessionWeight: e.sessionLoadKg,
        finalAmrapReps: e.sets.isNotEmpty && e.sets.last.amrap
            ? e.sets.last.logged
            : null,
      );
      // Read the slot back after advancing to see where progression left it —
      // the resulting target and the streaks — so the summary can explain it.
      final it = await _db.workoutItemById(itemId);
      if (it == null) continue; // slot deleted mid-session; nothing to say
      // The axis that actually paid out, which on a slot taking reps and weight
      // in turn is not the axis it is filed under — and the target read off
      // that same axis, so the two halves of the line agree.
      final mode = move.axis;
      final double? target = switch (mode) {
        ProgressionMode.weight => it.suggestedWeight,
        ProgressionMode.reps => it.goalReps.toDouble(),
        ProgressionMode.time => it.holdSeconds.toDouble(),
      };
      // A weight slot with no suggested weight is a bodyweight movement with no
      // target to move — it does not get to claim it progressed.
      if (target == null) continue;
      outcomes.add(
        ProgressionOutcome(
          name: e.name,
          seedKey: e.seedKey,
          mode: mode,
          moved: move.moved,
          target: target,
          successes: it.successStreak,
          failures: it.failStreak,
          successThreshold: it.successThreshold,
          failureThreshold: it.failureThreshold,
          unit: e.unit,
        ),
      );
    }

    // Stash the deltas keyed by this session, for the summary to explain. Empty
    // means nothing had a target to move (an ad-hoc or all-bodyweight session),
    // and the summary shows no banner at all.
    ref
        .read(lastProgressionProvider.notifier)
        .set(
          outcomes.isEmpty
              ? null
              : ProgressionReport(sessionId: id, outcomes: outcomes),
        );

    state = null;
    return id;
  }

  /// Throws the session away, and the clips it filmed with it.
  ///
  /// Nothing was ever written to the database, so nothing points at those
  /// files — abandoning a workout that leaves footage behind would be an app
  /// quietly hoarding video of somebody for a session they chose to bin.
  Future<void> discard() async {
    _timer?.cancel();
    _elapsedAnchor = null;
    _restTimer?.cancel();
    _restTimer = null;
    _restEndsAt = null;
    ref.read(restAlarmProvider).clear();
    _forget();
    final clips = _clipPaths.toList();
    state = null;
    await ref.read(setVideoStoreProvider).deleteAll(clips);
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
) => [
  for (final s in computeWarmups(
    workingKg: workingKg,
    ladder: ladder,
    barKg: barKg,
    sets: count,
  ))
    SetEntry(goal: s.reps, goalWeight: s.weightKg, weight: s.weightKg),
];

/// Formats a weight without a trailing ".0" (e.g. 80.0 -> "80", 12.5 -> "12.5").

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
    this.seedKey,
    required this.mode,
    required this.moved,
    required this.target,
    required this.successes,
    required this.failures,
    required this.successThreshold,
    required this.failureThreshold,
    this.unit = 'kg',
  });

  /// The unit this movement's target and step are read in — carried from the
  /// session entry, because the banner names one exercise's numbers and a
  /// pounds-pinned lift must not report its step in kilograms. Meaningless on
  /// the rep and time axes, which count the same everywhere.
  final String unit;

  /// The canonical English name. The summary renders
  /// `seededName(l10n, seedKey, name)` — see `util/seed_names.dart`.
  final String name;

  /// The movement's seed key, carried from the session so the progression
  /// banner names it in the app's language like every other screen does.
  final String? seedKey;

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

/// What time it is.
///
/// Both of the session's clocks read this rather than counting their own ticks
/// — see [ActiveWorkoutController._syncRest] for why that distinction is the
/// whole point.
///
/// **`clock.now()`, not `DateTime.now()`.** `package:clock` is `DateTime.now`
/// in a running app, and in a widget test it is the *fake* clock the test
/// binding installs — the one `tester.pump(Duration(...))` moves. A clock that
/// read the wall directly would leave every existing rest-timer widget test
/// pumping a countdown that never came down, which is precisely the trap this
/// change would otherwise have walked into.
///
/// It is still a provider on top of that, because a plain `test()` has no fake
/// binding to pump and needs to move time by hand.
final clockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => clock.now(),
);

/// The one player for the rest tone, disposed with the scope that made it. One
/// instance rather than one per rest: an `AudioPlayer` holds a platform
/// resource, and a session is dozens of rests.
final restToneProvider = Provider<RestTone>((ref) {
  final tone = RestTone();
  ref.onDispose(tone.dispose);
  return tone;
});

/// The rest ending as a notification, for when the app is not on screen — see
/// [RestAlarm]. Here rather than in `providers.dart` for the same reason the
/// tone is: the rest clock is on the controller above.
final restAlarmProvider = Provider<RestAlarm>((ref) => RestAlarm());

/// The rest ending as a vibration, wherever the phone is — see [RestBuzz].
/// Beside the tone and the alarm, since all three are the same event.
final restBuzzProvider = Provider<RestBuzz>((ref) => RestBuzz());

/// Whether the app is the thing on screen right now.
///
/// A function rather than a value: it is asked once, at the instant a rest runs
/// out, and nothing should rebuild when it changes. A test overrides it to say
/// where the phone is, which is not something a test runner has an opinion on.
///
/// A binding that has not reported a lifecycle state yet reads as *not* on
/// screen — the safe way round, since the cost of being wrong is a notification
/// nobody needed rather than a rest that ends in silence.
final appOnScreenProvider = Provider<bool Function()>(
  (ref) =>
      () => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
);

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

  /// The screen reports itself gone from `dispose`, one microtask later so the
  /// notification never lands mid-teardown — by which time the provider itself
  /// may have been disposed (the app closing, a container torn down). A flag
  /// nobody is left to read is not worth throwing over.
  void set(bool visible) {
    if (!ref.mounted) return;
    state = visible;
  }
}

final workoutScreenVisibleProvider =
    NotifierProvider<WorkoutScreenVisible, bool>(WorkoutScreenVisible.new);
