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
    // Skeleton constructors rather than a pattern: the language decides both
    // the words and the order the day and date come out in.
    final eyebrow =
        '${DateFormat.EEEE(l10n.localeName).format(now)} · '
        '${DateFormat.MMMd(l10n.localeName).format(now)}';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ScreenHeader(eyebrow: eyebrow, title: l10n.todayTitle),
          // Above everything a session could be started from, because that is
          // the point of it: a browser that cannot keep the log has to say so
          // before somebody trains into it. Nothing off the web.
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
            // Anchor for the tour's "lifetime totals" coach mark.
            key: tutorialLifetimeKey,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const _LifetimeCard(),
          ),
        ],
      ),
    );
  }
}

/// Finds the line that opens the rest of a long routine's workouts.
const ValueKey<String> kTodayShowAllWorkoutsKey =
    ValueKey('today-show-all-workouts');

/// How many training days a routine may hold before Today folds it.
///
/// A week's worth. A split has three or four days and listing them is the whole
/// screen; past seven, the routine is a program written out session by session
/// rather than a week to pick from, and listing it buries everything under it.
const int kTodayWorkoutsShownWhole = 7;

/// How many of the folded routine's days are shown around the one you are on:
/// the one before it, and the two after.
///
/// Asymmetric on purpose. What is behind you is context — one day of it is
/// enough to see where you are — and what is ahead is the thing you might
/// actually want to look at next.
const int kTodayWorkoutsBefore = 1;
const int kTodayWorkoutsAfter = 2;

/// The workouts of the current routine — pick one and you are one tap from
/// starting it.
class _CurrentRoutineSection extends ConsumerStatefulWidget {
  const _CurrentRoutineSection({required this.current});
  final RoutineWithCount current;

  @override
  ConsumerState<_CurrentRoutineSection> createState() =>
      _CurrentRoutineSectionState();
}

class _CurrentRoutineSectionState
    extends ConsumerState<_CurrentRoutineSection> {
  /// Whether the fold has been opened. Held here rather than stored: it is a
  /// look at the rest of the program, not a preference about it, and coming
  /// back to Today should come back to the session you are on.
  bool _showAll = false;

  /// Whether this routine is long enough to fold, and still folded.
  bool _isFolded(List<WorkoutWithCount> list) =>
      !_showAll && list.length > kTodayWorkoutsShownWhole;

  /// The days to draw: all of them, or a window around the one you are on.
  ///
  /// The window is measured from the session you are on and shrinks at the ends
  /// rather than sliding to keep its width. On the first session of a program
  /// there is nothing behind you, and filling the gap with a fourth day ahead
  /// would put the day you are on at the top of a list that is not a window on
  /// anything.
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
          // Anchor for the tour's "the routine you are on" coach mark.
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
                          '${branchRoot(context)}/workout/${w.workout.id}'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Only while something is folded. Opened, this is the plain
                  // list it always was, and a link that undoes nothing is a
                  // control with no state to be in.
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

/// Shown when no routine is current: pick one (or build the first).
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
                  // The first screen of a fresh install: the routine list is
                  // empty until somebody puts something in it, so this is where
                  // both ways to do that are offered. The ready-made one leads,
                  // because it is the one that has you training today.
                  //
                  // It is also the tour's Today anchor, for the same reason:
                  // there is no routine and no workout card on a first run, and
                  // this is the card that changes that.
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
                          '${branchRoot(context)}/routine/${r.routine.id}'),
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

/// One training day on the Today screen. The suggested next day is outlined in
/// the routine's accent and badged; the others stay plain but tappable.
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
                    // A Wrap, not a Row: at 2× text the count and the estimate
                    // no longer share a line, and they take a second one rather
                    // than overflowing the card.
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

/// A small text action in a section header.
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

/// A centred "nothing here yet" card with a single call to action.
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

  /// A second way out of the same empty state, offered plainly beneath the
  /// first. The install with no routines at all has two — take a program the app
  /// ships, or write your own — and naming only one of them would hide the other
  /// on the one screen where the question is being asked.
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
          // Full width, not shrink-wrapped to the label. This is the one thing
          // to do on a fresh install — nothing else on Today is reachable
          // until a routine exists — and a small pill adrift in the middle of
          // a card reads as a link in a caption rather than as the way on.
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
