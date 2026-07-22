import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../state/active_workout.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';

String fmtDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});
  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  Timer? _restTimer;
  int _restLeft = 0;

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  void _startRest([int seconds = 90]) {
    _restTimer?.cancel();
    setState(() => _restLeft = seconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _restLeft--);
      if (_restLeft <= 0) _stopRest();
    });
  }

  void _stopRest() {
    _restTimer?.cancel();
    _restTimer = null;
    if (mounted) setState(() => _restLeft = 0);
  }

  /// The escape hatch for high rep counts, where tapping down from a goal of 20
  /// is absurd, and for timed sets, where the tap cycle only claims the whole
  /// hold. Returns the set to untouched if the field is cleared.
  Future<void> _editResult(int ei, int si, SetEntry entry) async {
    final result = await showDialog<({int? value})>(
      context: context,
      builder: (_) => _ResultDialog(entry: entry),
    );
    if (result == null || !mounted) return;
    final wasDone = entry.done;
    ref.read(activeWorkoutProvider.notifier).setLogged(ei, si, result.value);
    if (!wasDone && result.value != null) {
      final session = ref.read(activeWorkoutProvider);
      if (session != null) _startRest(session.exercises[ei].restSeconds);
    }
  }

  Future<void> _finish() async {
    final id = await ref.read(activeWorkoutProvider.notifier).finish();
    if (!mounted) return;
    if (id != null) {
      context.pushReplacement('/summary/$id');
    } else {
      context.go('/today');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeWorkoutProvider);
    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final controller = ref.read(activeWorkoutProvider.notifier);
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _Header(title: session.name, onFinish: _finish),
                _StatStrip(session: session),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      const _LoggingHint(),
                      for (var ei = 0; ei < session.exercises.length; ei++)
                        _ExerciseBlock(
                          exercise: session.exercises[ei],
                          unit: unit,
                          rowBuilder: (si) {
                            final entry = session.exercises[ei].sets[si];
                            return _SetRow(
                              key: ValueKey('$ei-$si-${session.exercises[ei].name}'),
                              number: si + 1,
                              entry: entry,
                              unit: unit,
                              onWeight: (v) => controller.setWeight(ei, si, v),
                              onTap: () {
                                final wasDone = entry.done;
                                controller.cycleSet(ei, si);
                                HapticFeedback.selectionClick();
                                // Rest starts when the set is first logged;
                                // correcting the count afterwards must not
                                // restart the clock you are already resting on.
                                if (!wasDone) {
                                  _startRest(session.exercises[ei].restSeconds);
                                }
                              },
                              onTypeResult: () => _editResult(ei, si, entry),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_restLeft > 0)
              _RestBanner(
                secondsLeft: _restLeft,
                onSub: () => setState(() =>
                    _restLeft = _restLeft > 15 ? _restLeft - 15 : _restLeft),
                onAdd: () => setState(() => _restLeft += 15),
                onSkip: _stopRest,
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onFinish});
  final String title;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/today'),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            tooltip: 'Minimize',
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.good,
              foregroundColor: const Color(0xFF062015),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
            onPressed: onFinish,
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.session});
  final ActiveWorkout session;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.line),
          bottom: BorderSide(color: AppColors.line),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Stat(label: 'Duration', value: fmtDuration(session.elapsed)),
            const VerticalDivider(width: 1, color: AppColors.line),
            _Stat(
              label: 'Sets',
              value: '${session.doneSets}/${session.totalSets}',
              accent: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.accent = false});
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Column(
          children: [
            Text(
              value,
              style: kMono.copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: accent ? AppColors.accent : AppColors.text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label.toUpperCase(),
              style: kMono.copyWith(fontSize: 10, letterSpacing: 1.0, color: AppColors.faint),
            ),
          ],
        ),
      ),
    );
  }
}

/// Said once, at the top of the list, rather than as a legend under every
/// exercise: the tap cycle is quick to demonstrate and tedious to repeat.
class _LoggingHint extends StatelessWidget {
  const _LoggingHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        'Tap a set to log it at the goal · tap again for each rep you fell '
        'short · hold to type',
        style: kMono.copyWith(
            fontSize: 11, height: 1.45, color: AppColors.faint),
      ),
    );
  }
}

class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({
    required this.exercise,
    required this.unit,
    required this.rowBuilder,
  });
  final ExerciseEntry exercise;
  final String unit;
  final Widget Function(int setIndex) rowBuilder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 10),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  exercise.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _ColumnHeaders(unit: unit, timed: exercise.mode.timed),
          for (var si = 0; si < exercise.sets.length; si++) rowBuilder(si),
        ],
      ),
    );
  }
}

class _ColumnHeaders extends StatelessWidget {
  const _ColumnHeaders({required this.unit, required this.timed});
  final String unit;
  final bool timed;
  @override
  Widget build(BuildContext context) {
    Widget h(String t, {double? width, bool left = false}) {
      final child = Text(
        t.toUpperCase(),
        textAlign: left ? TextAlign.left : TextAlign.center,
        style: kMono.copyWith(fontSize: 10, letterSpacing: 0.9, color: AppColors.faint),
      );
      return width != null ? SizedBox(width: width, child: child) : Expanded(child: child);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 2),
      child: Row(
        children: [
          h('Set', width: 40),
          h('Goal', width: 78, left: true),
          h(unitLabel(unit)),
          h(timed ? 'Sec held' : 'Reps done'),
        ],
      ),
    );
  }
}

/// One set. The weight stays a text field — deloading mid-session is a real
/// thing you have to be able to do — but the reps cell is a tap target, not an
/// editor: you log what you got against a goal you cannot edit.
class _SetRow extends StatefulWidget {
  const _SetRow({
    super.key,
    required this.number,
    required this.entry,
    required this.unit,
    required this.onWeight,
    required this.onTap,
    required this.onTypeResult,
  });
  final int number;
  final SetEntry entry;
  final String unit;
  final ValueChanged<double> onWeight;
  final VoidCallback onTap;
  final VoidCallback onTypeResult;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _w;

  SetEntry get _entry => widget.entry;

  /// What the template asked for: "82.5×8", "BW×12", or "—×8" when it suggests
  /// no weight and the choice is yours. A timed set reads "45s", or "20×45s"
  /// when there is load to hold as well.
  String get _goalLabel {
    final e = _entry;
    final target = e.timed ? '${e.goal}s' : '${e.goal}';
    final gw = e.goalWeight;
    // An unloaded plank has no weight worth naming; an unloaded barbell lift
    // still wants its "—", because the number is yours to pick.
    if (e.timed && (gw == null || gw == 0)) return target;
    final w = gw == null
        ? '—'
        : (gw == 0 ? 'BW' : fmtWeight(toDisplayWeight(gw, widget.unit)));
    return '$w×$target';
  }

  /// Green for a set that met its goal, gold for one that came up short —
  /// including a set finished at a reduced weight.
  Color get _tone => _entry.missedGoal ? AppColors.gold : AppColors.good;

  @override
  void initState() {
    super.initState();
    _w = TextEditingController(
        text: fmtWeight(toDisplayWeight(_entry.weight, widget.unit)));
  }

  @override
  void dispose() {
    _w.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 40, child: Center(child: _setNumber())),
            SizedBox(
              width: 78,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _goalLabel,
                  style: kMono.copyWith(
                    fontSize: 12.5,
                    color: _entry.done ? AppColors.muted : AppColors.faint,
                  ),
                ),
              ),
            ),
            Expanded(child: _weightField()),
            Expanded(child: _resultBox()),
          ],
        ),
      ),
    );
  }

  Widget _setNumber() {
    final done = _entry.done;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? _tone.withValues(alpha: 0.15) : AppColors.surface3,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${widget.number}',
        style: kMono.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: done ? _tone : AppColors.muted,
        ),
      ),
    );
  }

  Widget _weightField() {
    final done = _entry.done;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: _w,
        onChanged: (v) =>
            widget.onWeight(toKg(double.tryParse(v) ?? 0, widget.unit)),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: kMono.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          filled: true,
          fillColor:
              done ? _tone.withValues(alpha: 0.10) : AppColors.surface2,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(
              color: done ? _tone.withValues(alpha: 0.30) : AppColors.line,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
        ),
      ),
    );
  }

  /// Untouched, the cell shows the goal greyed out — the number you are about
  /// to claim. One tap turns that same number green; further taps count it
  /// down in gold. Nothing here can change the goal itself.
  Widget _resultBox() {
    final done = _entry.done;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onTypeResult,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: done ? _tone.withValues(alpha: 0.15) : AppColors.surface2,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: done ? _tone.withValues(alpha: 0.55) : AppColors.line,
            ),
          ),
          child: Text(
            '${_entry.logged ?? _entry.goal}${_entry.timed ? 's' : ''}',
            style: kMono.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: done ? _tone : AppColors.faint,
            ),
          ),
        ),
      ),
    );
  }
}

/// Direct entry of what a set actually came to — reps done, or seconds held on
/// a timed set. For the sets where tapping down from a goal of 20 is absurd,
/// and for every plank. An empty field means the set never happened, which is
/// the same thing the Clear button does.
class _ResultDialog extends StatefulWidget {
  const _ResultDialog({required this.entry});
  final SetEntry entry;

  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog> {
  late final TextEditingController _c = TextEditingController(
      text: '${widget.entry.logged ?? widget.entry.goal}');

  bool get _timed => widget.entry.timed;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _pop(int? value) => Navigator.pop<({int? value})>(context, (value: value));

  void _save() {
    final v = int.tryParse(_c.text.trim());
    _pop(v == null ? null : (v < 0 ? 0 : v));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(_timed ? 'Seconds held' : 'Reps done'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _c,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: kMono.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              filled: true,
              fillColor: AppColors.surface2,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 10),
          Text(
            'Goal ${widget.entry.goal}${_timed ? 's' : ''}',
            style: kMono.copyWith(fontSize: 12, color: AppColors.faint),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _pop(null),
          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _RestBanner extends StatelessWidget {
  const _RestBanner({
    required this.secondsLeft,
    required this.onSub,
    required this.onAdd,
    required this.onSkip,
  });
  final int secondsLeft;
  final VoidCallback onSub;
  final VoidCallback onAdd;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface3,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('REST',
                      style: kMono.copyWith(fontSize: 11, letterSpacing: 1.0, color: AppColors.muted)),
                  Text(
                    fmtDuration(secondsLeft),
                    style: kMono.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.good,
                    ),
                  ),
                ],
              ),
            ),
            _pill('−15s', onSub),
            const SizedBox(width: 8),
            _pill('+15s', onAdd),
            const SizedBox(width: 8),
            _pill('Skip', onSkip),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, VoidCallback onTap) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      child: Text(label, style: kMono.copyWith(fontSize: 12)),
    );
  }
}
