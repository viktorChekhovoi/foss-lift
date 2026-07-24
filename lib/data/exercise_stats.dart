/// Per-exercise progress maths and CSV rendering.
///
/// Deliberately free of Flutter and drift: the aggregation and the export are
/// pure functions over plain data, so both are unit-tested without a database
/// and reused by the chart screen. Weights in here are canonical kilograms —
/// convert to the display unit at the view boundary, exactly like the rest of
/// the app.
library;

import 'package:intl/intl.dart';

/// One logged set of a single exercise, flattened with the date and name of the
/// session it belongs to. Built from a `SessionSets` row joined to its session
/// by [AppDatabase.watchExerciseSetHistory]; kept drift-free so the maths below
/// can be tested against plain constructions.
class ExerciseSetEntry {
  const ExerciseSetEntry({
    required this.sessionId,
    required this.date,
    required this.sessionName,
    required this.setNumber,
    required this.weightKg,
    required this.reps,
    required this.seconds,
    required this.done,
  });

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

  bool get timed => seconds != null;
}

/// Epley one-rep-max estimate from a working set: `w · (1 + reps/30)`.
///
/// A single rep is already a one-rep max, so it returns the weight untouched
/// rather than inflating it; zero reps (a set that was logged but not really
/// performed) has no estimate and returns zero.
double estimatedOneRepMax(double weightKg, int reps) {
  if (reps <= 0) return 0;
  if (reps == 1) return weightKg;
  return weightKg * (1 + reps / 30.0);
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
    required this.est1RMKg,
    required this.bestSeconds,
  });

  final DateTime date;

  /// The heaviest weight carried on any completed set that session.
  final double topWeightKg;

  /// Reps done on the set that set [topWeightKg] (the most reps, if it was hit
  /// at more than one rep count).
  final int repsAtTop;

  /// The best estimated one-rep max across the session's completed sets — the
  /// metric that credits an extra rep at the same weight, not only more load.
  final double est1RMKg;

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
    var est1RM = 0.0;
    var bestSeconds = 0;
    for (final e in entries) {
      if (e.weightKg > topWeight ||
          (e.weightKg == topWeight && e.reps > repsAtTop)) {
        topWeight = e.weightKg;
        repsAtTop = e.reps;
      }
      final oneRm = estimatedOneRepMax(e.weightKg, e.reps);
      if (oneRm > est1RM) est1RM = oneRm;
      if ((e.seconds ?? 0) > bestSeconds) bestSeconds = e.seconds ?? 0;
    }
    points.add(ExerciseProgressPoint(
      date: entries.first.date,
      topWeightKg: topWeight == double.negativeInfinity ? 0 : topWeight,
      repsAtTop: repsAtTop,
      est1RMKg: est1RM,
      bestSeconds: bestSeconds,
    ));
  }

  points.sort((a, b) => a.date.compareTo(b.date));
  return points;
}

/// Renders one exercise's whole set history as a CSV document.
///
/// A header row then one row per logged set, oldest first. Weights are
/// converted to [unit] with [convertWeight] (pass the app's `toDisplayWeight`)
/// and the weight/1RM column headers name that unit, so a file opened later is
/// unambiguous. Everything is built in memory from data already on the device —
/// there is nothing here that touches the network.
String exerciseHistoryCsv({
  required String exerciseName,
  required List<ExerciseSetEntry> sets,
  required String unit,
  required double Function(double kg, String unit) convertWeight,
}) {
  final fmt = DateFormat('yyyy-MM-dd HH:mm');
  final rows = <List<String>>[
    ['Date', 'Session', 'Exercise', 'Set', 'Weight ($unit)', 'Reps', 'Seconds',
        'Est 1RM ($unit)'],
  ];

  for (final s in sets) {
    final est = estimatedOneRepMax(s.weightKg, s.reps);
    rows.add([
      fmt.format(s.date),
      s.sessionName,
      exerciseName,
      '${s.setNumber}',
      _num(convertWeight(s.weightKg, unit)),
      '${s.reps}',
      s.seconds == null ? '' : '${s.seconds}',
      est == 0 ? '' : _num(convertWeight(est, unit)),
    ]);
  }

  return rows.map((r) => r.map(_csvField).join(',')).join('\r\n');
}

/// Quotes a field only when it has to be: a comma, a quote, or a newline.
String _csvField(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// A weight for a cell: at most two decimals, with a trailing `.0`/`.00` and
/// any dangling zeros trimmed so 80 reads "80" and 82.55 stays "82.55".
String _num(double v) {
  var s = v.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}
