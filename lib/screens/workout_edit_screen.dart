import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/seed_names.dart';
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

  /// The name put in the field. On a day the app shipped that is a translation
  /// of the stored English, so handing it back untouched must not count as a
  /// rename — writing it would store the translation and clear the seed key,
  /// and the day would stop following the language for good.
  String _shownName = '';

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
    _shownName =
        seededName(AppLocalizations.of(context), workout.seedKey, workout.name);
    setState(() {
      _name.text = _shownName;
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
      _toast(AppLocalizations.of(context).workoutEditNameRequired);
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    // Only a name that actually changed is written: renaming is what makes a
    // day yours, and [AppDatabase.renameWorkout] clears the seed key to say so.
    if (name != _shownName) await db.renameWorkout(widget.workoutId, name);
    await db.replaceWorkoutItems(
      widget.workoutId,
      itemCompanions(
        _items,
        workoutId: widget.workoutId,
        defaultBarKg: ref.read(plateSettingsProvider).barKg,
      ),
    );
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.workoutEditDeleteTitle),
        content: Text(l10n.workoutEditDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete,
                style: const TextStyle(color: Color(0xFFFF5D5D))),
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
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workoutEditTitle),
        actions: [
          IconButton(
            tooltip: l10n.commonDelete,
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
                        builderLabel(l10n.commonName),
                        TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.sentences,
                          maxLength: kMaxNameLength,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                          decoration: builderInput(l10n.workoutEditNameHint),
                        ),
                        WorkoutItemsEditor(
                          defaultBarKg: ref.watch(plateSettingsProvider).barKg,
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
                        child: Text(
                            _saving ? l10n.commonSaving : l10n.workoutEditSave),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
