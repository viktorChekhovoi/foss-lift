import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../state/active_workout.dart' show fmtWeight;
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../widgets/common.dart';

/// Swatches offered for a routine's accent colour.
const _palette = ['FF6A3D', '3ED598', 'FFC24B', '4B9BFF', 'B06AFF', 'FF5D8F'];

/// A mutable working copy of one routine item while editing.
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

/// Create ([routineId] == null) or edit an existing routine.
class RoutineEditScreen extends ConsumerStatefulWidget {
  const RoutineEditScreen({super.key, this.routineId});
  final int? routineId;

  @override
  ConsumerState<RoutineEditScreen> createState() => _RoutineEditScreenState();
}

class _RoutineEditScreenState extends ConsumerState<RoutineEditScreen> {
  final _name = TextEditingController();
  String _color = _palette.first;
  int _restSeconds = 90;
  final List<_Draft> _items = [];
  bool _loaded = false;
  bool _saving = false;

  bool get _isEdit => widget.routineId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _load();
    } else {
      _loaded = true;
    }
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final routine = await db.routineById(widget.routineId!);
    final items = await db.itemsForRoutine(widget.routineId!);
    if (!mounted) return;
    setState(() {
      _name.text = routine.name;
      _color = routine.colorHex;
      _restSeconds = routine.restSeconds;
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
    final picked = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ExercisePicker(),
    );
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
        routineRest: _restSeconds,
        onChanged: () => setState(() {}),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('Give the routine a name first.');
      return;
    }
    if (_items.isEmpty) {
      _toast('Add at least one exercise.');
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);

    final int routineId;
    if (_isEdit) {
      routineId = widget.routineId!;
      await db.updateRoutineMeta(routineId,
          name: name, color: _color, restSeconds: _restSeconds);
    } else {
      routineId = await db.createRoutine(
          name: name, color: _color, restSeconds: _restSeconds);
    }

    final companions = <RoutineItemsCompanion>[];
    for (var i = 0; i < _items.length; i++) {
      final d = _items[i];
      companions.add(RoutineItemsCompanion.insert(
        routineId: routineId,
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
    await db.replaceRoutineItems(routineId, companions);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete routine?'),
        content: const Text('This removes the template. Logged history is kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF5D5D))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(databaseProvider).deleteRoutine(widget.routineId!);
    if (!mounted) return;
    // Pop back past the (now-deleted) detail screen to the routines list.
    context.go('/routines');
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit routine' : 'New routine'),
        actions: [
          if (_isEdit)
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
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      children: [
                        _label('Name'),
                        TextField(
                          controller: _name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          decoration: _inputDecoration('e.g. Upper Body A'),
                        ),
                        const SizedBox(height: 20),
                        _label('Accent colour'),
                        _ColorRow(
                          selected: _color,
                          onSelect: (c) => setState(() => _color = c),
                        ),
                        const SizedBox(height: 20),
                        _label('Default rest between sets'),
                        _Stepper(
                          value: _restSeconds,
                          suffix: 's',
                          step: 15,
                          min: 0,
                          max: 300,
                          onChanged: (v) => setState(() => _restSeconds = v),
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
                        child: Text(_saving ? 'Saving…' : 'Save routine'),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(t.toUpperCase(),
            style: kMono.copyWith(
                fontSize: 11, letterSpacing: 1.2, color: AppColors.faint)),
      );
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    );

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

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final c in _palette)
          GestureDetector(
            onTap: () => onSelect(c),
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: hexColor(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: c == selected ? AppColors.text : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: c == selected
                  ? const Icon(Icons.check, size: 18, color: Color(0xFF0F1218))
                  : null,
            ),
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
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(_draftSummary(draft, unit),
                        style: kMono.copyWith(fontSize: 12.5, color: AppColors.accent)),
                  ],
                ),
              ),
              _iconBtn(Icons.keyboard_arrow_up, isFirst ? null : onUp),
              _iconBtn(Icons.keyboard_arrow_down, isLast ? null : onDown),
              _iconBtn(Icons.close, onRemove, danger: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback? onTap, {bool danger = false}) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      onPressed: onTap,
      icon: Icon(icon,
          size: 20,
          color: onTap == null
              ? AppColors.faint.withValues(alpha: 0.4)
              : (danger ? const Color(0xFFFF5D5D) : AppColors.muted)),
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
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(d.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(d.muscle, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 18),
          _row('Sets', _Stepper(
            value: d.sets,
            min: 1,
            max: 12,
            onChanged: (v) => _bump(() => d.sets = v),
          )),
          const SizedBox(height: 14),
          _row('To failure', Switch(
            value: d.toFailure,
            activeThumbColor: AppColors.accent,
            onChanged: (v) => _bump(() => d.toFailure = v),
          )),
          if (!d.toFailure) ...[
            const SizedBox(height: 14),
            _row('Min reps', _Stepper(
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
                          style: kMono.copyWith(fontSize: 13, color: AppColors.accent)),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Stepper(
                          value: d.repsMax!,
                          min: d.repsMin,
                          max: 100,
                          onChanged: (v) => _bump(() => d.repsMax = v),
                        ),
                        IconButton(
                          onPressed: () => _bump(() => d.repsMax = null),
                          icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                        ),
                      ],
                    ),
            ),
          ],
          const SizedBox(height: 14),
          _row(
            'Rest',
            _Stepper(
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
            decoration: _inputDecoration('Optional — leave blank for bodyweight'),
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

/// A compact "− value + " stepper.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.step = 1,
    this.suffix = '',
    this.badge,
  });
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final String suffix;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (badge != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(badge!.toUpperCase(),
                style: kMono.copyWith(
                    fontSize: 9, letterSpacing: 0.8, color: AppColors.faint)),
          ),
        _btn(Icons.remove, value > min ? () => onChanged(_clamp(value - step)) : null),
        Container(
          constraints: const BoxConstraints(minWidth: 54),
          alignment: Alignment.center,
          child: Text('$value$suffix',
              style: kMono.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        _btn(Icons.add, value < max ? () => onChanged(_clamp(value + step)) : null),
      ],
    );
  }

  int _clamp(int v) => v < min ? min : (v > max ? max : v);

  Widget _btn(IconData icon, VoidCallback? onTap) {
    return Material(
      color: onTap == null ? AppColors.surface : AppColors.surface2,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon,
              size: 18,
              color: onTap == null ? AppColors.faint : AppColors.text),
        ),
      ),
    );
  }
}

/// Searchable library picker shown as a bottom sheet; pops the chosen exercise.
class _ExercisePicker extends ConsumerStatefulWidget {
  const _ExercisePicker();
  @override
  ConsumerState<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<_ExercisePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(exerciseLibraryProvider);
    final height = MediaQuery.of(context).size.height * 0.8;
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              decoration: _inputDecoration('Search exercises…').copyWith(
                prefixIcon: const Icon(Icons.search, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: library.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.accent)),
                error: (e, _) => Center(
                    child: Text('$e', style: const TextStyle(color: AppColors.muted))),
                data: (all) {
                  final q = _query.trim().toLowerCase();
                  final list = q.isEmpty
                      ? all
                      : all
                          .where((e) =>
                              e.name.toLowerCase().contains(q) ||
                              e.muscleGroup.toLowerCase().contains(q))
                          .toList();
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.line),
                    itemBuilder: (_, i) {
                      final e = list[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        subtitle: Text('${e.muscleGroup} · ${e.equipment}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted)),
                        trailing: const Icon(Icons.add, color: AppColors.accent),
                        onTap: () => Navigator.pop(context, e),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
