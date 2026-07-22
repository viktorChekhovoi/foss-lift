import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';

/// Covers the fresh-install path: `onCreate` + the starter seed, in the
/// routine → workout → exercise shape.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('seeds two routines, counted by workout', () async {
    final routines = await db.watchRoutines().first;
    expect(routines.map((r) => r.routine.name),
        ['Push / Pull / Legs', 'Upper / Lower']);
    expect(routines.map((r) => r.workoutCount), [3, 4]);
  });

  test('a routine holds its workouts in order', () async {
    final ppl = (await db.watchRoutines().first).first.routine;
    final workouts = await db.workoutsForRoutine(ppl.id);
    expect(workouts.map((w) => w.name), ['Push', 'Pull', 'Legs']);
    expect(workouts.map((w) => w.position), [0, 1, 2]);
  });

  test('workout names may repeat within a routine', () async {
    final ul = (await db.watchRoutines().first).last.routine;
    final names = (await db.workoutsForRoutine(ul.id)).map((w) => w.name);
    expect(names, ['Upper 1', 'Lower 1', 'Upper 2', 'Lower 2']);
  });

  test('exercises hang off the workout, not the routine', () async {
    final ppl = (await db.watchRoutines().first).first.routine;
    final push = (await db.workoutsForRoutine(ppl.id)).first;
    final items = await db.itemsForWorkout(push.id);

    expect(items.first.exercise.name, 'Bench Press');
    expect(items.first.item.targetSets, 4);
    expect(items.map((i) => i.item.position), [0, 1, 2, 3, 4]);
  });

  test('deleting a routine takes its workouts and items with it', () async {
    final ppl = (await db.watchRoutines().first).first.routine;
    final push = (await db.workoutsForRoutine(ppl.id)).first;

    await db.deleteRoutine(ppl.id);

    expect(await db.workoutsForRoutine(ppl.id), isEmpty);
    expect(await db.itemsForWorkout(push.id), isEmpty);
    expect(await db.watchRoutines().first, hasLength(1));
  });

  test('a fresh install starts with the first routine current', () async {
    final ppl = (await db.watchRoutines().first).first.routine;
    expect(await db.watchActiveRoutineId().first, ppl.id);
  });

  test('setting the current routine leaves the weight unit alone', () async {
    await db.setWeightUnit('lb');
    final ul = (await db.watchRoutines().first).last.routine;
    await db.setActiveRoutineId(ul.id);

    expect(await db.watchActiveRoutineId().first, ul.id);
    expect(await db.watchWeightUnit().first, 'lb');
  });

  test('setting the weight unit leaves the current routine alone', () async {
    final ul = (await db.watchRoutines().first).last.routine;
    await db.setActiveRoutineId(ul.id);
    await db.setWeightUnit('lb');

    expect(await db.watchActiveRoutineId().first, ul.id);
  });

  test('the current routine can be cleared', () async {
    await db.setActiveRoutineId(null);
    expect(await db.watchActiveRoutineId().first, isNull);
  });

  test('deleting the current routine leaves a dangling id, not a crash',
      () async {
    final ppl = (await db.watchRoutines().first).first.routine;
    await db.deleteRoutine(ppl.id);

    // The pointer survives the delete; the UI resolves it against the routine
    // list and falls back to the chooser when it no longer matches.
    expect(await db.watchActiveRoutineId().first, ppl.id);
    final remaining = await db.watchRoutines().first;
    expect(remaining.any((r) => r.routine.id == ppl.id), isFalse);
  });

  test('replaceRoutineWorkouts keeps exercises of workouts it retains',
      () async {
    final ppl = (await db.watchRoutines().first).first.routine;
    final before = await db.workoutsForRoutine(ppl.id);
    final push = before.first;
    final pushItems = await db.itemsForWorkout(push.id);

    // Drop "Legs", rename "Pull", reorder, and add a new day.
    await db.replaceRoutineWorkouts(ppl.id, [
      (id: before[1].id, name: 'Pull A'),
      (id: push.id, name: 'Push'),
      (id: null, name: 'Arms'),
    ]);

    final after = await db.workoutsForRoutine(ppl.id);
    expect(after.map((w) => w.name), ['Pull A', 'Push', 'Arms']);
    expect(await db.itemsForWorkout(push.id), hasLength(pushItems.length));
    expect(await db.itemsForWorkout(before[2].id), isEmpty);
  });
}
