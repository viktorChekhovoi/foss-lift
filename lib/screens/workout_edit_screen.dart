import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/builder_widgets.dart';
import '../widgets/workout_items_editor.dart';

/// Edits one saved workout: its name and the ordered exercises it contains.
/// New workouts are built inline in the routine builder instead.
class WorkoutEditScreen extends ConsumerStatefulWidget {
  const WorkoutEditScreen({super.key, required this.workoutId});
  final int workoutId;

  @override
  ConsumerState<WorkoutEditScreen> createState() => _WorkoutEditScreenState();
}

class _WorkoutEditScreenState extends ConsumerState<WorkoutEditScreen> {
  final _name = TextEditingController();
  final List<ItemDraft> _items = [];
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
        ..addAll(items.map(ItemDraft.fromView));
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
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
    await db.replaceWorkoutItems(
        widget.workoutId, itemCompanions(_items, workoutId: widget.workoutId));
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
            ? Center(
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
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                          decoration: builderInput('e.g. Push'),
                        ),
                        WorkoutItemsEditor(
                          items: _items,
                          unit: unit,
                          routineRest: _routineRest,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                    decoration: BoxDecoration(
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
