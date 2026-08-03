/// Getting a routine out of the database and back into one.
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

/// Matches each of [incoming] against [library] by name, case-insensitively,
/// and says which ones the user has to rule on.
///
/// Only the fields a code actually carries are compared. Coaching cues do not
/// travel at all, and a video link only travels when it resolves to a video —
/// so a difference in either is invisible here, which is right: the import
/// cannot offer to replace what it was never given.
List<ExerciseArrival> planExerciseArrivals(
  List<SharedExercise> incoming,
  List<Exercise> library,
) {
  final byName = {
    for (final e in library) e.name.trim().toLowerCase(): e,
  };

  return [
    for (final e in incoming)
      () {
        final existing = byName[e.name.trim().toLowerCase()];
        return ExerciseArrival(
          incoming: e,
          existing: existing,
          clashes: existing != null && _differs(e, existing),
        );
      }(),
  ];
}

bool _differs(SharedExercise incoming, Exercise existing) {
  if (incoming.muscleGroup != existing.muscleGroup) return true;
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
        items.add(SharedItem(
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
          // successStreak and failStreak are left behind on purpose: momentum
          // is earned on your own bar, not inherited with a program.
        ));
      }
      workouts.add(SharedWorkout(name: day.name, items: items));
    }

    return SharedRoutine(
      name: routine.name,
      colorHex: routine.colorHex,
      restSeconds: routine.restSeconds,
      scheduleDays: routine.scheduleDays,
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
          // Anything this phone has never had arrives as one of the user's own
          // exercises, whatever it was on the sender's.
          ids.add(await into(exercises).insert(
            _companion(arrival.incoming).copyWith(isCustom: const Value(true)),
          ));
          continue;
        }
        if (arrival.clashes && replace.contains(i)) {
          await (update(exercises)..where((e) => e.id.equals(existing.id)))
              .write(_companion(arrival.incoming));
        }
        ids.add(existing.id);
      }

      // A rate the sender did not spend bytes on is *their* default, which is
      // the kilogram one whatever unit they train in — the wire format has no
      // unit in it. Filling it in from this phone's unit is what keeps an
      // imported routine stepping by 5 lb in a pounds gym.
      final unit = (await (select(settings)..where((s) => s.id.equals(1)))
                  .getSingleOrNull())
              ?.weightUnit ??
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
                  increment: Value(isDefaultIncrement(
                          it.increment, it.progression, 'kg')
                      ? defaultIncrementFor(it.progression, unit)
                      : it.increment),
                  deload: Value(
                      isDefaultDeload(it.deload, it.progression, 'kg')
                          ? defaultDeloadFor(it.progression, unit)
                          : it.deload),
                  successThreshold: Value(it.successThreshold),
                  failureThreshold: Value(it.failureThreshold),
                  scheme: Value(it.scheme),
                  schemePercent: Value(it.schemePercent),
                  customSets: Value(it.scheme.isCustom
                      ? encodeCustomSets(it.customSets)
                      : null),
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
      muscleGroup: e.muscleGroup,
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

/// The incoming definition as a row patch.
///
/// Touches only what the code carried. The instruction column is never written:
/// a cue does not travel, so replacing an exercise leaves whatever description
/// the recipient had — including, on a starter movement, the one the app
/// shipped. The video link is written only when one arrived, for the same
/// reason.
ExercisesCompanion _companion(SharedExercise e) => ExercisesCompanion(
      name: Value(e.name),
      muscleGroup: Value(e.muscleGroup),
      equipment: Value(e.equipment),
      measure: Value(e.measure),
      weightType: Value(e.weightType),
      barWeight: Value(e.barWeight),
      videoUrl:
          e.videoUrl == null ? const Value.absent() : Value(e.videoUrl),
    );
