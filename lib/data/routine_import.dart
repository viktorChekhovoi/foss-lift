/// Getting a routine out of the database and back into one.
///
/// The wire format (`routine_code.dart`) knows nothing about drift, and the
/// database knows nothing about sharing. This is the seam: an extension that
/// reads a routine into a [SharedRoutine], and lands one back — plus the small
/// piece of judgement in between, which is what to do about an incoming
/// exercise whose name is already taken.
library;

import 'package:drift/drift.dart';

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
/// A built-in exercise carries no instructions or video (the recipient has
/// their own copy), so those are only compared when the sender actually sent
/// them — otherwise every shared starter movement would look like a clash that
/// wants to blank out a coaching cue.
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
  if (incoming.instructions.isNotEmpty &&
      incoming.instructions != existing.instructions) {
    return true;
  }
  final video = incoming.videoUrl;
  if (video != null && video.isNotEmpty && video != existing.videoUrl) {
    return true;
  }
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
          suggestedWeight: it.suggestedWeight,
          progression: it.progression,
          holdSeconds: it.holdSeconds,
          increment: it.increment,
          deload: it.deload,
          successThreshold: it.successThreshold,
          failureThreshold: it.failureThreshold,
          // successStreak and failStreak are left behind on purpose: momentum
          // is earned on your own bar, not inherited with a programme.
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
  /// survive. The current routine is left alone too — importing a programme is
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
                  suggestedWeight: Value(it.suggestedWeight),
                  progression: Value(it.progression),
                  holdSeconds: Value(it.holdSeconds),
                  increment: Value(it.increment),
                  deload: Value(it.deload),
                  successThreshold: Value(it.successThreshold),
                  failureThreshold: Value(it.failureThreshold),
                ),
            ],
          ),
      ]);

      return routineId;
    });
  }
}

/// An exercise as it should travel: a custom one whole, a starter-library one
/// by name alone. Sending the shipped coaching text would be paying QR density
/// for a copy of something the recipient already has.
SharedExercise _share(Exercise e) => SharedExercise(
      name: e.name,
      muscleGroup: e.muscleGroup,
      equipment: e.equipment,
      isCustom: e.isCustom,
      measure: e.measure,
      weightType: e.weightType,
      instructions: e.isCustom ? e.instructions : '',
      videoUrl: e.isCustom ? e.videoUrl : null,
      barWeight: e.barWeight,
    );

/// The incoming definition as a row patch.
///
/// Instructions and the video link are only written when the sender actually
/// sent them: a built-in arrives without them, and blanking a starter movement's
/// coaching cue because a routine mentioned it would be a poor trade.
ExercisesCompanion _companion(SharedExercise e) => ExercisesCompanion(
      name: Value(e.name),
      muscleGroup: Value(e.muscleGroup),
      equipment: Value(e.equipment),
      measure: Value(e.measure),
      weightType: Value(e.weightType),
      barWeight: Value(e.barWeight),
      instructions:
          e.instructions.isEmpty ? const Value.absent() : Value(e.instructions),
      videoUrl: (e.videoUrl?.isEmpty ?? true)
          ? const Value.absent()
          : Value(e.videoUrl),
    );
