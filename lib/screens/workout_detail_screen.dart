import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

/// One training day: the exercises it contains, and the button that starts it.
class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});
  final int workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(workoutProvider(workoutId)).value;
    final items = ref.watch(workoutItemsProvider(workoutId));

    return Scaffold(
      appBar: AppBar(
        title: Text(workout?.name ?? 'Workout'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/workout/$workoutId/edit'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: items.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (e, _) => Center(
                  child:
                      Text('$e', style: const TextStyle(color: AppColors.muted)),
                ),
                data: (list) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    _CountChip(count: list.length),
                    const SizedBox(height: 14),
                    if (list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No exercises yet. Tap the edit icon to add some.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.line),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            for (var i = 0; i < list.length; i++)
                              _ExerciseRow(
                                index: i + 1,
                                view: list[i],
                                last: i == list.length - 1,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _StartBar(
              enabled: (items.value ?? const []).isNotEmpty,
              onStart: () async {
                await ref.read(activeWorkoutProvider.notifier).start(
                      workoutId: workoutId,
                      name: workout?.name ?? 'Workout',
                    );
                if (context.mounted) context.push('/session');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.line),
        ),
        child: Text.rich(
          TextSpan(
            style: kMono.copyWith(fontSize: 12, color: AppColors.muted),
            children: [
              TextSpan(
                text: '$count',
                style: const TextStyle(
                    color: AppColors.text, fontWeight: FontWeight.w600),
              ),
              TextSpan(text: count == 1 ? ' exercise' : ' exercises'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow(
      {required this.index, required this.view, required this.last});
  final int index;
  final WorkoutItemView view;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border:
            last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
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
                Text(view.exercise.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(view.exercise.muscleGroup,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          Text(
            '${view.item.targetSets} × ${repsLabel(view.item)}',
            style: kMono.copyWith(
              fontSize: 13,
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartBar extends StatelessWidget {
  const _StartBar({required this.onStart, required this.enabled});
  final VoidCallback onStart;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: enabled ? onStart : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start workout'),
        ),
      ),
    );
  }
}
