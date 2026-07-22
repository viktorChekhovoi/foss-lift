import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

/// A routine's training days. You start a workout from here, never the routine
/// itself — a routine is a container, not a session.
class RoutineDetailScreen extends ConsumerWidget {
  const RoutineDetailScreen({super.key, required this.routineId});
  final int routineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routinesProvider).value;
    final workouts = ref.watch(routineWorkoutsProvider(routineId));

    Routine? routine;
    if (routines != null) {
      for (final r in routines) {
        if (r.routine.id == routineId) {
          routine = r.routine;
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(routine?.name ?? 'Routine'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/routine/$routineId/edit'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: workouts.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (e, _) => Center(
            child: Text('$e', style: const TextStyle(color: AppColors.muted)),
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
                    'This routine has no workouts yet. Tap the edit icon to add '
                    'training days like Push, Pull and Legs.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else
                for (var i = 0; i < list.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WorkoutRow(
                      index: i + 1,
                      data: list[i],
                      accent: routine?.colorHex,
                      onTap: () => context.push('/workout/${list[i].workout.id}'),
                    ),
                  ),
            ],
          ),
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
              TextSpan(text: count == 1 ? ' workout' : ' workouts'),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({
    required this.index,
    required this.data,
    required this.accent,
    required this.onTap,
  });
  final int index;
  final WorkoutWithCount data;
  final String? accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text('$index',
                    textAlign: TextAlign.center,
                    style:
                        kMono.copyWith(fontSize: 13, color: AppColors.faint)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.workout.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      '${data.exerciseCount} '
                      '${data.exerciseCount == 1 ? 'exercise' : 'exercises'}',
                      style: kMono.copyWith(
                          fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}
