import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../state/active_workout.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../widgets/common.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key, required this.sessionId});
  final int sessionId;

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  List<ProgressionOutcome> _progression = const [];

  @override
  void initState() {
    super.initState();
    // The progression banner belongs to the session that was just finished.
    // Grab its report if this is that screen, and clear the stash so reaching
    // the same summary later from History finds nothing and shows nothing.
    final report = ref.read(lastProgressionProvider);
    if (report != null && report.sessionId == widget.sessionId) {
      _progression = report.outcomes;
      Future.microtask(() {
        if (mounted) ref.read(lastProgressionProvider.notifier).clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(sessionSummaryProvider(widget.sessionId));
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';

    return Scaffold(
      body: SafeArea(
        child: data.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          error: (e, _) =>
              Center(child: Text('$e', style: const TextStyle(color: AppColors.muted))),
          data: (d) => _SummaryBody(
            session: d.session,
            sets: d.sets,
            unit: unit,
            progression: _progression,
          ),
        ),
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.session,
    required this.sets,
    required this.unit,
    required this.progression,
  });
  final Session session;
  final List<SessionSet> sets;
  final String unit;
  final List<ProgressionOutcome> progression;

  @override
  Widget build(BuildContext context) {
    // Group sets by exercise, preserving first-seen order.
    final grouped = <String, List<SessionSet>>{};
    for (final s in sets) {
      grouped.putIfAbsent(s.exerciseName, () => []).add(s);
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.good, Color(0xFF2FAE7D)],
                    ),
                  ),
                  child: const Icon(Icons.check_rounded, size: 40, color: Color(0xFF062015)),
                ),
              ),
              const SizedBox(height: 18),
              const Center(
                child: Text('Workout logged',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(session.name,
                    style: const TextStyle(color: AppColors.muted, fontSize: 14)),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  DateFormat('EEE d MMM · HH:mm').format(session.startedAt),
                  style: kMono.copyWith(fontSize: 12, color: AppColors.faint),
                ),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _SumCell(
                        value: '${(session.durationSeconds / 60).round()}',
                        unit: 'min',
                        label: 'Duration',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SumCell(
                          value: '${session.setsCompleted}', label: 'Sets done'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SumCell(
                          value: '${grouped.length}', label: 'Exercises'),
                    ),
                  ],
                ),
              ),
              if (progression.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Progression'),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.line),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            for (final e in progression.asMap().entries)
                              _ProgressionRow(
                                outcome: e.value,
                                unit: unit,
                                last: e.key == progression.length - 1,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Session'),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.line),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          for (final entry in grouped.entries.toList().asMap().entries)
                            _SessionExerciseRow(
                              index: entry.key + 1,
                              name: entry.value.key,
                              sets: entry.value.value,
                              unit: unit,
                              last: entry.key == grouped.length - 1,
                            ),
                          if (grouped.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Text('No sets were logged this session.',
                                  style: TextStyle(color: AppColors.muted)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go('/today'),
              child: const Text('Done'),
            ),
          ),
        ),
      ],
    );
  }
}

class _SumCell extends StatelessWidget {
  const _SumCell({required this.value, required this.label, this.unit});
  final String value;
  final String label;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text.rich(
            TextSpan(
              style: kMono.copyWith(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3),
              children: [
                TextSpan(text: value),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: kMono.copyWith(fontSize: 11, letterSpacing: 0.9, color: AppColors.faint),
          ),
        ],
      ),
    );
  }
}

/// One line of the "what progression did" banner: the exercise, where its
/// target now sits, and — coloured green up / gold down / muted for a hold —
/// the change that got it there or how close a held one is to the next move.
class _ProgressionRow extends StatelessWidget {
  const _ProgressionRow({
    required this.outcome,
    required this.unit,
    required this.last,
  });
  final ProgressionOutcome outcome;
  final String unit;
  final bool last;

  /// Where the slot now points — the load, reps, or hold the next session opens
  /// at. A weight target driven to zero is the bodyweight movement it always
  /// was, not "0 kg".
  String _target() {
    switch (outcome.mode) {
      case ProgressionMode.weight:
        if (outcome.target == 0) return 'bodyweight';
        return '${fmtWeight(toDisplayWeight(outcome.target, unit))} ${unitLabel(unit)}';
      case ProgressionMode.reps:
        return '${outcome.target.round()} reps';
      case ProgressionMode.time:
        return '${outcome.target.round()}s';
    }
  }

  /// The change in the mode's own unit, converted for display. Deltas are
  /// linear across units, so a kg step reads correctly once scaled to lb.
  String _delta() {
    final mag = outcome.moved.abs();
    final sign = outcome.moved > 0 ? '+' : '−';
    final amount = switch (outcome.mode) {
      ProgressionMode.weight =>
        '${fmtWeight(toDisplayWeight(mag, unit))} ${unitLabel(unit)}',
      ProgressionMode.reps => mag == 1 ? '1 rep' : '${mag.round()} reps',
      ProgressionMode.time => '${mag.round()}s',
    };
    return '$sign$amount';
  }

  /// The subline for a held exercise: how many more sessions or misses stand
  /// between it and the next move. Null when there is nothing pending to say.
  String? _heldNote() {
    if (outcome.failures > 0) {
      final n = outcome.failureThreshold - outcome.failures;
      if (n > 0) {
        return n == 1 ? '1 more miss to a back-off' : '$n more misses to a back-off';
      }
    } else if (outcome.successes > 0) {
      final n = outcome.successThreshold - outcome.successes;
      if (n > 0) {
        return n == 1
            ? '1 more clean session to a step'
            : '$n more clean sessions to a step';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color tone) = outcome.steppedUp
        ? (Icons.arrow_upward_rounded, AppColors.good)
        : outcome.backedOff
            ? (Icons.arrow_downward_rounded, AppColors.gold)
            : (Icons.remove_rounded, AppColors.muted);
    final sub = outcome.held ? _heldNote() : _delta();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border:
            last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(outcome.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ],
            ),
          ),
          Text(
            _target(),
            style: kMono.copyWith(
                fontSize: 13, fontWeight: FontWeight.w700, color: tone),
          ),
        ],
      ),
    );
  }
}

class _SessionExerciseRow extends StatelessWidget {
  const _SessionExerciseRow({
    required this.index,
    required this.name,
    required this.sets,
    required this.unit,
    required this.last,
  });
  final int index;
  final String name;
  final List<SessionSet> sets;
  final String unit;
  final bool last;

  @override
  Widget build(BuildContext context) {
    // Best set = highest weight × reps, or the longest hold when the exercise
    // is measured in time and weight × reps is zero for all of them.
    final timed = sets.any((s) => s.goalSeconds != null || s.seconds != null);
    SessionSet best = sets.first;
    for (final s in sets) {
      final better = timed
          ? (s.seconds ?? 0) > (best.seconds ?? 0)
          : s.weight * s.reps > best.weight * best.reps;
      if (better) best = s;
    }
    final missed = sets.where(setMissedGoal).length;
    final w =
        best.weight == 0 ? 'BW' : fmtWeight(toDisplayWeight(best.weight, unit));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text('$index',
                textAlign: TextAlign.center,
                style: kMono.copyWith(fontSize: 13, color: AppColors.faint)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    children: [
                      TextSpan(text: '${sets.length} sets'),
                      // Only ever shown when there is something to say — a
                      // clean session should not carry a "0 missed" badge.
                      if (missed > 0)
                        TextSpan(
                          text: ' · $missed missed',
                          style: const TextStyle(color: AppColors.gold),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Text.rich(
            TextSpan(
              style: kMono.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
              children: timed
                  ? [
                      TextSpan(text: '${best.seconds ?? 0}s'),
                      if (best.weight != 0)
                        TextSpan(
                            text: ' @ $w',
                            style: const TextStyle(color: AppColors.faint)),
                    ]
                  : [
                      TextSpan(text: w),
                      TextSpan(
                          text: ' ×${best.reps}',
                          style: const TextStyle(color: AppColors.faint)),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}
