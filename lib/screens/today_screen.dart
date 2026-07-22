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
          ScreenHeader(eyebrow: eyebrow, title: 'Today'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionLabel(
              'Start a routine',
              trailing: _BuildLink(onTap: () => context.push('/routine/new')),
            ),
          ),
          routines.when(
            loading: () => const _PadLoader(),
            error: (e, _) => _PadError('$e'),
            data: (list) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if (list.isEmpty)
                    _NoRoutines(onCreate: () => context.push('/routine/new'))
                  else
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

/// A small "+ Build" affordance in the section header.
class _BuildLink extends StatelessWidget {
  const _BuildLink({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text('+ Build',
            style: kMono.copyWith(
                fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _NoRoutines extends StatelessWidget {
  const _NoRoutines({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Column(
        children: [
          const Text('No routines yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Build one from the exercise library to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          FilledButton(onPressed: onCreate, child: const Text('Build a routine')),
        ],
      ),
    );
  }
}

class _LifetimeCard extends ConsumerWidget {
  const _LifetimeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(sessionCountProvider).value ?? 0;
    final routines = ref.watch(routinesProvider).value?.length ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        children: [
          Expanded(child: _MiniStat(label: 'Workouts', value: '$workouts')),
          Expanded(child: _MiniStat(label: 'Routines', value: '$routines')),
        ],
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
