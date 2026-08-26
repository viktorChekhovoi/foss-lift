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

const kWeightFieldKey = ValueKey('slot-weight');
const kStepUpFieldKey = ValueKey('amount-step-up');
const kBackOffFieldKey = ValueKey('amount-back-off');
const kRepsStepUpFieldKey = ValueKey('amount-reps-step-up');
const kRepsBackOffFieldKey = ValueKey('amount-reps-back-off');

const kRepRangeFieldKey = ValueKey('rep-range');

const kModeWeightKey = ValueKey('mode-weight');
const kModeRepsKey = ValueKey('mode-reps');
const kModeTimeKey = ValueKey('mode-time');
const kModeAdvancedKey = ValueKey('mode-advanced');
const kGzclTierKey = ValueKey('gzcl-tier');
const kGzclStagesKey = ValueKey('gzcl-stages');

const kSupersetCheckKey = ValueKey('superset-with-previous');
const kSupersetHintKey = ValueKey('superset-hint');

class ItemDraft {
  ItemDraft({
    required this.exerciseId,
    required this.name,
    required this.muscle,
    this.sets = 3,
    this.repsMin = 8,
    this.repsMax,
    this.toFailure = false,
    this.targetRpe,
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
    this.cycleNames = const [],
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
    this.gzclTier,
    List<GzclStage>? gzclStages,
    this.gzclStage = 0,
    this.gzclAmrapTarget = defaultGzclT3AmrapTarget,
    this.supersetWithPrevious = false,
    this.exercise,
    Map<RateAxis, ProgressionRates> sparedRates = const {},
  }) : gzclStages = [...?gzclStages],
       _rates = {...sparedRates},
       progression = _startingMode(measure, weightType, progression),
       increment =
           increment ??
           _startingMode(measure, weightType, progression).defaultIncrement,
       deload =
           deload ??
           _startingMode(measure, weightType, progression).defaultDeload,
       // Exercises without a load must not retain a stale weight.
       weightKg = weightType.carriesWeight ? weightKg : null;

  static ProgressionMode _startingMode(
    ExerciseMeasure measure,
    WeightType weightType,
    ProgressionMode? want,
  ) {
    final allowed = _axesFor(measure, weightType);
    final asked = want ?? ProgressionMode.weight;
    return allowed.contains(asked) ? asked : allowed.first;
  }

  static List<ProgressionMode> _axesFor(
    ExerciseMeasure measure,
    WeightType weightType,
  ) => [
    for (final m in measure.modes)
      if (m != ProgressionMode.weight || weightType.carriesWeight) m,
  ];

  factory ItemDraft.fromView(WorkoutItemView v) => ItemDraft(
    exercise: v.exercise,
    exerciseId: v.exercise.id,
    name: v.exercise.name,
    muscle: v.exercise.muscleGroup,
    sets: v.item.targetSets,
    repsMin: v.item.repsMin,
    repsMax: v.item.repsMax,
    toFailure: v.item.toFailure,
    targetRpe: v.item.targetRpe,
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
    cycleNames: v.item.cycleWeekNameList,
    cyclePosition: v.item.cyclePosition,
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
    gzclTier: v.item.gzclTier,
    gzclStages: v.item.gzclStageList,
    gzclStage: v.item.gzclStage,
    gzclAmrapTarget: v.item.gzclAmrapTarget,
    supersetWithPrevious: v.item.supersetWithPrevious,
    sparedRates: decodeSparedRates(v.item.sparedRates),
  );

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

  Exercise? exercise;

  String name;
  String muscle;

  ExerciseMeasure measure;

  WeightType weightType;

  double? barKg;

  int sets;
  int repsMin;
  int? repsMax;
  bool toFailure;
  int? targetRpe;

  bool addWeightAtTopOfRange;

  double repsIncrement;
  double repsDeload;

  int? repsTarget;

  int? restSeconds;

  double? weightKg;

  SetScheme scheme;

  int schemePercent;

  List<CustomSet> customSets;

  List<List<CustomSet>> cycle;

  List<String> cycleNames;

  String cycleNameOf(int week) => cycleNameAt(cycleNames, week);

  int cyclePosition;

  int get setCount {
    final rows = cycleRows;
    return rows.isEmpty ? sets : rows.length;
  }

  List<CustomSet> get cycleRows =>
      scheme == SetScheme.cycle ? cycleBlockAt(cycle, cyclePosition) : const [];

  bool get runsPercentages => scheme == SetScheme.cycle
      ? cycleRows.isNotEmpty
      : (scheme == SetScheme.custom && customSets.isNotEmpty);

  bool get usesAdvanced =>
      toFailure ||
      repsMax != null ||
      targetRpe != null ||
      scheme != SetScheme.flat;

  bool get usesProgressionAdvanced => addWeightAtTopOfRange;

  bool get canClimbRange =>
      !toFailure && repsMax != null && modes.contains(ProgressionMode.weight);

  bool get onAdvancedAxis => addWeightAtTopOfRange && canClimbRange;

  int get goalReps {
    if (toFailure) return repsMin;
    final top = repsMax;
    if (top == null) return repsMin;
    if (!onAdvancedAxis) return top;
    final goal = repsTarget ?? repsMin;
    return goal < repsMin ? repsMin : (goal > top ? top : goal);
  }

  String unitIn(String appUnit) =>
      unitForExercise(appUnit, exercise?.unitOverride);

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
        targetRpe: targetRpe,
      );

  ProgressionMode progression;
  int holdSeconds;
  double increment;
  double deload;
  int successThreshold;
  int failureThreshold;

  int successStreak;
  int failStreak;
  GzclTier? gzclTier;
  List<GzclStage> gzclStages;
  int gzclStage;
  int gzclAmrapTarget;

  void setGzclTier(GzclTier? tier) {
    gzclTier = tier;
    gzclStage = 0;
    if (tier == GzclTier.t1 && gzclStages.isEmpty) {
      gzclStages = [...gzclpT1Stages];
    } else if (tier == GzclTier.t2 && gzclStages.isEmpty) {
      gzclStages = [...gzclpT2Stages];
    }
    if (tier != null) progression = ProgressionMode.weight;
  }

  bool supersetWithPrevious;

  List<ProgressionMode> get modes => _axesFor(measure, weightType);

  double floorKg(double defaultBarKg) =>
      loadFloorKg(type: weightType, barKg: barKg, defaultBarKg: defaultBarKg);

  double? clampedWeightKg(double defaultBarKg) {
    final w = weightKg;
    if (w == null || !weightType.carriesWeight) return null;
    final floor = floorKg(defaultBarKg);
    return w < floor ? floor : w;
  }

  final Map<RateAxis, ProgressionRates> _rates;

  String? get sparedRates => encodeSparedRates(_rates);

  RateAxis get _rateAxis => onAdvancedAxis
      ? RateAxis.advanced
      : switch (progression) {
          ProgressionMode.weight => RateAxis.weight,
          ProgressionMode.reps => RateAxis.reps,
          ProgressionMode.time => RateAxis.time,
        };

  void setMode(ProgressionMode mode, {String unit = 'kg'}) {
    if (!modes.contains(mode)) return;
    if (mode == progression && !onAdvancedAxis) return;
    _switchAxis(unit, () {
      addWeightAtTopOfRange = false;
      progression = mode;
    });
  }

  void setAdvanced(bool on, {String unit = 'kg'}) {
    if (on == onAdvancedAxis || (on && !canClimbRange)) return;
    _switchAxis(unit, () {
      addWeightAtTopOfRange = on;
      if (on) progression = ProgressionMode.weight;
    });
  }

  void _switchAxis(String unit, VoidCallback change) {
    final from = _rateAxis;
    _rates[from] = (increment: increment, deload: deload);
    change();
    final to = _rateAxis;
    final kept =
        _rates.remove(to) ??
        (to == RateAxis.advanced ? _rates[RateAxis.weight] : null);
    if (to == from) return;
    final mode = to == RateAxis.advanced ? ProgressionMode.weight : progression;
    increment = kept?.increment ?? defaultIncrementFor(mode, unit);
    deload = kept?.deload ?? defaultDeloadFor(mode, unit);
  }

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

List<WorkoutItemsCompanion> itemCompanions(
  List<ItemDraft> drafts, {
  int workoutId = 0,
  double defaultBarKg = 0,
}) {
  final joined = normaliseJoins([
    for (final d in drafts) d.supersetWithPrevious,
  ]);
  return [
    for (var i = 0; i < drafts.length; i++)
      WorkoutItemsCompanion.insert(
        workoutId: workoutId,
        exerciseId: drafts[i].exerciseId,
        position: Value(i),
        targetSets: Value(drafts[i].sets),
        repsMin: Value(drafts[i].repsMin),
        repsMax: Value(drafts[i].repsMax),
        toFailure: Value(drafts[i].toFailure),
        targetRpe: Value(drafts[i].targetRpe),
        addWeightAtTopOfRange: Value(drafts[i].addWeightAtTopOfRange),
        repsIncrement: Value(drafts[i].repsIncrement),
        repsDeload: Value(drafts[i].repsDeload),
        repsTarget: Value(drafts[i].repsTarget),
        sparedRates: Value(drafts[i].sparedRates),
        restSeconds: Value(drafts[i].restSeconds),
        suggestedWeight: Value(drafts[i].clampedWeightKg(defaultBarKg)),
        scheme: Value(drafts[i].scheme),
        schemePercent: Value(drafts[i].schemePercent),
        customSets: Value(
          drafts[i].scheme.isCustom
              ? encodeCustomSets(drafts[i].customSets)
              : null,
        ),
        cycleNames: Value(
          drafts[i].scheme == SetScheme.cycle
              ? encodeCycleNames(drafts[i].cycleNames)
              : null,
        ),
        cycleBlocks: Value(
          drafts[i].scheme == SetScheme.cycle
              ? encodeCycleBlocks(drafts[i].cycle)
              : null,
        ),
        cyclePosition: Value(drafts[i].cyclePosition),
        progression: Value(drafts[i].progression),
        holdSeconds: Value(drafts[i].holdSeconds),
        increment: Value(drafts[i].increment),
        deload: Value(drafts[i].deload),
        successThreshold: Value(drafts[i].successThreshold),
        failureThreshold: Value(drafts[i].failureThreshold),
        successStreak: Value(drafts[i].successStreak),
        failStreak: Value(drafts[i].failStreak),
        gzclTier: Value(drafts[i].gzclTier),
        gzclStages: Value(encodeGzclStages(drafts[i].gzclStages)),
        gzclStage: Value(drafts[i].gzclStage),
        gzclAmrapTarget: Value(drafts[i].gzclAmrapTarget),
        supersetWithPrevious: Value(joined[i]),
      ),
  ];
}

WorkoutItemsCompanion itemUpdate(ItemDraft d, {double defaultBarKg = 0}) =>
    WorkoutItemsCompanion(
      targetSets: Value(d.sets),
      repsMin: Value(d.repsMin),
      repsMax: Value(d.repsMax),
      toFailure: Value(d.toFailure),
      targetRpe: Value(d.targetRpe),
      addWeightAtTopOfRange: Value(d.addWeightAtTopOfRange),
      repsIncrement: Value(d.repsIncrement),
      repsDeload: Value(d.repsDeload),
      repsTarget: Value(d.repsTarget),
      sparedRates: Value(d.sparedRates),
      restSeconds: Value(d.restSeconds),
      suggestedWeight: Value(d.clampedWeightKg(defaultBarKg)),
      scheme: Value(d.scheme),
      schemePercent: Value(d.schemePercent),
      customSets: Value(
        d.scheme.isCustom ? encodeCustomSets(d.customSets) : null,
      ),
      cycleBlocks: Value(
        d.scheme == SetScheme.cycle ? encodeCycleBlocks(d.cycle) : null,
      ),
      cycleNames: Value(
        d.scheme == SetScheme.cycle ? encodeCycleNames(d.cycleNames) : null,
      ),
      cyclePosition: Value(d.cyclePosition),
      progression: Value(d.progression),
      holdSeconds: Value(d.holdSeconds),
      increment: Value(d.increment),
      deload: Value(d.deload),
      successThreshold: Value(d.successThreshold),
      failureThreshold: Value(d.failureThreshold),
      gzclTier: Value(d.gzclTier),
      gzclStages: Value(encodeGzclStages(d.gzclStages)),
      gzclStage: Value(d.gzclStage),
      gzclAmrapTarget: Value(d.gzclAmrapTarget),
    );

double roundStepWeight(double display) =>
    double.parse(display.toStringAsFixed(3));

String progressionAmount(
  AppLocalizations l10n,
  double amount,
  ProgressionMode mode,
  String unit,
) {
  return switch (mode) {
    ProgressionMode.weight => l10n.unitWeightShort(
      fmtWeight(toDisplayWeight(amount, unit)),
      unitSuffix(l10n, unit),
    ),
    ProgressionMode.reps => l10n.itemEditorAmountReps(amount.round()),
    ProgressionMode.time => '${amount.round()}${l10n.itemEditorSecondsSuffix}',
  };
}

String progressionRule(AppLocalizations l10n, ItemDraft d, String unit) {
  if (d.scheme == SetScheme.cycle) {
    return l10n.itemEditorProgressionRuleCycle(
      progressionAmount(l10n, d.increment, ProgressionMode.weight, unit),
      progressionAmount(l10n, d.deload, ProgressionMode.weight, unit),
      d.failureThreshold,
    );
  }
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

String draftSummary(AppLocalizations l10n, ItemDraft d, String unit) {
  final rows = d.scheme == SetScheme.cycle ? d.cycleRows : d.customSets;
  final target = d.scheme.isWrittenOut && rows.isNotEmpty
      ? rowsTargetLabel(l10n, rows)
      : setsTargetLabel(
          l10n,
          sets: d.sets,
          progression: d.progression,
          toFailure: d.toFailure,
          holdSeconds: d.holdSeconds,
          repsMin: d.goalReps,
          repsMax: d.onAdvancedAxis ? null : d.repsMax,
        );
  final weight = d.weightKg == null
      ? null
      : l10n.unitWeightShort(
          fmtWeight(toDisplayWeight(d.weightKg!, unit)),
          unitSuffix(l10n, unit),
        );
  final w = weight != null && d.runsPercentages
      ? l10n.itemEditorSummaryTrainingMax(weight)
      : weight;
  final step = '+${progressionAmount(l10n, d.increment, d.progression, unit)}';
  final scheme = d.scheme == SetScheme.flat
      ? null
      : _SchemePicker._label(l10n, d.scheme).toLowerCase();
  return [target, ?w, ?scheme, step].join(' · ');
}

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

  final double defaultBarKg;

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

  void _normalise() {
    if (_items.isNotEmpty) _items.first.supersetWithPrevious = false;
  }

  Future<void> _addExercise() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await pickExercise(context);
    FocusManager.instance.primaryFocus?.unfocus();
    if (picked == null) return;
    _bump(
      () => _items.add(
        ItemDraft.forExercise(
          picked,
          unit: unitForExercise(widget.unit, picked.unitOverride),
        ),
      ),
    );
    if (!mounted) return;
    await _configure(_items.length - 1);
  }

  Future<void> _configure(int i) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final l10n = AppLocalizations.of(context);
    final above = i == 0
        ? null
        : seededName(l10n, _items[i - 1].exercise?.seedKey, _items[i - 1].name);
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
    final joins = normaliseJoins([
      for (final d in _items) d.supersetWithPrevious,
    ]);
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
        badge: inSuperset(joins, i) && !joins[i] ? l10n.commonSuperset : null,
        grouped: inSuperset(joins, i),
        onTap: () => _configure(i),
        onRemove: () => _remove(i),
      ),
    );
  }
}

Future<void> showItemConfigSheet(
  BuildContext context, {
  required ItemDraft draft,
  required String unit,
  required int routineRest,
  double defaultBarKg = 0,
  String? exerciseAbove,
  required VoidCallback onChanged,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppColors.ground,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
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

  final String? exerciseAbove;
  final VoidCallback onChanged;

  @override
  ConsumerState<_ItemConfigSheet> createState() => _ItemConfigSheetState();
}

class _ItemConfigSheetState extends ConsumerState<_ItemConfigSheet> {
  String get _unit => unitForExercise(widget.unit, d.exercise?.unitOverride);

  late final TextEditingController _weight;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _progressionAnchor = GlobalKey();

  late bool _advanced = widget.draft.usesAdvanced;

  int? _autoRepRangeMax;

  ItemDraft get d => widget.draft;

  bool get _timed => d.progression.timed;

  String _weightHint(AppLocalizations l10n) {
    final floor = d.floorKg(widget.defaultBarKg);
    if (floor <= 0) return l10n.itemEditorWeightUnset;
    return l10n.itemEditorWeightFloor(fmtWeight(toDisplayWeight(floor, _unit)));
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
    _scrollController.dispose();
    super.dispose();
  }

  double _weightNudge(int sign) {
    final onWeightRates =
        d.progression == ProgressionMode.weight || d.onAdvancedAxis;
    if (!onWeightRates) return unitStepKg(_unit);
    final rate = sign > 0 || d.deload <= 0 ? d.increment : d.deload;
    return rate > 0 ? rate : unitStepKg(_unit);
  }

  bool get _canNudgeWeightDown {
    final w = d.weightKg;
    return w != null && w > d.floorKg(widget.defaultBarKg) + 1e-9;
  }

  void _nudgeWeight(int sign) {
    final floor = d.floorKg(widget.defaultBarKg);
    final current = d.weightKg;
    if (current == null) {
      if (sign > 0) _setWeight(floor > 0 ? floor : _weightNudge(1));
      return;
    }
    final next = current + sign * _weightNudge(sign);
    _setWeight(next < floor ? floor : next);
  }

  void _setWeight(double kg) {
    final display = roundStepWeight(toDisplayWeight(kg, _unit));
    _weight.text = fmtWeight(display);
    _bump(() => d.weightKg = toKg(display, _unit));
  }

  Widget _note(String text) => Text(
    text,
    style: kMono.copyWith(fontSize: 11, height: 1.5, color: AppColors.faint),
  );

  void _bump(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  _ProgressionType get _progressionType {
    if (d.gzclTier case final tier?) {
      return switch (tier) {
        GzclTier.t1 => _ProgressionType.gzclT1,
        GzclTier.t2 => _ProgressionType.gzclT2,
        GzclTier.t3 => _ProgressionType.gzclT3,
      };
    }
    if (d.scheme == SetScheme.cycle) return _ProgressionType.cycle;
    if (d.onAdvancedAxis) return _ProgressionType.repsThenWeight;
    return switch (d.progression) {
      ProgressionMode.weight => _ProgressionType.weight,
      ProgressionMode.reps => _ProgressionType.reps,
      ProgressionMode.time => _ProgressionType.time,
    };
  }

  void _selectProgressionType(_ProgressionType type) {
    final before = _anchorY;
    _bump(() {
      if (type != _ProgressionType.repsThenWeight &&
          _autoRepRangeMax != null &&
          d.repsMax == _autoRepRangeMax) {
        d.repsMax = null;
      }
      if (type != _ProgressionType.repsThenWeight) _autoRepRangeMax = null;
      d.setGzclTier(null);
      if (d.scheme == SetScheme.cycle) d.scheme = SetScheme.flat;
      switch (type) {
        case _ProgressionType.weight:
          d.setMode(ProgressionMode.weight, unit: _unit);
        case _ProgressionType.reps:
          d.setMode(ProgressionMode.reps, unit: _unit);
        case _ProgressionType.time:
          d.setMode(ProgressionMode.time, unit: _unit);
        case _ProgressionType.repsThenWeight:
          d.toFailure = false;
          if (d.repsMax == null) {
            d.repsMax = (d.repsMin + 2).clamp(1, 100);
            _autoRepRangeMax = d.repsMax;
          }
          d.setAdvanced(true, unit: _unit);
          _advanced = true;
        case _ProgressionType.cycle:
          d.setMode(ProgressionMode.weight, unit: _unit);
          d.scheme = SetScheme.cycle;
          if (d.cycle.isEmpty) d.cycle = [_seedCustomRows(d)];
        case _ProgressionType.gzclT1:
        case _ProgressionType.gzclT2:
        case _ProgressionType.gzclT3:
          d.setMode(ProgressionMode.weight, unit: _unit);
          d.setGzclTier(switch (type) {
            _ProgressionType.gzclT1 => GzclTier.t1,
            _ProgressionType.gzclT2 => GzclTier.t2,
            _ => GzclTier.t3,
          });
      }
    });
    if (before != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final after = _anchorY;
        if (after == null) return;
        final position = _scrollController.position;
        _scrollController.jumpTo(
          (_scrollController.offset + after - before).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
      });
    }
  }

  double? get _anchorY {
    final box = _progressionAnchor.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

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

  void _adopt(Exercise e) {
    _bump(() {
      d.adoptExercise(e, unit: unitForExercise(_unit, e.unitOverride));
      if (d.weightKg == null) _weight.text = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mq = MediaQuery.of(context);
    final ex = d.exercise;
    ref.listen(exerciseLibraryProvider, (_, next) {
      final all = next.value;
      if (all == null || !mounted) return;
      for (final e in all) {
        if (e.id == d.exerciseId) _adopt(e);
      }
    });
    return SingleChildScrollView(
      controller: _scrollController,
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
                      Text(
                        d.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        d.muscle,
                        style: TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
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
              if (d.scheme == SetScheme.cycle) ...[
                _CycleEditor(draft: d, onChanged: () => _bump(() {})),
                const SizedBox(height: 16),
              ],
              builderGrid([
                if (d.scheme != SetScheme.cycle) ...[
                  BuilderField(
                    label: l10n.itemEditorSets,
                    child: NumberStepper(
                      value: d.setCount,
                      min: 1,
                      max: 12,
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
                          _autoRepRangeMax = null;
                          d.repsMin = v;
                          if (d.repsMax != null && d.repsMax! < v) {
                            d.repsMax = v;
                          }
                        }),
                      ),
                    ),
                ],
                BuilderField(
                  label: l10n.itemEditorRest,
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
              if (widget.exerciseAbove case final above?) ...[
                const SizedBox(height: 16),
                _CheckRow(
                  key: kSupersetCheckKey,
                  label: l10n.itemEditorSupersetWith(above),
                  value: d.supersetWithPrevious,
                  onChanged: (v) => _bump(() => d.supersetWithPrevious = v),
                  onExplain: () => _explainSuperset(context),
                ),
              ],
              if (!_timed) ...[
                const SizedBox(height: 14),
                _AdvancedToggle(
                  open: _advanced,
                  onTap: () => setState(() => _advanced = !_advanced),
                ),
                if (_advanced) ...[
                  const SizedBox(height: 14),
                  builderGrid([
                    BuilderField(
                      label: l10n.itemEditorRepRange,
                      note: d.repsMax == null
                          ? null
                          : l10n.itemEditorRepRangeSpan(d.repsMin, d.repsMax!),
                      child: NumberStepper(
                        key: kRepRangeFieldKey,
                        value: d.repsMax ?? d.repsMin,
                        isEmpty: d.repsMax == null,
                        emptyLabel: l10n.itemEditorNoUpper,
                        min: d.repsMin,
                        max: 100,
                        enabled: !d.toFailure,
                        onChanged: (v) => _bump(() {
                          _autoRepRangeMax = null;
                          d.repsMax = v;
                        }),
                        onClear: () => _bump(() {
                          _autoRepRangeMax = null;
                          d.repsMax = null;
                        }),
                      ),
                    ),
                    _EffortTargetField(
                      label: l10n.itemEditorEffortTarget,
                      tooltip: l10n.itemEditorEffortTargetWhat,
                      onExplain: () => _explainEffortTarget(context),
                      child: _MenuField<int?>(
                        value: d.targetRpe,
                        height: 36,
                        choices: [
                          null,
                          for (var rpe = 60; rpe <= 100; rpe += 5) rpe,
                        ],
                        label: (rpe) => rpe == null
                            ? l10n.commonNone
                            : '@${formatRpe(rpe)}',
                        onChanged: (v) => _bump(() => d.targetRpe = v),
                      ),
                    ),
                  ]),
                  if (d.targetRpe != null) ...[
                    const SizedBox(height: 10),
                    Text('6 · ${l10n.rpeFourPlusRepsLeft}'),
                    Text('8 · ${l10n.rpeRepsLeft(2)}'),
                    Text('10 · ${l10n.rpeNoRepsLeft}'),
                  ],
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
            if (!d.weightType.carriesWeight)
              builderCard(l10n.itemEditorWeight, [
                Text(
                  l10n.itemEditorBodyweight,
                  style: kMono.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ])
            else
              builderCard(
                d.runsPercentages
                    ? '${l10n.itemEditorTrainingMax} '
                          '(${unitSuffix(l10n, _unit)})'
                    : l10n.itemEditorWeightWithUnit(unitSuffix(l10n, _unit)),
                [
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
                            decimal: true,
                          ),
                          style: kMono.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: builderInput(_weightHint(l10n)),
                          onChanged: (v) {
                            final parsed = double.tryParse(
                              v.trim().replaceAll(',', '.'),
                            );
                            _bump(
                              () => d.weightKg = parsed == null
                                  ? null
                                  : toKg(parsed, _unit),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      stepperButton(Icons.add, () => _nudgeWeight(1)),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 14),
            builderCard(l10n.itemEditorProgression, [
              Text(
                l10n.itemEditorProgressionMethod,
                style: sectionLabelStyle(),
              ),
              const SizedBox(height: 10),
              _ProgressionTypePicker(
                key: _progressionAnchor,
                type: _progressionType,
                modes: d.modes,
                carriesWeight: d.weightType.carriesWeight,
                onChanged: _selectProgressionType,
              ),
              if (_progressionHint(l10n, _progressionType)
                  case final hint?) ...[
                const SizedBox(height: 10),
                _GuidanceCallout(text: hint),
              ],
              const SizedBox(height: 16),
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
              if (!d.onAdvancedAxis) ...[
                const SizedBox(height: 14),
                _note(progressionRule(l10n, d, _unit)),
              ],
              if (d.gzclTier == GzclTier.t1 || d.gzclTier == GzclTier.t2) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: kGzclStagesKey,
                  initialValue: encodeGzclStages(
                    d.gzclStages,
                  )?.replaceAll(';', ', '),
                  decoration: builderInput(l10n.itemEditorGzclStages),
                  onChanged: (value) => _bump(() {
                    final stages = decodeGzclStages(
                      value.replaceAll(',', ';').replaceAll('×', 'x'),
                    );
                    if (stages.isNotEmpty) {
                      d.gzclStages = stages;
                      d.gzclStage = d.gzclStage.clamp(0, stages.length - 1);
                    }
                  }),
                ),
              ],
              if (d.gzclTier == GzclTier.t3) ...[
                const SizedBox(height: 12),
                BuilderField(
                  label: l10n.itemEditorGzclAmrapTarget,
                  child: NumberStepper(
                    value: d.gzclAmrapTarget,
                    min: 1,
                    max: 100,
                    onChanged: (value) =>
                        _bump(() => d.gzclAmrapTarget = value),
                  ),
                ),
              ],
            ]),
            if (ex != null) ...[
              const SizedBox(height: 14),
              builderCard(l10n.itemEditorExercise, [
                Text(
                  l10n.itemEditorExerciseShared,
                  style: kMono.copyWith(
                    fontSize: 11,
                    height: 1.5,
                    color: AppColors.faint,
                  ),
                ),
                const SizedBox(height: 16),
                ExerciseLoadingSection(exercise: ex),
                const SizedBox(height: 18),
                ExerciseNoteSection(exercise: ex),
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

String soleAxis(AppLocalizations l10n, ProgressionMode m) => switch (m) {
  ProgressionMode.time => l10n.itemEditorAxisTime,
  ProgressionMode.reps => l10n.itemEditorAxisReps,
  ProgressionMode.weight => l10n.itemEditorAxisWeight,
};

const kAdvancedToggleKey = ValueKey('target-advanced');
const kSchemePickerKey = ValueKey('set-scheme');
const kSchemePercentKey = ValueKey('scheme-percent');
const kSchemePreviewKey = ValueKey('scheme-preview');
const kCycleAddWeekKey = ValueKey('cycle-add-week');
const kRangeClimbKey = ValueKey('add-weight-at-top-of-range');
const kProgressionAdvancedKey = ValueKey('progression-advanced');

class _AdvancedToggle extends StatelessWidget {
  const _AdvancedToggle({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EditorPill(
      key: kAdvancedToggleKey,
      label: l10n.itemEditorAdvanced,
      icon: open ? Icons.expand_less : Icons.expand_more,
      on: open,
      onTap: onTap,
    );
  }
}

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
        Text(
          l10n.itemEditorSetScheme,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: sectionLabelStyle(),
        ),
        const SizedBox(height: 10),
        _SchemePicker(
          key: kSchemePickerKey,
          scheme: d.scheme,
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
        const SizedBox(height: 14),
        Text(
          key: kSchemePreviewKey,
          _schemeLine(l10n, d, unit, defaultBarKg),
          style: kMono.copyWith(
            fontSize: 11,
            height: 1.5,
            color: AppColors.faint,
          ),
        ),
      ],
    );
  }
}

List<CustomSet> _seedCustomRows(ItemDraft d) => [
  for (var i = 0; i < d.sets; i++) CustomSet(reps: d.goalReps, percent: 100),
];

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

  final bool on;

  final VoidCallback? onTap;

  final IconData? icon;

  final bool centred;

  @override
  Widget build(BuildContext context) {
    final live = onTap != null;
    final colour = on
        ? AppColors.accent
        : (live ? AppColors.muted : AppColors.faint);
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
                    Flexible(child: text),
                  ],
                ),
        ),
      ),
    );
  }
}

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
  final varyingReps = targets.map((t) => t.reps).toSet().length > 1;
  final body = targets
      .map(
        (t) => varyingReps
            ? '${t.reps}×${fmtWeight(toDisplayWeight(t.weightKg ?? 0, unit))}'
            : fmtWeight(toDisplayWeight(t.weightKg ?? 0, unit)),
      )
      .join(sep);
  return '$body ${unitSuffix(l10n, unit)}';
}

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
    EditorPill pill(SetScheme s) => EditorPill(
      label: _label(l10n, s),
      on: s == scheme,
      onTap: () => onChanged(s),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in SetScheme.values)
          if (s != SetScheme.cycle) pill(s),
      ],
    );
  }
}

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
    final capped = !row.amrap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.itemEditorSchemeSetNumber(index + 1),
          style: kMono.copyWith(
            fontSize: 11,
            letterSpacing: 0.5,
            color: AppColors.faint,
          ),
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
      repsMax: top == null ? null : (top < bottom ? bottom : top),
      amrap: open,
      percent: percent ?? row.percent,
    );
  }
}

class _CycleEditor extends StatefulWidget {
  const _CycleEditor({required this.draft, required this.onChanged});

  final ItemDraft draft;
  final VoidCallback onChanged;

  @override
  State<_CycleEditor> createState() => _CycleEditorState();
}

class _CycleEditorState extends State<_CycleEditor> {
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
            title: cycleWeekTitle(l10n, _d.cycleNameOf(w), w),
            rows: _d.cycle[w],
            open: w == _open,
            current:
                _d.cycle.length > 1 && w == _d.cyclePosition % _d.cycle.length,
            onToggle: () => setState(() => _open = w == _open ? null : w),
            onRename: () => _renameWeek(w),
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
    final weeks = [
      for (final w in _d.cycle) [...w],
    ];
    weeks[week][index] = row;
    _d.cycle = weeks;
    widget.onChanged();
  }

  void _addSet(int week) {
    final weeks = [
      for (final w in _d.cycle) [...w],
    ];
    weeks[week].add(
      weeks[week].isEmpty
          ? CustomSet(reps: _d.goalReps, percent: 100)
          : weeks[week].last,
    );
    _d.cycle = weeks;
    widget.onChanged();
  }

  void _removeSet(int week) {
    final weeks = [
      for (final w in _d.cycle) [...w],
    ];
    weeks[week].removeLast();
    _d.cycle = weeks;
    widget.onChanged();
  }

  Future<void> _renameWeek(int week) async {
    final typed = await showCycleWeekNameDialog(
      context,
      current: _d.cycleNameOf(week),
    );
    if (typed == null || !mounted) return;
    final names = [
      for (var i = 0; i < _d.cycle.length; i++)
        i == week ? typed : _d.cycleNameOf(i),
    ];
    while (names.isNotEmpty && names.last.isEmpty) {
      names.removeLast();
    }
    setState(() => _d.cycleNames = names);
    widget.onChanged();
  }

  void _addWeek() {
    _d.cycle = [
      ..._d.cycle,
      if (_d.cycle.isEmpty) _seedCustomRows(_d) else [..._d.cycle.last],
    ];
    setState(() => _open = _d.cycle.length - 1);
    widget.onChanged();
  }

  void _removeWeek(int week) {
    final weeks = [
      for (final w in _d.cycle) [...w],
    ]..removeAt(week);
    _d.cycle = weeks;
    if (week < _d.cycleNames.length) {
      _d.cycleNames = [..._d.cycleNames]..removeAt(week);
    }
    if (_d.cyclePosition >= weeks.length && weeks.isNotEmpty) {
      _d.cyclePosition = weeks.length - 1;
    }
    setState(() {
      if (_open == null) return;
      _open = _open == week ? null : (_open! > week ? _open! - 1 : _open);
    });
    widget.onChanged();
  }
}

ValueKey<String> cycleWeekKey(int week) => ValueKey('cycle-week-$week');

const ValueKey<String> cycleWeekRenameKey = ValueKey('cycle-week-rename');

const ValueKey<String> cycleWeekNameFieldKey = ValueKey(
  'cycle-week-name-field',
);
const ValueKey<String> cycleWeekNameSaveKey = ValueKey('cycle-week-name-save');

String cycleWeekTitle(AppLocalizations l10n, String name, int index) =>
    name.trim().isEmpty ? l10n.itemEditorCycleWeek(index + 1) : name.trim();

Future<String?> showCycleWeekNameDialog(
  BuildContext context, {
  required String current,
}) async {
  final typed = await showDialog<String>(
    context: context,
    builder: (context) => _CycleWeekNameDialog(current: current),
  );
  return typed?.trim();
}

class _CycleWeekNameDialog extends StatefulWidget {
  const _CycleWeekNameDialog({required this.current});

  final String current;

  @override
  State<_CycleWeekNameDialog> createState() => _CycleWeekNameDialogState();
}

class _CycleWeekNameDialogState extends State<_CycleWeekNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.itemEditorCycleNameWeek),
      content: TextField(
        key: cycleWeekNameFieldKey,
        controller: _controller,
        autofocus: true,
        maxLength: kCycleNameMaxLength,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(hintText: l10n.itemEditorCycleWeekNameHint),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          key: cycleWeekNameSaveKey,
          onPressed: _save,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

class _CycleWeekCard extends StatelessWidget {
  const _CycleWeekCard({
    super.key,
    required this.title,
    required this.rows,
    required this.open,
    required this.current,
    required this.onToggle,
    required this.onRename,
    required this.onRemove,
    required this.onRowChanged,
    required this.onAddSet,
    required this.onRemoveSet,
  });

  final String title;
  final List<CustomSet> rows;
  final bool open;

  final bool current;

  final VoidCallback onToggle;

  final VoidCallback onRename;

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
        border: Border.all(color: current ? AppColors.accent : AppColors.line),
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
                  if (!open) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _summary(l10n),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kMono.copyWith(
                          fontSize: 12,
                          color: AppColors.faint,
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  IconButton(
                    key: cycleWeekRenameKey,
                    onPressed: onRename,
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.itemEditorCycleNameWeek,
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.faint,
                    ),
                  ),
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
                          color: AppColors.line.withValues(alpha: 0.6),
                        ),
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

  String _summary(AppLocalizations l10n) => l10n.itemEditorCycleWeekSummary(
    rowsTargetLabel(l10n, rows),
    joinRowLabels(l10n, rows.map((r) => '${r.percent}')),
  );
}

class _CycleActions extends StatelessWidget {
  const _CycleActions({required this.onAddSet, required this.onRemoveSet});

  final VoidCallback onAddSet;
  final VoidCallback? onRemoveSet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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

Future<void> _explainEffortTarget(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showAppDialog<void>(
    context,
    builder: (ctx) => AppDialog(
      title: l10n.itemEditorEffortTargetWhat,
      content: Text(l10n.itemEditorEffortTargetExplained),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.commonDone),
        ),
      ],
    ),
  );
}

const kCycleExplainKey = ValueKey('cycle-explain');

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

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onExplain,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onExplain;

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
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppColors.accent,
            checkColor: const Color(0xFF1A0E07),
            side: BorderSide(color: AppColors.line, width: 1.5),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, color: null),
          ),
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

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [row],
      ),
    );
  }
}

const kProgressionCycleKey = ValueKey('progression-cycle');

class _GuidanceCallout extends StatelessWidget {
  const _GuidanceCallout({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: .22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.route_rounded, size: 17, color: AppColors.accent),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EffortTargetField extends StatelessWidget {
  const _EffortTargetField({
    required this.label,
    required this.tooltip,
    required this.onExplain,
    required this.child,
  });

  final String label;
  final String tooltip;
  final VoidCallback onExplain;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: kMono.copyWith(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: AppColors.faint,
                ),
              ),
            ),
            IconButton(
              tooltip: tooltip,
              onPressed: onExplain,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 22, height: 18),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: AppColors.faint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

enum _ProgressionType {
  weight,
  reps,
  time,
  repsThenWeight,
  cycle,
  gzclT1,
  gzclT2,
  gzclT3,
}

class _ProgressionTypePicker extends StatelessWidget {
  const _ProgressionTypePicker({
    super.key,
    required this.type,
    required this.modes,
    required this.carriesWeight,
    required this.onChanged,
  });

  final _ProgressionType type;
  final List<ProgressionMode> modes;
  final bool carriesWeight;
  final ValueChanged<_ProgressionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final choices = <_ProgressionType>[
      if (modes.contains(ProgressionMode.weight)) _ProgressionType.weight,
      if (modes.contains(ProgressionMode.reps)) _ProgressionType.reps,
      if (modes.contains(ProgressionMode.time)) _ProgressionType.time,
      if (modes.contains(ProgressionMode.weight) &&
          modes.contains(ProgressionMode.reps))
        _ProgressionType.repsThenWeight,
      if (carriesWeight) ...[
        _ProgressionType.cycle,
        _ProgressionType.gzclT1,
        _ProgressionType.gzclT2,
        _ProgressionType.gzclT3,
      ],
    ];
    return Row(
      children: [
        Expanded(
          child: _MenuField<_ProgressionType>(
            key: kGzclTierKey,
            value: type,
            choices: choices,
            label: (choice) => _progressionTypeLabel(l10n, choice),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          key: kCycleExplainKey,
          onPressed: () => _explainProgressionType(context, type),
          tooltip: l10n.itemEditorProgressionTypeInfo,
          icon: const Icon(Icons.info_outline),
        ),
      ],
    );
  }
}

class _MenuField<T> extends StatelessWidget {
  const _MenuField({
    super.key,
    required this.value,
    required this.choices,
    required this.label,
    required this.onChanged,
    this.height = 48,
  });

  final T value;
  final List<T> choices;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: '',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      elevation: 12,
      color: AppColors.surface3,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.line),
      ),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final choice in choices)
          PopupMenuItem<T>(
            value: choice,
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label(choice),
                    style: TextStyle(
                      color: choice == value
                          ? AppColors.accent
                          : AppColors.text,
                      fontWeight: choice == value
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (choice == value)
                  Icon(Icons.check_rounded, size: 18, color: AppColors.accent),
              ],
            ),
          ),
      ],
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, .12),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Align(
                      key: ValueKey(value),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label(value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kMono.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                Icon(Icons.expand_more_rounded, color: AppColors.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _progressionTypeLabel(AppLocalizations l10n, _ProgressionType type) =>
    switch (type) {
      _ProgressionType.weight => l10n.itemEditorModeWeight,
      _ProgressionType.reps => l10n.itemEditorModeReps,
      _ProgressionType.time => l10n.itemEditorModeTime,
      _ProgressionType.repsThenWeight => l10n.itemEditorModeRepsThenWeight,
      _ProgressionType.cycle => l10n.itemEditorSchemeCycle,
      _ProgressionType.gzclT1 => l10n.itemEditorGzclpT1,
      _ProgressionType.gzclT2 => l10n.itemEditorGzclpT2,
      _ProgressionType.gzclT3 => l10n.itemEditorGzclpT3,
    };

String? _progressionHint(AppLocalizations l10n, _ProgressionType type) =>
    switch (type) {
      _ProgressionType.repsThenWeight => l10n.itemEditorRepsThenWeightHint,
      _ProgressionType.cycle => l10n.itemEditorCycleHint,
      _ProgressionType.gzclT1 => l10n.itemEditorGzclT1Hint,
      _ProgressionType.gzclT2 => l10n.itemEditorGzclT2Hint,
      _ProgressionType.gzclT3 => l10n.itemEditorGzclT3Hint,
      _ => null,
    };

String _progressionExplanation(AppLocalizations l10n, _ProgressionType type) =>
    switch (type) {
      _ProgressionType.weight => l10n.itemEditorWeightProgressionExplained,
      _ProgressionType.reps => l10n.itemEditorRepsProgressionExplained,
      _ProgressionType.time => l10n.itemEditorTimeProgressionExplained,
      _ProgressionType.repsThenWeight => l10n.itemEditorRepsThenWeightExplained,
      _ProgressionType.cycle => l10n.itemEditorCycleExplained,
      _ProgressionType.gzclT1 => l10n.itemEditorGzclT1Explained,
      _ProgressionType.gzclT2 => l10n.itemEditorGzclT2Explained,
      _ProgressionType.gzclT3 => l10n.itemEditorGzclT3Explained,
    };

Future<void> _explainProgressionType(
  BuildContext context,
  _ProgressionType type,
) {
  final l10n = AppLocalizations.of(context);
  return showAppDialog<void>(
    context,
    builder: (ctx) => AppDialog(
      title: type == _ProgressionType.cycle
          ? l10n.itemEditorCycleWhat
          : _progressionTypeLabel(l10n, type),
      content: Text(_progressionExplanation(l10n, type)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.commonDone),
        ),
      ],
    ),
  );
}

class GzclTierPicker extends StatelessWidget {
  const GzclTierPicker({
    super.key,
    required this.tier,
    required this.onChanged,
  });

  final GzclTier? tier;
  final ValueChanged<GzclTier?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final choices = <(GzclTier?, String, String)>[
      (null, l10n.itemEditorGzclStandard, l10n.itemEditorGzclStandardHint),
      (GzclTier.t1, l10n.itemEditorGzclT1, l10n.itemEditorGzclT1Hint),
      (GzclTier.t2, l10n.itemEditorGzclT2, l10n.itemEditorGzclT2Hint),
      (GzclTier.t3, l10n.itemEditorGzclT3, l10n.itemEditorGzclT3Hint),
    ];
    return RadioGroup<GzclTier?>(
      groupValue: tier,
      onChanged: onChanged,
      child: Column(
        children: [
          for (final choice in choices)
            Material(
              color: Colors.transparent,
              child: RadioListTile<GzclTier?>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: choice.$1,
                title: Text(choice.$2),
                subtitle: Text(choice.$3),
              ),
            ),
        ],
      ),
    );
  }
}

class ModePicker extends StatelessWidget {
  const ModePicker({
    super.key,
    required this.modes,
    required this.mode,
    required this.onChanged,
    this.advanced = false,
    this.advancedOffered = false,
    this.advancedEnabled = false,
    this.onAdvanced,
    this.cycleOffered = false,
    this.cycleOn = false,
    this.onCycle,
  });
  final List<ProgressionMode> modes;
  final ProgressionMode mode;
  final ValueChanged<ProgressionMode> onChanged;

  final bool advanced;

  final bool advancedOffered;
  final bool advancedEnabled;
  final VoidCallback? onAdvanced;
  final bool cycleOffered;
  final bool cycleOn;
  final VoidCallback? onCycle;

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
        if (advancedOffered || cycleOffered) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (advancedOffered)
                Expanded(
                  child: EditorPill(
                    key: kModeAdvancedKey,
                    label: l10n.itemEditorModeAdvanced,
                    centred: true,
                    on: advanced,
                    onTap: advancedEnabled ? onAdvanced : null,
                  ),
                ),
              if (advancedOffered && cycleOffered) const SizedBox(width: 8),
              if (cycleOffered)
                Expanded(
                  child: EditorPill(
                    key: kProgressionCycleKey,
                    label: l10n.itemEditorSchemeCycle,
                    centred: true,
                    on: cycleOn,
                    onTap: onCycle,
                  ),
                ),
              if (cycleOffered)
                IconButton(
                  key: kCycleExplainKey,
                  onPressed: () => _explainCycle(context),
                  tooltip: l10n.itemEditorCycleWhat,
                  icon: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.faint,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

double amountStep(ProgressionMode mode, String unit) => switch (mode) {
  ProgressionMode.weight => unit == 'lb' ? 2.5 : 1.25,
  ProgressionMode.reps => 1,
  ProgressionMode.time => 5,
};

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

  final bool allowZero;
  final ValueChanged<double> onChanged;

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  late final TextEditingController _c = TextEditingController(text: _shown);
  final _focus = FocusNode();

  double get _display => widget.mode == ProgressionMode.weight
      ? toDisplayWeight(widget.value, widget.unit)
      : widget.value;

  String get _shown => fmtWeight(_display);

  double get _step => amountStep(widget.mode, widget.unit);

  double get _floor => widget.allowZero ? 0 : _step;

  @override
  void initState() {
    super.initState();
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

  void _nudge(int sign) {
    final next = _display + sign * _step;
    _commit(next < _floor ? _floor : next);
  }

  void _commit(double display) {
    final tidy = widget.mode == ProgressionMode.weight
        ? roundStepWeight(display)
        : display;
    _c.text = fmtWeight(tidy);
    widget.onChanged(
      widget.mode == ProgressionMode.weight ? toKg(tidy, widget.unit) : tidy,
    );
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              style: kMono.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                filled: true,
                fillColor: AppColors.surface,
                suffixText: suffix,
                suffixStyle: kMono.copyWith(
                  fontSize: 12,
                  color: AppColors.faint,
                ),
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
                widget.onChanged(
                  widget.mode == ProgressionMode.weight
                      ? toKg(parsed, widget.unit)
                      : parsed,
                );
              },
            ),
          ),
          stepperButton(Icons.add, () => _nudge(1)),
        ],
      ),
    );
  }
}
