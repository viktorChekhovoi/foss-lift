import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/superset.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../screens/exercise_detail_screen.dart'
    show ExerciseLoadingSection, ExerciseNoteSection;
import '../screens/exercise_form_screen.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../util/seed_names.dart';
import '../util/target_label.dart';
import '../util/units.dart';
import 'builder_widgets.dart';
import 'common.dart' show AppDialog, sectionLabelStyle, showAppDialog;

/// Finds the progression-amount fields in a test. The first two are the pair
/// every axis has; on the axis that takes reps and weight in turn they are its
/// weight pair, and the rep pair below is beside them.
const kWeightFieldKey = ValueKey('slot-weight');
const kStepUpFieldKey = ValueKey('amount-step-up');
const kBackOffFieldKey = ValueKey('amount-back-off');
const kRepsStepUpFieldKey = ValueKey('amount-reps-step-up');
const kRepsBackOffFieldKey = ValueKey('amount-reps-back-off');

/// Finds the rep range's stepper, which is greyed rather than gone on a slot
/// whose sets run to failure.
const kRepRangeFieldKey = ValueKey('rep-range');

/// Finds the axis pills.
const kModeWeightKey = ValueKey('mode-weight');
const kModeRepsKey = ValueKey('mode-reps');
const kModeTimeKey = ValueKey('mode-time');
const kModeAdvancedKey = ValueKey('mode-advanced');

/// Finds the checkbox that joins a slot to the one above it as a superset, and
/// the icon beside it that says what one is.
const kSupersetCheckKey = ValueKey('superset-with-previous');
const kSupersetHintKey = ValueKey('superset-hint');

/// A mutable working copy of one workout item while editing.
///
/// Lives outside any screen so the exercise list can be edited both against a
/// saved workout and against a routine that has not been written yet.
class ItemDraft {
  ItemDraft({
    required this.exerciseId,
    required this.name,
    required this.muscle,
    this.sets = 3,
    this.repsMin = 8,
    this.repsMax,
    this.toFailure = false,
    this.addWeightAtTopOfRange = false,
    this.repsIncrement = 1,
    this.repsDeload = 2,
    this.repsTarget,
    this.restSeconds,
    double? weightKg,
    this.scheme = SetScheme.flat,
    this.schemePercent = kDefaultSchemePercent,
    this.customSets = const [],
    this.cycle = const [],
    this.cyclePosition = 0,
    this.measure = ExerciseMeasure.reps,
    this.weightType = WeightType.machine,
    this.barKg,
    ProgressionMode? progression,
    this.holdSeconds = 30,
    double? increment,
    double? deload,
    this.successThreshold = defaultSuccessThreshold,
    this.failureThreshold = defaultFailureThreshold,
    this.successStreak = 0,
    this.failStreak = 0,
    this.supersetWithPrevious = false,
    this.exercise,
    Map<RateAxis, ProgressionRates> sparedRates = const {},
  })  : _rates = {...sparedRates},
        progression = _startingMode(measure, weightType, progression),
        increment = increment ??
            _startingMode(measure, weightType, progression).defaultIncrement,
        deload = deload ??
            _startingMode(measure, weightType, progression).defaultDeload,
        // A movement that carries nothing has no load to suggest, so a number
        // left over from before it was reclassified goes with the loading.
        weightKg = weightType.carriesWeight ? weightKg : null;

  /// The axis a draft opens on: what was asked for, if the slot allows it.
  static ProgressionMode _startingMode(
    ExerciseMeasure measure,
    WeightType weightType,
    ProgressionMode? want,
  ) {
    final allowed = _axesFor(measure, weightType);
    final asked = want ?? ProgressionMode.weight;
    return allowed.contains(asked) ? asked : allowed.first;
  }

  /// The axes a slot may progress on: what the measure permits, less load for a
  /// movement that carries none. Adding 2.5 kg a week to a push-up is an
  /// instruction nobody can follow.
  static List<ProgressionMode> _axesFor(
          ExerciseMeasure measure, WeightType weightType) =>
      [
        for (final m in measure.modes)
          if (m != ProgressionMode.weight || weightType.carriesWeight) m,
      ];

  /// Rehydrates a draft from a stored item.
  factory ItemDraft.fromView(WorkoutItemView v) => ItemDraft(
        exercise: v.exercise,
        exerciseId: v.exercise.id,
        name: v.exercise.name,
        muscle: v.exercise.muscleGroup,
        sets: v.item.targetSets,
        repsMin: v.item.repsMin,
        repsMax: v.item.repsMax,
        toFailure: v.item.toFailure,
        addWeightAtTopOfRange: v.item.addWeightAtTopOfRange,
        repsIncrement: v.item.repsIncrement,
        repsDeload: v.item.repsDeload,
        repsTarget: v.item.repsTarget,
        restSeconds: v.item.restSeconds,
        weightKg: v.item.suggestedWeight,
        scheme: v.item.scheme,
        schemePercent: v.item.schemePercent,
        customSets: decodeCustomSets(v.item.customSets),
        cycle: v.item.cycleWeeks,
        cyclePosition: v.item.cyclePosition,
        // The library has the final say on the axis: an exercise that changed
        // measure — or lost its loading — must not leave a saved workout
        // counting reps against a hold or kilograms against a pull-up.
        measure: v.exercise.measure,
        weightType: v.exercise.weightType,
        barKg: v.exercise.barWeight,
        progression: v.item.progression,
        holdSeconds: v.item.holdSeconds,
        increment: v.item.increment,
        deload: v.item.deload,
        successThreshold: v.item.successThreshold,
        failureThreshold: v.item.failureThreshold,
        successStreak: v.item.successStreak,
        failStreak: v.item.failStreak,
        supersetWithPrevious: v.item.supersetWithPrevious,
        sparedRates: decodeSparedRates(v.item.sparedRates),
      );

  /// A brand-new slot for [e], on whichever axis it can actually move along,
  /// stepping by whatever [unit] counts by — 2.5 kg, or 5 lb.
  factory ItemDraft.forExercise(Exercise e, {String unit = 'kg'}) {
    final mode = e.measure.defaultMode;
    return ItemDraft(
      exercise: e,
      exerciseId: e.id,
      name: e.name,
      muscle: e.muscleGroup,
      measure: e.measure,
      weightType: e.weightType,
      barKg: e.barWeight,
      progression: mode,
      increment: defaultIncrementFor(mode, unit),
      deload: defaultDeloadFor(mode, unit),
    );
  }

  final int exerciseId;

  /// The library row this slot points at, as of the last [adoptExercise], or
  /// null for a draft built without one.
  ///
  /// Carried rather than looked up so the slot sheet can show the movement's
  /// own properties on its first frame: reading them off a stream instead means
  /// a card that arrives late and shoves everything under it down the sheet.
  Exercise? exercise;

  /// The library's copy of the movement, as of the last [adoptExercise]. Not
  /// edited through the draft — a rename happens to the exercise, and this
  /// follows it.
  String name;
  String muscle;

  /// Whether the movement is counted or held. Fixed by the library, not the
  /// program — it is what limits which axes [setMode] will accept.
  ExerciseMeasure measure;

  /// What the movement's weight column means, [WeightType.none] included. Also
  /// fixed by the library, and the other half of what [modes] allows: there is
  /// no load to add to a movement that carries none.
  WeightType weightType;

  /// The exercise's own bar, if it has one. Null means the app-wide default,
  /// which the draft cannot see — callers pass it to [floorKg].
  double? barKg;

  int sets;
  int repsMin;
  int? repsMax;
  bool toFailure;

  /// Double progression: take the reps and the load in turn, climbing
  /// [repsTarget] to the top of the rep range before the load moves. Kept while
  /// [canClimbRange] is false rather than cleared, so taking a rep range off and
  /// putting it back does not silently change how the slot progresses — see the
  /// column of the same name.
  bool addWeightAtTopOfRange;

  /// The rep half of the rates the advanced axis advances by. The weight half
  /// is [increment] and [deload], which every other axis uses for whatever it
  /// moves.
  double repsIncrement;
  double repsDeload;

  /// Where inside the range the climb has got to. Carried, not edited: it is
  /// where the program stands rather than something the builder sets, and a
  /// draft that dropped it would restart everybody's climb on a rename.
  int? repsTarget;

  int? restSeconds;

  /// The top of every ladder [scheme] produces, not the weight of set one —
  /// see `data/set_scheme.dart`.
  double? weightKg;

  /// How the sets differ from one another.
  SetScheme scheme;

  /// One rung of a back-off or a ramp, as a whole percentage.
  int schemePercent;

  /// The written-out rows of a custom scheme. Kept across a switch to another
  /// scheme and back, so trying a ramp does not throw away what was typed.
  List<CustomSet> customSets;

  /// The weeks a cycle rotates through, kept on the same terms as [customSets]
  /// — a cycle somebody wrote out is far more work than a ramp, and switching
  /// away for a session must not cost it.
  List<List<CustomSet>> cycle;

  /// Where the slot has got to in that cycle. **Carried, not edited**: fixing a
  /// typo in week three cannot send the slot back to week one, any more than
  /// opening the builder can forgive a pending back-off.
  int cyclePosition;

  /// How many working sets this slot has — the current week's row count on a
  /// cycle, and [sets] everywhere else. The draft's copy of
  /// [WorkoutItemTarget.setCount].
  int get setCount {
    final rows = cycleRows;
    return rows.isEmpty ? sets : rows.length;
  }

  /// The rows the next session of this slot would be prescribed, or empty when
  /// it is not on a cycle.
  List<CustomSet> get cycleRows => scheme == SetScheme.cycle
      ? cycleBlockAt(cycle, cyclePosition)
      : const [];

  /// Whether anything in the Advanced half of the Target card is in use. The
  /// card opens expanded when it is, so nothing a slot actually does is hidden
  /// behind a toggle somebody has to think to press.
  bool get usesAdvanced =>
      toFailure || repsMax != null || scheme != SetScheme.flat;

  /// The same question for the Progression card's own Advanced half, which
  /// holds only the range climb so far.
  ///
  /// Asks the tick alone rather than [canClimbRange] as well: a slot that is
  /// ticked but has lost its range is exactly the slot whose owner needs to see
  /// the greyed row and the line saying what it wants.
  bool get usesProgressionAdvanced => addWeightAtTopOfRange;

  /// Whether the advanced axis is on offer: a rep range to climb, and a load to
  /// wait at the top of it. Sets taken to failure are not aiming at a range, and
  /// a movement that is held or carries nothing has no second axis to take turns
  /// with.
  ///
  /// Asks what the exercise *allows* rather than which axis the slot is on:
  /// picking Advanced while the slot sits on the reps pill is a legal move, and
  /// it is the move that puts it on the weight axis.
  bool get canClimbRange =>
      !toFailure &&
      repsMax != null &&
      modes.contains(ProgressionMode.weight);

  /// Whether the slot is actually running that rule — ticked, and able to.
  bool get onAdvancedAxis => addWeightAtTopOfRange && canClimbRange;

  /// The rep goal a set of this slot aims at: the number to beat when the sets
  /// run to failure, wherever the climb has got to on the advanced axis, and
  /// otherwise the top of the range or the fixed count. The draft's copy of
  /// [WorkoutItemTarget.goalReps], which is what the board reads.
  int get goalReps {
    if (toFailure) return repsMin;
    final top = repsMax;
    if (top == null) return repsMin;
    if (!onAdvancedAxis) return top;
    final goal = repsTarget ?? repsMin;
    return goal < repsMin ? repsMin : (goal > top ? top : goal);
  }

  /// The unit this slot's weights are read and typed in: the movement's own if
  /// it has been pinned to one, [appUnit] otherwise. See `unitForExercise`.
  ///
  /// Every screen that draws a slot resolves it through here, so the summary
  /// line under a row, the sheet that edits it and the board that runs it all
  /// name the same number the same way.
  String unitIn(String appUnit) =>
      unitForExercise(appUnit, exercise?.unitOverride);

  /// What each set is aiming at, given the gym's [unit] and the lightest weight
  /// this slot may be loaded to. The one place the scheme is turned into
  /// numbers on this side of the app — the live session calls the same
  /// function with the session's own unit and bar.
  List<SetTarget> targets({required String unit, double defaultBarKg = 0}) =>
      resolveSetTargets(
        scheme: scheme,
        sets: sets,
        goalReps: goalReps,
        topWeightKg: clampedWeightKg(defaultBarKg),
        unit: unit,
        percent: schemePercent,
        custom: customSets,
        cycle: cycle,
        cyclePosition: cyclePosition,
        floorKg: floorKg(defaultBarKg),
      );

  ProgressionMode progression;
  int holdSeconds;
  double increment;
  double deload;
  int successThreshold;
  int failureThreshold;

  /// Carried, not edited. Saving a workout rewrites its items wholesale, so a
  /// draft that dropped these would reset a pending back-off every time the
  /// user renamed the day.
  int successStreak;
  int failStreak;

  /// Whether this slot is trained in the same round as the one above it — the
  /// join that makes a run of slots a superset. Mutable: it is a checkbox, and
  /// dragging a joined row to the top of the list takes it off again.
  bool supersetWithPrevious;

  /// The axes this slot may be put on, per the exercise's measure and loading.
  List<ProgressionMode> get modes => _axesFor(measure, weightType);

  /// The lightest weight this slot may suggest, given the app-wide default bar.
  ///
  /// The board clamps the same way while a session runs; this stops a template
  /// being *authored* under the bar, which is where the nonsense used to get in.
  double floorKg(double defaultBarKg) => loadFloorKg(
        type: weightType,
        barKg: barKg,
        defaultBarKg: defaultBarKg,
      );

  /// [weightKg] as it may be stored: nothing at all for a movement that carries
  /// no load, and never below [floorKg] for one over a bar.
  ///
  /// The constructor drops a weight the loading cannot justify, but the field is
  /// mutable and the loading is not — so the invariant is enforced here, at the
  /// one point every draft passes through on its way to the database.
  double? clampedWeightKg(double defaultBarKg) {
    final w = weightKg;
    if (w == null || !weightType.carriesWeight) return null;
    final floor = floorKg(defaultBarKg);
    return w < floor ? floor : w;
  }

  /// The step and back-off last set on each axis this slot is *not* on, so
  /// switching away and back does not throw away numbers somebody typed — the
  /// same keeping as [customSets]. The axis in use keeps its own pair in
  /// [increment] and [deload], and is never a key here.
  ///
  /// Stored, as `WorkoutItems.spared_rates`: the sheet closes, the app is shut
  /// and the numbers are still what they were. Read through [sparedRates],
  /// which is what the two write paths put in the column.
  ///
  /// The advanced axis is a key of its own rather than the weight axis it runs
  /// on: its step is what to add at the top of a rep range, which is not
  /// necessarily what the same slot adds every session on the plain rule. Its
  /// rep rates need no keeping — [repsIncrement] and [repsDeload] are fields
  /// nothing else writes.
  final Map<RateAxis, ProgressionRates> _rates;

  /// The set-aside pairs as the column holds them, or null when none are.
  String? get sparedRates => encodeSparedRates(_rates);

  RateAxis get _rateAxis => onAdvancedAxis
      ? RateAxis.advanced
      : switch (progression) {
          ProgressionMode.weight => RateAxis.weight,
          ProgressionMode.reps => RateAxis.reps,
          ProgressionMode.time => RateAxis.time,
        };

  /// Switches the axis, bringing back the rates last set on it, or that mode's
  /// defaults in [unit] on an axis this slot has not been on: 2.5 of anything
  /// is a sane step in kilograms and nonsense in reps. An axis the exercise
  /// does not allow is ignored.
  ///
  /// Picking one of the plain axes leaves the advanced one, which is what the
  /// pills mean: they are four ways for this slot to advance and it is on one.
  void setMode(ProgressionMode mode, {String unit = 'kg'}) {
    if (!modes.contains(mode)) return;
    if (mode == progression && !onAdvancedAxis) return;
    _switchAxis(unit, () {
      addWeightAtTopOfRange = false;
      progression = mode;
    });
  }

  /// Puts the slot on — or takes it off — the axis that climbs the rep range
  /// before the load moves. Going on brings the weight axis with it: it is the
  /// load that waits at the top of the range.
  void setAdvanced(bool on, {String unit = 'kg'}) {
    if (on == onAdvancedAxis || (on && !canClimbRange)) return;
    _switchAxis(unit, () {
      addWeightAtTopOfRange = on;
      if (on) progression = ProgressionMode.weight;
    });
  }

  /// Runs [change] between putting the rates of the axis being left aside and
  /// bringing back those of the axis being joined.
  void _switchAxis(String unit, VoidCallback change) {
    final from = _rateAxis;
    _rates[from] = (increment: increment, deload: deload);
    change();
    final to = _rateAxis;
    // The axis being joined comes out of the map on the way in: what is left
    // there is exactly the axes the slot is not on, which is what gets stored.
    // The advanced axis, entered for the first time, opens on the slot's own
    // weight rates rather than on the defaults: it is the same load it was
    // about to move, and a 5 kg step nobody has changed their mind about should
    // not silently become 2.5 for having been asked to wait for the top of a
    // range.
    final kept = _rates.remove(to) ??
        (to == RateAxis.advanced ? _rates[RateAxis.weight] : null);
    if (to == from) return;
    final mode = to == RateAxis.advanced ? ProgressionMode.weight : progression;
    increment = kept?.increment ?? defaultIncrementFor(mode, unit);
    deload = kept?.deload ?? defaultDeloadFor(mode, unit);
  }

  /// Takes the library's word for what this movement now is.
  ///
  /// The exercise is editable while a slot on it is open — from the slot sheet
  /// itself — and everything the draft copied off it can change underneath:
  /// a rename, a different measure, a loading that has gone. So the copy is
  /// refreshed, and anything the new facts no longer permit is pulled back into
  /// line rather than left to reach the database as nonsense.
  void adoptExercise(Exercise e, {String unit = 'kg'}) {
    exercise = e;
    name = e.name;
    muscle = e.muscleGroup;
    measure = e.measure;
    weightType = e.weightType;
    barKg = e.barWeight;
    if (!modes.contains(progression)) setMode(modes.first, unit: unit);
    if (!weightType.carriesWeight) weightKg = null;
  }
}

/// Turns drafts into insertable rows, in list order.
///
/// [defaultBarKg] is the app-wide bar, needed to hold a bar-loaded slot at or
/// above the bar it is over. Zero means "no floor", which is what a caller with
/// no bar-loaded drafts can pass.
List<WorkoutItemsCompanion> itemCompanions(List<ItemDraft> drafts,
    {int workoutId = 0, double defaultBarKg = 0}) {
  // The one join a workout cannot hold: the first slot has nothing above it. A
  // row keeps its join as it is dragged, so this is how a list that has been
  // reordered stops asserting it — see [normaliseJoins].
  final joined = normaliseJoins([for (final d in drafts) d.supersetWithPrevious]);
  return [
    for (var i = 0; i < drafts.length; i++)
      WorkoutItemsCompanion.insert(
        workoutId: workoutId,
        exerciseId: drafts[i].exerciseId,
        position: Value(i),
        targetSets: Value(drafts[i].sets),
        repsMin: Value(drafts[i].repsMin),
        // Kept as it stands under a slot run to failure: the range is not what
        // those sets aim at, and taking the number away would make trying
        // failure for a week cost the range somebody set.
        repsMax: Value(drafts[i].repsMax),
        toFailure: Value(drafts[i].toFailure),
        addWeightAtTopOfRange: Value(drafts[i].addWeightAtTopOfRange),
        repsIncrement: Value(drafts[i].repsIncrement),
        repsDeload: Value(drafts[i].repsDeload),
        repsTarget: Value(drafts[i].repsTarget),
        sparedRates: Value(drafts[i].sparedRates),
        restSeconds: Value(drafts[i].restSeconds),
        suggestedWeight: Value(drafts[i].clampedWeightKg(defaultBarKg)),
        scheme: Value(drafts[i].scheme),
        schemePercent: Value(drafts[i].schemePercent),
        // Only a custom slot spends a column on rows: a back-off that was once
        // a custom keeps them in the draft, not in the database.
        customSets: Value(drafts[i].scheme.isCustom
            ? encodeCustomSets(drafts[i].customSets)
            : null),
        // The same rule one level up: only a cycle spends the column, and the
        // position rides along untouched — see [ItemDraft.cyclePosition].
        cycleBlocks: Value(drafts[i].scheme == SetScheme.cycle
            ? encodeCycleBlocks(drafts[i].cycle)
            : null),
        cyclePosition: Value(drafts[i].cyclePosition),
        progression: Value(drafts[i].progression),
        holdSeconds: Value(drafts[i].holdSeconds),
        increment: Value(drafts[i].increment),
        deload: Value(drafts[i].deload),
        successThreshold: Value(drafts[i].successThreshold),
        failureThreshold: Value(drafts[i].failureThreshold),
        successStreak: Value(drafts[i].successStreak),
        failStreak: Value(drafts[i].failStreak),
        supersetWithPrevious: Value(joined[i]),
      ),
  ];
}

/// One draft as an update to the slot it came from — everything the config
/// sheet edits, and nothing else.
///
/// [itemCompanions] is for saving a *list*: the builder rewrites the lot,
/// because position and the superset joins are facts about the order. This is
/// for the one slot the live board's settings sheet changed, written through
/// [AppDatabase.updateWorkoutItem] so the row keeps its id — the session is
/// holding it, and the streaks live on it.
///
/// Position, workout and the superset join are deliberately absent: the sheet
/// opened from the board does not offer them, and a companion that named them
/// would write today's guess over what the builder set.
WorkoutItemsCompanion itemUpdate(ItemDraft d, {double defaultBarKg = 0}) =>
    WorkoutItemsCompanion(
      targetSets: Value(d.sets),
      repsMin: Value(d.repsMin),
      repsMax: Value(d.repsMax),
      toFailure: Value(d.toFailure),
      addWeightAtTopOfRange: Value(d.addWeightAtTopOfRange),
      repsIncrement: Value(d.repsIncrement),
      repsDeload: Value(d.repsDeload),
      repsTarget: Value(d.repsTarget),
      sparedRates: Value(d.sparedRates),
      restSeconds: Value(d.restSeconds),
      suggestedWeight: Value(d.clampedWeightKg(defaultBarKg)),
      scheme: Value(d.scheme),
      schemePercent: Value(d.schemePercent),
      customSets: Value(d.scheme.isCustom ? encodeCustomSets(d.customSets) : null),
      cycleBlocks:
          Value(d.scheme == SetScheme.cycle ? encodeCycleBlocks(d.cycle) : null),
      cyclePosition: Value(d.cyclePosition),
      progression: Value(d.progression),
      holdSeconds: Value(d.holdSeconds),
      increment: Value(d.increment),
      deload: Value(d.deload),
      successThreshold: Value(d.successThreshold),
      failureThreshold: Value(d.failureThreshold),
    );

/// The decimals [fmtWeight] will show, as a rounding: what the field puts back
/// must be what the field says.
double roundStepWeight(double display) =>
    double.parse(display.toStringAsFixed(3));

/// Formats a progression amount in its mode's own unit: "2.5 kg", "1 rep",
/// "5s". Weight is converted to the display unit like every other weight.
String progressionAmount(
  AppLocalizations l10n,
  double amount,
  ProgressionMode mode,
  String unit,
) {
  return switch (mode) {
    ProgressionMode.weight => l10n.unitWeightShort(
        fmtWeight(toDisplayWeight(amount, unit)), unitSuffix(l10n, unit)),
    ProgressionMode.reps => l10n.itemEditorAmountReps(amount.round()),
    ProgressionMode.time =>
      '${amount.round()}${l10n.itemEditorSecondsSuffix}',
  };
}

/// The four progression numbers read back as the rule they add up to: "Add
/// 2.5 kg after 2 clean sessions; drop 5 kg after 2 missed sessions in a row."
///
/// "in a row" only when there is more than one to be in a row with — a rule that
/// backs off on the first miss says so in the singular, and a threshold of one
/// is the default for a weight slot. Both halves are plural branches of the
/// message, so the phrase lives inside the translation rather than being
/// stitched on after it.
String progressionRule(AppLocalizations l10n, ItemDraft d, String unit) {
  // A cycle reads its own rule, because the numbers mean something else on
  // one: what they move is the training max the sets are percentages of, and
  // they move it at the wrap rather than after a run of clean sessions.
  if (d.scheme == SetScheme.cycle) {
    return l10n.itemEditorProgressionRuleCycle(
      progressionAmount(l10n, d.increment, ProgressionMode.weight, unit),
      progressionAmount(l10n, d.deload, ProgressionMode.weight, unit),
      d.failureThreshold,
    );
  }
  // On the advanced axis this sentence is the rep half of the rule — what the
  // load does is what happens at either end of the range, which is the two
  // lines under it.
  final mode = d.onAdvancedAxis ? ProgressionMode.reps : d.progression;
  final step = d.onAdvancedAxis ? d.repsIncrement : d.increment;
  final back = d.onAdvancedAxis ? d.repsDeload : d.deload;
  return l10n.itemEditorProgressionRule(
    progressionAmount(l10n, step, mode, unit),
    d.successThreshold,
    progressionAmount(l10n, back, mode, unit),
    d.failureThreshold,
  );
}

/// Compact target/weight/progression summary for a draft item, e.g.
/// "4 × 6–8 · 80 kg · +2.5 kg".
String draftSummary(AppLocalizations l10n, ItemDraft d, String unit) {
  // A cycle's week is written out a set at a time, so the summary lists the
  // rows rather than multiplying one of them — the same choice the training
  // day makes.
  final target = d.cycleRows.isNotEmpty
      ? rowsTargetLabel(l10n, d.cycleRows)
      : setsTargetLabel(
          l10n,
          sets: d.sets,
          progression: d.progression,
          toFailure: d.toFailure,
          holdSeconds: d.holdSeconds,
          // The same phrase the training day shows, and for the same reason: a
          // slot climbing its range aims at one number rather than at the range.
          repsMin: d.goalReps,
          repsMax: d.onAdvancedAxis ? null : d.repsMax,
        );
  final weight = d.weightKg == null
      ? null
      : l10n.unitWeightShort(
          fmtWeight(toDisplayWeight(d.weightKg!, unit)), unitSuffix(l10n, unit));
  // A cycle's number is a training max rather than a load, and it is named as
  // one here for the reason the board names it: the sets beside it are
  // percentages of it, so an unlabelled figure claims to be what you lift.
  final w = weight != null && d.scheme == SetScheme.cycle
      ? l10n.itemEditorSummaryTrainingMax(weight)
      : weight;
  final step = '+${progressionAmount(l10n, d.increment, d.progression, unit)}';
  // A slot whose sets are a ladder must not read in the list exactly like one
  // whose sets are all alike. Flat says nothing, because flat is the default
  // and naming it on every row would be noise on nearly every row.
  final scheme = d.scheme == SetScheme.flat
      ? null
      : _SchemePicker._label(l10n, d.scheme).toLowerCase();
  return [target, ?w, ?scheme, step].join(' · ');
}

/// The ordered exercise list of one workout: add, reorder, configure, remove.
///
/// Edits [items] in place and reports via [onChanged], so the owner can hold
/// the list as its own draft state and decide when to persist it.
class WorkoutItemsEditor extends StatefulWidget {
  const WorkoutItemsEditor({
    super.key,
    required this.items,
    required this.unit,
    required this.routineRest,
    this.defaultBarKg = 0,
    this.onChanged,
  });

  final List<ItemDraft> items;
  final String unit;

  /// The app-wide bar, so a bar-loaded slot can say what it may not go below.
  final double defaultBarKg;

  /// The routine's default rest, shown when an item has no override.
  final int routineRest;
  final VoidCallback? onChanged;

  @override
  State<WorkoutItemsEditor> createState() => _WorkoutItemsEditorState();
}

class _WorkoutItemsEditorState extends State<WorkoutItemsEditor> {
  List<ItemDraft> get _items => widget.items;

  void _bump(VoidCallback fn) {
    setState(fn);
    widget.onChanged?.call();
  }

  void _reorder(int from, int to) {
    _bump(() {
      _items.insert(to, _items.removeAt(from));
      _normalise();
    });
  }

  void _remove(int i) => _bump(() {
        _items.removeAt(i);
        _normalise();
      });

  /// Drops a join the list can no longer hold. A row keeps its join as it moves,
  /// so dragging a joined row to the top — or deleting the row it was joined to,
  /// leaving it at the top — is where a list would otherwise claim that the
  /// first exercise is supersetted with the one above it.
  void _normalise() {
    if (_items.isNotEmpty) _items.first.supersetWithPrevious = false;
  }

  Future<void> _addExercise() async {
    // Dismissing a sheet hands focus back to whatever had it, which pops the
    // keyboard open on the name field above. Nobody asked to rename anything.
    // Dropping focus before opening leaves nothing to hand back, which beats
    // racing the restore on the way in.
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await pickExercise(context);
    FocusManager.instance.primaryFocus?.unfocus();
    if (picked == null) return;
    // In the movement's own unit, where it has one: a slot on a pounds-pinned
    // lift opens on the 5 lb step rather than on the metric pair.
    _bump(() => _items.add(
          ItemDraft.forExercise(
            picked,
            unit: unitForExercise(widget.unit, picked.unitOverride),
          ),
        ));
    // Straight into the new slot's settings: an exercise nobody has set the
    // sets, reps and weight on is not finished being added, and landing back on
    // the list makes every add two taps with the second one easy to forget.
    // Backing out keeps it at its defaults — it is already in the workout, and
    // the sheet is for tuning it rather than for confirming it.
    if (!mounted) return;
    await _configure(_items.length - 1);
  }

  Future<void> _configure(int i) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final l10n = AppLocalizations.of(context);
    // The movement directly above, as the screen names it — what the superset
    // checkbox is offering to join to. Null on the first row, which has nothing
    // above it.
    final above = i == 0
        ? null
        : seededName(
            l10n, _items[i - 1].exercise?.seedKey, _items[i - 1].name);
    await showItemConfigSheet(
      context,
      draft: _items[i],
      unit: _items[i].unitIn(widget.unit),
      routineRest: widget.routineRest,
      defaultBarKg: widget.defaultBarKg,
      exerciseAbove: above,
      onChanged: () => _bump(() {}),
    );
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final joins = normaliseJoins([for (final d in _items) d.supersetWithPrevious]);
    return BuilderReorderList<ItemDraft>(
      caption: l10n.itemEditorCaption,
      items: _items,
      emptyText: l10n.itemEditorEmpty,
      addLabel: l10n.itemEditorAdd,
      onAdd: _addExercise,
      onReorder: _reorder,
      rowBuilder: (i, draft) => BuilderReorderRow(
        index: i,
        title: draft.name,
        subtitle: draftSummary(l10n, draft, draft.unitIn(widget.unit)),
        // The group is tagged once, on the row it starts at, and drawn on all of
        // its rows.
        badge: inSuperset(joins, i) && !joins[i] ? l10n.commonSuperset : null,
        grouped: inSuperset(joins, i),
        onTap: () => _configure(i),
        onRemove: () => _remove(i),
      ),
    );
  }
}

/// Opens the slot editor over [draft], editing it in place and reporting each
/// change through [onChanged].
///
/// Public because the builder is no longer the only screen that configures a
/// slot: the live board opens the same sheet from the settings control beside an
/// exercise's name, so a progression rule can be changed where somebody notices
/// it is wrong. Passing no [exerciseAbove] leaves out the superset checkbox,
/// which is what the board does — what is trained in the same round is the shape
/// of the day, and re-shaping it around sets already logged is the one edit a
/// running session refuses.
Future<void> showItemConfigSheet(
  BuildContext context, {
  required ItemDraft draft,
  required String unit,
  required int routineRest,
  double defaultBarKg = 0,
  String? exerciseAbove,
  required VoidCallback onChanged,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Without this the sheet grows behind the status bar and the camera
      // cut-out takes a bite out of the exercise name at the top of it.
      useSafeArea: true,
      backgroundColor: AppColors.ground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // The keyboard inset is taken here, outside the sheet's own scroll view:
      // that is what ends the viewport above the keyboard, so a field tapped
      // near the bottom of the sheet can be scrolled clear of it rather than
      // left underneath it.
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _ItemConfigSheet(
          draft: draft,
          unit: unit,
          routineRest: routineRest,
          defaultBarKg: defaultBarKg,
          exerciseAbove: exerciseAbove,
          onChanged: onChanged,
        ),
      ),
    );

/// Bottom-sheet editor for a single item's sets / reps / rest / weight, plus
/// the library properties of the movement it stands for.
class _ItemConfigSheet extends ConsumerStatefulWidget {
  const _ItemConfigSheet({
    required this.draft,
    required this.unit,
    required this.routineRest,
    required this.defaultBarKg,
    required this.exerciseAbove,
    required this.onChanged,
  });
  final ItemDraft draft;
  final String unit;
  final int routineRest;
  final double defaultBarKg;

  /// The movement directly above this slot in the workout, named the way the
  /// screens name it — what the superset checkbox offers to join to. Null on the
  /// first slot, which has nothing above it and so gets no checkbox.
  final String? exerciseAbove;
  final VoidCallback onChanged;

  @override
  ConsumerState<_ItemConfigSheet> createState() => _ItemConfigSheetState();
}

class _ItemConfigSheetState extends ConsumerState<_ItemConfigSheet> {
  /// The unit every weight on this sheet is read and typed in.
  ///
  /// Resolved on each build rather than taken once, because the movement behind
  /// the slot is editable from here: swapping it for one pinned to another unit
  /// has to move the fields with it, not leave them reading the unit the sheet
  /// opened in.
  String get _unit => unitForExercise(widget.unit, d.exercise?.unitOverride);

  late final TextEditingController _weight;

  /// Whether the Target card's advanced half is open.
  ///
  /// Shut on a slot that only uses the three fields above it, and open on one
  /// that does not — a setting a slot is actually using must not be hidden
  /// behind a toggle somebody has to think to press. Once open it stays open
  /// for the life of the sheet, including after the last advanced setting is
  /// turned back off: closing the panel out from under the tap that emptied it
  /// is the app arguing with you.
  late bool _advanced = widget.draft.usesAdvanced;

  /// The same, for the Progression card's own half.
  late bool _progressionAdvanced = widget.draft.usesProgressionAdvanced;

  ItemDraft get d => widget.draft;

  /// True when [d] is measured in seconds rather than reps.
  bool get _timed => d.progression.timed;

  /// What an empty weight field says: over a bar, the lightest it can be.
  String _weightHint(AppLocalizations l10n) {
    final floor = d.floorKg(widget.defaultBarKg);
    if (floor <= 0) return l10n.itemEditorWeightUnset;
    return l10n.itemEditorWeightFloor(
      fmtWeight(toDisplayWeight(floor, _unit)),
    );
  }

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(
      text: d.weightKg == null
          ? ''
          : fmtWeight(toDisplayWeight(d.weightKg!, _unit)),
    );
  }

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  /// What one tap of the weight field's − or + is worth.
  ///
  /// The slot's own rates, because they are what a session would do to this
  /// weight: + adds the step up and − takes off the back off, and on a slot
  /// climbing 2.5 and dropping 5 the two taps are deliberately different sizes.
  /// A back-off of zero is a slot that never lightens on a miss, which is a real
  /// answer for progression and a dead button here, so − borrows the step
  /// instead. Where the slot progresses by reps or by seconds there is no weight
  /// rate to borrow at all and the unit's own step stands in.
  double _weightNudge(int sign) {
    final onWeightRates =
        d.progression == ProgressionMode.weight || d.onAdvancedAxis;
    if (!onWeightRates) return unitStepKg(_unit);
    final rate = sign > 0 || d.deload <= 0 ? d.increment : d.deload;
    return rate > 0 ? rate : unitStepKg(_unit);
  }

  /// Whether − has anywhere to go: a field nobody has filled in has no number to
  /// take anything off, and one already at the bar is at the floor.
  bool get _canNudgeWeightDown {
    final w = d.weightKg;
    return w != null && w > d.floorKg(widget.defaultBarKg) + 1e-9;
  }

  void _nudgeWeight(int sign) {
    final floor = d.floorKg(widget.defaultBarKg);
    final current = d.weightKg;
    if (current == null) {
      // + on an empty field fills in the lightest the movement can be — the bar
      // it is loaded on, or one tap's worth where there is no bar.
      if (sign > 0) _setWeight(floor > 0 ? floor : _weightNudge(1));
      return;
    }
    final next = current + sign * _weightNudge(sign);
    _setWeight(next < floor ? floor : next);
  }

  /// Writes a nudged weight to the draft and to the box at once.
  ///
  /// Rounded to what the box will actually show, so a rate converted from
  /// pounds cannot leave a tail behind the text on every tap.
  void _setWeight(double kg) {
    final display = roundStepWeight(toDisplayWeight(kg, _unit));
    _weight.text = fmtWeight(display);
    _bump(() => d.weightKg = toKg(display, _unit));
  }

  /// One of the faint lines this sheet explains itself with — the axis it has
  /// no choice about, and the rule its numbers add up to.
  Widget _note(String text) => Text(
        text,
        style: kMono.copyWith(
            fontSize: 11, height: 1.5, color: AppColors.faint),
      );

  /// A progression amount in the display unit, as a weight — what the two ends
  /// of a climbed range are worth, whichever axis the sentence around it is
  /// about.
  String _weightAmount(AppLocalizations l10n, double amount) =>
      progressionAmount(l10n, amount, ProgressionMode.weight, _unit);

  void _bump(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  /// Opens the same form the library edits a movement you made with, and takes
  /// what comes back — the name at the top of this sheet is one of the things
  /// it may have changed.
  Future<void> _editExercise() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final saved = await Navigator.of(context, rootNavigator: true)
        .push<Exercise>(
          MaterialPageRoute(
            builder: (_) => ExerciseFormScreen(exerciseId: d.exerciseId),
          ),
        );
    if (saved == null || !mounted) return;
    _adopt(saved);
  }

  /// Takes the library's new facts, and the weight field with them: a movement
  /// that has just been told it carries nothing has no number left to show.
  void _adopt(Exercise e) {
    _bump(() {
      // The unit the *new* movement is read in: swapping a slot onto a
      // pounds-pinned lift is a move between units for every default it takes.
      d.adoptExercise(e, unit: unitForExercise(_unit, e.unitOverride));
      if (d.weightKg == null) _weight.text = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mq = MediaQuery.of(context);
    final ex = d.exercise;
    // The exercise is editable from this sheet, and from the library while a
    // builder sits behind it. Either way the slot above has to hear about it.
    ref.listen(exerciseLibraryProvider, (_, next) {
      final all = next.value;
      if (all == null || !mounted) return;
      for (final e in all) {
        if (e.id == d.exerciseId) _adopt(e);
      }
    });
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + mq.padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(d.muscle,
                          style: TextStyle(
                              fontSize: 13, color: AppColors.muted)),
                    ],
                  ),
                ),
                // Dragging the sheet down closes it too, but only if your
                // thumb lands somewhere that is not the scrolling content.
                // A close button is always where you left it.
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: AppColors.muted,
                  tooltip: l10n.itemEditorClose,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 14),
            builderCard(l10n.itemEditorTarget, [
              builderGrid([
                BuilderField(
                  label: l10n.itemEditorSets,
                  child: NumberStepper(
                    value: d.setCount,
                    min: 1,
                    max: 12,
                    // A cycle writes its week out a row at a time, so how many
                    // rows the week has *is* how many sets there are. The
                    // stepper reads it and goes dead rather than disappearing —
                    // the count is still a fact about the slot, it is just not
                    // this control's to set any more.
                    enabled: d.scheme != SetScheme.cycle,
                    onChanged: (v) => _bump(() => d.sets = v),
                  ),
                ),
                if (_timed)
                  BuilderField(
                    label: l10n.itemEditorHold,
                    child: NumberStepper(
                      value: d.holdSeconds,
                      suffix: l10n.itemEditorSecondsSuffix,
                      step: 5,
                      min: 5,
                      max: 600,
                      onChanged: (v) => _bump(() => d.holdSeconds = v),
                    ),
                  )
                else
                  BuilderField(
                    label: d.toFailure
                        ? l10n.itemEditorRepsToBeat
                        : l10n.itemEditorReps,
                    child: NumberStepper(
                      value: d.repsMin,
                      min: 1,
                      max: 100,
                      onChanged: (v) => _bump(() {
                        d.repsMin = v;
                        if (d.repsMax != null && d.repsMax! < v) d.repsMax = v;
                      }),
                    ),
                  ),
                BuilderField(
                  label: l10n.itemEditorRest,
                  // Editing rest here creates an explicit per-exercise
                  // override; the caption is where that gets said, so the
                  // stepper stays the same width as its neighbours.
                  note: d.restSeconds == null
                      ? l10n.itemEditorRestDefault
                      : l10n.itemEditorRestCustom,
                  child: NumberStepper(
                    value: d.restSeconds ?? widget.routineRest,
                    suffix: l10n.itemEditorSecondsSuffix,
                    step: 15,
                    min: 0,
                    max: 300,
                    onChanged: (v) => _bump(() => d.restSeconds = v),
                  ),
                ),
              ]),
              // How this slot is performed against the one above it. In the
              // basic half rather than behind Advanced: a superset changes what
              // you do in the gym far more than a rep range does.
              if (widget.exerciseAbove case final above?) ...[
                const SizedBox(height: 16),
                _CheckRow(
                  key: kSupersetCheckKey,
                  label: l10n.itemEditorSupersetWith(above),
                  value: d.supersetWithPrevious,
                  onChanged: (v) => _bump(() => d.supersetWithPrevious = v),
                  // The one word on this sheet that is a training method rather
                  // than a number, and the only one somebody can tick without
                  // knowing what they have asked for. Behind a tap, not under the
                  // control: a paragraph nobody needs would sit there for ever,
                  // and this is read once.
                  onExplain: () => _explainSuperset(context),
                ),
              ],
              // A hold has no rep range, no failure and no ladder, so it has no
              // advanced half either — and a toggle that opens onto nothing is
              // worse than no toggle.
              if (!_timed) ...[
                const SizedBox(height: 14),
                _AdvancedToggle(
                  open: _advanced,
                  onTap: () => setState(() => _advanced = !_advanced),
                ),
                if (_advanced) ...[
                  const SizedBox(height: 14),
                  // Sets taken to failure are not aiming at a range, so the
                  // stepper goes dead — and keeps what it is holding. Taking
                  // the field away would take the number with it, and trying
                  // failure for a week would cost the range you had.
                  builderGrid([
                    BuilderField(
                      label: l10n.itemEditorRepRange,
                      // The range it currently produces, so the caption says
                      // what the number does rather than where it goes. The
                      // Reps field it extends is in the basic half above, out
                      // of sight of this one.
                      note: d.repsMax == null
                          ? null
                          : l10n.itemEditorRepRangeSpan(d.repsMin, d.repsMax!),
                      child: NumberStepper(
                        key: kRepRangeFieldKey,
                        // Stepping down past the lower bound drops the upper
                        // one entirely — no stray clear button to knock the
                        // row out of line with the rest of the grid.
                        value: d.repsMax ?? d.repsMin,
                        isEmpty: d.repsMax == null,
                        emptyLabel: l10n.itemEditorNoUpper,
                        min: d.repsMin,
                        max: 100,
                        enabled: !d.toFailure,
                        onChanged: (v) => _bump(() => d.repsMax = v),
                        onClear: () => _bump(() => d.repsMax = null),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _CheckRow(
                    label: l10n.itemEditorToFailure,
                    value: d.toFailure,
                    onChanged: (v) => _bump(() => d.toFailure = v),
                  ),
                  const SizedBox(height: 18),
                  _SchemeSection(
                    draft: d,
                    unit: _unit,
                    defaultBarKg: widget.defaultBarKg,
                    onChanged: () => _bump(() {}),
                  ),
                ],
              ],
            ]),
            const SizedBox(height: 14),
            // A movement that carries nothing gets the word, not a field: there
            // is no number to type, and an empty box does not say so.
            if (!d.weightType.carriesWeight)
              builderCard(l10n.itemEditorWeight, [
                Text(
                  l10n.itemEditorBodyweight,
                  style: kMono.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text),
                ),
              ])
            else
              builderCard(
                  d.scheme == SetScheme.cycle
                      ? '${l10n.itemEditorTrainingMax} '
                          '(${unitSuffix(l10n, _unit)})'
                      : l10n.itemEditorWeightWithUnit(
                          unitSuffix(l10n, _unit)), [
                Row(
                  key: kWeightFieldKey,
                  children: [
                    stepperButton(
                      Icons.remove,
                      _canNudgeWeightDown ? () => _nudgeWeight(-1) : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _weight,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: kMono.copyWith(
                            fontSize: 16, fontWeight: FontWeight.w600),
                        // Blank on a loaded movement is a number nobody has
                        // filled in yet, not bodyweight — the loading says which
                        // it is, and this one carries a weight. Over a bar, the
                        // hint is the bar: it is the floor the value is held at
                        // on the way to the database.
                        decoration: builderInput(_weightHint(l10n)),
                        onChanged: (v) {
                          final parsed =
                              double.tryParse(v.trim().replaceAll(',', '.'));
                          _bump(() => d.weightKg =
                              parsed == null ? null : toKg(parsed, _unit));
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    stepperButton(Icons.add, () => _nudgeWeight(1)),
                  ],
                ),
              ]),
            const SizedBox(height: 14),
            builderCard(l10n.itemEditorProgression, [
              // One axis available is no choice to present; the caption names it
              // instead of showing a picker of one.
              if (d.modes.length > 1)
                _ModePicker(
                  modes: d.modes,
                  mode: d.progression,
                  advanced: d.onAdvancedAxis,
                  // Offered wherever the two axes it takes in turn exist, and
                  // dead until there is a range for them to take turns inside —
                  // the tick below is where the sentence saying so fits.
                  advancedOffered: d.modes.contains(ProgressionMode.weight) &&
                      d.modes.contains(ProgressionMode.reps),
                  advancedEnabled: d.canClimbRange,
                  onChanged: (m) =>
                      _bump(() => d.setMode(m, unit: _unit)),
                  onAdvanced: () =>
                      _bump(() => d.setAdvanced(true, unit: _unit)),
                )
              else
                _note(_soleAxis(l10n, d.modes.first)),
              const SizedBox(height: 16),
              // Two amounts on an ordinary axis; four on the one that takes reps
              // and weight in turn, because a rep is not a kilogram. The two
              // thresholds are not doubled with them: a session is clean or
              // missed for the slot, not for one of its axes.
              builderGrid([
                BuilderField(
                  label: d.onAdvancedAxis
                      ? l10n.itemEditorStepUpWeight
                      : l10n.itemEditorStepUpBy,
                  child: _AmountField(
                    key: kStepUpFieldKey,
                    value: d.increment,
                    mode: d.progression,
                    unit: _unit,
                    // A slot that steps up by nothing never progresses, so the
                    // buttons stop at one tap's worth rather than at zero.
                    allowZero: false,
                    onChanged: (v) => _bump(() => d.increment = v),
                  ),
                ),
                if (d.onAdvancedAxis)
                  BuilderField(
                    label: l10n.itemEditorStepUpReps,
                    child: _AmountField(
                      key: kRepsStepUpFieldKey,
                      value: d.repsIncrement,
                      mode: ProgressionMode.reps,
                      unit: _unit,
                      allowZero: false,
                      onChanged: (v) => _bump(() => d.repsIncrement = v),
                    ),
                  ),
                BuilderField(
                  label: d.onAdvancedAxis
                      ? l10n.itemEditorBackOffWeight
                      : l10n.itemEditorBackOffBy,
                  child: _AmountField(
                    key: kBackOffFieldKey,
                    value: d.deload,
                    mode: d.progression,
                    unit: _unit,
                    // Zero is a real answer here: a missed session that never
                    // lightens the load.
                    onChanged: (v) => _bump(() => d.deload = v),
                  ),
                ),
                if (d.onAdvancedAxis)
                  BuilderField(
                    label: l10n.itemEditorBackOffReps,
                    child: _AmountField(
                      key: kRepsBackOffFieldKey,
                      value: d.repsDeload,
                      mode: ProgressionMode.reps,
                      unit: _unit,
                      onChanged: (v) => _bump(() => d.repsDeload = v),
                    ),
                  ),
                // A cycle steps up when it comes round, not after a run of
                // clean sessions — so there is no run to count, and a stepper
                // that changes nothing is worse than no stepper.
                if (d.scheme != SetScheme.cycle)
                  BuilderField(
                    label: l10n.itemEditorCleanSessions,
                    child: NumberStepper(
                      value: d.successThreshold,
                      min: 1,
                      max: 10,
                      onChanged: (v) => _bump(() => d.successThreshold = v),
                    ),
                  ),
                BuilderField(
                  label: l10n.itemEditorMisses,
                  child: NumberStepper(
                    value: d.failureThreshold,
                    min: 1,
                    max: 10,
                    onChanged: (v) => _bump(() => d.failureThreshold = v),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              // The numbers above, read back as the rule they add up to: one
              // sentence on an ordinary axis, and on the advanced one what the
              // reps do plus what happens at each end of the range.
              _note(progressionRule(l10n, d, _unit)),
              if (d.onAdvancedAxis) ...[
                const SizedBox(height: 6),
                _note(l10n.itemEditorRuleAtTop(
                  d.repsMax!,
                  _weightAmount(l10n, d.increment),
                  d.repsMin,
                )),
                const SizedBox(height: 6),
                _note(l10n.itemEditorRuleAtBottom(
                  d.repsMin,
                  _weightAmount(l10n, d.deload),
                  d.repsMax!,
                )),
              ],
              // The ways of advancing most slots never use. In this card rather
              // than beside the rep range one of them reads: how a slot
              // progresses is decided in one place, whatever the rule happens to
              // look at.
              // The toggle holds exactly one control, so it is drawn only
              // where that control can be taken: opening it onto a single dead
              // row is a promise the card then refuses. The greyed pill on the
              // axis row above is what stays on screen meanwhile, so there is
              // still somewhere to find double progression and learn what it
              // wants.
              if (d.canClimbRange || d.onAdvancedAxis) ...[
                const SizedBox(height: 14),
                _AdvancedToggle(
                  rowKey: kProgressionAdvancedKey,
                  open: _progressionAdvanced,
                  onTap: () => setState(
                      () => _progressionAdvanced = !_progressionAdvanced),
                ),
              ],
              if (_progressionAdvanced && (d.canClimbRange || d.onAdvancedAxis)) ...[
                const SizedBox(height: 14),
                _CheckRow(
                  key: kRangeClimbKey,
                  label: l10n.itemEditorAddWeightAtTop,
                  value: d.onAdvancedAxis,
                  enabled: d.canClimbRange,
                  // What the combination does, said once under the one control
                  // that offers it — this is the tick somebody meets without
                  // knowing what they have been offered.
                  note: l10n.itemEditorAddWeightAtTopHint,
                  disabledNote: l10n.itemEditorRangeClimbNeedsRange,
                  onChanged: (v) =>
                      _bump(() => d.setAdvanced(v, unit: _unit)),
                ),
              ],
            ]),
            // Last, and in a card of its own: everything above belongs to this
            // slot, everything here belongs to the movement.
            if (ex != null) ...[
              const SizedBox(height: 14),
              builderCard(l10n.itemEditorExercise, [
                Text(
                  l10n.itemEditorExerciseShared,
                  style: kMono.copyWith(
                      fontSize: 11, height: 1.5, color: AppColors.faint),
                ),
                const SizedBox(height: 16),
                ExerciseLoadingSection(exercise: ex),
                const SizedBox(height: 18),
                ExerciseNoteSection(exercise: ex),
                // The name and the classification of a movement the app
                // shipped are shared vocabulary — a routine code that says
                // "Bench Press" has to mean what everyone else calls that — so
                // the form that changes them is offered only for your own.
                if (ex.isCustom) ...[
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      side: BorderSide(color: AppColors.line),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Icon(Icons.edit_outlined, color: AppColors.accent),
                    label: Text(l10n.itemEditorEditExercise),
                    onPressed: _editExercise,
                  ),
                ],
              ]),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonDone),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one axis a slot has no choice about, named.
String _soleAxis(AppLocalizations l10n, ProgressionMode m) => switch (m) {
      ProgressionMode.time => l10n.itemEditorAxisTime,
      ProgressionMode.reps => l10n.itemEditorAxisReps,
      ProgressionMode.weight => l10n.itemEditorAxisWeight,
    };

/// Finds the Target card's advanced half in a test.
const kAdvancedToggleKey = ValueKey('target-advanced');
const kSchemePickerKey = ValueKey('set-scheme');
const kSchemePercentKey = ValueKey('scheme-percent');
const kSchemePreviewKey = ValueKey('scheme-preview');
const kCycleAddWeekKey = ValueKey('cycle-add-week');
const kRangeClimbKey = ValueKey('add-weight-at-top-of-range');
const kProgressionAdvancedKey = ValueKey('progression-advanced');

/// The one control that opens the rest of the Target card.
///
/// A pill rather than a Material [ExpansionTile]: the card already has its own
/// padding and its own type, and a tile brings a second set of both. The same
/// pill the pickers above it are made of, at the same size — what it opens is
/// half a card, and a small line of coloured text reads as a caption on the
/// half above rather than as the way to the half below.
class _AdvancedToggle extends StatelessWidget {
  const _AdvancedToggle({
    required this.open,
    required this.onTap,
    this.rowKey = kAdvancedToggleKey,
  });

  final bool open;
  final VoidCallback onTap;

  /// Which half of the sheet this one opens — there is one per card, and a test
  /// tapping "Advanced" has to be able to say which.
  final Key rowKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EditorPill(
      key: rowKey,
      label: l10n.itemEditorAdvanced,
      icon: open ? Icons.expand_less : Icons.expand_more,
      on: open,
      onTap: onTap,
    );
  }
}

/// How the sets of this slot differ from one another: the schemes on offer, the
/// percentage the two ladders are made of, the written-out rows of a custom one
/// or the weeks of a cycle, and the whole thing read back as the weights it
/// produces.
class _SchemeSection extends StatelessWidget {
  const _SchemeSection({
    required this.draft,
    required this.unit,
    required this.defaultBarKg,
    required this.onChanged,
  });

  final ItemDraft draft;
  final String unit;
  final double defaultBarKg;

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                l10n.itemEditorSetScheme,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: sectionLabelStyle(),
              ),
            ),
            // A cycle is the one thing this picker offers that is a way of
            // training rather than a shape, and somebody can pick it without
            // knowing what they have asked for. Explained behind a tap, on the
            // same terms as the superset tick — and only where it is on offer.
            // Only while the slot is on one. A cycle is the one thing this
            // picker offers that is a way of training rather than a shape, and
            // somebody can pick it without knowing what they have asked for.
            if (d.scheme == SetScheme.cycle)
              IconButton(
                key: kCycleExplainKey,
                onPressed: () => _explainCycle(context),
                visualDensity: VisualDensity.compact,
                tooltip: l10n.itemEditorCycleWhat,
                icon:
                    Icon(Icons.info_outline, size: 16, color: AppColors.faint),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _SchemePicker(
          key: kSchemePickerKey,
          scheme: d.scheme,
          // The rows a custom scheme was given survive a trip through another
          // scheme and back, so trying a ramp does not throw away what was
          // typed. Only a custom slot ever writes them to the database, and a
          // cycle's weeks are kept on exactly the same terms.
          onChanged: (s) {
            d.scheme = s;
            if (s.isCustom && d.customSets.isEmpty) {
              d.customSets = _seedCustomRows(d);
            }
            if (s == SetScheme.cycle && d.cycle.isEmpty) {
              d.cycle = [_seedCustomRows(d)];
            }
            onChanged();
          },
        ),
        if (d.scheme == SetScheme.backOff || d.scheme == SetScheme.ramp) ...[
          const SizedBox(height: 14),
          builderGrid([
            BuilderField(
              label: d.scheme == SetScheme.backOff
                  ? l10n.itemEditorSchemeDropPerSet
                  : l10n.itemEditorSchemeStepPerSet,
              child: NumberStepper(
                key: kSchemePercentKey,
                value: d.schemePercent,
                suffix: '%',
                step: 5,
                min: 5,
                max: 50,
                onChanged: (v) {
                  d.schemePercent = v;
                  onChanged();
                },
              ),
            ),
          ]),
        ],
        if (d.scheme.isCustom) ...[
          const SizedBox(height: 14),
          // One row per set the slot asks for, so adding a set adds a row
          // rather than leaving the two lists to disagree.
          for (var i = 0; i < d.sets; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _CustomSetRow(
              index: i,
              row: i < d.customSets.length
                  ? d.customSets[i]
                  : CustomSet(reps: d.goalReps, percent: 100),
              onChanged: (row) {
                final rows = [
                  for (var j = 0; j < d.sets; j++)
                    j < d.customSets.length
                        ? d.customSets[j]
                        : CustomSet(reps: d.goalReps, percent: 100),
                ];
                rows[i] = row;
                d.customSets = rows;
                onChanged();
              },
            ),
          ],
        ],
        if (d.scheme == SetScheme.cycle) ...[
          const SizedBox(height: 14),
          _CycleEditor(
            draft: d,
            onChanged: onChanged,
          ),
        ],
        const SizedBox(height: 14),
        // The scheme read back as the sets it adds up to — the same trick the
        // progression card plays with its four numbers.
        Text(
          key: kSchemePreviewKey,
          _schemeLine(l10n, d, unit, defaultBarKg),
          style:
              kMono.copyWith(fontSize: 11, height: 1.5, color: AppColors.faint),
        ),
      ],
    );
  }
}

/// What a fresh custom scheme opens on: the slot as it already is, one row per
/// set. Editing from what you have beats editing from blanks.
List<CustomSet> _seedCustomRows(ItemDraft d) => [
      for (var i = 0; i < d.sets; i++)
        CustomSet(reps: d.goalReps, percent: 100),
    ];

/// One outlined, tappable option: the shape every picker on this sheet is made
/// of, and the shape the two Advanced disclosures take.
///
/// One widget rather than one per picker. They were three copies of the same
/// Material/InkWell/Ink sandwich, and the third had drifted — a disclosure set
/// in 12-point coloured text beside 13-point bordered pills reads as a caption
/// on the card above it rather than as the control that opens half of it.
class EditorPill extends StatelessWidget {
  const EditorPill({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
    this.icon,
    this.centred = false,
  });

  final String label;

  /// Whether this is the option in force — accent border and accent text.
  final bool on;

  /// Null is a dead pill: shown, greyed, and not tappable.
  final VoidCallback? onTap;

  /// Drawn before the label, in the label's own colour.
  final IconData? icon;

  /// Whether the label sits in the middle. True where the pill is stretched to
  /// a share of the row; false where it is only as wide as its own text.
  final bool centred;

  @override
  Widget build(BuildContext context) {
    final live = onTap != null;
    final colour =
        on ? AppColors.accent : (live ? AppColors.muted : AppColors.faint);
    final text = Text(
      label,
      textAlign: centred ? TextAlign.center : TextAlign.start,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: kMono.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: colour,
      ),
    );
    return Material(
      color: on ? AppColors.accent.withValues(alpha: 0.16) : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: on
                  ? AppColors.accent
                  : (live
                      ? AppColors.line
                      : AppColors.line.withValues(alpha: 0.5)),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: icon == null
              ? text
              : Row(
                  mainAxisSize: centred ? MainAxisSize.min : MainAxisSize.max,
                  mainAxisAlignment: centred
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Icon(icon, size: 18, color: colour),
                    const SizedBox(width: 8),
                    // The label gives before the icon does, as everywhere else.
                    Flexible(child: text),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The scheme as the sets it produces: "100 · 90 · 80 kg", or the rep counts
/// alone on a movement with no weight to scale.
String _schemeLine(
  AppLocalizations l10n,
  ItemDraft d,
  String unit,
  double defaultBarKg,
) {
  final targets = d.targets(unit: unit, defaultBarKg: defaultBarKg);
  final sep = l10n.itemEditorSchemeSeparator;
  if (targets.every((t) => t.weightKg == null)) {
    return targets.map((t) => '${t.reps}').join(sep);
  }
  // Reps only when they differ set to set, so a back-off does not repeat the
  // same number three times beside the weights that are the point of it.
  final varyingReps = targets.map((t) => t.reps).toSet().length > 1;
  final body = targets
      .map((t) => varyingReps
          ? '${t.reps}×${fmtWeight(toDisplayWeight(t.weightKg ?? 0, unit))}'
          : fmtWeight(toDisplayWeight(t.weightKg ?? 0, unit)))
      .join(sep);
  return '$body ${unitSuffix(l10n, unit)}';
}

/// The four schemes as one row of pills.
class _SchemePicker extends StatelessWidget {
  const _SchemePicker({
    super.key,
    required this.scheme,
    required this.onChanged,
  });

  final SetScheme scheme;
  final ValueChanged<SetScheme> onChanged;

  static String _label(AppLocalizations l10n, SetScheme s) => switch (s) {
        SetScheme.flat => l10n.itemEditorSchemeFlat,
        SetScheme.backOff => l10n.itemEditorSchemeBackOff,
        SetScheme.ramp => l10n.itemEditorSchemeRamp,
        SetScheme.custom => l10n.itemEditorSchemeCustom,
        SetScheme.cycle => l10n.itemEditorSchemeCycle,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Wrapped rather than four equal columns: "Back-off" in a language that
    // spells it out does not fit a quarter of a phone at 2× text.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in SetScheme.values)
          EditorPill(
            label: _label(l10n, s),
            on: s == scheme,
            onTap: () => onChanged(s),
          ),
      ],
    );
  }
}

/// One written-out set of a custom scheme: which set it is, its reps, and its
/// percentage of the slot's weight.
class _CustomSetRow extends StatelessWidget {
  const _CustomSetRow({
    required this.index,
    required this.row,
    required this.onChanged,
  });

  final int index;
  final CustomSet row;
  final ValueChanged<CustomSet> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A row with no ceiling has no upper bound to set, so the bound goes dead
    // rather than away — the same rule the slot's own range follows under
    // "to failure", and for the same reason: taking the field away takes the
    // number with it.
    final capped = !row.amrap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.itemEditorSchemeSetNumber(index + 1),
          style: kMono.copyWith(
              fontSize: 11, letterSpacing: 0.5, color: AppColors.faint),
        ),
        const SizedBox(height: 6),
        builderGrid([
          BuilderField(
            label: l10n.itemEditorReps,
            child: NumberStepper(
              value: row.reps,
              min: 1,
              max: 100,
              onChanged: (v) => onChanged(_with(reps: v)),
            ),
          ),
          BuilderField(
            label: l10n.itemEditorSchemeOfWeight,
            child: NumberStepper(
              value: row.percent,
              suffix: '%',
              step: 5,
              min: 0,
              max: 150,
              onChanged: (v) => onChanged(_with(percent: v)),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        builderGrid([
            BuilderField(
              label: l10n.itemEditorRepRange,
              child: NumberStepper(
                value: row.repsMax ?? row.reps,
                isEmpty: row.repsMax == null,
                emptyLabel: l10n.itemEditorNoUpper,
                min: row.reps,
                max: 100,
                enabled: capped,
                onChanged: (v) => onChanged(_with(repsMax: v)),
                onClear: () => onChanged(_with(clearMax: true)),
              ),
            ),
          ]),
        const SizedBox(height: 10),
        _CheckRow(
          label: l10n.itemEditorSchemeAmrap,
          value: row.amrap,
          onChanged: (v) => onChanged(_with(amrap: v, clearMax: v)),
        ),
      ],
    );
  }

  /// The row with one thing changed. Written out because [CustomSet] is
  /// immutable and every control here changes exactly one of its four fields.
  CustomSet _with({
    int? reps,
    int? percent,
    int? repsMax,
    bool? amrap,
    bool clearMax = false,
  }) {
    final open = amrap ?? row.amrap;
    final top = clearMax || open ? null : (repsMax ?? row.repsMax);
    final bottom = reps ?? row.reps;
    return CustomSet(
      reps: bottom,
      // Raising the bottom past the top would ask for a range that runs
      // backwards; the top comes with it instead.
      repsMax: top == null ? null : (top < bottom ? bottom : top),
      amrap: open,
      percent: percent ?? row.percent,
    );
  }
}

/// The weeks of a cycle: each one a list of written-out rows, added, edited and
/// removed a week at a time.
///
/// Deliberately a plain column rather than anything reorderable. Weeks are read
/// in the order they are written and a cycle is three or four of them — the
/// drag handles that earn their place on a list of exercises would be chrome
/// here.
class _CycleEditor extends StatefulWidget {
  const _CycleEditor({
    required this.draft,
    required this.onChanged,
  });

  final ItemDraft draft;
  final VoidCallback onChanged;

  @override
  State<_CycleEditor> createState() => _CycleEditorState();
}

class _CycleEditorState extends State<_CycleEditor> {
  /// The one week showing its rows, or null for all of them folded.
  ///
  /// One at a time rather than a set of flags. Four weeks of four sets each is
  /// sixteen rep steppers, sixteen percentages and sixteen headings in one
  /// scrolling column, and the question anybody is actually holding — how does
  /// this week differ from the one before it — is unanswerable in that. Folded,
  /// a week is one line that answers it.
  late int? _open = widget.draft.cycle.isEmpty
      ? null
      : widget.draft.cyclePosition % widget.draft.cycle.length;

  ItemDraft get _d => widget.draft;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var w = 0; w < _d.cycle.length; w++) ...[
          if (w > 0) const SizedBox(height: 12),
          _CycleWeekCard(
            key: cycleWeekKey(w),
            // Counting from one, and marked when it is the week the next
            // session will actually run — the cycle's position is program
            // state the builder shows rather than edits.
            title: l10n.itemEditorCycleWeek(w + 1),
            rows: _d.cycle[w],
            open: w == _open,
            current: _d.cycle.length > 1 && w == _d.cyclePosition % _d.cycle.length,
            onToggle: () => setState(() => _open = w == _open ? null : w),
            onRemove: _d.cycle.length > 1 ? () => _removeWeek(w) : null,
            onRowChanged: (i, row) => _setRow(w, i, row),
            onAddSet: () => _addSet(w),
            onRemoveSet: _d.cycle[w].length > 1 ? () => _removeSet(w) : null,
          ),
        ],
        const SizedBox(height: 14),
        _AddWeekButton(onTap: _addWeek),
      ],
    );
  }

  void _setRow(int week, int index, CustomSet row) {
    final weeks = [for (final w in _d.cycle) [...w]];
    weeks[week][index] = row;
    _d.cycle = weeks;
    widget.onChanged();
  }

  void _addSet(int week) {
    final weeks = [for (final w in _d.cycle) [...w]];
    // The last row again rather than a blank: a week is written by copying the
    // set above it and changing one number.
    weeks[week].add(weeks[week].isEmpty
        ? CustomSet(reps: _d.goalReps, percent: 100)
        : weeks[week].last);
    _d.cycle = weeks;
    widget.onChanged();
  }

  void _removeSet(int week) {
    final weeks = [for (final w in _d.cycle) [...w]];
    weeks[week].removeLast();
    _d.cycle = weeks;
    widget.onChanged();
  }

  /// A new week is a copy of the last one, for the reason a new set is a copy
  /// of the set above it: week two of a cycle differs from week one by a rep
  /// count and a percentage, not by everything.
  void _addWeek() {
    _d.cycle = [
      ..._d.cycle,
      if (_d.cycle.isEmpty)
        _seedCustomRows(_d)
      else
        [..._d.cycle.last],
    ];
    // A week you just asked for is a week you are about to edit, so it opens —
    // and the one you were looking at folds, which is the accordion working.
    setState(() => _open = _d.cycle.length - 1);
    widget.onChanged();
  }

  void _removeWeek(int week) {
    final weeks = [for (final w in _d.cycle) [...w]]..removeAt(week);
    _d.cycle = weeks;
    // The position is held inside what is left rather than reset: removing
    // week four must not send a slot on week three back to week one.
    if (_d.cyclePosition >= weeks.length && weeks.isNotEmpty) {
      _d.cyclePosition = weeks.length - 1;
    }
    setState(() {
      if (_open == null) return;
      // The weeks after the removed one have all moved up one.
      _open = _open == week
          ? null
          : (_open! > week ? _open! - 1 : _open);
    });
    widget.onChanged();
  }
}

/// Finds one week of a cycle in a test.
ValueKey<String> cycleWeekKey(int week) => ValueKey('cycle-week-$week');

/// One week of a cycle: a card of its own, headed by the tap that folds it.
///
/// The card is what keeps four weeks from reading as one long list of steppers.
/// Its rows are boxed inside it for the same reason one level down — "Set 2" in
/// small type over a grid is a heading only while nothing else on screen looks
/// like the grid under it.
class _CycleWeekCard extends StatelessWidget {
  const _CycleWeekCard({
    super.key,
    required this.title,
    required this.rows,
    required this.open,
    required this.current,
    required this.onToggle,
    required this.onRemove,
    required this.onRowChanged,
    required this.onAddSet,
    required this.onRemoveSet,
  });

  final String title;
  final List<CustomSet> rows;
  final bool open;

  /// Whether this is the week the next session will run.
  final bool current;

  final VoidCallback onToggle;
  final VoidCallback? onRemove;
  final void Function(int index, CustomSet row) onRowChanged;
  final VoidCallback onAddSet;
  final VoidCallback? onRemoveSet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: current ? AppColors.accent : AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Row(
                children: [
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: current ? AppColors.accent : AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      current ? l10n.itemEditorCycleWeekNext(title) : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: kMono.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: current ? AppColors.accent : AppColors.muted,
                      ),
                    ),
                  ),
                  // Folded, the heading carries the week read back, so nothing
                  // has to be opened to see what it asks for.
                  if (!open) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _summary(l10n),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kMono.copyWith(
                            fontSize: 12, color: AppColors.faint),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  if (onRemove != null)
                    IconButton(
                      onPressed: onRemove,
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.itemEditorCycleRemoveWeek,
                      icon: Icon(Icons.close, size: 18, color: AppColors.faint),
                    )
                  else
                    const SizedBox(width: 6),
                ],
              ),
            ),
          ),
          if (open) ...[
            Divider(height: 1, thickness: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.line.withValues(alpha: 0.6)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: _CustomSetRow(
                          index: i,
                          row: rows[i],
                          onChanged: (row) => onRowChanged(i, row),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  _CycleActions(onAddSet: onAddSet, onRemoveSet: onRemoveSet),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The week in one line — "5/5/5+ · 65/75/85%".
  String _summary(AppLocalizations l10n) => l10n.itemEditorCycleWeekSummary(
        rowsTargetLabel(l10n, rows),
        joinRowLabels(l10n, rows.map((r) => '${r.percent}')),
      );
}

/// Add or drop a set inside one week.
class _CycleActions extends StatelessWidget {
  const _CycleActions({required this.onAddSet, required this.onRemoveSet});

  final VoidCallback onAddSet;
  final VoidCallback? onRemoveSet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Wrapped rather than a row: these sit inside a week card inside the
    // sheet's own padding, so two spelled-out buttons do not fit a narrow
    // phone's line — and at 2x text they do not fit anybody's.
    return Wrap(
      spacing: 8,
      children: [
        TextButton.icon(
          onPressed: onAddSet,
          icon: const Icon(Icons.add, size: 16),
          label: Text(l10n.itemEditorCycleAddSet),
        ),
        if (onRemoveSet != null)
          TextButton.icon(
            onPressed: onRemoveSet,
            icon: const Icon(Icons.remove, size: 16),
            label: Text(l10n.itemEditorCycleRemoveSet),
          ),
      ],
    );
  }
}

class _AddWeekButton extends StatelessWidget {
  const _AddWeekButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton.icon(
      key: kCycleAddWeekKey,
      onPressed: onTap,
      icon: const Icon(Icons.add, size: 18),
      label: Text(l10n.itemEditorCycleAddWeek),
    );
  }
}

/// What a superset is, for somebody who has just been offered one.
///
/// The screens label their controls and leave the vocabulary to the tour — but a
/// superset is the one thing on this sheet that is a training method rather than a
/// number, and it is the one a user can switch on without knowing what they have
/// asked for. So it is explained, in two sentences, behind a tap: an icon nobody
/// has to press, rather than a paragraph under the checkbox that everybody has to
/// read past for ever.
Future<void> _explainSuperset(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showAppDialog<void>(
    context,
    builder: (ctx) => AppDialog(
      title: l10n.itemEditorSupersetWhat,
      content: Text(l10n.itemEditorSupersetExplained),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.commonDone),
        ),
      ],
    ),
  );
}

/// Finds the (i) beside the Set scheme label in a test.
const kCycleExplainKey = ValueKey('cycle-explain');


/// What a cycle is, for somebody who has just been offered one.
///
/// The second thing on this sheet explained rather than labelled, and for the
/// reason the superset is: it is a way of training rather than a number, and
/// picking it without knowing what it does gets you a slot whose weight stops
/// moving for a month. Behind a tap, read once — see [_explainSuperset].
Future<void> _explainCycle(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showAppDialog<void>(
    context,
    builder: (ctx) => AppDialog(
      title: l10n.itemEditorCycleWhat,
      content: Text(l10n.itemEditorCycleExplained),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.commonDone),
        ),
      ],
    ),
  );
}

/// A label with a checkbox, tappable across its whole width.
///
/// [onExplain] hangs an info icon on the end of the row — for a setting whose
/// label names something the user may not know.
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onExplain,
    this.enabled = true,
    this.note,
    this.disabledNote,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onExplain;

  /// Whether the option can be taken at all. A row that cannot is greyed and
  /// untickable rather than absent — see [disabledNote].
  final bool enabled;

  /// The one line under the row saying what the option does, shown whether or
  /// not it can be taken. For a setting whose label names a training method
  /// rather than a number — where the alternative is a word nobody can act on.
  final String? note;

  /// The one line under a disabled row saying what it wants before it can be
  /// ticked. Not a caption explaining the option: it is what somebody has to do
  /// next, which is the one thing a helper line under a control is for.
  final String? disabledNote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final row = Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            // Null is what makes Flutter draw the box as disabled, and it is
            // also what stops the tap: one signal rather than a grey paint job
            // over a control that still works.
            onChanged: enabled ? (v) => onChanged(v ?? false) : null,
            activeColor: AppColors.accent,
            checkColor: const Color(0xFF1A0E07),
            side: BorderSide(color: AppColors.line, width: 1.5),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 12),
        // The label gives; the checkbox is the control and stays whole.
        Expanded(
          child: Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                color: enabled ? null : AppColors.faint,
              )),
        ),
        if (onExplain != null)
          IconButton(
            key: kSupersetHintKey,
            onPressed: onExplain,
            icon: const Icon(Icons.info_outline, size: 20),
            color: AppColors.accent,
            tooltip: l10n.itemEditorSupersetWhat,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
      ],
    );

    // What the option does, then — while it cannot be taken — what it wants
    // first. Both indented to the label rather than to the row, so they read as
    // belonging to this option and not to the next one down.
    final lines = [
      ?note,
      if (!enabled) ?disabledNote,
    ];
    // The lines are inside the tap target, not under it: they are part of what
    // is being offered, and a row that stops reacting halfway down its own
    // explanation is a row that looks broken.
    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row,
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 2),
              child: Text(
                line,
                style: kMono.copyWith(
                    fontSize: 11, height: 1.5, color: AppColors.faint),
              ),
            ),
        ],
      ),
    );
  }
}

/// The ways an exercise may be set to advance, as pills.
///
/// Only ever shows [modes] — the axes its measure allows. Offering to progress
/// a deadlift by time is offering a choice with no right answer in it. The
/// advanced rule is a pill like the others because it is a fourth answer to the
/// same question, and it sits on a row of its own: it is the one whose name is
/// not the number it moves, and three pills abreast leaves no room to say so in
/// any language.
class _ModePicker extends StatelessWidget {
  const _ModePicker({
    required this.modes,
    required this.mode,
    required this.onChanged,
    this.advanced = false,
    this.advancedOffered = false,
    this.advancedEnabled = false,
    this.onAdvanced,
  });
  final List<ProgressionMode> modes;
  final ProgressionMode mode;
  final ValueChanged<ProgressionMode> onChanged;

  /// Whether the slot is on the axis that takes reps and weight in turn — which
  /// is also what makes none of [modes] the selected one.
  final bool advanced;

  /// Whether that pill is shown at all, and whether it can be pressed. Shown
  /// wherever the two axes it combines exist, and dead until there is a rep
  /// range for them to take turns inside.
  final bool advancedOffered;
  final bool advancedEnabled;
  final VoidCallback? onAdvanced;

  static String _label(AppLocalizations l10n, ProgressionMode m) => switch (m) {
        ProgressionMode.weight => l10n.itemEditorModeWeight,
        ProgressionMode.reps => l10n.itemEditorModeReps,
        ProgressionMode.time => l10n.itemEditorModeTime,
      };

  static Key _key(ProgressionMode m) => switch (m) {
        ProgressionMode.weight => kModeWeightKey,
        ProgressionMode.reps => kModeRepsKey,
        ProgressionMode.time => kModeTimeKey,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final m in modes)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: m == modes.last ? 0 : 8),
                  child: EditorPill(
                    key: _key(m),
                    label: _label(l10n, m),
                    centred: true,
                    on: !advanced && m == mode,
                    onTap: () => onChanged(m),
                  ),
                ),
              ),
          ],
        ),
        if (advancedOffered) ...[
          const SizedBox(height: 8),
          EditorPill(
            key: kModeAdvancedKey,
            label: l10n.itemEditorModeAdvanced,
            centred: true,
            on: advanced,
            onTap: advancedEnabled ? onAdvanced : null,
          ),
        ],
      ],
    );
  }

}

/// One tap of a progression amount, in the display unit of [mode].
///
/// A weight moves by the smallest pair of plates a gym actually racks — 1.25 kg
/// in a metric gym, 2.5 lb in a pounds one — rather than by the same number in
/// whichever unit happens to be on. Reps move by one and a hold by five
/// seconds, matching the hold stepper above.
double amountStep(ProgressionMode mode, String unit) => switch (mode) {
      ProgressionMode.weight => unit == 'lb' ? 2.5 : 1.25,
      ProgressionMode.reps => 1,
      ProgressionMode.time => 5,
    };

/// A compact decimal entry for a progression amount, in the mode's own unit,
/// with a − and a + either side of it.
///
/// Weight is typed and shown in the display unit and stored in kilograms like
/// every other weight; reps and seconds are unitless and pass straight through.
/// Typing is not rounded to the tap: 3 kg is a step somebody may want, and only
/// the buttons move in [amountStep]s.
class _AmountField extends StatefulWidget {
  const _AmountField({
    super.key,
    required this.value,
    required this.mode,
    required this.unit,
    required this.onChanged,
    this.allowZero = true,
  });
  final double value;
  final ProgressionMode mode;
  final String unit;

  /// Whether the value may be taken all the way down to nothing. False on the
  /// step-up, where zero is a slot that never progresses.
  final bool allowZero;
  final ValueChanged<double> onChanged;

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  late final TextEditingController _c = TextEditingController(text: _shown);
  final _focus = FocusNode();

  /// The value in the unit it is typed in: the display unit for a weight,
  /// itself for anything else.
  double get _display => widget.mode == ProgressionMode.weight
      ? toDisplayWeight(widget.value, widget.unit)
      : widget.value;

  /// The value as the box shows it.
  String get _shown => fmtWeight(_display);

  double get _step => amountStep(widget.mode, widget.unit);

  /// The lowest this may be driven from the buttons.
  double get _floor => widget.allowZero ? 0 : _step;

  @override
  void initState() {
    super.initState();
    // Leaving the field settles it: a half-typed entry stops disagreeing with
    // the value behind it, and a number below the floor is raised to it. The
    // check waits for the field to be left rather than firing per keystroke,
    // because 1.25 is typed through 1, and refusing that would make the floor
    // impossible to type.
    _focus.addListener(() {
      if (_focus.hasFocus) return;
      if (_display < _floor) {
        _commit(_floor);
      } else if (_c.text != _shown) {
        _c.text = _shown;
      }
    });
  }

  @override
  void didUpdateWidget(_AmountField old) {
    super.didUpdateWidget(old);
    // Switching the axis swaps the amount underneath the field, and so does a
    // button press; typing does not, and rewriting the text mid-edit would
    // fight the cursor.
    if (widget.mode != old.mode || (!_focus.hasFocus && _shown != _c.text)) {
      _c.text = _shown;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _c.dispose();
    super.dispose();
  }

  /// Moves the value one tap, held at [_floor] on the way down.
  void _nudge(int sign) {
    final next = _display + sign * _step;
    _commit(next < _floor ? _floor : next);
  }

  void _commit(double display) {
    // Rounded to what the box will actually show, so a converted pound cannot
    // leave a tail behind the text on every tap.
    final tidy = widget.mode == ProgressionMode.weight
        ? roundStepWeight(display)
        : display;
    _c.text = fmtWeight(tidy);
    widget.onChanged(widget.mode == ProgressionMode.weight
        ? toKg(tidy, widget.unit)
        : tidy);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final suffix = widget.mode == ProgressionMode.weight
        ? unitSuffix(l10n, widget.unit)
        : (widget.mode.timed
            ? l10n.itemEditorSuffixSeconds
            : l10n.itemEditorSuffixReps);
    return SizedBox(
      height: 36, // matches a NumberStepper, so grid rows line up
      child: Row(
        children: [
          stepperButton(
            Icons.remove,
            _display - _step < _floor - 0.001 ? null : () => _nudge(-1),
          ),
          Expanded(
            child: TextField(
                controller: _c,
                focusNode: _focus,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                style: kMono.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  filled: true,
                  fillColor: AppColors.surface,
                  suffixText: suffix,
                  suffixStyle:
                      kMono.copyWith(fontSize: 12, color: AppColors.faint),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.accent),
                  ),
                ),
                onChanged: (v) {
                  final parsed = double.tryParse(v.trim().replaceAll(',', '.'));
                  if (parsed == null || parsed < 0) return;
                  widget.onChanged(widget.mode == ProgressionMode.weight
                      ? toKg(parsed, widget.unit)
                      : parsed);
                },
            ),
          ),
          stepperButton(Icons.add, () => _nudge(1)),
        ],
      ),
    );
  }
}
