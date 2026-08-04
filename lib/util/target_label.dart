/// What one exercise slot is aiming at, in words.
///
/// "4 × 6–8", "3 × 45s", "3 × Failure" — the same phrase wherever a slot is
/// summarised: the training day, the editor's one-line summary of a slot, and
/// the routine on the import confirmation. Those three read from one formatter
/// so a target cannot say one thing on the screen that offers the import and
/// another on the screen it lands on.
///
/// It lives up here rather than beside the drift row it usually describes
/// because it is words, and the words are in the catalogue: the data layer
/// deliberately cannot see the generated localisations, so a target formatted
/// down there is English on a Ukrainian phone forever.
library;

import '../data/progression.dart';
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
  if (repsMax == null || repsMax == repsMin) return '$repsMin';
  return '$repsMin–$repsMax';
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
