import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../screens/exercise_detail_screen.dart'
    show ExerciseLoadingSection, ExerciseNoteSection;
import '../screens/exercise_form_screen.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../util/target_label.dart';
import '../util/units.dart';
import 'builder_widgets.dart';
import 'common.dart' show sectionLabelStyle;

/// Finds the two progression-amount fields in a test.
const kStepUpFieldKey = ValueKey('amount-step-up');
const kBackOffFieldKey = ValueKey('amount-back-off');

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
    this.restSeconds,
    double? weightKg,
    this.scheme = SetScheme.flat,
    this.schemePercent = kDefaultSchemePercent,
    this.customSets = const [],
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
    this.exercise,
  })  : progression = _startingMode(measure, weightType, progression),
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
        restSeconds: v.item.restSeconds,
        weightKg: v.item.suggestedWeight,
        scheme: v.item.scheme,
        schemePercent: v.item.schemePercent,
        customSets: decodeCustomSets(v.item.customSets),
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

  /// Whether anything in the Advanced half of the Target card is in use. The
  /// card opens expanded when it is, so nothing a slot actually does is hidden
  /// behind a toggle somebody has to think to press.
  bool get usesAdvanced =>
      toFailure || repsMax != null || scheme != SetScheme.flat;

  /// What each set is aiming at, given the gym's [unit] and the lightest weight
  /// this slot may be loaded to. The one place the scheme is turned into
  /// numbers on this side of the app — the live session calls the same
  /// function with the session's own unit and bar.
  List<SetTarget> targets({required String unit, double defaultBarKg = 0}) =>
      resolveSetTargets(
        scheme: scheme,
        sets: sets,
        goalReps: toFailure ? repsMin : (repsMax ?? repsMin),
        topWeightKg: clampedWeightKg(defaultBarKg),
        unit: unit,
        percent: schemePercent,
        custom: customSets,
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

  /// Switches the axis, resetting the rates to that mode's defaults in [unit]:
  /// 2.5 of anything is a sane step in kilograms and nonsense in reps. An axis
  /// the exercise does not allow is ignored.
  void setMode(ProgressionMode mode, {String unit = 'kg'}) {
    if (mode == progression || !modes.contains(mode)) return;
    _putOnAxis(mode, unit);
  }

  void _putOnAxis(ProgressionMode mode, String unit) {
    progression = mode;
    increment = defaultIncrementFor(mode, unit);
    deload = defaultDeloadFor(mode, unit);
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
    if (!modes.contains(progression)) _putOnAxis(modes.first, unit);
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
  return [
    for (var i = 0; i < drafts.length; i++)
      WorkoutItemsCompanion.insert(
        workoutId: workoutId,
        exerciseId: drafts[i].exerciseId,
        position: Value(i),
        targetSets: Value(drafts[i].sets),
        repsMin: Value(drafts[i].repsMin),
        repsMax: Value(drafts[i].toFailure ? null : drafts[i].repsMax),
        toFailure: Value(drafts[i].toFailure),
        restSeconds: Value(drafts[i].restSeconds),
        suggestedWeight: Value(drafts[i].clampedWeightKg(defaultBarKg)),
        scheme: Value(drafts[i].scheme),
        schemePercent: Value(drafts[i].schemePercent),
        // Only a custom slot spends a column on rows: a back-off that was once
        // a custom keeps them in the draft, not in the database.
        customSets: Value(drafts[i].scheme.isCustom
            ? encodeCustomSets(drafts[i].customSets)
            : null),
        progression: Value(drafts[i].progression),
        holdSeconds: Value(drafts[i].holdSeconds),
        increment: Value(drafts[i].increment),
        deload: Value(drafts[i].deload),
        successThreshold: Value(drafts[i].successThreshold),
        failureThreshold: Value(drafts[i].failureThreshold),
        successStreak: Value(drafts[i].successStreak),
        failStreak: Value(drafts[i].failStreak),
      ),
  ];
}

/// The decimals [fmtWeight] will show, as a rounding: what the field puts back
/// must be what the field says.
double roundStepWeight(double display) =>
    double.parse(display.toStringAsFixed(2));

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
  return l10n.itemEditorProgressionRule(
    progressionAmount(l10n, d.increment, d.progression, unit),
    d.successThreshold,
    progressionAmount(l10n, d.deload, d.progression, unit),
    d.failureThreshold,
  );
}

/// Compact target/weight/progression summary for a draft item, e.g.
/// "4 × 6–8 · 80 kg · +2.5 kg".
String draftSummary(AppLocalizations l10n, ItemDraft d, String unit) {
  final target = setsTargetLabel(
    l10n,
    sets: d.sets,
    progression: d.progression,
    toFailure: d.toFailure,
    holdSeconds: d.holdSeconds,
    repsMin: d.repsMin,
    repsMax: d.repsMax,
  );
  final w = d.weightKg == null
      ? null
      : l10n.unitWeightShort(
          fmtWeight(toDisplayWeight(d.weightKg!, unit)), unitSuffix(l10n, unit));
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
    _bump(() => _items.insert(to, _items.removeAt(from)));
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
    _bump(() => _items.add(ItemDraft.forExercise(picked, unit: widget.unit)));
  }

  Future<void> _configure(int i) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showModalBottomSheet<void>(
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
          draft: _items[i],
          unit: widget.unit,
          routineRest: widget.routineRest,
          defaultBarKg: widget.defaultBarKg,
          onChanged: () => _bump(() {}),
        ),
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
        subtitle: draftSummary(l10n, draft, widget.unit),
        onTap: () => _configure(i),
        onRemove: () => _bump(() => _items.removeAt(i)),
      ),
    );
  }
}

/// Bottom-sheet editor for a single item's sets / reps / rest / weight, plus
/// the library properties of the movement it stands for.
class _ItemConfigSheet extends ConsumerStatefulWidget {
  const _ItemConfigSheet({
    required this.draft,
    required this.unit,
    required this.routineRest,
    required this.defaultBarKg,
    required this.onChanged,
  });
  final ItemDraft draft;
  final String unit;
  final int routineRest;
  final double defaultBarKg;
  final VoidCallback onChanged;

  @override
  ConsumerState<_ItemConfigSheet> createState() => _ItemConfigSheetState();
}

class _ItemConfigSheetState extends ConsumerState<_ItemConfigSheet> {
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

  ItemDraft get d => widget.draft;

  /// True when [d] is measured in seconds rather than reps.
  bool get _timed => d.progression.timed;

  /// What an empty weight field says: over a bar, the lightest it can be.
  String _weightHint(AppLocalizations l10n) {
    final floor = d.floorKg(widget.defaultBarKg);
    if (floor <= 0) return l10n.itemEditorWeightUnset;
    return l10n.itemEditorWeightFloor(
      fmtWeight(toDisplayWeight(floor, widget.unit)),
    );
  }

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(
      text: d.weightKg == null
          ? ''
          : fmtWeight(toDisplayWeight(d.weightKg!, widget.unit)),
    );
  }

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

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
      d.adoptExercise(e, unit: widget.unit);
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
                    value: d.sets,
                    min: 1,
                    max: 12,
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
                  // A range has no meaning once the set runs to failure, so the
                  // field goes away rather than sitting there greyed out.
                  if (!d.toFailure) ...[
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
                          // Stepping down past the lower bound drops the upper
                          // one entirely — no stray clear button to knock the
                          // row out of line with the rest of the grid.
                          value: d.repsMax ?? d.repsMin,
                          isEmpty: d.repsMax == null,
                          emptyLabel: l10n.itemEditorNoUpper,
                          min: d.repsMin,
                          max: 100,
                          onChanged: (v) => _bump(() => d.repsMax = v),
                          onClear: () => _bump(() => d.repsMax = null),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                  ],
                  _CheckRow(
                    label: l10n.itemEditorToFailure,
                    value: d.toFailure,
                    onChanged: (v) => _bump(() => d.toFailure = v),
                  ),
                  const SizedBox(height: 18),
                  _SchemeSection(
                    draft: d,
                    unit: widget.unit,
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
                  l10n.itemEditorWeightWithUnit(unitSuffix(l10n, widget.unit)), [
                TextField(
                  controller: _weight,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style:
                      kMono.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                  // Blank on a loaded movement is a number nobody has filled in
                  // yet, not bodyweight — the loading says which it is, and this
                  // one carries a weight. Over a bar, the hint is the bar: it is
                  // the floor the value is held at on the way to the database.
                  decoration: builderInput(_weightHint(l10n)),
                  onChanged: (v) {
                    final parsed = double.tryParse(v.trim());
                    d.weightKg =
                        parsed == null ? null : toKg(parsed, widget.unit);
                    widget.onChanged();
                  },
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
                  onChanged: (m) =>
                      _bump(() => d.setMode(m, unit: widget.unit)),
                )
              else
                Text(
                  _soleAxis(l10n, d.modes.first),
                  style: kMono.copyWith(
                      fontSize: 11, height: 1.5, color: AppColors.faint),
                ),
              const SizedBox(height: 16),
              builderGrid([
                BuilderField(
                  label: l10n.itemEditorStepUpBy,
                  child: _AmountField(
                    key: kStepUpFieldKey,
                    value: d.increment,
                    mode: d.progression,
                    unit: widget.unit,
                    // A slot that steps up by nothing never progresses, so the
                    // buttons stop at one tap's worth rather than at zero.
                    allowZero: false,
                    onChanged: (v) => _bump(() => d.increment = v),
                  ),
                ),
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
                  label: l10n.itemEditorBackOffBy,
                  child: _AmountField(
                    key: kBackOffFieldKey,
                    value: d.deload,
                    mode: d.progression,
                    unit: widget.unit,
                    // Zero is a real answer here: a missed session that never
                    // lightens the load.
                    onChanged: (v) => _bump(() => d.deload = v),
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
              // The four numbers above, read back as the rule they add up to.
              Text(
                progressionRule(l10n, d, widget.unit),
                style: kMono.copyWith(
                    fontSize: 11, height: 1.5, color: AppColors.faint),
              ),
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

/// The one control that opens the rest of the Target card.
///
/// A row rather than a Material [ExpansionTile]: the card already has its own
/// padding and its own type, and a tile brings a second set of both.
class _AdvancedToggle extends StatelessWidget {
  const _AdvancedToggle({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      key: kAdvancedToggleKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              open ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: AppColors.accent,
            ),
            const SizedBox(width: 8),
            // The label gives before the chevron does, as everywhere else.
            Expanded(
              child: Text(
                l10n.itemEditorAdvanced,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kMono.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How the sets of this slot differ from one another: the four schemes, the
/// percentage the two ladders are made of, the written-out rows of a custom
/// one, and the whole thing read back as the weights it produces.
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
        Text(l10n.itemEditorSetScheme, style: sectionLabelStyle()),
        const SizedBox(height: 10),
        _SchemePicker(
          key: kSchemePickerKey,
          scheme: d.scheme,
          // The rows a custom scheme was given survive a trip through another
          // scheme and back, so trying a ramp does not throw away what was
          // typed. Only a custom slot ever writes them to the database.
          onChanged: (s) {
            d.scheme = s;
            if (s.isCustom && d.customSets.isEmpty) {
              d.customSets = _seedCustomRows(d);
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
                  : CustomSet(reps: _goalReps(d), percent: 100),
              onChanged: (row) {
                final rows = [
                  for (var j = 0; j < d.sets; j++)
                    j < d.customSets.length
                        ? d.customSets[j]
                        : CustomSet(reps: _goalReps(d), percent: 100),
                ];
                rows[i] = row;
                d.customSets = rows;
                onChanged();
              },
            ),
          ],
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

/// The rep target a scheme repeats: the top of the range, or the number to beat
/// on a set run to failure.
int _goalReps(ItemDraft d) => d.toFailure ? d.repsMin : (d.repsMax ?? d.repsMin);

/// What a fresh custom scheme opens on: the slot as it already is, one row per
/// set. Editing from what you have beats editing from blanks.
List<CustomSet> _seedCustomRows(ItemDraft d) => [
      for (var i = 0; i < d.sets; i++)
        CustomSet(reps: _goalReps(d), percent: 100),
    ];

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
          _pill(label: _label(l10n, s), on: s == scheme, onTap: () => onChanged(s)),
      ],
    );
  }

  Widget _pill({
    required String label,
    required bool on,
    required VoidCallback onTap,
  }) =>
      Material(
        color: on ? AppColors.accent.withValues(alpha: 0.16) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? AppColors.accent : AppColors.line),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Text(
              label,
              style: kMono.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: on ? AppColors.accent : AppColors.muted,
              ),
            ),
          ),
        ),
      );
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
              onChanged: (v) => onChanged(CustomSet(reps: v, percent: row.percent)),
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
              onChanged: (v) => onChanged(CustomSet(reps: row.reps, percent: v)),
            ),
          ),
        ]),
      ],
    );
  }
}

/// A label with a checkbox, tappable across its whole width.
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Row(
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
          // The label gives; the checkbox is the control and stays whole.
          Expanded(
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

/// The axes an exercise may progress on, as one row of pills.
///
/// Only ever shows [modes] — the axes its measure allows. Offering to progress
/// a deadlift by time is offering a choice with no right answer in it.
class _ModePicker extends StatelessWidget {
  const _ModePicker({
    required this.modes,
    required this.mode,
    required this.onChanged,
  });
  final List<ProgressionMode> modes;
  final ProgressionMode mode;
  final ValueChanged<ProgressionMode> onChanged;

  static String _label(AppLocalizations l10n, ProgressionMode m) => switch (m) {
        ProgressionMode.weight => l10n.itemEditorModeWeight,
        ProgressionMode.reps => l10n.itemEditorModeReps,
        ProgressionMode.time => l10n.itemEditorModeTime,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        for (final m in modes)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: m == modes.last ? 0 : 8),
              child: _pill(l10n, m),
            ),
          ),
      ],
    );
  }

  Widget _pill(AppLocalizations l10n, ProgressionMode m) {
    final on = m == mode;
    return Material(
      color: on ? AppColors.accent.withValues(alpha: 0.16) : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => onChanged(m),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? AppColors.accent : AppColors.line),
          ),
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Text(
            _label(l10n, m),
            textAlign: TextAlign.center,
            style: kMono.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: on ? AppColors.accent : AppColors.muted,
            ),
          ),
        ),
      ),
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
    // Switching the axis resets the amount underneath the field, and so does a
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
