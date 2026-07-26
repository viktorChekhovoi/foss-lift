// Lookups over the first-install seed data, shared by the progression and
// layoff feature tests so neither hard-codes an autoincrement id. The seed
// builds "Push / Pull / Legs" first, but ids are still resolved by name here so
// a change to the seed order cannot quietly break every test at once.
import 'package:foss_lift/data/database.dart';

/// The demo routine every seed lookup defaults to.
const kPpl = 'Push / Pull / Legs';

/// The seeded routine with [name], paired with its workout count.
Future<RoutineWithCount> routineWithCountNamed(
  AppDatabase db, [
  String name = kPpl,
]) async {
  final rows = await db.watchRoutines().first;
  return rows.firstWhere((r) => r.routine.name == name);
}

/// The seeded routine with [name].
Future<Routine> routineNamed(AppDatabase db, [String name = kPpl]) async =>
    (await routineWithCountNamed(db, name)).routine;

/// The workout (training day) called [workout] inside routine [routine].
Future<Workout> workoutNamed(
  AppDatabase db,
  String workout, {
  String routine = kPpl,
}) async {
  final r = await routineNamed(db, routine);
  final ws = await db.workoutsForRoutine(r.id);
  return ws.firstWhere((w) => w.name == workout);
}

/// Just the id of the [workout] day inside [routine].
Future<int> workoutIdNamed(
  AppDatabase db,
  String workout, {
  String routine = kPpl,
}) async => (await workoutNamed(db, workout, routine: routine)).id;

/// The slot for [exercise] inside the [workout] day, joined with its exercise.
Future<WorkoutItemView> slotNamed(
  AppDatabase db,
  String workout,
  String exercise, {
  String routine = kPpl,
}) async {
  final w = await workoutNamed(db, workout, routine: routine);
  final items = await db.itemsForWorkout(w.id);
  return items.firstWhere((v) => v.exercise.name == exercise);
}

/// Just the id of the [exercise] slot in the [workout] day.
Future<int> slotIdNamed(
  AppDatabase db,
  String workout,
  String exercise, {
  String routine = kPpl,
}) async => (await slotNamed(db, workout, exercise, routine: routine)).item.id;

/// The seeded library exercise called [name].
Future<Exercise> exerciseNamed(AppDatabase db, String name) async {
  final all = await db.watchExercises().first;
  return all.firstWhere((e) => e.name == name);
}
