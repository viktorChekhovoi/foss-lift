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
  });

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
      ),
  ];
}

/// Compact reps/weight summary for a draft item, e.g. "4 × 6–8 · 80 kg".
String draftSummary(ItemDraft d, String unit) {
  final reps = d.toFailure
      ? 'to failure'
      : (d.repsMax == null || d.repsMax == d.repsMin
          ? '${d.repsMin}'
          : '${d.repsMin}–${d.repsMax}');
  final w = d.weightKg == null
      ? null
      : '${fmtWeight(toDisplayWeight(d.weightKg!, unit))} ${unitLabel(unit)}';
  return ['${d.sets} × $reps', ?w].join(' · ');
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
    final picked = await pickExercise(context);
    // Dismissing a sheet hands focus back to whatever had it, which pops the
    // keyboard open on the name field above. Nobody asked to rename anything.
    FocusManager.instance.primaryFocus?.unfocus();
    if (picked == null) return;
    _bump(() => _items.add(ItemDraft(
          exerciseId: picked.id,
          name: picked.name,
          muscle: picked.muscleGroup,
        )));
  }

  Future<void> _configure(int i) async {
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
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetGrabber(),
          Text(d.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(d.muscle,
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 18),
          _row(
              'Sets',
              NumberStepper(
                value: d.sets,
                min: 1,
                max: 12,
                onChanged: (v) => _bump(() => d.sets = v),
              )),
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
                      onPressed: () => _bump(() => d.repsMax = d.repsMin + 2),
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
          Text('SUGGESTED WEIGHT (${unitLabel(widget.unit).toUpperCase()})',
              style: kMono.copyWith(
                  fontSize: 11, letterSpacing: 1.1, color: AppColors.faint)),
          const SizedBox(height: 8),
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
    );
  }

  Widget _row(String label, Widget trailing) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
        trailing,
      ],
    );
  }
}
