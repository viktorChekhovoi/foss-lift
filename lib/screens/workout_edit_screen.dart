import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../state/active_workout.dart' show fmtWeight;
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../widgets/builder_widgets.dart';
import '../widgets/common.dart';

/// A mutable working copy of one workout item while editing.
class _Draft {
  _Draft({
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

/// Edits one workout: its name and the ordered exercises it contains.
class WorkoutEditScreen extends ConsumerStatefulWidget {
  const WorkoutEditScreen({super.key, required this.workoutId});
  final int workoutId;

  @override
  ConsumerState<WorkoutEditScreen> createState() => _WorkoutEditScreenState();
}

class _WorkoutEditScreenState extends ConsumerState<WorkoutEditScreen> {
  final _name = TextEditingController();
  final List<_Draft> _items = [];
  int _routineId = 0;
  int _routineRest = 90;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final workout = await db.workoutById(widget.workoutId);
    final routine = await db.routineById(workout.routineId);
    final items = await db.itemsForWorkout(widget.workoutId);
    if (!mounted) return;
    setState(() {
      _name.text = workout.name;
      _routineId = workout.routineId;
      _routineRest = routine.restSeconds;
      _items
        ..clear()
        ..addAll(items.map((v) => _Draft(
              exerciseId: v.exercise.id,
              name: v.exercise.name,
              muscle: v.exercise.muscleGroup,
              sets: v.item.targetSets,
              repsMin: v.item.repsMin,
              repsMax: v.item.repsMax,
              toFailure: v.item.toFailure,
              restSeconds: v.item.restSeconds,
              weightKg: v.item.suggestedWeight,
            )));
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _move(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _items.length) return;
    setState(() {
      final it = _items.removeAt(i);
      _items.insert(j, it);
    });
  }

  Future<void> _addExercise() async {
    final picked = await pickExercise(context);
    if (picked == null) return;
    setState(() {
      _items.add(_Draft(
        exerciseId: picked.id,
        name: picked.name,
        muscle: picked.muscleGroup,
      ));
    });
  }

  Future<void> _configure(int i) async {
    final unit = ref.read(weightUnitProvider).value ?? 'kg';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ItemConfigSheet(
        draft: _items[i],
        unit: unit,
        routineRest: _routineRest,
        onChanged: () => setState(() {}),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('Give the workout a name first.');
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    await db.renameWorkout(widget.workoutId, name);

    final companions = <WorkoutItemsCompanion>[];
    for (var i = 0; i < _items.length; i++) {
      final d = _items[i];
      companions.add(WorkoutItemsCompanion.insert(
        workoutId: widget.workoutId,
        exerciseId: d.exerciseId,
        position: Value(i),
        targetSets: Value(d.sets),
        repsMin: Value(d.repsMin),
        repsMax: Value(d.toFailure ? null : d.repsMax),
        toFailure: Value(d.toFailure),
        restSeconds: Value(d.restSeconds),
        suggestedWeight: Value(d.weightKg),
      ));
    }
    await db.replaceWorkoutItems(widget.workoutId, companions);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete workout?'),
        content: const Text(
            'This removes the day from the routine. Logged history is kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: Color(0xFFFF5D5D))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(databaseProvider).deleteWorkout(widget.workoutId);
    if (!mounted) return;
    // Pop past the (now-deleted) workout detail screen to its routine.
    context.go('/routine/$_routineId');
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit workout'),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: !_loaded
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent))
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      children: [
                        builderLabel('Name'),
                        TextField(
                          controller: _name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                          decoration: builderInput('e.g. Push'),
                        ),
                        const SizedBox(height: 8),
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
                              unit: unit,
                              isFirst: i == 0,
                              isLast: i == _items.length - 1,
                              onTap: () => _configure(i),
                              onUp: () => _move(i, -1),
                              onDown: () => _move(i, 1),
                              onRemove: () => setState(() => _items.removeAt(i)),
                            ),
                          ),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            side: const BorderSide(color: AppColors.line),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _addExercise,
                          icon: const Icon(Icons.add),
                          label: const Text('Add exercise'),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.line)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving…' : 'Save workout'),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Compact reps/weight summary for a draft item, e.g. "4 × 6–8 · 80 kg".
String _draftSummary(_Draft d, String unit) {
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
  final _Draft draft;
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
                    Text(_draftSummary(draft, unit),
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
  final _Draft draft;
  final String unit;
  final int routineRest;
  final VoidCallback onChanged;

  @override
  State<_ItemConfigSheet> createState() => _ItemConfigSheetState();
}

class _ItemConfigSheetState extends State<_ItemConfigSheet> {
  late final TextEditingController _weight;

  _Draft get d => widget.draft;

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
