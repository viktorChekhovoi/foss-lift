import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme/app_theme.dart';
import '../util/seed_names.dart';
import '../widgets/common.dart';
import 'training_max_screen.dart';

/// A routine's training days. You start a workout from here, never the routine
/// itself — a routine is a container, not a session.
class RoutineDetailScreen extends ConsumerWidget {
  const RoutineDetailScreen({super.key, required this.routineId});
  final int routineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final routines = ref.watch(routinesProvider).value;
    final workouts = ref.watch(routineWorkoutsProvider(routineId));
    final isCurrent = ref.watch(currentRoutineProvider)?.routine.id == routineId;
    // Only where there is one to set. A routine of flat sets has no training
    // max, and an action that opens onto nothing is worse than a missing one.
    final hasTrainingMaxes =
        (ref.watch(trainingMaxGroupsProvider(routineId)).value ?? const [])
            .isNotEmpty;
    final nextId = ref.watch(nextWorkoutIdProvider(routineId));

    Routine? routine;
    if (routines != null) {
      for (final r in routines) {
        if (r.routine.id == routineId) {
          routine = r.routine;
          break;
        }
      }
    }

    final description =
        seededDescription(l10n, routine?.seedKey, routine?.description);

    return Scaffold(
      appBar: AppBar(
        title: Text(routine == null
            ? l10n.routineDetailTitle
            : seededName(l10n, routine.seedKey, routine.name)),
        actions: [
          IconButton(
            tooltip: isCurrent
                ? l10n.routineDetailShownOnToday
                : l10n.routineDetailShowOnToday,
            icon: Icon(isCurrent
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked),
            color: isCurrent ? AppColors.accent : null,
            onPressed: isCurrent
                ? null
                : () => ref
                    .read(databaseProvider)
                    .setActiveRoutineId(routineId),
          ),
          if (hasTrainingMaxes)
            IconButton(
              key: trainingMaxButtonKey,
              tooltip: l10n.trainingMaxOpen,
              icon: const Icon(Icons.percent),
              onPressed: () =>
                  context.push('/routine/$routineId/training-maxes'),
            ),
          IconButton(
            tooltip: l10n.routineDetailShare,
            icon: const Icon(Icons.ios_share),
            onPressed: () => context.push('/routine/$routineId/share'),
          ),
          IconButton(
            tooltip: l10n.commonEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/routine/$routineId/edit'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: workouts.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (e, _) => Center(
            child: Text('$e', style: TextStyle(color: AppColors.muted)),
          ),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              // What the program is, where a routine has been described — the
              // shipped paragraph in the app's language, or the one you typed.
              // Nothing at all where nobody has said anything.
              if (description != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 14, top: 2),
                  child: Text(
                    description,
                    style: TextStyle(
                        fontSize: 14, height: 1.4, color: AppColors.muted),
                  ),
                ),
              ],
              _CountChip(count: list.length),
              const SizedBox(height: 14),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    l10n.routineDetailEmpty,
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
                      isNext: list[i].workout.id == nextId,
                      onTap: () => context.push(
                          linkPath(context, '/workout/${list[i].workout.id}')),
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
                style: TextStyle(
                    color: AppColors.text, fontWeight: FontWeight.w600),
              ),
              TextSpan(
                  text: ' ${AppLocalizations.of(context)
                      .routineDetailWorkoutCount(count)}'),
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
    this.isNext = false,
  });
  final int index;
  final WorkoutWithCount data;
  final String? accent;
  final VoidCallback onTap;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accentColor = hexColor(accent ?? 'FF6A3D');
    return Material(
      color: isNext ? AppColors.surface2 : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isNext ? accentColor : AppColors.line,
              width: isNext ? 1.5 : 1,
            ),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                              seededName(l10n, data.workout.seedKey,
                                  data.workout.name),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                        if (isNext) ...[
                          const SizedBox(width: 8),
                          NextBadge(color: accentColor),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.commonExerciseCount(data.exerciseCount),
                      style: kMono.copyWith(
                          fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}
