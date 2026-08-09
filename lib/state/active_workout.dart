import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/warmup.dart';
import '../l10n/app_localizations.dart';
import '../providers/db_provider.dart';
import '../providers/providers.dart'
    show appLocalizationsProvider;
import '../services/rest_alarm.dart';
import '../services/rest_buzz.dart';
import '../services/rest_tone.dart';
import '../services/set_video_store.dart';
import '../services/workout_shade.dart'
    show pendingShadeActionsProvider, restIsOverLine;
import 'session_mirror.dart';
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
    this.loggedOrder,
    this.videoPath,
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

  /// Where this set falls in the order the session's sets were logged in —
  /// higher is more recent. Null whenever [logged] is.
  ///
  /// **A counter, not a clock.** All anything asks of it is which of two sets
  /// was logged later, and a wall clock answers that at the cost of making
  /// every test that logs two sets depend on how fast the machine ran them —
  /// and of being wrong on a phone whose time moved under the session. The
  /// numbers themselves mean nothing outside the session that handed them out.
  ///
  /// See [ActiveWorkout.restamp], which is the only thing that writes it.
  int? loggedOrder;

  /// The clip filmed of this set, relative to the app support directory, or
  /// null if nobody filmed it.
  ///
  /// **The file is on disk from the moment recording stops; only this pointer
  /// is in memory.** The live session does not touch the database until Finish,
  /// so a clip filmed mid-session is a file plus a path held here, written
  /// alongside the set when the session is saved — and deleted again if the
  /// session is abandoned. A crash in between strands a file, which the orphan
  /// sweep collects; the ordering is chosen so it can never strand a row
  /// pointing at nothing.
  String? videoPath;

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
    this.goalReps = 0,
    this.floorKg = 0,
  }) : warmups = warmups ?? <SetEntry>[];
  final int? exerciseId;

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

  /// The slot's own rep target, which every scheme but a custom one repeats.
  final int goalReps;

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
        floorKg: floorKg,
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
  final int restSeconds;

  /// Whether this counts as a clean session for progression: every planned set
  /// logged, and none of them short.
  ///
  /// Skipping a set is a miss. The program asked for four and got three —
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
    // The next exercise is the next one with anything left to do — skipping
    // past any that are already finished.
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
    // Nothing left anywhere: this was the last set of the session.
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
    _commit(s
        .copyWith(clearRest: true)
        .copyWith(restLeft: seconds, restPrompt: prompt, restFor: forSet));
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
    return s == null
        ? l10n.restAlarmBackToIt
        : restIsOverLine(l10n, nextUp(s), s.unit);
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
    // moved during the session is a decision about today.
    final warmupSets = await _db.defaultWarmupSets();
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
  /// [_takeTemplateAdditions] must use the ones the session froze on the way in
  /// — see [ActiveWorkout.barKg].
  ExerciseEntry _entryFor(
    WorkoutItemView v, {
    required String unit,
    required List<PlateStack> plates,
    required double barKg,
    required int warmupSets,
    required int defaultRestSeconds,
  }) {
    final mode = v.item.progression;
    // The goal is the hold for a timed exercise, and otherwise the top of
    // the rep range or the fixed count. A to-failure set carries no upper
    // bound, so its goal is `repsMin` — the number you have to beat for
    // the set to count, which is exactly what "to failure" is asking.
    final goal = mode.timed ? v.item.holdSeconds : (v.item.repsMax ?? v.item.repsMin);
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
      sets: v.item.targetSets,
      // A to-failure set has no upper bound, so its goal is `repsMin` —
      // the number you have to beat, which is what `goal` already is.
      goalReps: goal,
      topWeightKg: w,
      unit: unit,
      percent: v.item.schemePercent,
      custom: decodeCustomSets(v.item.customSets),
      floorKg: warmupBar,
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
      workingKg: resolveTopWeight(topWeightKg: w, unit: unit, floorKg: warmupBar),
      warmupBarKg: warmupBar,
      warmupCount: warmupSets,
      scheme: v.item.scheme,
      schemePercent: v.item.schemePercent,
      customSets: decodeCustomSets(v.item.customSets),
      goalReps: goal,
      floorKg: warmupBar,
      sets: [
        for (final t in targets)
          SetEntry(
            // A hold is counted in seconds and no scheme touches that; the
            // weight on it still ramps like anything else.
            goal: mode.timed ? goal : t.reps,
            goalWeight: t.weightKg,
            timed: mode.timed,
          ),
      ],
    );
    _rebuildRamp(e, unit: unit, inventory: plates);
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

  void _watchTemplate(int workoutId) {
    _stopWatchingTemplate();
    _templateWatch = _db
        .tableUpdates(TableUpdateQuery.onTable(_db.workoutItems))
        .listen((_) => unawaited(_rereadTemplate(workoutId)));
  }

  /// Reads the day back and hands it to [_takeTemplateAdditions].
  ///
  /// [_gone] is checked either side of the read: the notification arrives from a
  /// stream that outlives the session, and the trip to the database gives the
  /// provider itself time to be disposed underneath it.
  Future<void> _rereadTemplate(int workoutId) async {
    if (_gone || state?.workoutId != workoutId) return;
    final items = await _db.itemsForWorkout(workoutId);
    if (_gone) return;
    await _takeTemplateAdditions(items);
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

  /// Puts whatever [items] has that the session has not on the end of the board.
  Future<void> _takeTemplateAdditions(List<WorkoutItemView> items) async {
    final before = state;
    final workoutId = before?.workoutId;
    if (before == null || workoutId == null) return;
    if (_additionsIn(before, items).isEmpty) return;
    // The rest a slot falls back on when it names none of its own — read the
    // same way [start] reads it.
    final routine =
        await _db.routineById((await _db.workoutById(workoutId)).routineId);
    // That was a trip to the database, and the session may have been finished,
    // thrown away or replaced while it ran — so what gets appended is worked out
    // again against the session as it stands now.
    if (_gone) return;
    final s = state;
    if (s == null || s.workoutId != before.workoutId) return;
    final extra = _additionsIn(s, items);
    if (extra.isEmpty) return;
    for (final v in extra) {
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
    }
    _commit(s.copyWith());
  }

  /// The template rows the session has not got, in template order.
  ///
  /// **Movements counted off, not item ids compared.** Saving the workout editor
  /// deletes and reinserts every row, so every item id changes on any save at
  /// all — and an id diff would read a plain reorder as five additions and
  /// append the whole day to itself. What a slot is, to a session, is which
  /// movement it holds; so the template's movements are counted off against the
  /// ones the session is already carrying and whatever is left over is what
  /// somebody added. A removal leaves nothing over, and neither does a reorder,
  /// a rename or a slot re-configured.
  List<WorkoutItemView> _additionsIn(
    ActiveWorkout s,
    List<WorkoutItemView> items,
  ) {
    final held = <int, int>{};
    for (final e in s.exercises) {
      if (e.exerciseId case final id?) held[id] = (held[id] ?? 0) + 1;
    }
    final extra = <WorkoutItemView>[];
    for (final v in items) {
      final left = held[v.exercise.id] ?? 0;
      if (left > 0) {
        held[v.exercise.id] = left - 1;
      } else {
        extra.add(v);
      }
    }
    return extra;
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
      unit: s.unit,
      floorKg: e.floorKg,
    );
    // Through the scheme, not straight onto every row: on a back-off or a ramp
    // the sets are a ladder, and moving its top has to move the rungs with it
    // rather than flatten them all onto the new number.
    final targets = e.targetsAt(e.workingKg, s.unit);
    for (var i = 0; i < e.sets.length; i++) {
      if (!e.sets[i].done) e.sets[i].weight = targets[i].weightKg ?? 0;
    }
    _rebuildRamp(e, unit: s.unit, inventory: s.plates);
    _commit(s.copyWith());
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

    // The sets are edited in place, so starting the rest publishes the logged set
    // with it — one new state, one snapshot.
    startRest(
      cue.warmup ? e.restAfterWarmup(cue.setIndex) : e.restSeconds,
      cue.warmup
          ? s.restAfterWarmup(cue.exerciseIndex, cue.setIndex)
          : s.restAfterSet(cue.exerciseIndex, cue.setIndex),
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
    _rebuildRamp(e, unit: s.unit, inventory: s.plates);
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
      final moved = await _db.advanceProgression(
        itemId,
        success: e.succeeded,
        performedWeight: e.performedWeight,
        // What this session carried, for a slot that arrived with no target at
        // all. Typing a weight onto a slot the builder never gave one is how a
        // target gets established, and it must not leave the exercise off the
        // recap.
        sessionWeight: e.sessionLoadKg,
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
      outcomes.add(
        ProgressionOutcome(
          name: e.name,
          seedKey: e.seedKey,
          mode: mode,
          moved: moved,
          target: target,
          successes: it.successStreak,
          failures: it.failStreak,
          successThreshold: it.successThreshold,
          failureThreshold: it.failureThreshold,
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
  });

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
final clockProvider = Provider<DateTime Function()>((ref) => () => clock.now());

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
