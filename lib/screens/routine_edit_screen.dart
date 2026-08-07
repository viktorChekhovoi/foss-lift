import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../state/unsaved_work.dart';
import '../theme/app_theme.dart';
import '../util/schedule_labels.dart';
import '../util/seed_names.dart';
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
    required this.shown,
    this.seedKey,
    this.storedCount = 0,
    this.items,
  });
  final int? id;

  /// The name as it will be stored — English, for a day the app shipped.
  String name;

  /// The name on screen: [name] translated for as long as [seedKey] survives.
  String shown;

  /// Which day of a demo program this is, until you rename it.
  String? seedKey;

  /// Exercise count as stored, used until [items] is loaded.
  final int storedCount;
  List<ItemDraft>? items;

  int get exerciseCount => items?.length ?? storedCount;

  /// Takes [typed] as the day's new name — unless it is the name already on
  /// screen.
  ///
  /// That equality is what "I did not touch it" looks like on a demo day, whose
  /// field was pre-filled with a *translation*. Writing that back would store
  /// the Ukrainian words in the name column and drop the seed key, quietly
  /// turning a day that follows the language into one that no longer can —
  /// for nothing more than opening the editor.
  void rename(String typed) {
    if (typed == shown) return;
    name = typed;
    shown = typed;
    seedKey = null;
  }
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

class _RoutineEditScreenState extends ConsumerState<RoutineEditScreen>
    with TracksUnsavedEdits {
  final _name = TextEditingController();
  String _color = _palette.first;
  int _restSeconds = 90;
  int _scheduleDays = kNoScheduleMask;
  int? _reminderMinutes;
  final List<_WorkoutDraft> _workouts = [];
  bool _loaded = false;
  bool _saving = false;

  /// Which demo program this routine is, until the name is changed.
  String? _seedKey;

  /// The name as stored, and the name put in the field — the same string unless
  /// this is a demo routine being shown in another language. See
  /// [_WorkoutDraft.rename] for why both are kept.
  String _storedName = '';
  String _shownName = '';

  bool get _isEdit => widget.routineId != null;

  @override
  void initState() {
    super.initState();
    _name.addListener(markEdited);
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
    final l10n = AppLocalizations.of(context);
    setState(() {
      _seedKey = routine.seedKey;
      _storedName = routine.name;
      _shownName = seededName(l10n, routine.seedKey, routine.name);
      _name.text = _shownName;
      _color = routine.colorHex;
      _restSeconds = routine.restSeconds;
      _scheduleDays = routine.scheduleDays;
      _reminderMinutes = routine.reminderMinutes;
      _workouts
        ..clear()
        ..addAll(workouts.map((w) => _WorkoutDraft(
              id: w.id,
              name: w.name,
              shown: seededName(l10n, w.seedKey, w.name),
              seedKey: w.seedKey,
              storedCount: counts[w.id] ?? 0,
            )));
      _loaded = true;
    });
    // Filling the field moved the controller, which is not an edit — see the
    // same note in exercise_form_screen.dart.
    markSaved();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Applies a change the user made, and records that there is now something to
  /// lose if the page goes away. Every control on this screen is one, so the
  /// mark is taken here rather than repeated at each of them — and `_load`
  /// deliberately does not go through it.
  void _edit(VoidCallback change) {
    markEdited();
    setState(change);
  }

  void _reorder(int from, int to) {
    _edit(() => _workouts.insert(to, _workouts.removeAt(from)));
  }

  Future<void> _addWorkout() async {
    final name =
        await _promptName(AppLocalizations.of(context).routineEditNewWorkout);
    if (name == null) return;
    // Yours from the first keystroke: a day you named has no seed key to lose.
    final draft = _WorkoutDraft(name: name, shown: name, items: []);
    _edit(() => _workouts.add(draft));
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
    // The day editor writes straight into the draft this screen holds, so
    // coming back from it is an edit of this screen even though nothing here
    // moved.
    if (mounted) _edit(() {});
  }

  /// A single-field dialog; returns null if cancelled or left blank.
  Future<String?> _promptName(String title) async {
    // Same story as _editWorkout: the dialog's own field takes focus, and
    // cancelling it must not hand focus back to the routine name.
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title: title),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    final trimmed = result?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final typed = _name.text.trim();
    if (typed.isEmpty) {
      _toast(l10n.routineEditNameRequired);
      return;
    }
    if (_workouts.isEmpty) {
      _toast(l10n.routineEditWorkoutRequired);
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);

    // The field was pre-filled with the routine's *translated* name. Handing
    // that back untouched is not a rename, so the English original and the key
    // it hangs on both stay — see [_WorkoutDraft.rename].
    final keepsSeed = _seedKey != null && typed == _shownName;
    final name = keepsSeed ? _storedName : typed;

    final int routineId;
    if (_isEdit) {
      routineId = widget.routineId!;
      await db.updateRoutineMeta(
        routineId,
        name: name,
        seedKey: keepsSeed ? _seedKey : null,
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

    final defaultBarKg = ref.read(plateSettingsProvider).barKg;
    await db.replaceRoutineWorkouts(
      routineId,
      [
        for (final w in _workouts)
          (
            id: w.id,
            name: w.name,
            // Untouched workouts pass null so their exercises are left alone.
            items: w.items == null
                ? null
                : itemCompanions(w.items!, defaultBarKg: defaultBarKg),
          ),
      ],
    );
    markSaved();
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.routineEditDeleteTitle),
        content: Text(l10n.routineEditDeleteBody),
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
      _edit(() => _reminderMinutes = null);
      return;
    }
    final reminders = ref.read(reminderServiceProvider);
    // On a platform that has nothing to ask (the desktop test bench), the
    // setting is still worth storing — it just will not fire there.
    final granted = !reminders.supported || await reminders.requestPermission();
    if (!mounted) return;
    if (!granted) {
      _toast(AppLocalizations.of(context).routineEditNotifyDenied);
      return;
    }
    _edit(() => _reminderMinutes ??= 18 * 60);
  }

  Future<void> _pickReminderTime() async {
    final now = _reminderMinutes ?? 18 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now ~/ 60, minute: now % 60),
    );
    if (picked == null || !mounted) return;
    _edit(() => _reminderMinutes = picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.routineEditTitle : l10n.routineEditNewTitle),
        actions: [
          if (_isEdit)
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
                          // Naming it is the first thing you do on a new
                          // routine — but never grab focus when editing one
                          // that already has a name.
                          autofocus: !_isEdit,
                          textCapitalization: TextCapitalization.sentences,
                          maxLength: kMaxNameLength,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                          decoration: builderInput(l10n.routineEditNameHint),
                        ),
                        const SizedBox(height: 20),
                        builderLabel(l10n.routineEditAccentColor),
                        _ColorRow(
                          selected: _color,
                          onSelect: (c) => _edit(() => _color = c),
                        ),
                        const SizedBox(height: 20),
                        builderLabel(l10n.routineEditDefaultRest),
                        NumberStepper(
                          value: _restSeconds,
                          // The same abbreviation the rest stepper inside a
                          // slot uses — one string, so the two cannot drift.
                          suffix: l10n.itemEditorSecondsSuffix,
                          step: 15,
                          min: 0,
                          max: 300,
                          onChanged: (v) => _edit(() => _restSeconds = v),
                        ),
                        const SizedBox(height: 22),
                        builderLabel(l10n.routineEditTrainingDays),
                        _DayToggles(
                          mask: _scheduleDays,
                          onToggle: (d) => _edit(
                              () => _scheduleDays = toggleDay(_scheduleDays, d)),
                        ),
                        // The days stay on every build — they are part of the
                        // programme and they travel in a share code. Only the
                        // reminder goes, on a build with nothing to post one
                        // with.
                        if (ref.watch(capabilitiesProvider).reminders) ...[
                          const SizedBox(height: 18),
                          builderLabel(l10n.routineEditReminder),
                          _ReminderRow(
                            minutes: _reminderMinutes,
                            onToggle: _toggleReminder,
                            onPickTime: _pickReminderTime,
                          ),
                        ],
                        const SizedBox(height: 16),
                        // The same list the exercises inside a day get, so a
                        // day is dragged into place exactly the way a slot is.
                        BuilderReorderList<_WorkoutDraft>(
                          caption: l10n.routineEditWorkouts,
                          items: _workouts,
                          emptyText: l10n.routineEditNoWorkouts,
                          addLabel: l10n.routineEditAddWorkout,
                          onAdd: _addWorkout,
                          onReorder: _reorder,
                          rowBuilder: (i, draft) => BuilderReorderRow(
                            index: i,
                            title: draft.shown,
                            subtitle: _exerciseCountLabel(l10n, draft),
                            onTap: () => _editWorkout(draft),
                            onRemove: () =>
                                _edit(() => _workouts.removeAt(i)),
                          ),
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
                            _saving ? l10n.commonSaving : l10n.routineEditSave),
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
  // Pre-filled with what the routine builder is showing for this day, which on
  // a demo day is a translation — hence [_WorkoutDraft.rename] rather than a
  // plain assignment on the way out.
  late final TextEditingController _name =
      TextEditingController(text: widget.draft.shown);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Keep the draft in step on the way out, whether by button or back gesture.
  void _commitName() {
    final trimmed = _name.text.trim();
    if (trimmed.isNotEmpty) widget.draft.rename(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final items = widget.draft.items ??= [];

    return PopScope(
      onPopInvokedWithResult: (_, _) => _commitName(),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.routineEditWorkoutTitle)),
        body: SafeArea(
          top: false,
          child: Column(
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
                      decoration:
                          builderInput(l10n.workoutEditNameHint),
                      onChanged: (_) => _commitName(),
                    ),
                    WorkoutItemsEditor(
                      defaultBarKg: ref.watch(plateSettingsProvider).barKg,
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
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      _commitName();
                      Navigator.pop(context);
                    },
                    child: Text(l10n.commonDone),
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
  const _NameDialog({required this.title});
  final String title;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        maxLength: kMaxNameLength,
        decoration: builderInput(l10n.workoutEditNameHint),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.routineEditOk),
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
    final initials = dayInitials(AppLocalizations.of(context));
    return Row(
      children: [
        for (var day = 1; day <= 7; day++) ...[
          if (day > 1) const SizedBox(width: 8),
          Expanded(
            child: _DayToggle(
              label: initials[day - 1],
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
          Expanded(
            child: Text(AppLocalizations.of(context).routineEditNotifyMe,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
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

/// What a day's row says under its name.
String _exerciseCountLabel(AppLocalizations l10n, _WorkoutDraft draft) {
  final n = draft.exerciseCount;
  return n == 0
      ? l10n.routineEditNoExercises
      : l10n.commonExerciseCount(n);
}
