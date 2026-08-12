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

  /// True when opened from the History tab to read a past session, rather than
  /// at the end of a just-finished one. Swaps the celebration header for a plain
  /// back-and-title bar and never shows the progression banner.
  final bool fromHistory;

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  List<ProgressionOutcome> _progression = const [];

  @override
  void initState() {
    super.initState();
    // The progression banner belongs to the session that was just finished, not
    // to a past one browsed from History. Grab its report if this is that
    // screen, and clear the stash so reaching the same summary later finds
    // nothing and shows nothing.
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
          error: (e, _) =>
              Center(child: Text('$e', style: TextStyle(color: AppColors.muted))),
          data: (d) => _SummaryBody(
            session: d.session,
            sets: d.sets,
            unit: unit,
            progression: _progression,
            fromHistory: widget.fromHistory,
          ),
        ),
      ),
    );
  }
}

/// When a session ran, ordered by the language rather than by a hand-written
/// pattern: `EEE d MMM` is an English ordering, and the skeleton constructors
/// let the locale put the parts where it wants them. The `·` between date and
/// clock is punctuation this app owns, so it stays.
String _sessionStamp(DateTime at, String locale) =>
    '${DateFormat.MMMEd(locale).format(at)} · ${DateFormat.Hm(locale).format(at)}';

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.session,
    required this.sets,
    required this.unit,
    required this.progression,
    required this.fromHistory,
  });
  final Session session;
  final List<SessionSet> sets;
  final String unit;
  final List<ProgressionOutcome> progression;
  final bool fromHistory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Group sets by exercise, preserving first-seen order. Keyed by the stored
    // English name, not the translated one: the key is an identity, and two
    // movements that share a translation are still two movements.
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
                    child: const Icon(Icons.check_rounded, size: 40, color: Color(0xFF062015)),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(l10n.summaryTitle,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(seededName(l10n, session.seedKey, session.name),
                      style: TextStyle(color: AppColors.muted, fontSize: 14)),
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
                          label: l10n.summarySetsDone),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SumCell(
                          value: fmtTotal(grouped.length),
                          label: l10n.summaryExercises),
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
                                unit: unit,
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
                          for (final entry in grouped.entries.toList().asMap().entries)
                            _SessionExerciseRow(
                              index: entry.key + 1,
                              sets: entry.value.value,
                              unit: unit,
                              date: session.startedAt,
                              last: entry.key == grouped.length - 1,
                            ),
                          if (grouped.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: Text(l10n.summaryNoSets,
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
              // From History, step back to the list; at the end of a session,
              // there is nothing behind this screen so head home to Today.
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

/// The plain header a session gets when opened from History: a back button and
/// the session's name and date, in place of the just-finished celebration.
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
                  Text(seededName(l10n, session.seedKey, session.name),
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5)),
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
              style: kMono.copyWith(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3),
              children: [
                TextSpan(text: value),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
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

/// One line of the "what progression did" banner: the exercise, where its
/// target now sits, and — coloured green up / gold down / muted for a hold —
/// the change that got it there or how close a held one is to the next move.
class _ProgressionRow extends StatelessWidget {
  const _ProgressionRow({
    required this.outcome,
    required this.unit,
    required this.last,
  });
  final ProgressionOutcome outcome;
  final String unit;
  final bool last;

  /// Where the slot now points — the load, reps, or hold the next session opens
  /// at. A weight target driven to zero is the bodyweight movement it always
  /// was, not "0 kg".
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

  /// The change in the mode's own unit, converted for display. Deltas are
  /// linear across units, so a kg step reads correctly once scaled to lb.
  ///
  /// Six whole messages rather than a sign glued to an amount: a step up and a
  /// back-off are different sentences in a language that inflects, and the
  /// rep counts need plural forms English does not have.
  String _delta(AppLocalizations l10n) {
    final mag = outcome.moved.abs();
    final up = outcome.moved > 0;
    return switch (outcome.mode) {
      ProgressionMode.weight => up
          ? l10n.summaryStepWeight(
              fmtWeight(toDisplayWeight(mag, unit)), unitSuffix(l10n, unit))
          : l10n.summaryBackOffWeight(
              fmtWeight(toDisplayWeight(mag, unit)), unitSuffix(l10n, unit)),
      ProgressionMode.reps => up
          ? l10n.summaryStepReps(mag.round())
          : l10n.summaryBackOffReps(mag.round()),
      ProgressionMode.time => up
          ? l10n.summaryStepTime('${mag.round()}')
          : l10n.summaryBackOffTime('${mag.round()}'),
    };
  }

  /// The subline for a held exercise: how many more sessions or misses stand
  /// between it and the next move. Null when there is nothing pending to say.
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
        border:
            last ? null : Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(seededName(l10n, outcome.seedKey, outcome.name),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ],
            ),
          ),
          Text(
            _target(l10n),
            style: kMono.copyWith(
                fontSize: 13, fontWeight: FontWeight.w700, color: tone),
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

  /// Every logged set of one movement, in the order they were done. The name
  /// and seed key come off the first of them rather than being passed in: they
  /// are the same on all of them, being copies of one library row.
  final List<SessionSet> sets;
  final String unit;

  /// The session's date, for the caption a clip opens with — so a clip reached
  /// from here says the same thing it says in the exercise's own reel.
  final DateTime date;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Best set = highest weight × reps, or the longest hold when the exercise
    // is measured in time and weight × reps is zero for all of them.
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
      // Only a row with something to play is tappable. A row that responds to a
      // tap by doing nothing is worse than one that does not respond.
      onTap: filmedSets.isEmpty
          ? null
          : () => _openClips(context, filmedSets),
      behavior: HitTestBehavior.opaque,
      child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: AppColors.line)),
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
                    seededName(l10n, sets.first.exerciseSeedKey,
                        sets.first.exerciseName),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                    children: [
                      TextSpan(text: l10n.commonSetCount(sets.length)),
                      // Only ever shown when there is something to say — a
                      // clean session should not carry a "0 missed" badge.
                      if (missed > 0)
                        TextSpan(
                          text: ' · ${l10n.summaryMissedCount(missed)}',
                          style: TextStyle(color: AppColors.gold),
                        ),
                      // A set carrying a clip has to be findable from here, or
                      // the recording is one nobody will ever watch again.
                      if (filmed > 0)
                        TextSpan(
                          text: ' · ${l10n.summaryFilmedCount(filmed)}',
                          style: TextStyle(color: AppColors.accent),
                        ),
                    ],
                  ),
                ),
                // What the machine was set to, on the set being reported above.
                // The whole reason for typing it during the session is that a
                // later reading of "20:00 on the treadmill" can tell a walk from
                // a run; a set carrying no readouts prints nothing at all.
                if (cardioSummary(l10n, best.console, unit: unit)
                    case final readouts?) ...[
                  const SizedBox(height: 2),
                  Text(
                    readouts,
                    style: kMono.copyWith(fontSize: 11, color: AppColors.faint),
                  ),
                ],
              ],
            ),
          ),
          Text.rich(
            TextSpan(
              style: kMono.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
              children: timed
                  ? [
                      TextSpan(
                          text: l10n.unitSecondsShort('${best.seconds ?? 0}')),
                      if (best.weight != 0)
                        TextSpan(
                            text: ' @ $w',
                            style: TextStyle(color: AppColors.faint)),
                    ]
                  : [
                      TextSpan(text: w),
                      TextSpan(
                          text: ' ×${best.reps}',
                          style: TextStyle(color: AppColors.faint)),
                    ],
            ),
          ),
          if (filmedSets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Icon(Icons.play_circle_outline,
                  size: 20, color: AppColors.accent),
            ),
        ],
      ),
      ),
    );
  }

  /// Opens the clip. With more than one filmed set of the same movement there
  /// is a choice to make, so it is offered rather than guessed at.
  Future<void> _openClips(
    BuildContext context,
    List<SessionSet> filmed,
  ) async {
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
                  leading: Icon(Icons.play_circle_outline,
                      color: AppColors.accent),
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
