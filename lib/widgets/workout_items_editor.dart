import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../data/database.dart';
import '../state/active_workout.dart' show fmtWeight;
import '../theme/app_theme.dart';
import '../util/units.dart';
import 'builder_widgets.dart';
import 'common.dart';

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
    this.weightKg,
    this.measure = ExerciseMeasure.reps,
    ProgressionMode? progression,
    this.holdSeconds = 30,
    double? increment,
    double? deload,
    this.successThreshold = defaultSuccessThreshold,
    this.failureThreshold = defaultFailureThreshold,
    this.successStreak = 0,
    this.failStreak = 0,
  })  : progression = _startingMode(measure, progression),
        increment =
            increment ?? _startingMode(measure, progression).defaultIncrement,
        deload = deload ?? _startingMode(measure, progression).defaultDeload;

  /// The axis a draft opens on: what was asked for, if the measure allows it.
  static ProgressionMode _startingMode(
          ExerciseMeasure measure, ProgressionMode? want) =>
      measure.coerce(want ?? ProgressionMode.weight);

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
        // measure must not leave a saved workout counting reps against a hold.
        measure: v.exercise.measure,
        progression: v.item.progression,
        holdSeconds: v.item.holdSeconds,
        increment: v.item.increment,
        deload: v.item.deload,
        successThreshold: v.item.successThreshold,
        failureThreshold: v.item.failureThreshold,
        successStreak: v.item.successStreak,
        failStreak: v.item.failStreak,
      );

  /// A brand-new slot for [e], on whichever axis its measure implies.
  factory ItemDraft.forExercise(Exercise e) => ItemDraft(
        exerciseId: e.id,
        name: e.name,
        muscle: e.muscleGroup,
        measure: e.measure,
        progression: e.measure.defaultMode,
      );

  final int exerciseId;
  final String name;
  final String muscle;

  /// Whether the movement is counted or held. Fixed by the library, not the
  /// programme — it is what limits which axes [setMode] will accept.
  final ExerciseMeasure measure;

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

  /// The axes this slot may be put on, per the exercise's measure.
  List<ProgressionMode> get modes => measure.modes;

  /// Switches the axis, resetting the rates to that mode's defaults: 2.5 of
  /// anything is a sane step in kilograms and nonsense in reps. An axis the
  /// measure does not allow is ignored.
  void setMode(ProgressionMode mode) {
    if (mode == progression || !modes.contains(mode)) return;
    progression = mode;
    increment = mode.defaultIncrement;
    deload = mode.defaultDeload;
  }
}

/// Turns drafts into insertable rows, in list order.
List<WorkoutItemsCompanion> itemCompanions(List<ItemDraft> drafts,
    {int workoutId = 0}) {
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
        suggestedWeight: Value(drafts[i].weightKg),
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
String progressionAmount(double amount, ProgressionMode mode, String unit) {
  return switch (mode) {
    ProgressionMode.weight =>
      '${fmtWeight(toDisplayWeight(amount, unit))} ${unitLabel(unit)}',
    ProgressionMode.reps => '${amount.round()} ${amount == 1 ? 'rep' : 'reps'}',
    ProgressionMode.time => '${amount.round()}s',
  };
}

/// Compact target/weight/progression summary for a draft item, e.g.
/// "4 × 6–8 · 80 kg · +2.5 kg".
String draftSummary(ItemDraft d, String unit) {
  final target = switch (d.progression) {
    ProgressionMode.time => '${d.holdSeconds}s',
    _ => d.toFailure
        ? 'to failure'
        : (d.repsMax == null || d.repsMax == d.repsMin
            ? '${d.repsMin}'
            : '${d.repsMin}–${d.repsMax}'),
  };
  final w = d.weightKg == null
      ? null
      : '${fmtWeight(toDisplayWeight(d.weightKg!, unit))} ${unitLabel(unit)}';
  final step = '+${progressionAmount(d.increment, d.progression, unit)}';
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
    this.onChanged,
  });

  final List<ItemDraft> items;
  final String unit;

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
        onChanged: () => _bump(() {}),
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('Exercises · ${_items.length}'),
        if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No exercises yet — add one below.',
                style: TextStyle(color: AppColors.muted)),
          ),
        // Shrink-wrapped and non-scrolling: the editor is already inside the
        // screen's scroll view, and a list with its own would trap the drag.
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          padding: EdgeInsets.zero,
          itemCount: _items.length,
          // onReorderItem, not onReorder: it hands back a destination index
          // already corrected for the item having been lifted out.
          onReorderItem: _reorder,
          proxyDecorator: (child, _, _) => Material(
            color: Colors.transparent,
            child: Opacity(opacity: 0.9, child: child),
          ),
          itemBuilder: (context, i) => Padding(
            key: ValueKey(_items[i]),
            padding: const EdgeInsets.only(bottom: 10),
            child: _ItemCard(
              index: i,
              draft: _items[i],
              unit: widget.unit,
              onTap: () => _configure(i),
              onRemove: () => _bump(() => _items.removeAt(i)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: const BorderSide(color: AppColors.line),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _addExercise,
          icon: const Icon(Icons.add),
          label: const Text('Add exercise'),
        ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.index,
    required this.draft,
    required this.unit,
    required this.onTap,
    required this.onRemove,
  });
  final int index;
  final ItemDraft draft;
  final String unit;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.fromLTRB(4, 10, 6, 10),
          child: Row(
            children: [
              // Grab here to drag the exercise up or down the list.
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Icon(Icons.drag_indicator,
                      size: 22, color: AppColors.faint),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(draft.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(draftSummary(draft, unit),
                        style: kMono.copyWith(
                            fontSize: 12.5, color: AppColors.accent)),
                  ],
                ),
              ),
              builderIconButton(Icons.close, onRemove, danger: true),
            ],
          ),
        ),
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
    required this.onChanged,
  });
  final ItemDraft draft;
  final String unit;
  final int routineRest;
  final VoidCallback onChanged;

  @override
  State<_ItemConfigSheet> createState() => _ItemConfigSheetState();
}

class _ItemConfigSheetState extends State<_ItemConfigSheet> {
  late final TextEditingController _weight;

  ItemDraft get d => widget.draft;

  /// True when [d] is measured in seconds rather than reps.
  bool get _timed => d.progression.timed;

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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetGrabber(),
            Text(d.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(d.muscle,
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 18),
            builderCard('Target', [
              builderGrid([
                BuilderField(
                  label: 'Sets',
                  child: NumberStepper(
                    value: d.sets,
                    min: 1,
                    max: 12,
                    onChanged: (v) => _bump(() => d.sets = v),
                  ),
                ),
                if (_timed)
                  BuilderField(
                    label: 'Hold',
                    child: NumberStepper(
                      value: d.holdSeconds,
                      suffix: 's',
                      step: 5,
                      min: 5,
                      max: 600,
                      onChanged: (v) => _bump(() => d.holdSeconds = v),
                    ),
                  )
                else ...[
                  BuilderField(
                    label: d.toFailure ? 'Reps to beat' : 'Reps',
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
                      label: 'Up to',
                      child: NumberStepper(
                        // Stepping down past the lower bound drops the upper
                        // one entirely — no stray clear button to knock the
                        // row out of line with the rest of the grid.
                        value: d.repsMax ?? d.repsMin,
                        isEmpty: d.repsMax == null,
                        emptyLabel: 'none',
                        min: d.repsMin,
                        max: 100,
                        onChanged: (v) => _bump(() => d.repsMax = v),
                        onClear: () => _bump(() => d.repsMax = null),
                      ),
                    ),
                ],
                BuilderField(
                  label: 'Rest',
                  // Editing rest here creates an explicit per-exercise
                  // override; the caption is where that gets said, so the
                  // stepper stays the same width as its neighbours.
                  note: d.restSeconds == null ? 'default' : 'custom',
                  child: NumberStepper(
                    value: d.restSeconds ?? widget.routineRest,
                    suffix: 's',
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
                  label: 'To failure',
                  value: d.toFailure,
                  onChanged: (v) => _bump(() => d.toFailure = v),
                ),
              ],
            ]),
            const SizedBox(height: 14),
            builderCard('Suggested weight (${unitLabel(widget.unit)})', [
              TextField(
                controller: _weight,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style:
                    kMono.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                decoration: builderInput('Blank for bodyweight'),
                onChanged: (v) {
                  final parsed = double.tryParse(v.trim());
                  d.weightKg = parsed == null ? null : toKg(parsed, widget.unit);
                  widget.onChanged();
                },
              ),
            ]),
            const SizedBox(height: 14),
            builderCard('Progression', [
              // A hold has one axis available and no choice to present; the
              // caption says so instead of showing a picker of one.
              if (d.modes.length > 1)
                _ModePicker(
                  modes: d.modes,
                  mode: d.progression,
                  onChanged: (m) => _bump(() => d.setMode(m)),
                )
              else
                Text(
                  'Held for time — the only axis a hold can progress on.',
                  style: kMono.copyWith(
                      fontSize: 11, height: 1.5, color: AppColors.faint),
                ),
              const SizedBox(height: 16),
              builderGrid([
                BuilderField(
                  label: 'Step up by',
                  child: _AmountField(
                    value: d.increment,
                    mode: d.progression,
                    unit: widget.unit,
                    onChanged: (v) => _bump(() => d.increment = v),
                  ),
                ),
                BuilderField(
                  label: 'Clean sessions',
                  child: NumberStepper(
                    value: d.successThreshold,
                    min: 1,
                    max: 10,
                    onChanged: (v) => _bump(() => d.successThreshold = v),
                  ),
                ),
                BuilderField(
                  label: 'Back off by',
                  child: _AmountField(
                    value: d.deload,
                    mode: d.progression,
                    unit: widget.unit,
                    onChanged: (v) => _bump(() => d.deload = v),
                  ),
                ),
                BuilderField(
                  label: 'Misses',
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
                'Add ${progressionAmount(d.increment, d.progression, widget.unit)} '
                'after ${_plural(d.successThreshold, 'clean session')}; '
                'drop ${progressionAmount(d.deload, d.progression, widget.unit)} '
                'after ${_plural(d.failureThreshold, 'missed one')} in a row.',
                style: kMono.copyWith(
                    fontSize: 11, height: 1.5, color: AppColors.faint),
              ),
            ]),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  String _plural(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
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
              side: const BorderSide(color: AppColors.line, width: 1.5),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 15)),
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

  static const _labels = {
    ProgressionMode.weight: 'Weight',
    ProgressionMode.reps: 'Reps',
    ProgressionMode.time: 'Time',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final m in modes)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: m == modes.last ? 0 : 8),
              child: _pill(m),
            ),
          ),
      ],
    );
  }

  Widget _pill(ProgressionMode m) {
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
            _labels[m]!,
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
    final suffix = widget.mode == ProgressionMode.weight
        ? unitLabel(widget.unit)
        : (widget.mode.timed ? 'sec' : 'reps');
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
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.accent),
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
