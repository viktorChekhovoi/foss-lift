import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/state/active_workout.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

/// What the rules do to a real template: which number moves, how far, and what
/// a session's sets have to look like for it to move at all.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// A one-exercise workout in its own routine, configured to taste.
  ///
  /// The exercise follows the axis: a squat for load and reps, a plank for
  /// time, because the library decides which axes a movement may go on and
  /// there is no such thing as a timed squat.
  Future<int> slot({
    ProgressionMode mode = ProgressionMode.weight,
    int sets = 3,
    int repsMin = 5,
    int? repsMax,
    bool toFailure = false,
    double? weightKg = 100,
    int holdSeconds = 30,
    double? increment,
    double? deload,
    int successThreshold = defaultSuccessThreshold,
    int failureThreshold = defaultFailureThreshold,
  }) async {
    final ex = (await db.watchExercises().first).firstWhere(
        (e) => e.name == (mode.timed ? 'Plank' : 'Back Squat'));
    final rid = await db.createRoutine(
        name: 'Test', color: 'FF6A3D', restSeconds: 90);
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
            repsMax: repsMax,
            toFailure: toFailure,
            weightKg: weightKg,
            progression: mode,
            holdSeconds: holdSeconds,
            increment: increment,
            deload: deload,
            successThreshold: successThreshold,
            failureThreshold: failureThreshold,
          ),
        ],
        workoutId: wid,
      ),
    );
    return (await db.itemsForWorkout(wid)).single.item.id;
  }

  Future<WorkoutItem> read(int id) async => (await db.workoutItemById(id))!;

  group('the weight axis', () {
    test('a clean session adds the increment to the suggested weight',
        () async {
      final id = await slot();
      final moved = await db.advanceProgression(id, success: true);

      expect(moved, 2.5);
      expect((await read(id)).suggestedWeight, 102.5);
    });

    test('two misses in a row back the weight off', () async {
      final id = await slot();

      expect(await db.advanceProgression(id, success: false), 0,
          reason: 'one bad session is a bad night, not a deload');
      expect((await read(id)).suggestedWeight, 100);
      expect((await read(id)).failStreak, 1);

      expect(await db.advanceProgression(id, success: false), -5);
      expect((await read(id)).suggestedWeight, 95);
      expect((await read(id)).failStreak, 0);
    });

    test('a good session between two bad ones cancels the deload', () async {
      final id = await slot(successThreshold: 5);
      await db.advanceProgression(id, success: false);
      await db.advanceProgression(id, success: true);
      await db.advanceProgression(id, success: false);

      expect((await read(id)).suggestedWeight, 100, reason: 'still holding');
      expect((await read(id)).failStreak, 1);
    });

    test('a bodyweight slot has no weight target to move', () async {
      // Stepping a null suggestion up would tell the user to load 2.5 kg onto
      // a pull-up they never put a number on.
      final id = await slot(weightKg: null);
      expect(await db.advanceProgression(id, success: true), 0);
      expect((await read(id)).suggestedWeight, isNull);
    });

    test('repeated back-offs stop at an empty bar, not below it', () async {
      final id = await slot(weightKg: 3, failureThreshold: 1);
      await db.advanceProgression(id, success: false);
      expect((await read(id)).suggestedWeight, 0);
    });
  });

  group('the reps axis', () {
    test('a clean session adds a rep at the same load', () async {
      final id = await slot(mode: ProgressionMode.reps, repsMin: 6);
      final moved = await db.advanceProgression(id, success: true);

      final it = await read(id);
      expect(moved, 1);
      expect(it.repsMin, 7);
      expect(it.suggestedWeight, 100, reason: 'the load is what stays fixed');
    });

    test('a rep range keeps its width', () async {
      final id =
          await slot(mode: ProgressionMode.reps, repsMin: 6, repsMax: 8);
      await db.advanceProgression(id, success: true);

      final it = await read(id);
      expect([it.repsMin, it.repsMax], [7, 9]);
    });

    test('backing off cannot drive the target below one rep', () async {
      final id = await slot(
          mode: ProgressionMode.reps, repsMin: 2, failureThreshold: 1);
      await db.advanceProgression(id, success: false);
      expect((await read(id)).repsMin, 1);
    });
  });

  group('the time axis', () {
    test('a clean session adds to the hold', () async {
      final id = await slot(mode: ProgressionMode.time, holdSeconds: 45);
      final moved = await db.advanceProgression(id, success: true);

      expect(moved, 5);
      expect((await read(id)).holdSeconds, 50);
    });

    test('backing off cannot drive the hold to nothing', () async {
      final id = await slot(
          mode: ProgressionMode.time, holdSeconds: 8, failureThreshold: 1);
      await db.advanceProgression(id, success: false);
      expect((await read(id)).holdSeconds, 5);
    });

    test('a slot deleted mid-session is simply not advanced', () async {
      final id = await slot();
      final wid = (await read(id)).workoutId;
      await db.replaceWorkoutItems(wid, const []);

      expect(await db.advanceProgression(id, success: true), 0);
    });
  });

  group('what a session has to look like to count', () {
    /// Runs the whole live-session path — start, log the sets the way a thumb
    /// would, finish — so the verdict is the one the app actually reaches
    /// rather than one assembled by hand. Returns the new session id.
    Future<int?> train(int itemId, void Function(ExerciseEntry e) log) async {
      final wid = (await read(itemId)).workoutId;
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final c = container.read(activeWorkoutProvider.notifier);
      await c.start(workoutId: wid, name: 'Day');
      log(container.read(activeWorkoutProvider)!.exercises.single);
      return c.finish();
    }

    test('every set at the goal is a success', () async {
      final id = await slot();
      await train(id, (e) {
        for (final s in e.sets) {
          s.cycle();
        }
      });
      expect((await read(id)).suggestedWeight, 102.5);
    });

    test('one set short of the goal fails the whole exercise', () async {
      final id = await slot();
      await train(id, (e) {
        for (final s in e.sets) {
          s.cycle();
        }
        e.sets.last.cycle(); // one rep down
      });
      expect((await read(id)).suggestedWeight, 100);
      expect((await read(id)).failStreak, 1);
    });

    test('a skipped set fails it too', () async {
      // The programme asked for three and got two. That is not the session the
      // next step up should be built on.
      final id = await slot();
      await train(id, (e) {
        e.sets[0].cycle();
        e.sets[1].cycle();
      });
      expect((await read(id)).failStreak, 1);
    });

    test('finishing a set at a reduced weight is a miss', () async {
      // The #8 rule: deloading mid-session to get the reps is still a deload.
      final id = await slot();
      await train(id, (e) {
        for (final s in e.sets) {
          s.cycle();
        }
        e.sets.last.weight = 90;
      });
      expect((await read(id)).failStreak, 1);
    });

    test('beating the goal is a success, not an anomaly', () async {
      final id = await slot(toFailure: true, repsMin: 8);
      await train(id, (e) {
        for (final s in e.sets) {
          s.logged = 12;
        }
      });
      expect((await read(id)).suggestedWeight, 102.5,
          reason: 'a to-failure set succeeds by clearing the reps to beat');
    });

    test('a to-failure set short of its rep floor is a miss', () async {
      final id = await slot(toFailure: true, repsMin: 8);
      await train(id, (e) {
        for (final s in e.sets) {
          s.logged = 6;
        }
      });
      expect((await read(id)).failStreak, 1);
    });

    test('a timed set is judged on seconds held', () async {
      final id = await slot(mode: ProgressionMode.time, holdSeconds: 45);
      final sessionId = await train(id, (e) {
        for (final s in e.sets) {
          s.logged = 45;
        }
      });
      expect((await read(id)).holdSeconds, 50);

      // Held time is logged as time. Folding it into the rep count would make
      // a 45-second plank read as forty-five repetitions of something.
      final logged = await db.setsForSession(sessionId!);
      expect(logged.every((s) => s.seconds == 45 && s.goalSeconds == 45), isTrue);
      expect(logged.every((s) => s.reps == 0 && s.goalReps == 0), isTrue);
      expect(logged.any(setMissedGoal), isFalse);

      await train(id, (e) {
        for (final s in e.sets) {
          s.logged = 30;
        }
      });
      expect((await read(id)).failStreak, 1);
    });

    test('a timed session adds nothing to lifetime reps or volume', () async {
      final id = await slot(
          mode: ProgressionMode.time, holdSeconds: 45, weightKg: null);
      await train(id, (e) {
        for (final s in e.sets) {
          s.logged = 45;
        }
      });

      final t = await db.watchLifetimeTotals().first;
      expect(t.sets, 3, reason: 'the sets happened');
      expect(t.reps, 0);
      expect(t.volumeKg, 0);
    });
  });

  group('loading the bar past the suggestion', () {
    /// Trains the slot with every set logged at [weights], in order.
    Future<void> trainAt(int itemId, List<double> weights) async {
      final wid = (await read(itemId)).workoutId;
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final c = container.read(activeWorkoutProvider.notifier);
      await c.start(workoutId: wid, name: 'Day');
      final e = container.read(activeWorkoutProvider)!.exercises.single;
      for (var i = 0; i < e.sets.length; i++) {
        e.sets[i].weight = weights[i];
        e.sets[i].cycle();
      }
      await c.finish();
    }

    test('a session done heavier steps up from the heavier weight', () async {
      // You put 105 on the bar instead of the 100 the template asked for and
      // finished the sets. The next target is built on 105, not on 100.
      final id = await slot();
      await trainAt(id, [105, 105, 105]);
      expect((await read(id)).suggestedWeight, 107.5);
    });

    test('the lightest set is the working weight, not the heaviest', () async {
      // One heavy set is a heavy single. What you carried through the whole
      // exercise is the lighter number.
      final id = await slot();
      await trainAt(id, [105, 110, 105]);
      expect((await read(id)).suggestedWeight, 107.5);
    });

    test('bumping a single set does not move the working weight', () async {
      final id = await slot();
      await trainAt(id, [100, 105, 100]);
      expect((await read(id)).suggestedWeight, 102.5,
          reason: 'stepped up from 100, the weight actually held throughout');
    });

    test('the heavier weight is adopted even before a step is earned',
        () async {
      // Three clean sessions to a step: the first two do not move the target
      // on their own, but they must not pretend you are still on 100.
      final id = await slot(successThreshold: 3);
      await trainAt(id, [105, 105, 105]);

      final it = await read(id);
      expect(it.suggestedWeight, 105);
      expect(it.successStreak, 1);
    });

    test('a back-off comes off the weight you were actually training at',
        () async {
      final id = await slot(failureThreshold: 1);
      // Heavier bar, but short on reps — a miss at 110, not a miss at 100.
      final wid = (await read(id)).workoutId;
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final c = container.read(activeWorkoutProvider.notifier);
      await c.start(workoutId: wid, name: 'Day');
      for (final s in container.read(activeWorkoutProvider)!.exercises.single.sets) {
        s.weight = 110;
        s.logged = 3;
      }
      await c.finish();

      expect((await read(id)).suggestedWeight, 105, reason: '110 less 5');
    });

    test('coming down mid-session does not drag the target with it', () async {
      // Deloading to finish is a miss, and the failure path answers it. The
      // stored target must not quietly follow the bar down as well.
      final id = await slot();
      await trainAt(id, [100, 90, 90]);

      final it = await read(id);
      expect(it.suggestedWeight, 100);
      expect(it.failStreak, 1);
    });

    test('a bodyweight slot is still left alone', () async {
      // Typing a number into the live weight field of a slot that never had a
      // suggestion is not the same as setting one.
      final id = await slot(weightKg: null);
      await trainAt(id, [20, 20, 20]);
      expect((await read(id)).suggestedWeight, isNull);
    });

    test('the reps axis keeps its fixed load', () async {
      // Adding load is not how this exercise progresses, so a heavier session
      // buys a rep, not a heavier suggestion.
      final id = await slot(mode: ProgressionMode.reps, repsMin: 6);
      await trainAt(id, [105, 105, 105]);

      final it = await read(id);
      expect(it.repsMin, 7);
      expect(it.suggestedWeight, 100);
    });
  });

  group('editing a workout', () {
    test('does not reset a pending back-off', () async {
      // Saving a workout rewrites its items wholesale. A draft that dropped the
      // streaks would forgive a miss every time the user renamed the day.
      final id = await slot();
      await db.advanceProgression(id, success: false);
      final wid = (await read(id)).workoutId;

      final drafts = (await db.itemsForWorkout(wid))
          .map(ItemDraft.fromView)
          .toList();
      await db.replaceWorkoutItems(wid, itemCompanions(drafts, workoutId: wid));

      final after = (await db.itemsForWorkout(wid)).single.item;
      expect(after.failStreak, 1);
      expect(after.progression, ProgressionMode.weight);
      expect(after.increment, 2.5);
    });
  });

  test('the seed gives loadless exercises a rep progression', () async {
    // Nothing to add load to, so "add 2.5 kg" would be a dead rule.
    final ppl = (await db.watchRoutines().first).first.routine;
    final pull = (await db.workoutsForRoutine(ppl.id))[1];
    final items = await db.itemsForWorkout(pull.id);

    final pullUp = items.firstWhere((i) => i.exercise.name == 'Pull-Up').item;
    expect(pullUp.progression, ProgressionMode.reps);
    expect(pullUp.increment, 1);
    expect(pullUp.deload, 2);

    final deadlift = items.firstWhere((i) => i.exercise.name == 'Deadlift').item;
    expect(deadlift.progression, ProgressionMode.weight);
    expect(deadlift.increment, 2.5);
  });
}
