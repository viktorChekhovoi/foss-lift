import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../util/units.dart';
import 'builder_widgets.dart';
import 'plate_line.dart' show loadFloorKg;

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
        exerciseId: v.exercise.id,
        name: v.exercise.name,
        muscle: v.exercise.muscleGroup,
        sets: v.item.targetSets,
        repsMin: v.item.repsMin,
        repsMax: v.item.repsMax,
        toFailure: v.item.toFailure,
        restSeconds: v.item.restSeconds,
        weightKg: v.item.suggestedWeight,
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

  /// A brand-new slot for [e], on whichever axis it can actually move along.
  factory ItemDraft.forExercise(Exercise e) => ItemDraft(
        exerciseId: e.id,
        name: e.name,
        muscle: e.muscleGroup,
        measure: e.measure,
        weightType: e.weightType,
        barKg: e.barWeight,
        progression: e.measure.defaultMode,
      );

  final int exerciseId;
  final String name;
  final String muscle;

  /// Whether the movement is counted or held. Fixed by the library, not the
  /// programme — it is what limits which axes [setMode] will accept.
  final ExerciseMeasure measure;

  /// What the movement's weight column means, [WeightType.none] included. Also
  /// fixed by the library, and the other half of what [modes] allows: there is
  /// no load to add to a movement that carries none.
  final WeightType weightType;

  /// The exercise's own bar, if it has one. Null means the app-wide default,
  /// which the draft cannot see — callers pass it to [floorKg].
  final double? barKg;

  int sets;
  int repsMin;
  int? repsMax;
  bool toFailure;
  int? restSeconds;
  double? weightKg;

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

  /// Switches the axis, resetting the rates to that mode's defaults: 2.5 of
  /// anything is a sane step in kilograms and nonsense in reps. An axis the
  /// exercise does not allow is ignored.
  void setMode(ProgressionMode mode) {
    if (mode == progression || !modes.contains(mode)) return;
    progression = mode;
    increment = mode.defaultIncrement;
    deload = mode.defaultDeload;
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
  final target = switch (d.progression) {
    ProgressionMode.time => '${d.holdSeconds}${l10n.itemEditorSecondsSuffix}',
    _ => d.toFailure
        ? l10n.itemEditorToFailureShort
        : (d.repsMax == null || d.repsMax == d.repsMin
            ? '${d.repsMin}'
            : '${d.repsMin}–${d.repsMax}'),
  };
  final w = d.weightKg == null
      ? null
      : l10n.unitWeightShort(
          fmtWeight(toDisplayWeight(d.weightKg!, unit)), unitSuffix(l10n, unit));
  final step = '+${progressionAmount(l10n, d.increment, d.progression, unit)}';
  return ['${d.sets} × $target', ?w, step].join(' · ');
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
    _bump(() => _items.add(ItemDraft.forExercise(picked)));
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
      builder: (_) => _ItemConfigSheet(
        draft: _items[i],
        unit: widget.unit,
        routineRest: widget.routineRest,
        defaultBarKg: widget.defaultBarKg,
        onChanged: () => _bump(() {}),
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

/// Bottom-sheet editor for a single item's sets / reps / rest / weight.
class _ItemConfigSheet extends StatefulWidget {
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
  State<_ItemConfigSheet> createState() => _ItemConfigSheetState();
}

class _ItemConfigSheetState extends State<_ItemConfigSheet> {
  late final TextEditingController _weight;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetGrabber(),
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
                else ...[
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
                  // A range has no meaning once the set runs to failure, so the
                  // field goes away rather than sitting there greyed out.
                  if (!d.toFailure)
                    BuilderField(
                      label: l10n.itemEditorUpTo,
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
                ],
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
              if (!_timed) ...[
                const SizedBox(height: 14),
                _CheckRow(
                  label: l10n.itemEditorToFailure,
                  value: d.toFailure,
                  onChanged: (v) => _bump(() => d.toFailure = v),
                ),
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
                  onChanged: (m) => _bump(() => d.setMode(m)),
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
                    value: d.increment,
                    mode: d.progression,
                    unit: widget.unit,
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
                    value: d.deload,
                    mode: d.progression,
                    unit: widget.unit,
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

/// A compact decimal entry for a progression amount, in the mode's own unit.
///
/// Weight is typed and shown in the display unit and stored in kilograms like
/// every other weight; reps and seconds are unitless and pass straight through.
class _AmountField extends StatefulWidget {
  const _AmountField({
    required this.value,
    required this.mode,
    required this.unit,
    required this.onChanged,
  });
  final double value;
  final ProgressionMode mode;
  final String unit;
  final ValueChanged<double> onChanged;

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  late final TextEditingController _c = TextEditingController(text: _shown);

  String get _shown => widget.mode == ProgressionMode.weight
      ? fmtWeight(toDisplayWeight(widget.value, widget.unit))
      : fmtWeight(widget.value);

  @override
  void didUpdateWidget(_AmountField old) {
    super.didUpdateWidget(old);
    // Switching the axis resets the amount underneath the field; typing in it
    // does not, and rewriting the text mid-edit would fight the cursor.
    if (widget.mode != old.mode) _c.text = _shown;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
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
      child: TextField(
        controller: _c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.right,
        style: kMono.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          filled: true,
          fillColor: AppColors.surface,
          suffixText: suffix,
          suffixStyle: kMono.copyWith(fontSize: 12, color: AppColors.faint),
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
          final parsed = double.tryParse(v.trim());
          if (parsed == null || parsed < 0) return;
          widget.onChanged(widget.mode == ProgressionMode.weight
              ? toKg(parsed, widget.unit)
              : parsed);
        },
      ),
    );
  }
}
