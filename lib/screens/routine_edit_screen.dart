import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/builder_widgets.dart';
import '../widgets/common.dart';
import '../widgets/workout_items_editor.dart';

/// Swatches offered for a routine's accent colour.
const _palette = ['FF6A3D', '3ED598', 'FFC24B', '4B9BFF', 'B06AFF', 'FF5D8F'];

/// A mutable working copy of one workout while editing the routine. A null
/// [id] is a workout that does not exist yet.
///
/// [items] is null until the user opens the workout — a saved workout whose
/// exercises were never loaded must be written back untouched, not blanked.
class _WorkoutDraft {
  _WorkoutDraft({
    this.id,
    required this.name,
    this.storedCount = 0,
    this.items,
  });
  final int? id;
  String name;

  /// Exercise count as stored, used until [items] is loaded.
  final int storedCount;
  List<ItemDraft>? items;

  int get exerciseCount => items?.length ?? storedCount;
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
  int _scheduleDays = kNoScheduleMask;
  int? _reminderMinutes;
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
      _scheduleDays = routine.scheduleDays;
      _reminderMinutes = routine.reminderMinutes;
      _workouts
        ..clear()
        ..addAll(workouts.map((w) => _WorkoutDraft(
              id: w.id,
              name: w.name,
              storedCount: counts[w.id] ?? 0,
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
    final draft = _WorkoutDraft(name: name, items: []);
    setState(() => _workouts.add(draft));
    // Go straight into it — naming a day and then adding its exercises is one
    // continuous thought.
    await _editWorkout(draft);
  }

  /// Opens a workout for editing. Its exercises are loaded from the database
  /// the first time it is opened, then kept in memory until the routine is
  /// saved, so a brand-new routine can be built exercises-and-all in one go.
  Future<void> _editWorkout(_WorkoutDraft draft) async {
    if (draft.items == null && draft.id != null) {
      final views = await ref.read(databaseProvider).itemsForWorkout(draft.id!);
      draft.items = views.map(ItemDraft.fromView).toList();
    }
    draft.items ??= [];
    if (!mounted) return;

    // Popping a route restores focus to whatever held it before, which would
    // reopen the keyboard on the routine name. Coming back from a workout is
    // not an invitation to rename the routine. Drop focus on the way *out* —
    // then there is nothing to restore, which does not depend on when the
    // restore happens relative to this await.
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _WorkoutDraftScreen(
          draft: draft,
          routineRest: _restSeconds,
        ),
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    if (mounted) setState(() {});
  }

  /// A single-field dialog; returns null if cancelled or left blank.
  Future<String?> _promptName(String title, String initial) async {
    // Same story as _editWorkout: the dialog's own field takes focus, and
    // cancelling it must not hand focus back to the routine name.
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title: title, initial: initial),
    );
    FocusManager.instance.primaryFocus?.unfocus();
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
      await db.updateRoutineMeta(
        routineId,
        name: name,
        color: _color,
        restSeconds: _restSeconds,
        scheduleDays: _scheduleDays,
        reminderMinutes: _reminderMinutes,
      );
    } else {
      routineId = await db.createRoutine(
        name: name,
        color: _color,
        restSeconds: _restSeconds,
        scheduleDays: _scheduleDays,
        reminderMinutes: _reminderMinutes,
      );
    }

    await db.replaceRoutineWorkouts(
      routineId,
      [
        for (final w in _workouts)
          (
            id: w.id,
            name: w.name,
            // Untouched workouts pass null so their exercises are left alone.
            items: w.items == null ? null : itemCompanions(w.items!),
          ),
      ],
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

  /// Turns the reminder on or off. Switching it on is the moment to ask for the
  /// notification permission — the system prompt then arrives with the reason
  /// for it still on screen, rather than on first launch out of nowhere.
  Future<void> _toggleReminder(bool on) async {
    if (!on) {
      setState(() => _reminderMinutes = null);
      return;
    }
    final reminders = ref.read(reminderServiceProvider);
    // On a platform that has nothing to ask (the desktop test bench), the
    // setting is still worth storing — it just will not fire there.
    final granted = !reminders.supported || await reminders.requestPermission();
    if (!mounted) return;
    if (!granted) {
      _toast('Foss Lift is not allowed to notify — turn it on in '
          'Android settings.');
      return;
    }
    setState(() => _reminderMinutes ??= 18 * 60);
  }

  Future<void> _pickReminderTime() async {
    final now = _reminderMinutes ?? 18 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now ~/ 60, minute: now % 60),
    );
    if (picked == null || !mounted) return;
    setState(() => _reminderMinutes = picked.hour * 60 + picked.minute);
  }

  String _reminderHint() {
    if (_reminderMinutes == null) {
      return 'No reminder. Nothing is sent anywhere — a reminder is an alarm '
          'this phone sets for itself.';
    }
    if (_scheduleDays == kNoScheduleMask) {
      return 'Pick at least one training day above, or there is no day for the '
          'reminder to fire on.';
    }
    final when = _scheduleDays == kEveryDayMask
        ? 'every day'
        : 'on ${scheduleLabel(_scheduleDays)}';
    return 'A notification at ${timeLabel(_reminderMinutes!)} $when, skipped '
        'on any day you have already trained this routine.';
  }

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
                          // Naming it is the first thing you do on a new
                          // routine — but never grab focus when editing one
                          // that already has a name.
                          autofocus: !_isEdit,
                          textCapitalization: TextCapitalization.sentences,
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
                        const SizedBox(height: 22),
                        builderLabel('Training days'),
                        _DayToggles(
                          mask: _scheduleDays,
                          onToggle: (d) => setState(
                              () => _scheduleDays = toggleDay(_scheduleDays, d)),
                        ),
                        const SizedBox(height: 18),
                        builderLabel('Reminder'),
                        _ReminderRow(
                          minutes: _reminderMinutes,
                          onToggle: _toggleReminder,
                          onPickTime: _pickReminderTime,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _reminderHint(),
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.muted,
                              height: 1.45),
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
                              onTap: () => _editWorkout(_workouts[i]),
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
                        if (_workouts.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'Tap a workout to rename it and pick its exercises. '
                            'Nothing is written until you save the routine.',
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

/// Edits one workout draft — its name and exercises — entirely in memory.
///
/// Nothing here touches the database: the routine builder owns the draft and
/// commits the whole tree when the routine is saved. That is what lets you add
/// exercises to a workout of a routine that does not exist yet.
class _WorkoutDraftScreen extends ConsumerStatefulWidget {
  const _WorkoutDraftScreen({required this.draft, required this.routineRest});
  final _WorkoutDraft draft;
  final int routineRest;

  @override
  ConsumerState<_WorkoutDraftScreen> createState() =>
      _WorkoutDraftScreenState();
}

class _WorkoutDraftScreenState extends ConsumerState<_WorkoutDraftScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.draft.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Keep the draft in step on the way out, whether by button or back gesture.
  void _commitName() {
    final trimmed = _name.text.trim();
    if (trimmed.isNotEmpty) widget.draft.name = trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final items = widget.draft.items ??= [];

    return PopScope(
      onPopInvokedWithResult: (_, _) => _commitName(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: SafeArea(
          top: false,
          child: Column(
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
                      onChanged: (_) => _commitName(),
                    ),
                    WorkoutItemsEditor(
                      items: items,
                      unit: unit,
                      routineRest: widget.routineRest,
                      onChanged: () => setState(() {}),
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
                    onPressed: () {
                      _commitName();
                      Navigator.pop(context);
                    },
                    child: const Text('Done'),
                  ),
                ),
              ),
            ],
          ),
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

/// The seven day toggles, Monday first.
///
/// A row of round buttons rather than a list of checkboxes: a week is a shape
/// people recognise at a glance, and Mon/Wed/Fri should be readable as one.
class _DayToggles extends StatelessWidget {
  const _DayToggles({required this.mask, required this.onToggle});
  final int mask;

  /// Called with a `DateTime.weekday` value (1 = Monday).
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var day = 1; day <= 7; day++) ...[
          if (day > 1) const SizedBox(width: 8),
          Expanded(
            child: _DayToggle(
              label: kDayInitials[day - 1],
              on: scheduledOn(mask, day),
              onTap: () => onToggle(day),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle(
      {required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: kMono.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: on ? AppColors.accent : AppColors.faint,
            ),
          ),
        ),
      ),
    );
  }
}

/// The reminder switch, with the time beside it once it is on.
class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.minutes,
    required this.onToggle,
    required this.onPickTime,
  });
  final int? minutes;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final on = minutes != null;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
      child: Row(
        children: [
          const Expanded(
            child: Text('Notify me',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          if (on)
            TextButton(
              onPressed: onPickTime,
              child: Text(
                timeLabel(minutes!),
                style: kMono.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
          Switch(
            value: on,
            activeThumbColor: AppColors.accent,
            onChanged: onToggle,
          ),
        ],
      ),
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
    final n = draft.exerciseCount;
    final subtitle = n == 0
        ? 'No exercises yet — tap to add'
        : '$n ${n == 1 ? 'exercise' : 'exercises'}';
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
