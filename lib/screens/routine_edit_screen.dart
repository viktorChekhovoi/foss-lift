import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/builder_widgets.dart';
import '../widgets/common.dart';

/// Swatches offered for a routine's accent colour.
const _palette = ['FF6A3D', '3ED598', 'FFC24B', '4B9BFF', 'B06AFF', 'FF5D8F'];

/// A mutable working copy of one workout while editing the routine. A null
/// [id] is a workout that does not exist yet.
class _WorkoutDraft {
  _WorkoutDraft({this.id, required this.name, this.exerciseCount = 0});
  final int? id;
  String name;
  final int exerciseCount;
}

/// Create ([routineId] == null) or edit an existing routine: its name, colour,
/// default rest, and the ordered list of workouts (training days) it contains.
/// The exercises inside each workout are edited on [WorkoutEditScreen].
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
  final List<_WorkoutDraft> _workouts = [];
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
    final workouts = await db.workoutsForRoutine(widget.routineId!);
    final counts = <int, int>{};
    for (final w in workouts) {
      counts[w.id] = (await db.itemsForWorkout(w.id)).length;
    }
    if (!mounted) return;
    setState(() {
      _name.text = routine.name;
      _color = routine.colorHex;
      _restSeconds = routine.restSeconds;
      _workouts
        ..clear()
        ..addAll(workouts.map((w) => _WorkoutDraft(
              id: w.id,
              name: w.name,
              exerciseCount: counts[w.id] ?? 0,
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
    if (j < 0 || j >= _workouts.length) return;
    setState(() {
      final w = _workouts.removeAt(i);
      _workouts.insert(j, w);
    });
  }

  Future<void> _addWorkout() async {
    final name = await _promptName('New workout', '');
    if (name == null) return;
    setState(() => _workouts.add(_WorkoutDraft(name: name)));
  }

  Future<void> _renameWorkout(int i) async {
    final name = await _promptName('Rename workout', _workouts[i].name);
    if (name == null) return;
    setState(() => _workouts[i].name = name);
  }

  /// A single-field dialog; returns null if cancelled or left blank.
  Future<String?> _promptName(String title, String initial) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title: title, initial: initial),
    );
    final trimmed = result?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('Give the routine a name first.');
      return;
    }
    if (_workouts.isEmpty) {
      _toast('Add at least one workout.');
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

    await db.replaceRoutineWorkouts(
      routineId,
      [for (final w in _workouts) (id: w.id, name: w.name)],
    );
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete routine?'),
        content: const Text(
            'This removes the routine and all of its workouts. Logged history '
            'is kept.'),
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
    await ref.read(databaseProvider).deleteRoutine(widget.routineId!);
    if (!mounted) return;
    // Pop back past the (now-deleted) detail screen to the routines list.
    context.go('/routines');
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
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
                          decoration:
                              builderInput('e.g. Push / Pull / Legs'),
                        ),
                        const SizedBox(height: 20),
                        builderLabel('Accent colour'),
                        _ColorRow(
                          selected: _color,
                          onSelect: (c) => setState(() => _color = c),
                        ),
                        const SizedBox(height: 20),
                        builderLabel('Default rest between sets'),
                        NumberStepper(
                          value: _restSeconds,
                          suffix: 's',
                          step: 15,
                          min: 0,
                          max: 300,
                          onChanged: (v) => setState(() => _restSeconds = v),
                        ),
                        const SizedBox(height: 8),
                        SectionLabel('Workouts · ${_workouts.length}'),
                        if (_workouts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'No workouts yet — a routine is made of training '
                              'days, like Push, Pull and Legs.',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                        for (var i = 0; i < _workouts.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _WorkoutCard(
                              draft: _workouts[i],
                              isFirst: i == 0,
                              isLast: i == _workouts.length - 1,
                              onTap: () => _renameWorkout(i),
                              onUp: () => _move(i, -1),
                              onDown: () => _move(i, 1),
                              onRemove: () =>
                                  setState(() => _workouts.removeAt(i)),
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
                          onPressed: _addWorkout,
                          icon: const Icon(Icons.add),
                          label: const Text('Add workout'),
                        ),
                        if (_isEdit && _workouts.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'Tap a workout to rename it. To edit its exercises, '
                            'open it from the routine screen.',
                            style: TextStyle(
                                fontSize: 12.5, color: AppColors.muted),
                          ),
                        ],
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
}

/// A one-field name prompt. The dialog owns its controller: disposing it from
/// the caller the moment `showDialog` returns tears it down while the route is
/// still animating out, and the still-mounted TextField trips an assertion.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});
  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: builderInput('e.g. Push'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('OK'),
        ),
      ],
    );
  }
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

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.draft,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    required this.onUp,
    required this.onDown,
    required this.onRemove,
  });
  final _WorkoutDraft draft;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final subtitle = draft.id == null
        ? 'New — add exercises after saving'
        : '${draft.exerciseCount} '
            '${draft.exerciseCount == 1 ? 'exercise' : 'exercises'}';
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
                    Text(subtitle,
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
