// JSON crash snapshot for the in-memory live session.
//
// The workout stays in memory and still writes its history only on Finish —
// that model is deliberate and unchanged. What this adds is a crash snapshot: a
// single JSON blob, rewritten on every mutation, read once on launch, deleted on
// finish or discard. Android kills backgrounded processes, and a session that
// evaporates because somebody looked at a text message is not a tracker.
//
// **The shape here is not a wire format.** It never leaves the phone and it is
// re-read only by the build that wrote it (a launch, minutes later), so a field
// can be renamed freely: a snapshot that will not parse is discarded and the
// user is where they would have been without it. `decodeSession` therefore
// returns null rather than throwing on anything it does not recognise.

import 'dart:convert';

import '../data/plates.dart';
import '../data/progression.dart' show ProgressionMode;
import '../data/set_scheme.dart';
import '../data/warmup.dart' show kDefaultWarmupSets;
import '../util/cardio_units.dart';
import 'active_workout.dart';

/// Encodes the live session as JSON.
String encodeSession(ActiveWorkout s) => jsonEncode({
      'routineId': s.routineId,
      'workoutId': s.workoutId,
      'name': s.name,
      'seedKey': s.seedKey,
      'startedAt': s.startedAt.millisecondsSinceEpoch,
      'elapsed': s.elapsed,
      'unit': s.unit,
      if (s.notice case final n?)
        'notice': {'percent': n.percent, 'days': n.days},
      'plates': [for (final p in s.plates) _stack(p)],
      'barKg': s.barKg,
      'warmupSets': s.warmupSets,
      'restLeft': s.restLeft,
      'restDone': s.restDone,
      if (s.restPrompt case final p?)
        'restPrompt': {
          'purpose': p.purpose.name,
          'weightKg': p.weightKg,
          'exercise': p.exercise,
          'exerciseSeedKey': p.exerciseSeedKey,
        },
      if (s.restFor case final r?)
        'restFor': {
          'exercise': r.exercise,
          'set': r.set,
          'warmup': r.warmup,
        },
      'exercises': [
        for (final e in s.exercises)
          {
            'exerciseId': e.exerciseId,
            'itemId': e.itemId,
            'name': e.name,
            'seedKey': e.seedKey,
            'muscle': e.muscle,
            'mode': e.mode.name,
            'weightType': e.weightType.name,
            'barKg': e.barKg,
            'restSeconds': e.restSeconds,
            'workingKg': e.workingKg,
            // The scheme, whole. A back-off that came back as a flat slot would
            // put every rung on the top weight the next time the working weight
            // moved — and quietly inflate what progression made of the session.
            'scheme': e.scheme.name,
            'schemePercent': e.schemePercent,
            'customSets': encodeCustomSets(e.customSets),
            'goalReps': e.goalReps,
            'floorKg': e.floorKg,
            'supersetWithPrevious': e.supersetWithPrevious,
            'cardioMachine': e.cardioMachine,
            'unit': e.unit,
            'warmupCount': e.warmupCount,
            'warmupBarKg': e.warmupBarKg,
            'warmupRestSeconds': e.warmupRestSeconds,
            'warmupLadder': [for (final r in e.warmupLadder) _rung(r)],
            'sets': [for (final x in e.sets) _set(x)],
            'warmups': [for (final x in e.warmups) _set(x)],
          },
      ],
    });

/// Decodes a snapshot and advances its timers by [dead], returning null when invalid.
///
/// Both clocks are rebuilt against that gap rather than resumed where they
/// stopped: a workout that started at nine is an hour old at ten whether or not
/// the app was alive for the hour, and a rest with forty seconds left when the
/// process died has none left two minutes later. A rest whose time is up comes
/// back as no rest at all — its notification has already sounded.
///
/// Returns null for anything unreadable; see the note at the top of this file.
ActiveWorkout? decodeSession(String payload, {Duration dead = Duration.zero}) {
  try {
    final m = jsonDecode(payload) as Map<String, dynamic>;
    final gone = dead.inSeconds < 0 ? 0 : dead.inSeconds;
    final restLeft = (m['restLeft'] as int) - gone;
    final resting = restLeft > 0;
    // A rest that ran out while the process was dead has already sounded and has
    // nothing left to announce; one that had already ended when the snapshot was
    // taken comes back still saying what it was for.
    final done = !resting && (m['restDone'] as bool? ?? false);
    final exercises = [
      for (final e in m['exercises'] as List)
        _readExercise(
          e as Map<String, dynamic>,
          sessionUnit: m['unit'] as String,
        ),
    ];
    _backfillLogOrder(exercises);
    return ActiveWorkout(
      routineId: m['routineId'] as int?,
      workoutId: m['workoutId'] as int?,
      name: m['name'] as String,
      seedKey: m['seedKey'] as String?,
      startedAt: DateTime.fromMillisecondsSinceEpoch(m['startedAt'] as int),
      elapsed: (m['elapsed'] as int) + gone,
      unit: m['unit'] as String,
      notice: _readNotice(m['notice']),
      plates: [
        for (final p in m['plates'] as List) _readStack(p as Map<String, dynamic>),
      ],
      barKg: (m['barKg'] as num?)?.toDouble() ?? kDefaultBarKg,
      warmupSets: m['warmupSets'] as int? ?? kDefaultWarmupSets,
      restLeft: resting ? restLeft : 0,
      restPrompt: resting || done ? _readPrompt(m['restPrompt']) : null,
      restFor: resting || done ? _readRestFor(m['restFor']) : null,
      restDone: done,
      exercises: exercises,
    );
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _stack(PlateStack p) => {'kg': p.kg, 'count': p.count};
PlateStack _readStack(Map<String, dynamic> m) =>
    (kg: (m['kg'] as num).toDouble(), count: m['count'] as int);

Map<String, dynamic> _rung(LoadRung r) => {'kg': r.kg, 'cost': r.cost};
LoadRung _readRung(Map<String, dynamic> m) =>
    (kg: (m['kg'] as num).toDouble(), cost: m['cost'] as int);

Map<String, dynamic> _set(SetEntry s) => {
      'goal': s.goal,
      'timed': s.timed,
      'goalWeight': s.goalWeight,
      'weight': s.weight,
      'logged': s.logged,
      'loggedOrder': s.loggedOrder,
      'videoPath': s.videoPath,
      if (s.hasConsole) 'console': _console(s.console),
    };

SetEntry _readSet(Map<String, dynamic> m) => SetEntry(
      goal: m['goal'] as int,
      timed: m['timed'] as bool,
      goalWeight: (m['goalWeight'] as num?)?.toDouble(),
      weight: (m['weight'] as num).toDouble(),
      logged: m['logged'] as int?,
      loggedOrder: m['loggedOrder'] as int?,
      videoPath: m['videoPath'] as String?,
      console: _readConsole(m['console']),
    );

/// What the console said, when any readout was recorded. Nearly
/// every set has nothing here, and a key per set for four nulls is four keys per
/// set of a blob that is rewritten on every tap.
Map<String, dynamic> _console(ConsoleMetrics c) => {
      'speedKph': ?c.speedKph,
      'inclinePercent': ?c.inclinePercent,
      'resistanceLevel': ?c.resistanceLevel,
      'distanceKm': ?c.distanceKm,
    };

/// The readouts a snapshot carries, or none — which is also what a snapshot
/// written before there were any comes back as.
ConsoleMetrics _readConsole(Object? raw) {
  if (raw is! Map<String, dynamic>) return kNoConsoleMetrics;
  return (
    speedKph: (raw['speedKph'] as num?)?.toDouble(),
    inclinePercent: (raw['inclinePercent'] as num?)?.toDouble(),
    resistanceLevel: raw['resistanceLevel'] as int?,
    distanceKm: (raw['distanceKm'] as num?)?.toDouble(),
  );
}

RestSetRef? _readRestFor(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  return (
    exercise: raw['exercise'] as int,
    set: raw['set'] as int,
    warmup: raw['warmup'] as bool,
  );
}

/// Backfills log order for snapshots written before the field existed.
///
/// The shipped build recorded what was logged and not when, and read the last
/// logged set *in list order* as the one you were on. That is what absent means
/// here, so the stamps are handed out in list order and the restored session
/// carries on marking the same row it would have. A snapshot that has them
/// keeps them: this runs only when the whole session is without.
void _backfillLogOrder(List<ExerciseEntry> exercises) {
  // Exercise by exercise, so a stamp rises with position in the list and the
  // highest one lands in the last exercise that had anything logged in it.
  final rows = [
    for (final e in exercises) ...[...e.warmups, ...e.sets],
  ];
  if (rows.any((s) => s.loggedOrder != null)) return;
  var next = 1;
  for (final s in rows) {
    if (s.done) s.loggedOrder = next++;
  }
}

RestPrompt? _readPrompt(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  for (final purpose in RestPurpose.values) {
    if (purpose.name != raw['purpose']) continue;
    return (
      purpose: purpose,
      weightKg: (raw['weightKg'] as num?)?.toDouble(),
      exercise: raw['exercise'] as String?,
      exerciseSeedKey: raw['exerciseSeedKey'] as String?,
    );
  }
  return null;
}

LayoffNotice? _readNotice(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  return (percent: raw['percent'] as int, days: raw['days'] as int);
}

SetScheme _readScheme(Object? raw) {
  for (final scheme in SetScheme.values) {
    if (scheme.name == raw) return scheme;
  }
  return SetScheme.flat;
}

/// [sessionUnit] is what a movement with no unit of its own in the snapshot
/// falls back to — which is every movement in a snapshot written before an
/// exercise could carry one.
ExerciseEntry _readExercise(
  Map<String, dynamic> m, {
  required String sessionUnit,
}) =>
    ExerciseEntry(
      exerciseId: m['exerciseId'] as int?,
      itemId: m['itemId'] as int?,
      name: m['name'] as String,
      seedKey: m['seedKey'] as String?,
      muscle: m['muscle'] as String,
      mode: ProgressionMode.values.byName(m['mode'] as String),
      weightType: WeightType.values.byName(m['weightType'] as String),
      barKg: (m['barKg'] as num?)?.toDouble(),
      restSeconds: m['restSeconds'] as int,
      workingKg: (m['workingKg'] as num?)?.toDouble(),
      // A snapshot written by an older build carries none of the five. Absent
      // reads as the default it had then — a flat slot — rather than failing the
      // whole session back to nothing.
      scheme: _readScheme(m['scheme']),
      schemePercent: m['schemePercent'] as int? ?? kDefaultSchemePercent,
      customSets: decodeCustomSets(m['customSets'] as String?),
      goalReps: m['goalReps'] as int? ?? 0,
      floorKg: (m['floorKg'] as num?)?.toDouble() ?? 0,
      // Absent in a snapshot from a build that had no supersets, which means
      // exactly what it says: this exercise stood on its own.
      supersetWithPrevious: m['supersetWithPrevious'] as bool? ?? false,
      // Likewise absent in a snapshot from a build that had no console readouts:
      // no exercise on that board offered them, so false is what it meant.
      cardioMachine: m['cardioMachine'] as bool? ?? false,
      // Absent in a snapshot from a build where no movement could be pinned to
      // a unit — where the session's was every movement's.
      unit: m['unit'] as String? ?? sessionUnit,
      warmupCount: m['warmupCount'] as int,
      warmupBarKg: (m['warmupBarKg'] as num).toDouble(),
      warmupRestSeconds: m['warmupRestSeconds'] as int,
      warmupLadder: [
        for (final r in m['warmupLadder'] as List)
          _readRung(r as Map<String, dynamic>),
      ],
      sets: [for (final s in m['sets'] as List) _readSet(s as Map<String, dynamic>)],
      warmups: [
        for (final s in m['warmups'] as List) _readSet(s as Map<String, dynamic>),
      ],
    );
