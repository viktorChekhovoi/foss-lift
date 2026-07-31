import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/seed_names.dart';
import '../widgets/plate_line.dart';
import '../widgets/start_workout.dart';

/// One training day: the exercises it contains, and the button that starts it.
class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});
  final int workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workout = ref.watch(workoutProvider(workoutId)).value;
    final items = ref.watch(workoutItemsProvider(workoutId));
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final plates = ref.watch(plateSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(workout == null
            ? l10n.workoutDetailTitle
            : seededName(l10n, workout.seedKey, workout.name)),
        actions: [
          IconButton(
            tooltip: l10n.commonEdit,
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
                loading: () => Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (e, _) => Center(
                  child:
                      Text('$e', style: TextStyle(color: AppColors.muted)),
                ),
                data: (list) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    _CountChip(count: list.length),
                    const SizedBox(height: 14),
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          l10n.workoutDetailEmpty,
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
                                unit: unit,
                                plates: plates,
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
              enabled: workout != null && (items.value ?? const []).isNotEmpty,
              // The *stored* name, not the one in the app bar: it is written to
              // history as the session's name, and history holds English plus a
              // key so a logged session follows the language like everything
              // else. The key rides along so the dialogs on the way in can
              // still say the day's name in the language on screen.
              onStart: () => startWorkout(context, ref, workoutId,
                  workout!.name, seedKey: workout.seedKey),
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
                style: TextStyle(
                    color: AppColors.text, fontWeight: FontWeight.w600),
              ),
              TextSpan(
                  text: ' ${AppLocalizations.of(context)
                      .workoutDetailExerciseCount(count)}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.index,
    required this.view,
    required this.unit,
    required this.plates,
    required this.last,
  });
  final int index;
  final WorkoutItemView view;
  final String unit;
  final PlateSettings plates;
  final bool last;

  /// "31.25/side" beside the muscle group, so a barbell day can be read as the
  /// bars it will be. The full breakdown waits for the session — this screen is
  /// a glance at the day, not a loading chart.
  String? _perSide(AppLocalizations l10n) {
    final w = view.item.suggestedWeight;
    if (w == null || w <= 0) return null;
    return perSideLabel(
      l10n: l10n,
      weightKg: w,
      type: view.exercise.weightType,
      settings: plates,
      unit: unit,
      barKg: view.exercise.barWeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final perSide = _perSide(l10n);
    final muscle = muscleGroupLabel(l10n, view.exercise.muscleGroup);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: AppColors.line)),
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
                Text(
                    seededName(
                        l10n, view.exercise.seedKey, view.exercise.name),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  perSide == null ? muscle : '$muscle · $perSide',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
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
          label: Text(AppLocalizations.of(context).workoutDetailStart),
        ),
      ),
    );
  }
}
