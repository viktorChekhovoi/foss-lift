import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'layoff.dart';
import 'progression.dart';
import 'schedule.dart';

export 'layoff.dart';
export 'progression.dart';
export 'schedule.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// The exercise library (Bench Press, Squat, …). Ships with a curated set;
/// users can add their own ([isCustom] == true).
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get muscleGroup => text().withDefault(const Constant('Other'))();
  TextColumn get equipment => text().withDefault(const Constant('Other'))();
  TextColumn get instructions => text().withDefault(const Constant(''))();
  TextColumn get videoUrl => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  /// Whether the movement is counted or held — see [ExerciseMeasure]. Decides
  /// which progression axes a workout may put it on.
  TextColumn get measure =>
      textEnum<ExerciseMeasure>().withDefault(const Constant('reps'))();
}

/// A training programme ("PPL", "Upper/Lower"). A routine is a container: the
/// thing you actually train is one of its [Workouts].
class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get colorHex => text().withDefault(const Constant('FF6A3D'))();
  IntColumn get position => integer().withDefault(const Constant(0))();

  /// Default rest between sets for this routine, in seconds.
  IntColumn get restSeconds => integer().withDefault(const Constant(90))();

  /// Which weekdays this routine is meant to be trained on, as the bitmask
  /// described in `schedule.dart`. Zero — the default — means no fixed days.
  IntColumn get scheduleDays =>
      integer().withDefault(const Constant(kNoScheduleMask))();

  /// Minutes past midnight for the reminder on a scheduled day, or null for no
  /// reminder. Null by default: a notification is something the user asks for,
  /// one routine at a time, not something an offline tracker starts doing.
  IntColumn get reminderMinutes => integer().nullable()();
}

/// One day within a routine ("Push", "Upper 1"). Names need not be unique — an
/// Upper/Lower split legitimately repeats "Upper" twice.
class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId =>
      integer().references(Routines, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  IntColumn get position => integer().withDefault(const Constant(0))();
}

/// One exercise slot inside a workout. Reps are stored structurally so the app
/// can express a fixed count (10), a range (6–8), or "to failure".
class WorkoutItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId =>
      integer().references(Workouts, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get position => integer().withDefault(const Constant(0))();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();

  /// Low end of the rep target (also the value used for a fixed count).
  IntColumn get repsMin => integer().withDefault(const Constant(8))();

  /// High end of the rep range. Null means a fixed count of [repsMin].
  IntColumn get repsMax => integer().nullable()();

  /// When true, the set is taken to failure ([repsMin] is the goal to beat).
  BoolColumn get toFailure => boolean().withDefault(const Constant(false))();

  /// Per-exercise rest override, in seconds. Null falls back to the routine.
  IntColumn get restSeconds => integer().nullable()();

  RealColumn get suggestedWeight => real().nullable()();

  // -- Progression ---------------------------------------------------------
  // Which number goes up when the sets go well, by how much, and how long it
  // takes. Defaults are the weight case, so an exercise nobody has configured
  // behaves like the barbell programme everyone expects.

  /// The axis this slot advances along — see [ProgressionMode].
  TextColumn get progression =>
      textEnum<ProgressionMode>().withDefault(const Constant('weight'))();

  /// The per-set hold, in seconds, when [progression] is
  /// [ProgressionMode.time]. Ignored by the other modes, which count reps.
  IntColumn get holdSeconds => integer().withDefault(const Constant(30))();

  /// How far the target moves on a step up, in the mode's own unit: kilograms,
  /// reps or seconds. Kept as a real because 2.5 kg is the smallest plate pair
  /// most gyms own.
  RealColumn get increment => real().withDefault(const Constant(2.5))();

  /// Consecutive clean sessions needed before the target goes up.
  IntColumn get successThreshold =>
      integer().withDefault(const Constant(defaultSuccessThreshold))();

  /// How far the target drops on a back-off, in the mode's own unit.
  RealColumn get deload => real().withDefault(const Constant(5))();

  /// Consecutive missed sessions before the target backs off.
  IntColumn get failureThreshold =>
      integer().withDefault(const Constant(defaultFailureThreshold))();

  /// Clean sessions since the last step up or miss.
  ///
  /// Stored rather than derived from history, unlike the next-workout
  /// suggestion: the target itself moves, so a session's success can only be
  /// judged against the goal that was live *on the day*, and replaying that
  /// from logged sets would have to reconstruct every intervening edit. The
  /// counters ride along with the thing they are counting towards instead.
  IntColumn get successStreak => integer().withDefault(const Constant(0))();

  /// Missed sessions since the last back-off or clean session.
  IntColumn get failStreak => integer().withDefault(const Constant(0))();
}

/// A logged training session — one performance of a [Workouts] row.
///
/// [routineId] and [workoutId] are deliberately plain integers rather than
/// foreign keys: deleting a template must not erase the history of having
/// trained it.
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId => integer().nullable()();
  IntColumn get workoutId => integer().nullable()();
  TextColumn get name => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  RealColumn get totalVolume => real().withDefault(const Constant(0))();
  IntColumn get setsCompleted => integer().withDefault(const Constant(0))();
}

/// A single logged set belonging to a session. `exerciseName` is denormalised
/// so history stays readable even if the library changes later. Weights are
/// always stored in kilograms; the UI converts for display.
class SessionSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(Sessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().nullable()();
  TextColumn get exerciseName => text()();
  IntColumn get setNumber => integer()();
  RealColumn get weight => real().withDefault(const Constant(0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();

  /// What the set was aiming for, captured as it was logged.
  ///
  /// Stored rather than looked up from the template later: templates get
  /// edited, and progression has to know what you were actually chasing on the
  /// day. Zero means "no goal recorded" — every set logged before schema v3.
  IntColumn get goalReps => integer().withDefault(const Constant(0))();

  /// The weight the template suggested, in kg. Null when it suggested none.
  RealColumn get goalWeight => real().nullable()();

  /// Seconds held, on a set measured in time rather than reps.
  ///
  /// A separate column rather than a reinterpretation of [reps]: a 60-second
  /// plank is not sixty repetitions, and folding it into the rep count would
  /// quietly inflate lifetime reps and volume alike. Null on a counted set.
  IntColumn get seconds => integer().nullable()();

  /// The hold the template was asking for, in seconds. Null when the set was
  /// counted in reps.
  IntColumn get goalSeconds => integer().nullable()();
}

/// A single-row key/value store for app-wide preferences (always id == 1).
class Settings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// 'kg' or 'lb'. Weights are stored in kg; this only affects display/input.
  TextColumn get weightUnit => text().withDefault(const Constant('kg'))();

  /// The routine the Today tab is currently about. Null means "not chosen yet",
  /// which makes Today fall back to a routine chooser. Not a foreign key: a
  /// dangling id after a delete resolves to null rather than failing.
  IntColumn get activeRoutineId => integer().nullable()();

  /// Days away from a workout before returning to it offers a back-off. Zero
  /// switches layoff deloads off entirely.
  IntColumn get layoffDays =>
      integer().withDefault(const Constant(kDefaultLayoffDays))();

  /// How much a layoff cuts the target for each whole period away, as a
  /// percentage — see `layoff.dart`.
  IntColumn get layoffPercent =>
      integer().withDefault(const Constant(kDefaultLayoffPercent))();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Read-model helpers
// ---------------------------------------------------------------------------

/// A routine plus how many workouts it contains (for list rows).
class RoutineWithCount {
  RoutineWithCount(this.routine, this.workoutCount);
  final Routine routine;
  final int workoutCount;
}

/// A workout plus how many exercises it contains (for list rows).
class WorkoutWithCount {
  WorkoutWithCount(this.workout, this.exerciseCount);
  final Workout workout;
  final int exerciseCount;
}

/// A workout item joined with its exercise (for the detail/builder screens).
class WorkoutItemView {
  WorkoutItemView(this.item, this.exercise);
  final WorkoutItem item;
  final Exercise exercise;
}

/// One workout as the routine builder holds it, before saving.
///
/// A null [id] is inserted; a known id is renamed and repositioned in place.
/// A null [items] leaves that workout's exercises untouched — only a list the
/// builder actually loaded and edited replaces them, so saving a routine can
/// never blank out exercises the user never opened.
typedef WorkoutDraft = ({
  int? id,
  String name,
  List<WorkoutItemsCompanion>? items,
});

/// Everything ever lifted, added up.
///
/// Derived from the logged sets on every read rather than kept as a running
/// counter: existing history counts automatically, and no stored tally can
/// drift out of step with the sets it is supposed to summarise. [volumeKg] is
/// canonical kilograms — convert at the view boundary like any other weight,
/// so switching to pounds changes the number shown and nothing else.
class LifetimeTotals {
  const LifetimeTotals({this.volumeKg = 0, this.reps = 0, this.sets = 0});
  final double volumeKg;
  final int reps;
  final int sets;
}

/// One seeded exercise slot (first-run demo data only).
typedef _SeedItem = ({String name, int sets, int min, int? max, double? w});

/// The workout a routine should suggest next, given its workouts in order and
/// the workout logged by the most recent finished session.
///
/// Derived, never stored: training out of order cannot corrupt anything,
/// because the suggestion is only ever "the one after whatever you did last".
/// Falls back to the first workout when the routine has never been trained, or
/// when the last one trained has since been deleted.
int? nextWorkoutId(List<int> orderedIds, int? lastWorkoutId) {
  if (orderedIds.isEmpty) return null;
  final i = lastWorkoutId == null ? -1 : orderedIds.indexOf(lastWorkoutId);
  if (i < 0) return orderedIds.first;
  return orderedIds[(i + 1) % orderedIds.length];
}

/// Whether a logged set fell short of what it was aiming for: fewer reps (or
/// seconds) than the goal, or a weight below the one the template suggested.
///
/// Dropping the weight counts as a miss even at full reps — deloading to finish
/// the set is exactly the failure progression needs to see. Sets logged before
/// schema v3 carry a zero goal and no goal weight, so old history never reads
/// as a failure.
bool setMissedGoal(SessionSet s) {
  final short = s.goalSeconds == null
      ? s.reps < s.goalReps
      : (s.seconds ?? 0) < s.goalSeconds!;
  return short || (s.goalWeight != null && s.weight < s.goalWeight! - 1e-9);
}

/// Human-readable set target, e.g. "10", "6–8", "45s", or "To failure".
String repsLabel(WorkoutItem it) {
  if (it.progression.timed) return '${it.holdSeconds}s';
  if (it.toFailure) return 'Failure';
  if (it.repsMax == null || it.repsMax == it.repsMin) return '${it.repsMin}';
  return '${it.repsMin}–${it.repsMax}';
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(
  tables: [
    Exercises,
    Routines,
    Workouts,
    WorkoutItems,
    Sessions,
    SessionSets,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For unit tests: pass an in-memory `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) await _migrateToWorkouts(m);
          if (from < 3) {
            // v2 → v3: logged sets start recording what they were aiming at.
            // Existing rows default to a zero goal, which reads as "no goal
            // recorded" rather than as a failed set.
            await m.addColumn(sessionSets, sessionSets.goalReps);
            await m.addColumn(sessionSets, sessionSets.goalWeight);
          }
          if (from < 4) {
            // v3 → v4: exercises gain a progression axis and the rules that
            // drive it. Every column carries a weight-progression default, so
            // exercises that predate the feature keep behaving as barbell lifts
            // without anyone having to configure them.
            await m.addColumn(workoutItems, workoutItems.progression);
            await m.addColumn(workoutItems, workoutItems.holdSeconds);
            await m.addColumn(workoutItems, workoutItems.increment);
            await m.addColumn(workoutItems, workoutItems.successThreshold);
            await m.addColumn(workoutItems, workoutItems.deload);
            await m.addColumn(workoutItems, workoutItems.failureThreshold);
            await m.addColumn(workoutItems, workoutItems.successStreak);
            await m.addColumn(workoutItems, workoutItems.failStreak);
            // Timed sets record seconds held; existing rows are all counted in
            // reps, and a null here is exactly that statement.
            await m.addColumn(sessionSets, sessionSets.seconds);
            await m.addColumn(sessionSets, sessionSets.goalSeconds);
          }
          if (from < 5) {
            // v4 → v5: the library says whether a movement is counted or held,
            // so a workout can only offer axes that mean something for it.
            await m.addColumn(exercises, exercises.measure);
            // Everything defaults to counted, which is right for all but the
            // holds in the starter library. Matched by name because that is
            // the only handle on a seeded row, and seeded rows cannot be
            // renamed from anywhere in the app.
            await customStatement(
                "UPDATE exercises SET measure = 'time' WHERE name = 'Plank'");
          }
          if (from < 6) {
            // v5 → v6: routines gain a weekly schedule and an opt-in reminder,
            // and the layoff rules get somewhere to live. Every column either
            // defaults to "off" or is nullable, so an existing install comes
            // out the far side scheduling nothing and notifying nobody.
            await m.addColumn(routines, routines.scheduleDays);
            await m.addColumn(routines, routines.reminderMinutes);
            await m.addColumn(settings, settings.layoffDays);
            await m.addColumn(settings, settings.layoffPercent);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// v1 → v2: insert a `Workouts` level between routines and their exercises.
  ///
  /// The name `workouts` used to mean "a logged session", so the old tables are
  /// renamed out of the way first. Every existing routine becomes a routine
  /// holding exactly one workout of the same name, which keeps its exercises.
  Future<void> _migrateToWorkouts(Migrator m) async {
    // 1. Logged sessions: workouts → sessions, workout_sets → session_sets.
    //    SQLite rewrites the dependent foreign-key clauses as part of a rename.
    await customStatement('ALTER TABLE workouts RENAME TO sessions');
    await customStatement('ALTER TABLE workout_sets RENAME TO session_sets');
    await customStatement(
        'ALTER TABLE session_sets RENAME COLUMN workout_id TO session_id');
    await customStatement('ALTER TABLE sessions ADD COLUMN workout_id INTEGER');

    // 2. `workouts` now means a day inside a routine — one per old routine.
    //
    //    Spelled out rather than created from the table definition: a
    //    `createTable` here would build whatever the schema looks like *today*,
    //    and every later step would then try to add columns this table already
    //    has. A migration step has to produce the shape of its own era.
    await customStatement('''
      CREATE TABLE "workouts" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "routine_id" INTEGER NOT NULL REFERENCES routines (id) ON DELETE CASCADE,
        "name" TEXT NOT NULL, "position" INTEGER NOT NULL DEFAULT 0)
    ''');
    await customStatement(
        'INSERT INTO workouts (routine_id, name, position) '
        'SELECT id, name, 0 FROM routines');

    // 3. Exercise slots hang off a workout instead of a routine.
    await customStatement('''
      CREATE TABLE "workout_items" (
        "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "workout_id" INTEGER NOT NULL REFERENCES workouts (id) ON DELETE CASCADE,
        "exercise_id" INTEGER NOT NULL REFERENCES exercises (id),
        "position" INTEGER NOT NULL DEFAULT 0,
        "target_sets" INTEGER NOT NULL DEFAULT 3,
        "reps_min" INTEGER NOT NULL DEFAULT 8, "reps_max" INTEGER NULL,
        "to_failure" INTEGER NOT NULL DEFAULT 0, "rest_seconds" INTEGER NULL,
        "suggested_weight" REAL NULL)
    ''');
    await customStatement('''
      INSERT INTO workout_items (workout_id, exercise_id, position, target_sets,
                                 reps_min, reps_max, to_failure, rest_seconds,
                                 suggested_weight)
      SELECT w.id, ri.exercise_id, ri.position, ri.target_sets, ri.reps_min,
             ri.reps_max, ri.to_failure, ri.rest_seconds, ri.suggested_weight
      FROM routine_items ri
      JOIN workouts w ON w.routine_id = ri.routine_id
    ''');
    await customStatement('DROP TABLE routine_items');

    // 4. The Today tab's current-routine pointer. Left null on upgrade: a v1
    //    user had several routines and we should not guess which one.
    await customStatement(
        'ALTER TABLE settings ADD COLUMN active_routine_id INTEGER');

    // 5. Point old history at the workout it would have been, where we can.
    await customStatement(
        'UPDATE sessions SET workout_id = ('
        'SELECT w.id FROM workouts w WHERE w.routine_id = sessions.routine_id'
        ') WHERE routine_id IS NOT NULL');
  }

  // ---- Exercise library --------------------------------------------------

  Stream<List<Exercise>> watchExercises() {
    return (select(exercises)
          ..orderBy([
            (e) => OrderingTerm(expression: e.muscleGroup),
            (e) => OrderingTerm(expression: e.name),
          ]))
        .watch();
  }

  Future<Exercise> exerciseById(int id) =>
      (select(exercises)..where((e) => e.id.equals(id))).getSingle();

  Future<int> createExercise({
    required String name,
    required String muscle,
    required String equipment,
    required String instructions,
    String? videoUrl,
    ExerciseMeasure measure = ExerciseMeasure.reps,
  }) {
    return into(exercises).insert(
      ExercisesCompanion.insert(
        name: name,
        muscleGroup: Value(muscle),
        equipment: Value(equipment),
        instructions: Value(instructions),
        videoUrl: Value(videoUrl),
        isCustom: const Value(true),
        measure: Value(measure),
      ),
    );
  }

  // ---- Routines -----------------------------------------------------------

  Stream<List<RoutineWithCount>> watchRoutines() {
    final count = workouts.id.count();
    final query = select(routines).join([
      leftOuterJoin(workouts, workouts.routineId.equalsExp(routines.id)),
    ])
      ..addColumns([count])
      ..groupBy([routines.id])
      ..orderBy([OrderingTerm(expression: routines.position)]);

    return query.watch().map(
          (rows) => rows
              .map((r) => RoutineWithCount(
                    r.readTable(routines),
                    r.read(count) ?? 0,
                  ))
              .toList(),
        );
  }

  Future<Routine> routineById(int id) =>
      (select(routines)..where((r) => r.id.equals(id))).getSingle();

  // ---- Workouts (the days inside a routine) -------------------------------

  Stream<List<WorkoutWithCount>> watchWorkoutsForRoutine(int routineId) {
    final count = workoutItems.id.count();
    final query = select(workouts).join([
      leftOuterJoin(workoutItems, workoutItems.workoutId.equalsExp(workouts.id)),
    ])
      ..where(workouts.routineId.equals(routineId))
      ..addColumns([count])
      ..groupBy([workouts.id])
      ..orderBy([OrderingTerm(expression: workouts.position)]);

    return query.watch().map(
          (rows) => rows
              .map((r) => WorkoutWithCount(
                    r.readTable(workouts),
                    r.read(count) ?? 0,
                  ))
              .toList(),
        );
  }

  Future<List<Workout>> workoutsForRoutine(int routineId) {
    return (select(workouts)
          ..where((w) => w.routineId.equals(routineId))
          ..orderBy([(w) => OrderingTerm(expression: w.position)]))
        .get();
  }

  Future<Workout> workoutById(int id) =>
      (select(workouts)..where((w) => w.id.equals(id))).getSingle();

  Stream<Workout?> watchWorkout(int id) =>
      (select(workouts)..where((w) => w.id.equals(id))).watchSingleOrNull();

  Future<int> createWorkout(int routineId, String name) async {
    final existing = await workoutsForRoutine(routineId);
    return into(workouts).insert(
      WorkoutsCompanion.insert(
        routineId: routineId,
        name: name,
        position: Value(existing.length),
      ),
    );
  }

  Future<void> renameWorkout(int id, String name) {
    return (update(workouts)..where((w) => w.id.equals(id)))
        .write(WorkoutsCompanion(name: Value(name)));
  }

  /// Deletes a workout; its exercise slots cascade away via the foreign key.
  Future<void> deleteWorkout(int id) =>
      (delete(workouts)..where((w) => w.id.equals(id))).go();

  /// Applies the routine builder's whole workout list in one transaction:
  /// workouts missing from [drafts] are deleted (taking their exercises with
  /// them), known ids are renamed and repositioned, null ids are inserted, and
  /// any draft carrying [WorkoutDraft.items] has its exercises replaced.
  ///
  /// Returns the resulting workout ids, in list order.
  Future<List<int>> replaceRoutineWorkouts(
    int routineId,
    List<WorkoutDraft> drafts,
  ) {
    return transaction(() async {
      final keep = drafts.map((d) => d.id).whereType<int>().toSet();
      final existing = await workoutsForRoutine(routineId);
      for (final w in existing) {
        if (!keep.contains(w.id)) await deleteWorkout(w.id);
      }

      final ids = <int>[];
      for (var i = 0; i < drafts.length; i++) {
        final d = drafts[i];
        final int workoutId;
        if (d.id == null) {
          workoutId = await into(workouts).insert(
            WorkoutsCompanion.insert(
              routineId: routineId,
              name: d.name,
              position: Value(i),
            ),
          );
        } else {
          workoutId = d.id!;
          await (update(workouts)..where((w) => w.id.equals(workoutId))).write(
            WorkoutsCompanion(name: Value(d.name), position: Value(i)),
          );
        }
        ids.add(workoutId);

        final items = d.items;
        if (items != null) {
          await (delete(workoutItems)
                ..where((it) => it.workoutId.equals(workoutId)))
              .go();
          for (final it in items) {
            await into(workoutItems)
                .insert(it.copyWith(workoutId: Value(workoutId)));
          }
        }
      }
      return ids;
    });
  }

  // ---- Workout items ------------------------------------------------------

  Stream<List<WorkoutItemView>> watchItemsForWorkout(int workoutId) {
    final query = select(workoutItems).join([
      innerJoin(exercises, exercises.id.equalsExp(workoutItems.exerciseId)),
    ])
      ..where(workoutItems.workoutId.equals(workoutId))
      ..orderBy([OrderingTerm(expression: workoutItems.position)]);

    return query.watch().map(
          (rows) => rows
              .map((r) => WorkoutItemView(
                    r.readTable(workoutItems),
                    r.readTable(exercises),
                  ))
              .toList(),
        );
  }

  Future<List<WorkoutItemView>> itemsForWorkout(int workoutId) async {
    final query = select(workoutItems).join([
      innerJoin(exercises, exercises.id.equalsExp(workoutItems.exerciseId)),
    ])
      ..where(workoutItems.workoutId.equals(workoutId))
      ..orderBy([OrderingTerm(expression: workoutItems.position)]);

    final rows = await query.get();
    return rows
        .map((r) =>
            WorkoutItemView(r.readTable(workoutItems), r.readTable(exercises)))
        .toList();
  }

  Future<int> _nextRoutinePosition() async {
    final maxPos = routines.position.max();
    final row = await (selectOnly(routines)..addColumns([maxPos]))
        .map((r) => r.read(maxPos))
        .getSingleOrNull();
    return (row ?? -1) + 1;
  }

  Future<int> createRoutine({
    required String name,
    required String color,
    required int restSeconds,
    int scheduleDays = kNoScheduleMask,
    int? reminderMinutes,
  }) async {
    final pos = await _nextRoutinePosition();
    return into(routines).insert(
      RoutinesCompanion.insert(
        name: name,
        colorHex: Value(color),
        position: Value(pos),
        restSeconds: Value(restSeconds),
        scheduleDays: Value(scheduleDays),
        reminderMinutes: Value(reminderMinutes),
      ),
    );
  }

  /// Rewrites a routine's own settings. The schedule and reminder are written
  /// every time, including back to null: the editor always holds the whole
  /// answer, so a null here means "no reminder", never "leave it alone".
  Future<void> updateRoutineMeta(
    int id, {
    required String name,
    required String color,
    required int restSeconds,
    int scheduleDays = kNoScheduleMask,
    int? reminderMinutes,
  }) {
    return (update(routines)..where((r) => r.id.equals(id))).write(
      RoutinesCompanion(
        name: Value(name),
        colorHex: Value(color),
        restSeconds: Value(restSeconds),
        scheduleDays: Value(scheduleDays),
        reminderMinutes: Value(reminderMinutes),
      ),
    );
  }

  /// Every routine's reminder, paired with when it was last actually trained.
  ///
  /// One query rather than a per-routine lookup because the scheduler wants the
  /// whole picture at once: it cancels and re-lays every pending notification
  /// each time anything moves, and a partial view would leave stale ones behind.
  Stream<List<RoutineReminder>> watchRoutineReminders() {
    final lastAt = sessions.startedAt.max();
    final query = select(routines).join([
      leftOuterJoin(
        sessions,
        sessions.routineId.equalsExp(routines.id) & sessions.endedAt.isNotNull(),
        useColumns: false,
      ),
    ])
      ..addColumns([lastAt])
      ..groupBy([routines.id])
      ..orderBy([OrderingTerm(expression: routines.position)]);

    return query.watch().map(
          (rows) => rows.map((r) {
            final routine = r.readTable(routines);
            return RoutineReminder(
              routineId: routine.id,
              name: routine.name,
              scheduleDays: routine.scheduleDays,
              reminderMinutes: routine.reminderMinutes,
              lastTrainedAt: r.read(lastAt),
            );
          }).toList(),
        );
  }

  /// Deletes a routine; its workouts and their items cascade away.
  Future<void> deleteRoutine(int id) =>
      (delete(routines)..where((r) => r.id.equals(id))).go();

  /// Replaces the full ordered set of items for a workout in one transaction.
  Future<void> replaceWorkoutItems(
    int workoutId,
    List<WorkoutItemsCompanion> items,
  ) {
    return transaction(() async {
      await (delete(workoutItems)..where((i) => i.workoutId.equals(workoutId)))
          .go();
      for (final it in items) {
        await into(workoutItems).insert(it);
      }
    });
  }

  // ---- Progression --------------------------------------------------------

  Future<WorkoutItem?> workoutItemById(int id) =>
      (select(workoutItems)..where((i) => i.id.equals(id))).getSingleOrNull();

  /// Advances one exercise slot after a session, per its own progression rules.
  ///
  /// [success] is the whole exercise's verdict for the session, not one set's —
  /// see `ExerciseEntry.succeeded`. [performedWeight] is the load actually
  /// carried through every set of it, which on the weight axis is allowed to
  /// raise the target on its own — see below. Returns how far the target
  /// moved, in the mode's own unit, counted from where it was before.
  ///
  /// The slot may be gone (the workout was edited while the session was in
  /// progress), in which case there is nothing to advance and nothing to say.
  Future<double> advanceProgression(
    int itemId, {
    required bool success,
    double? performedWeight,
  }) async {
    final it = await workoutItemById(itemId);
    if (it == null) return 0;

    final step = stepProgression(
      success: success,
      successes: it.successStreak,
      failures: it.failStreak,
      successThreshold: it.successThreshold,
      failureThreshold: it.failureThreshold,
      increment: it.increment,
      deload: it.deload,
    );

    var patch = WorkoutItemsCompanion(
      successStreak: Value(step.successes),
      failStreak: Value(step.failures),
    );
    var moved = 0.0;

    final mode = it.progression;
    switch (mode) {
      case ProgressionMode.weight:
        final stored = it.suggestedWeight;
        // A slot with no suggested weight is a bodyweight movement the user
        // never put a number on. Inventing one out of a step up would tell
        // them to load 2.5 kg onto a push-up.
        if (stored != null) {
          // Loading the bar past the suggestion *is* the progression: the step
          // is applied to what you actually carried, not to a number the
          // template has been left behind by. Only upwards — coming down
          // mid-session is a deload, and the failure path is what answers it.
          final base = performedWeight != null && performedWeight > stored
              ? performedWeight
              : stored;
          final to = advanceTarget(base, step.delta, mode);
          if (to != stored) patch = patch.copyWith(suggestedWeight: Value(to));
          moved = to - stored;
        }
      case ProgressionMode.reps:
        if (step.delta != 0) {
          final from = it.repsMin;
          final to = advanceTarget(from.toDouble(), step.delta, mode).round();
          patch = patch.copyWith(
            repsMin: Value(to),
            // A range keeps its width: 6–8 becomes 7–9, not 7–8.
            repsMax:
                Value(it.repsMax == null ? null : it.repsMax! + (to - from)),
          );
          moved = (to - from).toDouble();
        }
      case ProgressionMode.time:
        if (step.delta != 0) {
          final from = it.holdSeconds;
          final to = advanceTarget(from.toDouble(), step.delta, mode).round();
          patch = patch.copyWith(holdSeconds: Value(to));
          moved = (to - from).toDouble();
        }
    }

    await (update(workoutItems)..where((i) => i.id.equals(itemId))).write(patch);
    return moved;
  }

  // ---- Layoff deloads -----------------------------------------------------

  /// The back-off that returning to [workoutId] has earned, or null for none.
  ///
  /// Measured per workout rather than per routine: a split where Push comes
  /// round every week and Legs has not been touched since spring is exactly the
  /// case worth catching, and "the routine" was trained throughout. A workout
  /// that has never been trained has no gap and nothing to regress from.
  Future<LayoffDeload?> layoffFor(int workoutId, {DateTime? now}) async {
    final last = await lastTrainedAt(workoutId);
    if (last == null) return null;
    final rules = await layoffSettings();
    return layoffDeload(
      gapDays: daysBetween(last, now ?? DateTime.now()),
      thresholdDays: rules.days,
      percentPerPeriod: rules.percent,
    );
  }

  /// Cuts every slot in a workout by [percent] along its own axis, and clears
  /// the progression streaks with it.
  ///
  /// The streaks go because they are a claim about momentum, and a month off
  /// has settled that claim: the sessions either side of a layoff are not
  /// consecutive in any sense the progression rules mean. Returns how many
  /// slots actually moved — a workout of bodyweight movements with no target
  /// to cut moves nothing, and the UI should not claim otherwise.
  Future<int> applyLayoffDeload(int workoutId, int percent) {
    return transaction(() async {
      final items = await (select(workoutItems)
            ..where((i) => i.workoutId.equals(workoutId)))
          .get();

      var moved = 0;
      for (final it in items) {
        var patch = const WorkoutItemsCompanion(
          successStreak: Value(0),
          failStreak: Value(0),
        );
        final mode = it.progression;
        switch (mode) {
          case ProgressionMode.weight:
            final from = it.suggestedWeight;
            // No suggested weight is a movement nobody put a number on. There
            // is nothing to take ten percent of.
            if (from != null) {
              final to = deloadedTarget(from, percent, mode);
              if (to != from) {
                patch = patch.copyWith(suggestedWeight: Value(to));
                moved++;
              }
            }
          case ProgressionMode.reps:
            final from = it.repsMin;
            final to = deloadedTarget(from.toDouble(), percent, mode).round();
            if (to != from) {
              patch = patch.copyWith(
                repsMin: Value(to),
                // A range keeps its width, as it does on the way up.
                repsMax:
                    Value(it.repsMax == null ? null : it.repsMax! + (to - from)),
              );
              moved++;
            }
          case ProgressionMode.time:
            final from = it.holdSeconds;
            final to = deloadedTarget(from.toDouble(), percent, mode).round();
            if (to != from) {
              patch = patch.copyWith(holdSeconds: Value(to));
              moved++;
            }
        }
        await (update(workoutItems)..where((i) => i.id.equals(it.id)))
            .write(patch);
      }
      return moved;
    });
  }

  // ---- History ------------------------------------------------------------

  Stream<List<Session>> watchHistory() {
    return (select(sessions)
          ..where((s) => s.endedAt.isNotNull())
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .watch();
  }

  /// The most recently finished session of a routine, if it has ever been
  /// trained. Drives the next-workout suggestion.
  Stream<Session?> watchLastSessionForRoutine(int routineId) {
    return (select(sessions)
          ..where((s) => s.routineId.equals(routineId) & s.endedAt.isNotNull())
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// When a workout was last trained, or null if it never has been. Drives the
  /// layoff check on the way into a session.
  Future<DateTime?> lastTrainedAt(int workoutId) async {
    final row = await (select(sessions)
          ..where((s) => s.workoutId.equals(workoutId) & s.endedAt.isNotNull())
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .getSingleOrNull();
    return row?.startedAt;
  }

  Future<List<SessionSet>> setsForSession(int sessionId) {
    return (select(sessionSets)
          ..where((s) => s.sessionId.equals(sessionId))
          ..orderBy([(s) => OrderingTerm(expression: s.id)]))
        .get();
  }

  /// Persists a finished session and all of its completed sets in one tx.
  Future<int> saveSession({
    required int? routineId,
    required int? workoutId,
    required String name,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
    required double totalVolume,
    required List<SessionSetsCompanion> sets,
  }) {
    return transaction(() async {
      final sessionId = await into(sessions).insert(
        SessionsCompanion.insert(
          routineId: Value(routineId),
          workoutId: Value(workoutId),
          name: name,
          startedAt: startedAt,
          endedAt: Value(endedAt),
          durationSeconds: Value(durationSeconds),
          totalVolume: Value(totalVolume),
          setsCompleted: Value(sets.length),
        ),
      );
      for (final s in sets) {
        await into(sessionSets).insert(s.copyWith(sessionId: Value(sessionId)));
      }
      return sessionId;
    });
  }

  // ---- Aggregate stats ----------------------------------------------------

  Stream<int> watchSessionCount() {
    final countExp = sessions.id.count();
    final q = selectOnly(sessions)
      ..addColumns([countExp])
      ..where(sessions.endedAt.isNotNull());
    return q.watchSingle().map((row) => row.read(countExp) ?? 0);
  }

  /// Lifetime volume, reps and sets over every completed set of every finished
  /// session. Volume is kg·reps, in kilograms.
  Stream<LifetimeTotals> watchLifetimeTotals() {
    final volumeExp =
        (sessionSets.weight * sessionSets.reps.cast<double>()).total();
    final repsExp = sessionSets.reps.sum();
    final setsExp = sessionSets.id.count();

    final q = selectOnly(sessionSets).join([
      innerJoin(sessions, sessions.id.equalsExp(sessionSets.sessionId),
          useColumns: false),
    ])
      ..addColumns([volumeExp, repsExp, setsExp])
      ..where(sessionSets.done.equals(true) & sessions.endedAt.isNotNull());

    return q.watchSingle().map((row) => LifetimeTotals(
          volumeKg: row.read(volumeExp) ?? 0,
          reps: row.read(repsExp) ?? 0,
          sets: row.read(setsExp) ?? 0,
        ));
  }

  // ---- Settings -----------------------------------------------------------

  Stream<String> watchWeightUnit() {
    return (select(settings)..where((s) => s.id.equals(1)))
        .watchSingleOrNull()
        .map((s) => s?.weightUnit ?? 'kg');
  }

  Future<void> setWeightUnit(String unit) =>
      _writeSettings(SettingsCompanion(weightUnit: Value(unit)));

  /// The routine the Today tab is currently about, or null if none is chosen.
  Stream<int?> watchActiveRoutineId() {
    return (select(settings)..where((s) => s.id.equals(1)))
        .watchSingleOrNull()
        .map((s) => s?.activeRoutineId);
  }

  Future<void> setActiveRoutineId(int? routineId) =>
      _writeSettings(SettingsCompanion(activeRoutineId: Value(routineId)));

  /// The layoff rules, falling back to the defaults if the settings row has
  /// somehow not been written yet.
  Stream<LayoffSettings> watchLayoffSettings() {
    return (select(settings)..where((s) => s.id.equals(1)))
        .watchSingleOrNull()
        .map(_layoffOf);
  }

  Future<LayoffSettings> layoffSettings() async {
    final row = await (select(settings)..where((s) => s.id.equals(1)))
        .getSingleOrNull();
    return _layoffOf(row);
  }

  LayoffSettings _layoffOf(Setting? s) => (
        days: s?.layoffDays ?? kDefaultLayoffDays,
        percent: s?.layoffPercent ?? kDefaultLayoffPercent,
      );

  Future<void> setLayoffDays(int days) =>
      _writeSettings(SettingsCompanion(layoffDays: Value(days)));

  Future<void> setLayoffPercent(int percent) =>
      _writeSettings(SettingsCompanion(layoffPercent: Value(percent)));

  /// Updates the single settings row, creating it if it is somehow missing.
  /// Only the columns present in [patch] are touched.
  Future<void> _writeSettings(SettingsCompanion patch) {
    return into(settings).insert(
      patch.copyWith(id: const Value(1)),
      onConflict: DoUpdate((_) => patch),
    );
  }

  // ---- Seed ---------------------------------------------------------------

  Future<void> _seed() async {
    await into(settings).insert(
      const SettingsCompanion(id: Value(1), weightUnit: Value('kg')),
      mode: InsertMode.insertOrIgnore,
    );

    // A curated starter library. Each ships with a one-line cue and a demo
    // link (a YouTube search, so the link never rots).
    final ids = <String, int>{};
    final measures = <String, ExerciseMeasure>{};
    Future<int> ex(
      String name,
      String muscle,
      String equip,
      String how, {
      ExerciseMeasure measure = ExerciseMeasure.reps,
    }) async {
      measures[name] = measure;
      return ids[name] ??= await into(exercises).insert(
        ExercisesCompanion.insert(
          name: name,
          muscleGroup: Value(muscle),
          equipment: Value(equip),
          instructions: Value(how),
          measure: Value(measure),
          videoUrl: Value(
            'https://www.youtube.com/results?search_query='
            '${Uri.encodeQueryComponent('$name proper form')}',
          ),
        ),
      );
    }

    // Chest
    await ex('Bench Press', 'Chest', 'Barbell',
        'Lie flat, lower the bar to mid-chest, and press up while keeping your shoulder blades pinched.');
    await ex('Incline DB Press', 'Chest', 'Dumbbell',
        'On a 30° bench, press the dumbbells up and slightly together without clanking them.');
    await ex('Push-Up', 'Chest', 'Bodyweight',
        'Keep a straight line from head to heels; lower until your chest nearly touches the floor.');
    await ex('Cable Fly', 'Chest', 'Cable',
        'With a slight elbow bend, sweep the handles together in a wide hugging arc.');
    await ex('Machine Chest Press', 'Chest', 'Machine',
        'Set the seat so the handles are at mid-chest, then press without locking out hard.');
    // Back
    await ex('Deadlift', 'Back', 'Barbell',
        'Brace your core, push the floor away, and drag the bar up your legs to a tall lockout.');
    await ex('Pull-Up', 'Back', 'Bodyweight',
        'Start from a dead hang and pull your chest toward the bar, leading with your elbows.');
    await ex('Barbell Row', 'Back', 'Barbell',
        'Hinge to ~45°, keep a flat back, and row the bar to your lower ribs.');
    await ex('Lat Pulldown', 'Back', 'Cable',
        'Pull the bar to your upper chest, driving your elbows down and back.');
    await ex('Seated Cable Row', 'Back', 'Cable',
        'Sit tall, pull to your stomach, and squeeze your shoulder blades together.');
    await ex('Face Pull', 'Back', 'Cable',
        'Pull the rope toward your face, splitting the ends apart at eye level.');
    // Shoulders
    await ex('Overhead Press', 'Shoulders', 'Barbell',
        'Press the bar overhead in a straight line, moving your head "through the window" at lockout.');
    await ex('Lateral Raise', 'Shoulders', 'Dumbbell',
        'Raise the dumbbells out to the sides to shoulder height, leading with your elbows.');
    await ex('Rear Delt Fly', 'Shoulders', 'Dumbbell',
        'Hinge forward and raise the dumbbells out wide, squeezing your rear delts.');
    await ex('Arnold Press', 'Shoulders', 'Dumbbell',
        'Start palms-in at your chest, rotate out as you press overhead.');
    // Legs
    await ex('Back Squat', 'Legs', 'Barbell',
        'Brace, sit down between your hips to at least parallel, and drive up through mid-foot.');
    await ex('Front Squat', 'Legs', 'Barbell',
        'Keep your elbows high and torso upright as you squat down and stand.');
    await ex('Romanian Deadlift', 'Legs', 'Barbell',
        'Push your hips back with soft knees until you feel a hamstring stretch, then stand tall.');
    await ex('Leg Press', 'Legs', 'Machine',
        'Lower until your knees reach ~90°, then press without locking out sharply.');
    await ex('Leg Curl', 'Legs', 'Machine',
        'Curl the pad toward your glutes with control; don’t let it snap back.');
    await ex('Leg Extension', 'Legs', 'Machine',
        'Extend your knees fully and pause briefly at the top.');
    await ex('Calf Raise', 'Legs', 'Machine',
        'Rise onto your toes as high as possible, pause, then lower for a full stretch.');
    await ex('Walking Lunge', 'Legs', 'Dumbbell',
        'Step forward and lower your back knee toward the floor, then drive through your front heel.');
    // Arms
    await ex('Barbell Curl', 'Arms', 'Barbell',
        'Curl the bar with your elbows pinned to your sides; no swinging.');
    await ex('Dumbbell Curl', 'Arms', 'Dumbbell',
        'Curl and supinate (turn your pinky up) at the top of each rep.');
    await ex('Hammer Curl', 'Arms', 'Dumbbell',
        'Curl with a neutral (palms-facing) grip to hit the forearms and biceps.');
    await ex('Triceps Pushdown', 'Arms', 'Cable',
        'Keep your elbows tucked and push down until your arms are fully straight.');
    await ex('Skull Crusher', 'Arms', 'Barbell',
        'Lower the bar toward your forehead by bending only at the elbows, then extend.');
    // Core
    // The one held movement in the starter library: no rep count to progress,
    // so the only axis it offers is time.
    await ex('Plank', 'Core', 'Bodyweight',
        'Hold a straight line on your forearms; squeeze your glutes and brace your abs.',
        measure: ExerciseMeasure.time);
    await ex('Hanging Leg Raise', 'Core', 'Bodyweight',
        'From a hang, raise your legs to hip height (or higher) without swinging.');
    await ex('Cable Crunch', 'Core', 'Cable',
        'Kneel and crunch your ribs toward your hips, rounding your spine.');

    // Two starter programmes, each split into its training days. Upper/Lower
    // deliberately repeats a day name — that is legal and worth demonstrating.
    Future<int> routine(
      String name,
      String color,
      int pos,
      int rest,
      List<({String name, List<_SeedItem> items})> days, {
      int schedule = kNoScheduleMask,
    }) async {
      final rid = await into(routines).insert(
        RoutinesCompanion.insert(
          name: name,
          colorHex: Value(color),
          position: Value(pos),
          restSeconds: Value(rest),
          scheduleDays: Value(schedule),
        ),
      );
      var dayPos = 0;
      for (final day in days) {
        final wid = await into(workouts).insert(
          WorkoutsCompanion.insert(
            routineId: rid,
            name: day.name,
            position: Value(dayPos++),
          ),
        );
        var i = 0;
        for (final it in day.items) {
          // A held movement can only progress on time. Otherwise: a slot with
          // no suggested load has nothing to add load to, so it progresses on
          // reps — the right answer for the pull-ups and leg raises that make
          // up every one of them here.
          final measure = measures[it.name] ?? ExerciseMeasure.reps;
          final mode = measure.coerce(
              it.w == null ? ProgressionMode.reps : ProgressionMode.weight);
          await into(workoutItems).insert(
            WorkoutItemsCompanion.insert(
              workoutId: wid,
              exerciseId: ids[it.name]!,
              position: Value(i++),
              targetSets: Value(it.sets),
              repsMin: Value(it.min),
              repsMax: Value(it.max),
              suggestedWeight: Value(it.w),
              progression: Value(mode),
              increment: Value(mode.defaultIncrement),
              deload: Value(mode.defaultDeload),
            ),
          );
        }
      }
      return rid;
    }

    final ppl = await routine('Push / Pull / Legs', 'FF6A3D', 0, 120, [
      (name: 'Push', items: [
        (name: 'Bench Press', sets: 4, min: 6, max: 8, w: 80),
        (name: 'Overhead Press', sets: 4, min: 8, max: null, w: 50),
        (name: 'Incline DB Press', sets: 3, min: 10, max: 12, w: 30),
        (name: 'Lateral Raise', sets: 3, min: 15, max: null, w: 12),
        (name: 'Triceps Pushdown', sets: 3, min: 12, max: 15, w: 35),
      ]),
      (name: 'Pull', items: [
        (name: 'Deadlift', sets: 3, min: 5, max: null, w: 140),
        (name: 'Pull-Up', sets: 4, min: 6, max: 10, w: null),
        (name: 'Barbell Row', sets: 4, min: 8, max: null, w: 70),
        (name: 'Face Pull', sets: 3, min: 15, max: 20, w: 25),
        (name: 'Barbell Curl', sets: 3, min: 10, max: 12, w: 30),
      ]),
      (name: 'Legs', items: [
        (name: 'Back Squat', sets: 4, min: 6, max: null, w: 110),
        (name: 'Romanian Deadlift', sets: 3, min: 10, max: null, w: 90),
        (name: 'Leg Press', sets: 3, min: 12, max: 15, w: 180),
        (name: 'Leg Curl', sets: 3, min: 12, max: null, w: 45),
        (name: 'Calf Raise', sets: 4, min: 15, max: 20, w: 60),
      ]),
      // Mondays, Wednesdays and Fridays — a schedule on one of the two demo
      // routines and none on the other, so both states of the setting are
      // visible before anyone has configured anything. No reminder either way:
      // notifications are asked for, never assumed.
    ], schedule: 1 << 0 | 1 << 2 | 1 << 4);

    await routine('Upper / Lower', '3ED598', 1, 150, [
      (name: 'Upper 1', items: [
        (name: 'Bench Press', sets: 4, min: 5, max: null, w: 80),
        (name: 'Barbell Row', sets: 4, min: 6, max: 8, w: 70),
        (name: 'Overhead Press', sets: 3, min: 8, max: 10, w: 45),
        (name: 'Lat Pulldown', sets: 3, min: 10, max: 12, w: 55),
      ]),
      (name: 'Lower 1', items: [
        (name: 'Back Squat', sets: 4, min: 5, max: null, w: 110),
        (name: 'Romanian Deadlift', sets: 3, min: 8, max: 10, w: 90),
        (name: 'Leg Curl', sets: 3, min: 12, max: null, w: 45),
        (name: 'Calf Raise', sets: 4, min: 15, max: 20, w: 60),
      ]),
      (name: 'Upper 2', items: [
        (name: 'Incline DB Press', sets: 4, min: 8, max: 10, w: 30),
        (name: 'Pull-Up', sets: 4, min: 6, max: 10, w: null),
        (name: 'Lateral Raise', sets: 3, min: 15, max: null, w: 12),
        (name: 'Hammer Curl', sets: 3, min: 10, max: 12, w: 14),
      ]),
      (name: 'Lower 2', items: [
        (name: 'Deadlift', sets: 3, min: 5, max: null, w: 140),
        (name: 'Front Squat', sets: 3, min: 8, max: 10, w: 70),
        (name: 'Leg Press', sets: 3, min: 12, max: 15, w: 180),
        (name: 'Hanging Leg Raise', sets: 3, min: 10, max: null, w: null),
      ]),
    ]);

    // Give Today something to be about on first launch.
    await setActiveRoutineId(ppl);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'foss_lift.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
