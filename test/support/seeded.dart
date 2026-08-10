// Lookups over the shipped programs, shared by the progression, layoff and
// live-session feature tests so none of them hard-codes an autoincrement id or
// writes a program of its own.
//
// **The programs are no longer seeded.** A fresh install opens on an empty
// routine list; the five the app ships live in the routine library until somebody
// adds one — see `data/starter_routines.dart` and section 21. A test about
// progression or a live session still wants a real program to work against, and
// the library's own is the most honest one to use, so [routineWithCountNamed]
// installs the program it is asked for the first time it is asked. Every lookup
// below goes through it, which is why they all read exactly as they did.
//
// A test *about* the empty list, the library, or what adding a program does uses
// `memoryDb()` on its own and never comes here.
import 'package:foss_lift/data/database.dart';

/// The demo routine every seed lookup defaults to.
const kPpl = 'Push / Pull / Legs';

/// The routine with [name], added from the routine library if this database has
/// not got it yet, paired with its workout count.
Future<RoutineWithCount> routineWithCountNamed(
  AppDatabase db, [
  String name = kPpl,
]) async {
  var rows = await db.watchRoutines().first;
  if (!rows.any((r) => r.routine.name == name)) {
    await db.addStarterRoutine(
      kStarterRoutines.firstWhere((program) => program.name == name),
    );
    rows = await db.watchRoutines().first;
  }
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
