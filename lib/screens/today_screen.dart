import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../util/seed_names.dart';
import '../util/units.dart';
import '../widgets/common.dart';
import '../widgets/routine_card.dart';
import '../widgets/storage_warning.dart';
import '../widgets/tutorial.dart';
import '../widgets/workout_estimate.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final current = ref.watch(currentRoutineProvider);
    final eyebrow =
        '${DateFormat.EEEE(l10n.localeName).format(now)} · '
        '${DateFormat.MMMd(l10n.localeName).format(now)}';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ScreenHeader(eyebrow: eyebrow, title: l10n.todayTitle),
          const StorageWarning(),
          if (current != null)
            _CurrentRoutineSection(current: current)
          else
            const _RoutineChooserSection(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionLabel(l10n.todayLifetime),
          ),
          Padding(
            key: tutorialLifetimeKey,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const _LifetimeCard(),
          ),
        ],
      ),
    );
  }
}

const ValueKey<String> kTodayShowAllWorkoutsKey =
    ValueKey('today-show-all-workouts');

const int kTodayWorkoutsShownWhole = 7;

const int kTodayWorkoutsBefore = 1;
const int kTodayWorkoutsAfter = 2;

class _CurrentRoutineSection extends ConsumerStatefulWidget {
  const _CurrentRoutineSection({required this.current});
  final RoutineWithCount current;

  @override
  ConsumerState<_CurrentRoutineSection> createState() =>
      _CurrentRoutineSectionState();
}

class _CurrentRoutineSectionState
    extends ConsumerState<_CurrentRoutineSection> {
  bool _showAll = false;

  bool _isFolded(List<WorkoutWithCount> list) =>
      !_showAll && list.length > kTodayWorkoutsShownWhole;

  List<WorkoutWithCount> _shown(List<WorkoutWithCount> list, int? nextId) {
    if (!_isFolded(list)) return list;
    var at = list.indexWhere((w) => w.workout.id == nextId);
    if (at < 0) at = 0;
    final from = (at - kTodayWorkoutsBefore).clamp(0, list.length);
    final to = (at + kTodayWorkoutsAfter + 1).clamp(from, list.length);
    return list.sublist(from, to);
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    final l10n = AppLocalizations.of(context);
    final routine = current.routine;
    final routineName = seededName(l10n, routine.seedKey, routine.name);
    final workouts = ref.watch(routineWorkoutsProvider(routine.id));
    final nextId = ref.watch(nextWorkoutIdProvider(routine.id));

    return Column(
      children: [
        Padding(
          key: tutorialTodayRoutineKey,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionLabel(
            routineName,
            trailing: _TextLink(
              label: l10n.todayChange,
              onTap: () => context.push('/routines'),
            ),
          ),
        ),
        workouts.when(
          loading: () => const _PadLoader(),
          error: (e, _) => _PadError('$e'),
          data: (list) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                if (list.isEmpty)
                  _EmptyCard(
                    title: l10n.todayNoWorkoutsTitle,
                    body: l10n.todayNoWorkoutsBody(routineName),
                    action: l10n.todayEditRoutine,
                    onAction: () => context.push('/routine/${routine.id}/edit'),
                  )
                else ...[
                  for (final w in _shown(list, nextId)) ...[
                    _WorkoutCard(
                      data: w,
                      accent: hexColor(routine.colorHex),
                      isNext: w.workout.id == nextId,
                      onTap: () => context.push(
                          linkPath(context, '/workout/${w.workout.id}')),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_isFolded(list))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _TextLink(
                        key: kTodayShowAllWorkoutsKey,
                        label: l10n.todayShowAllWorkouts(list.length),
                        onTap: () => setState(() => _showAll = true),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutineChooserSection extends ConsumerWidget {
  const _RoutineChooserSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final routines = ref.watch(routinesProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionLabel(l10n.todayPickRoutine),
        ),
        routines.when(
          loading: () => const _PadLoader(),
          error: (e, _) => _PadError('$e'),
          data: (list) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                if (list.isEmpty)
                  KeyedSubtree(
                    key: tutorialTodayEmptyKey,
                    child: _EmptyCard(
                      title: l10n.todayNoRoutinesTitle,
                      body: l10n.todayNoRoutinesBody,
                      action: l10n.routineLibraryTitle,
                      onAction: () => context.push('/routines/library'),
                      secondAction: l10n.todayBuildRoutine,
                      onSecondAction: () => context.push('/routine/new'),
                    ),
                  )
                else
                  for (final r in list) ...[
                    RoutineCard(
                      data: r,
                      onSetCurrent: () => ref
                          .read(databaseProvider)
                          .setActiveRoutineId(r.routine.id),
                      onTap: () => context.push(
                          linkPath(context, '/routine/${r.routine.id}')),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.data,
    required this.accent,
    required this.onTap,
    this.isNext = false,
  });
  final WorkoutWithCount data;
  final Color accent;
  final VoidCallback onTap;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sub = kMono.copyWith(fontSize: 12.5, color: AppColors.muted);
    return Material(
      color: isNext ? AppColors.surface2 : AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isNext ? accent : AppColors.line,
              width: isNext ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 40,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            seededName(
                                l10n, data.workout.seedKey, data.workout.name),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (isNext) ...[
                          const SizedBox(width: 8),
                          NextBadge(color: accent),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      children: [
                        Text(l10n.commonExerciseCount(data.exerciseCount),
                            style: sub),
                        WorkoutEstimate(
                          workoutId: data.workout.id,
                          builder: (_, label) => Text('· $label', style: sub),
                        ),
                      ],
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

class _TextLink extends StatelessWidget {
  const _TextLink({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(label,
            style: kMono.copyWith(
                fontSize: 12,
                color: AppColors.accent,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
    this.secondAction,
    this.onSecondAction,
  });
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  final String? secondAction;
  final VoidCallback? onSecondAction;

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
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(body,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: Text(action, textAlign: TextAlign.center),
          ),
          if (secondAction case final second?) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: onSecondAction,
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              child: Text(second),
            ),
          ],
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
    final totals =
        ref.watch(lifetimeTotalsProvider).value ?? const LifetimeTotals();
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _MiniStat(
                      label: l10n.commonStatWorkouts, value: '$workouts')),
              Expanded(
                child: _MiniStat(
                  label: l10n.todayStatVolume(unitSuffix(l10n, unit)),
                  value: fmtTotal(toDisplayWeight(totals.volumeKg, unit)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                  child: _MiniStat(
                      label: l10n.todayStatSets,
                      value: fmtTotal(totals.sets))),
              Expanded(
                  child: _MiniStat(
                      label: l10n.todayStatReps,
                      value: fmtTotal(totals.reps))),
            ],
          ),
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
  Widget build(BuildContext context) => Padding(
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
        child: Text(message, style: TextStyle(color: AppColors.muted)),
      );
}
