/// Per-exercise progress maths.
///
/// Deliberately free of Flutter and drift: the aggregation is pure functions
/// over plain data, so it is unit-tested without a database and reused by the
/// chart screen. Weights in here are canonical kilograms — convert to the
/// display unit at the view boundary, exactly like the rest of the app.
library;

/// One logged set of a single exercise, flattened with the date and name of the
/// session it belongs to. Built from a `SessionSets` row joined to its session
/// by [AppDatabase.watchExerciseSetHistory]; kept drift-free so the maths below
/// can be tested against plain constructions.
class ExerciseSetEntry {
  const ExerciseSetEntry({
    required this.setId,
    required this.sessionId,
    required this.date,
    required this.sessionName,
    required this.setNumber,
    required this.weightKg,
    required this.reps,
    required this.seconds,
    required this.done,
    this.videoPath,
  });

  /// The `SessionSets` row this came from — what a clip is deleted by.
  final int setId;
  final int sessionId;
  final DateTime date;
  final String sessionName;
  final int setNumber;

  /// The load in canonical kilograms; zero for a bodyweight or held set.
  final double weightKg;
  final int reps;

  /// Seconds held on a timed set, or null when the set was counted in reps.
  final int? seconds;
  final bool done;

  /// The clip filmed of this set, relative to the app support directory, or
  /// null if nobody filmed it.
  final String? videoPath;

  bool get timed => seconds != null;
}

/// One point on the progress chart: the best set of a single session.
///
/// A session contributes at most one point, so a chart reads one dot per time
/// you trained the movement rather than one per set. All weights are kilograms.
class ExerciseProgressPoint {
  const ExerciseProgressPoint({
    required this.date,
    required this.topWeightKg,
    required this.repsAtTop,
    required this.bestSeconds,
  });

  final DateTime date;

  /// The heaviest weight carried on any completed set that session.
  final double topWeightKg;

  /// Reps done on the set that set [topWeightKg] (the most reps, if it was hit
  /// at more than one rep count).
  final int repsAtTop;

  /// The longest completed hold that session, for a timed movement.
  final int bestSeconds;
}

/// Collapses a flat set history into one point per session, keeping only
/// completed sets. Sessions whose sets were all skipped contribute nothing.
///
/// Input may be in any order; output is sorted oldest-first so a chart reads
/// left to right in time. Grouping is by session id, not by date, so two
/// sessions on the same day stay two points.
List<ExerciseProgressPoint> progressPoints(List<ExerciseSetEntry> sets) {
  final bySession = <int, List<ExerciseSetEntry>>{};
  for (final s in sets) {
    if (!s.done) continue;
    (bySession[s.sessionId] ??= []).add(s);
  }

  final points = <ExerciseProgressPoint>[];
  for (final entries in bySession.values) {
    var topWeight = double.negativeInfinity;
    var repsAtTop = 0;
    var bestSeconds = 0;
    for (final e in entries) {
      if (e.weightKg > topWeight ||
          (e.weightKg == topWeight && e.reps > repsAtTop)) {
        topWeight = e.weightKg;
        repsAtTop = e.reps;
      }
      if ((e.seconds ?? 0) > bestSeconds) bestSeconds = e.seconds ?? 0;
    }
    points.add(ExerciseProgressPoint(
      date: entries.first.date,
      topWeightKg: topWeight == double.negativeInfinity ? 0 : topWeight,
      repsAtTop: repsAtTop,
      bestSeconds: bestSeconds,
    ));
  }

  points.sort((a, b) => a.date.compareTo(b.date));
  return points;
}
