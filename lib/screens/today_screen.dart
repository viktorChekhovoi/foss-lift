import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/routine_card.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final routines = ref.watch(routinesProvider);
    final eyebrow =
        '${DateFormat('EEEE').format(now)} · ${DateFormat('MMM d').format(now)}';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ScreenHeader(eyebrow: eyebrow, title: 'Ready to train?'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _StartEmptyCard(
              onTap: () async {
                await ref
                    .read(activeWorkoutProvider.notifier)
                    .start(name: 'Quick workout');
                if (context.mounted) context.push('/workout');
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SectionLabel('Your routines'),
          ),
          routines.when(
            loading: () => const _PadLoader(),
            error: (e, _) => _PadError('$e'),
            data: (list) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (final r in list) ...[
                    RoutineCard(
                      data: r,
                      onTap: () => context.push('/routine/${r.routine.id}'),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SectionLabel('Lifetime'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _LifetimeCard(),
          ),
        ],
      ),
    );
  }
}

class _StartEmptyCard extends StatelessWidget {
  const _StartEmptyCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
            gradient: LinearGradient(
              colors: [
                AppColors.accent.withValues(alpha: 0.20),
                AppColors.accent.withValues(alpha: 0.05),
              ],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.add, color: Color(0xFF20130C), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Start empty workout',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Begin now, add exercises as you go',
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LifetimeCard extends ConsumerWidget {
  const _LifetimeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(totalsProvider);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: totals.when(
        loading: () => const SizedBox(height: 42),
        error: (e, _) => Text('$e', style: const TextStyle(color: AppColors.muted)),
        data: (t) => Row(
          children: [
            Expanded(child: _MiniStat(label: 'Workouts', value: '${t.workouts}')),
            Expanded(
              child: _MiniStat(
                label: 'Volume · kg',
                value: NumberFormat.decimalPattern().format(t.volume.round()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: kMono.copyWith(fontSize: 11, letterSpacing: 0.8, color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: kMono.copyWith(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
      ],
    );
  }
}

class _PadLoader extends StatelessWidget {
  const _PadLoader();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
}

class _PadError extends StatelessWidget {
  const _PadError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(message, style: const TextStyle(color: AppColors.muted)),
      );
}
