import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/providers.dart';
import '../state/active_workout.dart';
import '../theme/app_theme.dart';

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
                      for (var ei = 0; ei < session.exercises.length; ei++)
                        _ExerciseBlock(
                          exercise: session.exercises[ei],
                          onAddSet: () => controller.addSet(ei),
                          rowBuilder: (si) {
                            final entry = session.exercises[ei].sets[si];
                            return _SetRow(
                              key: ValueKey('$ei-$si-${session.exercises[ei].name}'),
                              number: si + 1,
                              entry: entry,
                              onWeight: (v) => controller.setWeight(ei, si, v),
                              onReps: (v) => controller.setReps(ei, si, v),
                              onToggle: () {
                                final wasDone = entry.done;
                                controller.toggleDone(ei, si);
                                if (!wasDone) {
                                  HapticFeedback.selectionClick();
                                  _startRest();
                                }
                              },
                            );
                          },
                        ),
                      if (session.exercises.isEmpty) const _EmptyHint(),
                    ],
                  ),
                ),
              ],
            ),
            if (_restLeft > 0)
              _RestBanner(
                secondsLeft: _restLeft,
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
              label: 'Volume · kg',
              value: NumberFormat.decimalPattern().format(session.volume.round()),
              accent: true,
            ),
            const VerticalDivider(width: 1, color: AppColors.line),
            _Stat(label: 'Sets', value: '${session.doneSets}/${session.totalSets}'),
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

class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({
    required this.exercise,
    required this.onAddSet,
    required this.rowBuilder,
  });
  final ExerciseEntry exercise;
  final VoidCallback onAddSet;
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
          const _ColumnHeaders(),
          for (var si = 0; si < exercise.sets.length; si++) rowBuilder(si),
          const SizedBox(height: 8),
          _AddSetButton(onTap: onAddSet),
        ],
      ),
    );
  }
}

class _ColumnHeaders extends StatelessWidget {
  const _ColumnHeaders();
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
          h('Previous', width: 78, left: true),
          h('Kg'),
          h('Reps'),
          h('✓', width: 40),
        ],
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  const _SetRow({
    super.key,
    required this.number,
    required this.entry,
    required this.onWeight,
    required this.onReps,
    required this.onToggle,
  });
  final int number;
  final SetEntry entry;
  final ValueChanged<double> onWeight;
  final ValueChanged<int> onReps;
  final VoidCallback onToggle;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _w;
  late final TextEditingController _r;

  @override
  void initState() {
    super.initState();
    _w = TextEditingController(text: fmtWeight(widget.entry.weight));
    _r = TextEditingController(text: '${widget.entry.reps}');
  }

  @override
  void dispose() {
    _w.dispose();
    _r.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.entry.done;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Center(
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.good.withValues(alpha: 0.15)
                      : AppColors.surface3,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.number}',
                  style: kMono.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: done ? AppColors.good : AppColors.muted,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 78,
            child: Text(
              widget.entry.prev ?? '—',
              style: kMono.copyWith(
                fontSize: 12.5,
                color: done ? AppColors.muted : AppColors.faint,
              ),
            ),
          ),
          Expanded(child: _cell(_w, done, (v) => widget.onWeight(double.tryParse(v) ?? 0))),
          Expanded(child: _cell(_r, done, (v) => widget.onReps(int.tryParse(v) ?? 0))),
          SizedBox(
            width: 40,
            child: Center(child: _check(done, widget.onToggle)),
          ),
        ],
      ),
    );
  }

  Widget _cell(TextEditingController c, bool done, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: c,
        onChanged: onChanged,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: kMono.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          filled: true,
          fillColor: done ? AppColors.good.withValues(alpha: 0.10) : AppColors.surface2,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(
              color: done ? AppColors.good.withValues(alpha: 0.30) : AppColors.line,
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

  Widget _check(bool done, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: done ? AppColors.good : AppColors.surface2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: done ? AppColors.good : AppColors.line, width: 1.5),
        ),
        child: Icon(
          Icons.check_rounded,
          size: 18,
          color: done ? const Color(0xFF062015) : Colors.transparent,
        ),
      ),
    );
  }
}

class _AddSetButton extends StatelessWidget {
  const _AddSetButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.muted,
          side: const BorderSide(color: AppColors.line),
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        onPressed: onTap,
        child: Text('+ Add set', style: kMono.copyWith(fontSize: 13)),
      ),
    );
  }
}

class _RestBanner extends StatelessWidget {
  const _RestBanner({
    required this.secondsLeft,
    required this.onAdd,
    required this.onSkip,
  });
  final int secondsLeft;
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

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 60),
      child: Center(
        child: Text(
          'Empty workout — exercise picker coming next.\nTap Finish to save an empty session.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
      ),
    );
  }
}
