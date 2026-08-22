import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../state/active_workout.dart';
import '../theme/app_theme.dart';
import '../util/cardio_units.dart';
import '../util/clip_label.dart';
import '../util/seed_names.dart';
import '../util/units.dart';
import '../widgets/common.dart';
import '../util/format.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({
    super.key,
    required this.sessionId,
    this.fromHistory = false,
  });
  final int sessionId;

  final bool fromHistory;

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  List<ProgressionOutcome> _progression = const [];

  @override
  void initState() {
    super.initState();
    if (widget.fromHistory) return;
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
              Center(child: CircularProgressIndicator(color: AppColors.accent)),
          error: (e, _) => Center(
            child: Text('$e', style: TextStyle(color: AppColors.muted)),
          ),
          data: (d) => _SummaryBody(
            session: d.session,
            sets: d.sets,
            unit: unit,
            units: ref.watch(exerciseUnitsProvider),
            progression: _progression,
            fromHistory: widget.fromHistory,
          ),
        ),
      ),
    );
  }
}

String _sessionStamp(DateTime at, String locale) =>
    '${DateFormat.MMMEd(locale).format(at)} · ${DateFormat.Hm(locale).format(at)}';

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.session,
    required this.sets,
    required this.unit,
    required this.units,
    required this.progression,
    required this.fromHistory,
  });
  final Session session;
  final List<SessionSet> sets;

  final String unit;

  final Map<int, String> units;
  final List<ProgressionOutcome> progression;
  final bool fromHistory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
              if (fromHistory)
                _HistoryHeader(session: session)
              else ...[
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.good, Color(0xFF2FAE7D)],
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 40,
                      color: Color(0xFF062015),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    l10n.summaryTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    seededName(l10n, session.seedKey, session.name),
                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    _sessionStamp(session.startedAt, l10n.localeName),
                    style: kMono.copyWith(fontSize: 12, color: AppColors.faint),
                  ),
                ),
                const SizedBox(height: 22),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _SumCell(
                        value: fmtTotal((session.durationSeconds / 60).round()),
                        unit: l10n.summaryMinutesUnit,
                        label: l10n.summaryDuration,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SumCell(
                          value: fmtTotal(session.setsCompleted),
                        label: l10n.summarySetsDone,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SumCell(
                          value: fmtTotal(grouped.length),
                        label: l10n.summaryExercises,
                      ),
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
                      SectionLabel(l10n.summaryProgressionHeading),
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
                    SectionLabel(l10n.summarySessionHeading),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.line),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          for (final entry
                              in grouped.entries.toList().asMap().entries)
                            _SessionExerciseRow(
                              index: entry.key + 1,
                              sets: entry.value.value,
                              unit: unitForExercise(
                                unit,
                                units[entry.value.value.first.exerciseId],
                              ),
                              date: session.startedAt,
                              last: entry.key == grouped.length - 1,
                            ),
                          if (grouped.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: Text(
                                l10n.summaryNoSets,
                                style: TextStyle(color: AppColors.muted),
                              ),
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
              onPressed: () =>
                  fromHistory ? context.pop() : context.go('/today'),
              child: Text(fromHistory ? l10n.commonBack : l10n.commonDone),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/history'),
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.commonBack,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seededName(l10n, session.seedKey, session.name),
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _sessionStamp(session.startedAt, l10n.localeName),
                    style: kMono.copyWith(fontSize: 12, color: AppColors.faint),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
              style: kMono.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
              children: [
                TextSpan(text: value),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: kMono.copyWith(
              fontSize: 11,
              letterSpacing: 0.9,
              color: AppColors.faint,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressionRow extends StatelessWidget {
  const _ProgressionRow({required this.outcome, required this.last});
  final ProgressionOutcome outcome;
  final bool last;

  String get unit => outcome.unit;

  String _target(AppLocalizations l10n) {
    switch (outcome.mode) {
      case ProgressionMode.weight:
        if (outcome.target == 0) return l10n.summaryTargetBodyweight;
        return l10n.unitWeightShort(
          fmtWeight(toDisplayWeight(outcome.target, unit)),
          unitSuffix(l10n, unit),
        );
      case ProgressionMode.reps:
        return l10n.summaryTargetReps(outcome.target.round());
      case ProgressionMode.time:
        return l10n.unitSecondsShort('${outcome.target.round()}');
    }
  }

  String _delta(AppLocalizations l10n) {
    final mag = outcome.moved.abs();
    final up = outcome.moved > 0;
    return switch (outcome.mode) {
      ProgressionMode.weight =>
        up
          ? l10n.summaryStepWeight(
                fmtWeight(toDisplayWeight(mag, unit)),
                unitSuffix(l10n, unit),
              )
          : l10n.summaryBackOffWeight(
                fmtWeight(toDisplayWeight(mag, unit)),
                unitSuffix(l10n, unit),
              ),
      ProgressionMode.reps =>
        up
          ? l10n.summaryStepReps(mag.round())
          : l10n.summaryBackOffReps(mag.round()),
      ProgressionMode.time =>
        up
          ? l10n.summaryStepTime('${mag.round()}')
          : l10n.summaryBackOffTime('${mag.round()}'),
    };
  }

  String? _heldNote(AppLocalizations l10n) {
    if (outcome.failures > 0) {
      final n = outcome.failureThreshold - outcome.failures;
      if (n > 0) return l10n.summaryHeldMisses(n);
    } else if (outcome.successes > 0) {
      final n = outcome.successThreshold - outcome.successes;
      if (n > 0) return l10n.summaryHeldCleanSessions(n);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (IconData icon, Color tone) = outcome.steppedUp
        ? (Icons.arrow_upward_rounded, AppColors.good)
        : outcome.backedOff
            ? (Icons.arrow_downward_rounded, AppColors.gold)
            : (Icons.remove_rounded, AppColors.muted);
    final sub = outcome.held ? _heldNote(l10n) : _delta(l10n);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seededName(l10n, outcome.seedKey, outcome.name),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
          Text(
            _target(l10n),
            style: kMono.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionExerciseRow extends StatelessWidget {
  const _SessionExerciseRow({
    required this.index,
    required this.sets,
    required this.unit,
    required this.date,
    required this.last,
  });
  final int index;

  final List<SessionSet> sets;
  final String unit;

  final DateTime date;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timed = sets.any((s) => s.goalSeconds != null || s.seconds != null);
    SessionSet best = sets.first;
    for (final s in sets) {
      final better = timed
          ? (s.seconds ?? 0) > (best.seconds ?? 0)
          : s.weight * s.reps > best.weight * best.reps;
      if (better) best = s;
    }
    final missed = sets.where(setMissedGoal).length;
    final filmed = sets.where((s) => s.videoPath != null).length;
    final w = best.weight == 0
        ? l10n.summaryBodyweightShort
        : fmtWeight(toDisplayWeight(best.weight, unit));

    final filmedSets = sets.where((s) => s.videoPath != null).toList();
    return GestureDetector(
      onTap: filmedSets.isEmpty ? null : () => _openClips(context, filmedSets),
      behavior: HitTestBehavior.opaque,
      child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
              child: Text(
                '$index',
                textAlign: TextAlign.center,
                style: kMono.copyWith(fontSize: 13, color: AppColors.faint),
              ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    seededName(
                      l10n,
                      sets.first.exerciseSeedKey,
                      sets.first.exerciseName,
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                    children: [
                      TextSpan(text: l10n.commonSetCount(sets.length)),
                      if (missed > 0)
                        TextSpan(
                          text: ' · ${l10n.summaryMissedCount(missed)}',
                          style: TextStyle(color: AppColors.gold),
                        ),
                      if (filmed > 0)
                        TextSpan(
                          text: ' · ${l10n.summaryFilmedCount(filmed)}',
                          style: TextStyle(color: AppColors.accent),
                        ),
                    ],
                  ),
                ),
                if (cardioSummary(l10n, best.console, unit: unit)
                    case final readouts?) ...[
                  const SizedBox(height: 2),
                  Text(
                    readouts,
                      style: kMono.copyWith(
                        fontSize: 11,
                        color: AppColors.faint,
                      ),
                  ),
                ],
              ],
            ),
          ),
            Text(
              timed
                  ? '${l10n.unitSecondsShort('${best.seconds ?? 0}')}'
                        '${best.weight == 0 ? '' : ' @ $w'}'
                  : '$w × ${best.reps}'
                        '${best.actualRpe == null ? '' : ' @${formatRpe(best.actualRpe!)}'}',
              style: kMono.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (filmedSets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 10),
                child: Icon(
                  Icons.play_circle_outline,
                  size: 20,
                  color: AppColors.accent,
                ),
            ),
        ],
      ),
      ),
    );
  }

  Future<void> _openClips(BuildContext context, List<SessionSet> filmed) async {
    final l10n = AppLocalizations.of(context);
    SessionSet? chosen = filmed.first;
    if (filmed.length > 1) {
      chosen = await showModalBottomSheet<SessionSet>(
        context: context,
        backgroundColor: AppColors.surface,
        builder: (sheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in filmed)
                ListTile(
                  leading: Icon(
                    Icons.play_circle_outline,
                    color: AppColors.accent,
                  ),
                  title: Text(_labelFor(l10n, s)),
                  onTap: () => Navigator.pop(sheet, s),
                ),
            ],
          ),
        ),
      );
    }
    if (chosen == null || !context.mounted) return;
    context.push(
      Uri(
        path: '/clip',
        queryParameters: {
          'path': chosen.videoPath!,
          'caption': _labelFor(l10n, chosen),
          'set': '${chosen.id}',
        },
      ).toString(),
    );
  }

  String _labelFor(AppLocalizations l10n, SessionSet s) => clipLabelOf(
        l10n,
        date: date,
        setNumber: s.setNumber,
        weightKg: s.weight,
        reps: s.reps,
        seconds: s.seconds,
        unit: unit,
      );
}
