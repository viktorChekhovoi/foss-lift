import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

/// What the just-finished session leaves behind for the summary to explain —
/// the [ProgressionReport] the controller stashes in [lastProgressionProvider].
/// The summary's own consume-and-clear is a screen concern; this is the data
/// underneath it.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// A one-exercise workout in its own routine. A squat for load, a plank when
  /// the axis is time — the library, not the workout, decides which is allowed.
  Future<int> slot({
    ProgressionMode mode = ProgressionMode.weight,
    int sets = 3,
    int repsMin = 5,
    double? weightKg = 100,
    int holdSeconds = 30,
    int failureThreshold = defaultFailureThreshold,
  }) async {
    final ex = (await db.watchExercises().first)
        .firstWhere((e) => e.name == (mode.timed ? 'Plank' : 'Back Squat'));
    final rid =
        await db.createRoutine(name: 'Test', color: 'FF6A3D', restSeconds: 90);
    final wid = await db.createWorkout(rid, 'Day');
    await db.replaceWorkoutItems(
      wid,
      itemCompanions(
        [
          ItemDraft(
            exerciseId: ex.id,
            name: ex.name,
            muscle: ex.muscleGroup,
            measure: ex.measure,
            sets: sets,
            repsMin: repsMin,
            weightKg: weightKg,
            progression: mode,
            holdSeconds: holdSeconds,
            failureThreshold: failureThreshold,
          ),
        ],
        workoutId: wid,
      ),
    );
    return (await db.itemsForWorkout(wid)).single.item.id;
  }

  /// Runs a session start-to-finish under a container and returns both the new
  /// session id and the report the controller stashed for it.
  Future<({int? id, ProgressionReport? report})> train(
    int itemId,
    void Function(ExerciseEntry e) log,
  ) async {
    final wid = (await db.workoutItemById(itemId))!.workoutId;
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final c = container.read(activeWorkoutProvider.notifier);
    await c.start(workoutId: wid, name: 'Day');
    log(container.read(activeWorkoutProvider)!.exercises.single);
    final id = await c.finish();
    return (id: id, report: container.read(lastProgressionProvider));
  }

  ProgressionOutcome only(ProgressionReport? r) => r!.outcomes.single;

  test('a clean session reports the step and where the target lands', () async {
    final id = await slot();
    final out = await train(id, (e) {
      for (final s in e.sets) {
        s.cycle();
      }
    });

    expect(out.report!.sessionId, out.id, reason: 'tagged with the session it is about');
    final o = only(out.report);
    expect(o.name, 'Back Squat');
    expect(o.steppedUp, isTrue);
    expect(o.moved, 2.5);
    expect(o.target, 102.5, reason: 'the load the next session opens at');
  });

  test('a missed session holds and counts toward a back-off', () async {
    final id = await slot();
    final out = await train(id, (e) {
      for (final s in e.sets) {
        s.cycle();
      }
      e.sets.last.cycle(); // one rep short — the whole exercise misses
    });

    final o = only(out.report);
    expect(o.held, isTrue);
    expect(o.moved, 0);
    expect(o.target, 100, reason: 'held where it was');
    expect(o.failures, 1);
    expect(o.failureThreshold, 2, reason: 'one more miss to a back-off');
  });

  test('loading past the suggestion reads as a step even without a streak',
      () async {
    // successThreshold is 1, so a clean session steps anyway; force a miss and
    // still carry more than suggested, to isolate the "heavier is progress" path.
    final id = await slot(failureThreshold: 5);
    final out = await train(id, (e) {
      for (final s in e.sets) {
        s.weight = 110; // carried through every set
        s.cycle();
      }
    });

    final o = only(out.report);
    expect(o.steppedUp, isTrue);
    expect(o.target, 112.5, reason: 'stepped up from the 110 actually carried');
  });

  test('a bodyweight slot with no target makes no claim', () async {
    final id = await slot(weightKg: null);
    final out = await train(id, (e) {
      for (final s in e.sets) {
        s.cycle();
      }
    });

    expect(out.report, isNull,
        reason: 'nothing to move means no banner at all');
  });

  test('the next start clears the last report', () async {
    final id = await slot();
    await train(id, (e) {
      for (final s in e.sets) {
        s.cycle();
      }
    });

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    // A brand-new container starts empty; prove start() actively clears rather
    // than relying on that by setting a report first.
    container.read(lastProgressionProvider.notifier).set(
        ProgressionReport(sessionId: 999, outcomes: const []));
    final wid = (await db.workoutItemById(id))!.workoutId;
    await container
        .read(activeWorkoutProvider.notifier)
        .start(workoutId: wid, name: 'Day');

    expect(container.read(lastProgressionProvider), isNull);
  });
}
