/// Converts shared routines to and from database rows.
///
/// The wire format (`routine_code.dart`) knows nothing about drift, and the
/// database knows nothing about sharing. This is the seam: an extension that
/// reads a routine into a [SharedRoutine], and lands one back — plus the small
/// piece of judgement in between, which is what to do about an incoming
/// exercise whose name is already taken.
library;

import 'package:drift/drift.dart';

import '../util/units.dart';
import '../util/video_links.dart';
import 'database.dart';
import 'routine_code.dart';
import 'seed_keys.dart';

/// The seed key [name] names, or null when it is nobody's starter movement.
///
/// A routine code carries the canonical English name and no key — see
/// `routine_code.dart` — so the receiving phone derives it back. That is what
/// lets a starter movement the recipient happens not to have arrive as one
/// rather than as a row named in English forever. Matched the way the library
/// is, case- and whitespace-insensitively.
String? seedKeyForName(String name) =>
    _seedKeysByName[name.trim().toLowerCase()];

final Map<String, String> _seedKeysByName = {
  for (final e in kSeedExerciseKeys.entries)
    e.key.trim().toLowerCase(): e.value,
};

/// One incoming exercise, resolved against the library it is landing in.
///
/// Three outcomes, and only one of them is a question for the user:
/// * [isNew] — nothing here by that name; it will be added.
/// * neither — the same movement, described the same way; it is simply reused.
/// * [clashes] — the name is taken and the definition differs. Whose version
///   wins is the user's call, never a guess: their "Zercher Squat" may be a
///   better description than mine, or it may be for a different movement
///   entirely, and only the person looking at both can tell.
class ExerciseArrival {
  const ExerciseArrival({
    required this.incoming,
    required this.existing,
    required this.clashes,
  });

  final SharedExercise incoming;

  /// The library row that already owns this name, if any.
  final Exercise? existing;

  final bool clashes;

  bool get isNew => existing == null;
}

/// Matches each of [incoming] against [library] — on seed key first, then on
/// the name, case-insensitively — and says which ones the user has to rule on.
///
/// The key comes first because it is the identity that survives a release: the
/// canonical English name of a starter movement can be corrected, its key
/// cannot, so a code written against the old name still lands on the row it
/// means rather than planting a second copy of the same movement.
///
/// Only the fields a code actually carries are compared. Coaching cues do not
/// travel at all, and a video link only travels when it resolves to a video —
/// so a difference in either is invisible here, which is right: the import
/// cannot offer to replace what it was never given.
List<ExerciseArrival> planExerciseArrivals(
  List<SharedExercise> incoming,
  List<Exercise> library,
) {
  final byName = {for (final e in library) e.name.trim().toLowerCase(): e};
  final bySeedKey = {
    for (final e in library)
      if (e.seedKey != null) e.seedKey!: e,
  };

  return [
    for (final e in incoming)
      () {
        final key = seedKeyForName(e.name);
        final existing =
            (key == null ? null : bySeedKey[key]) ??
            byName[e.name.trim().toLowerCase()];
        return ExerciseArrival(
          incoming: e,
          existing: existing,
          clashes: existing != null && _differs(e, existing),
        );
      }(),
  ];
}

bool _differs(SharedExercise incoming, Exercise existing) {
  if (incoming.muscles != existing.muscles) return true;
  if (incoming.equipment != existing.equipment) return true;
  if (incoming.measure != existing.measure) return true;
  if (incoming.weightType != existing.weightType) return true;
  if (incoming.barWeight != existing.barWeight) return true;
  final video = incoming.videoUrl;
  if (video != null && video != existing.videoUrl) return true;
  return false;
}

/// Reading a routine out for sharing, and landing a shared one.
extension RoutineSharing on AppDatabase {
  /// Gathers [routineId] into the shape the wire format takes.
  ///
  /// The exercise dictionary is built in first-use order and referenced by
  /// index, so a movement that appears on three days is described once.
  Future<SharedRoutine> sharedRoutine(int routineId) async {
    final routine = await routineById(routineId);
    final days = await workoutsForRoutine(routineId);

    final indices = <int, int>{};
    final dictionary = <SharedExercise>[];
    final workouts = <SharedWorkout>[];

    for (final day in days) {
      final items = <SharedItem>[];
      for (final view in await itemsForWorkout(day.id)) {
        final index = indices.putIfAbsent(view.exercise.id, () {
          dictionary.add(_share(view.exercise));
          return dictionary.length - 1;
        });
        final it = view.item;
        items.add(
          SharedItem(
            exercise: index,
            targetSets: it.targetSets,
            repsMin: it.repsMin,
            repsMax: it.repsMax,
            toFailure: it.toFailure,
            restSeconds: it.restSeconds,
            // The weight stays behind with the streaks: it is the sender's body,
            // not the sender's program. See routine_code.dart.
            progression: it.progression,
            holdSeconds: it.holdSeconds,
            increment: it.increment,
            deload: it.deload,
            successThreshold: it.successThreshold,
            failureThreshold: it.failureThreshold,
            // The scheme is part of the prescription, so it travels — as a shape
            // and its percentages, not as the weights it produces.
            scheme: it.scheme,
            schemePercent: it.schemePercent,
            customSets: decodeCustomSets(it.customSets),
            // The weeks travel; where the slot has got to in them does not, for
            // the reason repsTarget does not — see below.
            cycle: it.cycleWeeks,
            // And what they are called, which is part of the program in the way
            // the day's own name is.
            cycleNames: it.cycleWeekNameList,
            // Which slots are trained back to back is the program too, and so is
            // whether a slot climbs its range before its load moves.
            supersetWithPrevious: it.supersetWithPrevious,
            addWeightAtTopOfRange: it.addWeightAtTopOfRange,
            repsIncrement: it.repsIncrement,
            repsDeload: it.repsDeload,
            targetRpe: it.targetRpe,
            gzclTier: it.gzclTier,
            gzclStages: it.gzclStageList,
            gzclAmrapTarget: it.gzclAmrapTarget,
            // successStreak and failStreak are left behind on purpose: momentum
            // is earned on your own bar, not inherited with a program.
          ),
        );
      }
      workouts.add(SharedWorkout(name: day.name, items: items));
    }

    return SharedRoutine(
      name: routine.name,
      colorHex: routine.colorHex,
      restSeconds: routine.restSeconds,
      scheduleDays: routine.scheduleDays,
      // What the program is travels: it is a fact about the program rather than
      // about the sender, which is the line everything else here is drawn on.
      description: routine.description,
      // The reminder time does not travel — a notification is asked for.
      exercises: dictionary,
      workouts: workouts,
    );
  }

  /// Writes [shared] as a brand-new routine and returns its id.
  ///
  /// [replace] holds the indices — into [SharedRoutine.exercises] — of the
  /// clashes the user chose to overwrite. Everything not named there keeps the
  /// definition already in the library.
  ///
  /// Nothing existing is ever removed: a replaced exercise is *edited*, keeping
  /// its id, so its logged history and every other routine pointing at it
  /// survive. The current routine is left alone too — importing a program is
  /// not the same as deciding to train it.
  Future<int> importSharedRoutine(
    SharedRoutine shared, {
    Set<int> replace = const {},
  }) {
    return transaction(() async {
      final library = await select(exercises).get();
      final arrivals = planExerciseArrivals(shared.exercises, library);

      final ids = <int>[];
      for (var i = 0; i < arrivals.length; i++) {
        final arrival = arrivals[i];
        final existing = arrival.existing;
        if (existing == null) {
          // Anything this phone has never had is added. A name the starter
          // library knows arrives keyed and not custom — it is the movement
          // the app ships, arriving late, and it has to read in the app's
          // language and stay unrenameable like every other one. Anything else
          // is one of the user's own, whatever it was on the sender's phone.
          final key = seedKeyForName(arrival.incoming.name);
          ids.add(
            await into(exercises).insert(
              _companion(
                arrival.incoming,
              ).copyWith(seedKey: Value(key), isCustom: Value(key == null)),
            ),
          );
          continue;
        }
        if (arrival.clashes && replace.contains(i)) {
          // A starter movement keeps its name and its key through a Replace:
          // the name is the vocabulary every routine code is written in, and
          // is not editable by hand for the same reason. How it loads is the
          // sender's to describe, and is written.
          await (update(
            exercises,
          )..where((e) => e.id.equals(existing.id))).write(
            _companion(arrival.incoming, keepName: existing.seedKey != null),
          );
        }
        ids.add(existing.id);
      }

      // A rate the sender did not spend bytes on is *their* default, which is
      // the kilogram one whatever unit they train in — the wire format has no
      // unit in it. Filling it in from this phone's unit is what keeps an
      // imported routine stepping by 5 lb in a pounds gym.
      final unit =
          (await (select(
            settings,
          )..where((s) => s.id.equals(1))).getSingleOrNull())?.weightUnit ??
          'kg';

      // Each slot's weight comes off *this* phone: what it last logged for the
      // movement, or nothing at all, which is exactly what a slot added by hand
      // starts as.
      final weights = <int, double?>{
        for (final id in ids.toSet()) id: await lastLoggedWeight(id),
      };

      final routineId = await createRoutine(
        name: shared.name,
        color: shared.colorHex,
        restSeconds: shared.restSeconds,
        scheduleDays: shared.scheduleDays,
        // No seed key goes with it: an import is nobody's copy of a library
        // program, so the description it arrived with is shown as it arrived
        // rather than resolved as a shipped string.
        description: shared.description,
      );

      await replaceRoutineWorkouts(routineId, [
        for (final day in shared.workouts)
          (
            id: null,
            name: day.name,
            items: [
              for (final (i, it) in day.items.indexed)
                WorkoutItemsCompanion.insert(
                  // Rewritten by replaceRoutineWorkouts to the real workout.
                  workoutId: 0,
                  exerciseId: ids[it.exercise],
                  position: Value(i),
                  targetSets: Value(it.targetSets),
                  repsMin: Value(it.repsMin),
                  repsMax: Value(it.repsMax),
                  toFailure: Value(it.toFailure),
                  restSeconds: Value(it.restSeconds),
                  suggestedWeight: Value(weights[ids[it.exercise]]),
                  progression: Value(it.progression),
                  holdSeconds: Value(it.holdSeconds),
                  increment: Value(
                    isDefaultIncrement(it.increment, it.progression, 'kg')
                        ? defaultIncrementFor(it.progression, unit)
                        : _landedRate(it.increment, it.progression, unit),
                  ),
                  deload: Value(
                    isDefaultDeload(it.deload, it.progression, 'kg')
                        ? defaultDeloadFor(it.progression, unit)
                        : _landedRate(it.deload, it.progression, unit),
                  ),
                  successThreshold: Value(it.successThreshold),
                  failureThreshold: Value(it.failureThreshold),
                  scheme: Value(it.scheme),
                  schemePercent: Value(it.schemePercent),
                  customSets: Value(
                    it.scheme.isCustom ? encodeCustomSets(it.customSets) : null,
                  ),
                  cycleBlocks: Value(
                    it.scheme == SetScheme.cycle
                        ? encodeCycleBlocks(it.cycle)
                        : null,
                  ),
                  cycleNames: Value(
                    it.scheme == SetScheme.cycle
                        ? encodeCycleNames(it.cycleNames)
                        : null,
                  ),
                  // An imported copy opens on week one: cyclePosition takes its
                  // column default rather than the sender's progress.
                  // The first slot of a day cannot be joined to the one above
                  // it, whatever a code claims — see [normaliseJoins].
                  supersetWithPrevious: Value(i > 0 && it.supersetWithPrevious),
                  addWeightAtTopOfRange: Value(it.addWeightAtTopOfRange),
                  repsIncrement: Value(it.repsIncrement),
                  repsDeload: Value(it.repsDeload),
                  targetRpe: Value(it.targetRpe),
                  gzclTier: Value(it.gzclTier),
                  gzclStages: Value(encodeGzclStages(it.gzclStages)),
                  gzclAmrapTarget: Value(it.gzclAmrapTarget),
                  // repsTarget is left behind with the streaks: where the
                  // sender had got to inside their range is progress, not
                  // program, so an imported slot starts at the bottom of it.
                ),
            ],
          ),
      ]);

      return routineId;
    });
  }
}

/// An exercise as it should travel: what identifies the movement and how it is
/// loaded, and nothing else. The coaching cue stays behind — it is the largest
/// field on the row and the least worth carrying, since whoever receives the
/// routine can read the movement's name and already knows, or can look it up
/// with the link that does travel.
SharedExercise _share(Exercise e) => SharedExercise(
  name: e.name,
  muscles: e.muscles,
  equipment: e.equipment,
  isCustom: e.isCustom,
  measure: e.measure,
  weightType: e.weightType,
  // Canonicalised here rather than in the codec, so a [SharedRoutine] holds
  // the same link whether it came off this database or off a decoded code.
  videoUrl: _canonicalVideo(e.videoUrl),
  barWeight: e.barWeight,
);

/// A stored link reduced to the canonical short form, or null when there is no
/// video behind it — a search results page, a link to somewhere else entirely.
String? _canonicalVideo(String? url) {
  if (url == null) return null;
  final id = youTubeVideoId(url);
  return id == null ? null : youTubeUrl(id);
}

/// A rate the sender actually spent bytes on, as it lands here.
///
/// A weight is put back on the receiving phone's fine grid — see
/// [snapToFineGrid] for the format's rounding this undoes, and for why the same
/// grid a percentage lands on is the right one to repair onto. Reps and seconds
/// carry no unit and pass straight through.
double _landedRate(double value, ProgressionMode mode, String unit) =>
    mode == ProgressionMode.weight ? snapToFineGrid(value, unit) : value;

/// The incoming definition as a row patch.
///
/// Touches only what the code carried. The instruction column is never written:
/// a cue does not travel, so replacing an exercise leaves whatever description
/// the recipient had — including, on a starter movement, the one the app
/// shipped. The video link is written only when one arrived, for the same
/// reason. [keepName] leaves the name column alone, which is what a starter
/// movement's row gets: its name is the vocabulary a routine code is written
/// in rather than the sender's to redefine.
ExercisesCompanion _companion(SharedExercise e, {bool keepName = false}) {
  final groups = muscleColumns(e.muscles);
  return ExercisesCompanion(
    name: keepName ? const Value.absent() : Value(e.name),
    muscleGroup: groups.muscleGroup,
    extraPrimaryGroups: groups.extraPrimaryGroups,
    secondaryGroups: groups.secondaryGroups,
    equipment: Value(e.equipment),
    measure: Value(e.measure),
    weightType: Value(e.weightType),
    barWeight: Value(e.barWeight),
    videoUrl: e.videoUrl == null ? const Value.absent() : Value(e.videoUrl),
  );
}
