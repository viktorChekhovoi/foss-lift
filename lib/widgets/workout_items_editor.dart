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
    this.progression = ProgressionMode.weight,
    this.holdSeconds = 30,
    double? increment,
    double? deload,
    this.successThreshold = defaultSuccessThreshold,
    this.failureThreshold = defaultFailureThreshold,
    this.successStreak = 0,
    this.failStreak = 0,
  })  : increment = increment ?? progression.defaultIncrement,
        deload = deload ?? progression.defaultDeload;

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
        progression: v.item.progression,
        holdSeconds: v.item.holdSeconds,
        increment: v.item.increment,
        deload: v.item.deload,
        successThreshold: v.item.successThreshold,
        failureThreshold: v.item.failureThreshold,
        successStreak: v.item.successStreak,
        failStreak: v.item.failStreak,
      );

  final int exerciseId;
  final String name;
  final String muscle;
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

  /// Switches the axis, resetting the rates to that mode's defaults: 2.5 of
  /// anything is a sane step in kilograms and nonsense in reps.
  void setMode(ProgressionMode mode) {
    if (mode == progression) return;
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

  void _move(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _items.length) return;
    _bump(() => _items.insert(j, _items.removeAt(i)));
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
    _bump(() => _items.add(ItemDraft(
          exerciseId: picked.id,
          name: picked.name,
          muscle: picked.muscleGroup,
        )));
  }

  Future<void> _configure(int i) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
        for (var i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ItemCard(
              draft: _items[i],
              unit: widget.unit,
              isFirst: i == 0,
              isLast: i == _items.length - 1,
              onTap: () => _configure(i),
              onUp: () => _move(i, -1),
              onDown: () => _move(i, 1),
              onRemove: () => _bump(() => _items.removeAt(i)),
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
    required this.draft,
    required this.unit,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    required this.onUp,
    required this.onDown,
    required this.onRemove,
  });
  final ItemDraft draft;
  final String unit;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onUp;
  final VoidCallback onDown;
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
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
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
              builderIconButton(Icons.keyboard_arrow_up, isFirst ? null : onUp),
              builderIconButton(
                  Icons.keyboard_arrow_down, isLast ? null : onDown),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetGrabber(),
            Text(d.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(d.muscle,
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 18),
            // The axis comes first: it decides whether the controls below ask
            // for reps or for a hold.
            _ModePicker(
              mode: d.progression,
              onChanged: (m) => _bump(() => d.setMode(m)),
            ),
            const SizedBox(height: 16),
            _row(
                'Sets',
                NumberStepper(
                  value: d.sets,
                  min: 1,
                  max: 12,
                  onChanged: (v) => _bump(() => d.sets = v),
                )),
            if (_timed) ...[
              const SizedBox(height: 14),
              _row(
                  'Hold',
                  NumberStepper(
                    value: d.holdSeconds,
                    suffix: 's',
                    step: 5,
                    min: 5,
                    max: 600,
                    onChanged: (v) => _bump(() => d.holdSeconds = v),
                  )),
            ] else ...[
              const SizedBox(height: 14),
              _row(
                  'To failure',
                  Switch(
                    value: d.toFailure,
                    activeThumbColor: AppColors.accent,
                    onChanged: (v) => _bump(() => d.toFailure = v),
                  )),
              if (!d.toFailure) ...[
                const SizedBox(height: 14),
                _row(
                    'Min reps',
                    NumberStepper(
                      value: d.repsMin,
                      min: 1,
                      max: 100,
                      onChanged: (v) => _bump(() {
                        d.repsMin = v;
                        if (d.repsMax != null && d.repsMax! < v) d.repsMax = v;
                      }),
                    )),
                const SizedBox(height: 14),
                _row(
                  'Rep range',
                  d.repsMax == null
                      ? TextButton(
                          onPressed: () =>
                              _bump(() => d.repsMax = d.repsMin + 2),
                          child: Text('+ Add upper bound',
                              style: kMono.copyWith(
                                  fontSize: 13, color: AppColors.accent)),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            NumberStepper(
                              value: d.repsMax!,
                              min: d.repsMin,
                              max: 100,
                              onChanged: (v) => _bump(() => d.repsMax = v),
                            ),
                            IconButton(
                              onPressed: () => _bump(() => d.repsMax = null),
                              icon: const Icon(Icons.close,
                                  size: 18, color: AppColors.muted),
                            ),
                          ],
                        ),
                ),
              ],
            ],
            const SizedBox(height: 14),
            _row(
              'Rest',
              NumberStepper(
                value: d.restSeconds ?? widget.routineRest,
                suffix: 's',
                step: 15,
                min: 0,
                max: 300,
                // Editing rest here creates an explicit per-exercise override.
                onChanged: (v) => _bump(() => d.restSeconds = v),
                badge: d.restSeconds == null ? 'default' : 'custom',
              ),
            ),
            const SizedBox(height: 18),
            builderLabel(
                'Suggested weight (${unitLabel(widget.unit)})'),
            TextField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: kMono.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: builderInput('Optional — leave blank for bodyweight'),
              onChanged: (v) {
                final parsed = double.tryParse(v.trim());
                d.weightKg = parsed == null ? null : toKg(parsed, widget.unit);
                widget.onChanged();
              },
            ),
            const SizedBox(height: 22),
            builderLabel('Progression rates'),
            _row(
              'Step up by',
              _AmountField(
                value: d.increment,
                mode: d.progression,
                unit: widget.unit,
                onChanged: (v) => _bump(() => d.increment = v),
              ),
            ),
            const SizedBox(height: 10),
            _row(
                'Clean sessions to step up',
                NumberStepper(
                  value: d.successThreshold,
                  min: 1,
                  max: 10,
                  onChanged: (v) => _bump(() => d.successThreshold = v),
                )),
            const SizedBox(height: 14),
            _row(
              'Back off by',
              _AmountField(
                value: d.deload,
                mode: d.progression,
                unit: widget.unit,
                onChanged: (v) => _bump(() => d.deload = v),
              ),
            ),
            const SizedBox(height: 10),
            _row(
                'Misses to back off',
                NumberStepper(
                  value: d.failureThreshold,
                  min: 1,
                  max: 10,
                  onChanged: (v) => _bump(() => d.failureThreshold = v),
                )),
            const SizedBox(height: 10),
            Text(
              'Add ${progressionAmount(d.increment, d.progression, widget.unit)} '
              'after ${_plural(d.successThreshold, 'clean session')}; '
              'drop ${progressionAmount(d.deload, d.progression, widget.unit)} '
              'after ${_plural(d.failureThreshold, 'missed one')} in a row.',
              style: kMono.copyWith(
                  fontSize: 11, height: 1.5, color: AppColors.faint),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _plural(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

  Widget _row(String label, Widget trailing) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
        trailing,
      ],
    );
  }
}

/// The three progression axes as one row of pills.
class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.mode, required this.onChanged});
  final ProgressionMode mode;
  final ValueChanged<ProgressionMode> onChanged;

  static const _labels = {
    ProgressionMode.weight: 'Weight',
    ProgressionMode.reps: 'Reps',
    ProgressionMode.time: 'Time',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        builderLabel('Progress by'),
        Row(
          children: [
            for (final m in ProgressionMode.values)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: m == ProgressionMode.values.last ? 0 : 8),
                  child: _pill(m),
                ),
              ),
          ],
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
      width: 132,
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
