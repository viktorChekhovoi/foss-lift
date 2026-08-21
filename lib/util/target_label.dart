/// Formats an exercise target consistently across summaries and import previews.

library;

import '../data/progression.dart';
import '../data/set_scheme.dart';
import '../l10n/app_localizations.dart';

/// The rep half of the phrase: a hold in seconds, failure, a count, or a range.
///
/// The four are exclusive and are read in that order — a timed slot has no rep
/// target to fall back to, and a to-failure slot has dropped its range.
String repsTargetLabel(
  AppLocalizations l10n, {
  required ProgressionMode progression,
  required bool toFailure,
  required int holdSeconds,
  required int repsMin,
  int? repsMax,
}) {
  if (progression.timed) return l10n.unitSecondsShort('$holdSeconds');
  if (toFailure) return l10n.targetFailure;
  return rowLabel(l10n, reps: repsMin, repsMax: repsMax);
}

/// The whole phrase — how many sets, of what.
String setsTargetLabel(
  AppLocalizations l10n, {
  required int sets,
  required ProgressionMode progression,
  required bool toFailure,
  required int holdSeconds,
  required int repsMin,
  int? repsMax,
}) =>
    l10n.targetSetsReps(
      sets,
      repsTargetLabel(
        l10n,
        progression: progression,
        toFailure: toFailure,
        holdSeconds: holdSeconds,
        repsMin: repsMin,
        repsMax: repsMax,
      ),
    );

/// One set's rep target from its three numbers: a count, a range, or a minimum
/// with no top — "5", "8–12", "5+".
///
/// The primitive under both the slot-wide phrase above and the written-out rows
/// below, so a range reads the same whether it was asked for once for the slot
/// or set by set.
String rowLabel(
  AppLocalizations l10n, {
  required int reps,
  int? repsMax,
  bool amrap = false,
}) {
  if (amrap) return l10n.targetAmrap(reps);
  if (repsMax == null || repsMax == reps) return '$reps';
  return '$reps–$repsMax';
}

/// One written-out row's rep target.
String rowTargetLabel(AppLocalizations l10n, CustomSet row) => rowLabel(
      l10n,
      reps: row.reps,
      repsMax: row.repsMax,
      amrap: row.amrap,
    );

/// Already-formatted sets joined into one week — "5/3/1+".
///
/// A slash rather than the middot that separates a slot's summary into fields:
/// a summary reading "5 · 5 · 5+ · 100 kg · cycle" cannot be parsed into the
/// four things it is, because three of them are one thing.
String joinRowLabels(AppLocalizations l10n, Iterable<String> labels) =>
    labels.join(l10n.targetRowSeparator);

/// A whole written-out week, in order — "5/5/5+".
///
/// What a slot whose sets differ from one another has instead of "3 × 5": the
/// sets are the prescription, so listing them is the honest summary and a
/// single multiplication would have to pick one row to speak for the rest.
String rowsTargetLabel(AppLocalizations l10n, List<CustomSet> rows) =>
    joinRowLabels(l10n, rows.map((r) => rowTargetLabel(l10n, r)));

/// Where in its cycle a slot is, for the line under the exercise — "Week 2/4",
/// or "Deload 4/4" once that week has been given a name.
///
/// The name takes the place of the word rather than being added to it, and the
/// count stays either way: the name says what the week is and the count says
/// how much of the block is left, and neither answers the other.
String cycleWeekLine(
  AppLocalizations l10n,
  String name,
  int week,
  int weeks,
) =>
    name.trim().isEmpty
        ? l10n.sessionCycleWeek(week, weeks)
        : l10n.sessionCycleWeekNamed(name.trim(), week, weeks);
