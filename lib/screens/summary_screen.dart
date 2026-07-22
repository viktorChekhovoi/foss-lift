import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../state/active_workout.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../widgets/common.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key, required this.sessionId});
  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(sessionSummaryProvider(sessionId));
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';

    return Scaffold(
      body: SafeArea(
        child: data.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          error: (e, _) =>
              Center(child: Text('$e', style: const TextStyle(color: AppColors.muted))),
          data: (d) => _SummaryBody(session: d.session, sets: d.sets, unit: unit),
        ),
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.session, required this.sets, required this.unit});
  final Session session;
  final List<SessionSet> sets;
  final String unit;

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
    // Best set = highest weight × reps.
    SessionSet best = sets.first;
    for (final s in sets) {
      if (s.weight * s.reps > best.weight * best.reps) best = s;
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
              children: [
                TextSpan(text: w),
                TextSpan(text: ' ×${best.reps}', style: const TextStyle(color: AppColors.faint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
