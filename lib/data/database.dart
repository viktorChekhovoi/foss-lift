import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

/// One seeded exercise slot (first-run demo data only).
typedef _SeedItem = ({String name, int sets, int min, int? max, double? w});

/// Human-readable rep target, e.g. "10", "6–8", or "To failure".
String repsLabel(WorkoutItem it) {
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) await _migrateToWorkouts(m);
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
    await m.createTable(workouts);
    await customStatement(
        'INSERT INTO workouts (routine_id, name, position) '
        'SELECT id, name, 0 FROM routines');

    // 3. Exercise slots hang off a workout instead of a routine.
    await m.createTable(workoutItems);
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
  }) {
    return into(exercises).insert(
      ExercisesCompanion.insert(
        name: name,
        muscleGroup: Value(muscle),
        equipment: Value(equipment),
        instructions: Value(instructions),
        videoUrl: Value(videoUrl),
        isCustom: const Value(true),
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
  }) async {
    final pos = await _nextRoutinePosition();
    return into(routines).insert(
      RoutinesCompanion.insert(
        name: name,
        colorHex: Value(color),
        position: Value(pos),
        restSeconds: Value(restSeconds),
      ),
    );
  }

  Future<void> updateRoutineMeta(
    int id, {
    required String name,
    required String color,
    required int restSeconds,
  }) {
    return (update(routines)..where((r) => r.id.equals(id))).write(
      RoutinesCompanion(
        name: Value(name),
        colorHex: Value(color),
        restSeconds: Value(restSeconds),
      ),
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

  // ---- History ------------------------------------------------------------

  Stream<List<Session>> watchHistory() {
    return (select(sessions)
          ..where((s) => s.endedAt.isNotNull())
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .watch();
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
    Future<int> ex(
      String name,
      String muscle,
      String equip,
      String how,
    ) async {
      return ids[name] ??= await into(exercises).insert(
        ExercisesCompanion.insert(
          name: name,
          muscleGroup: Value(muscle),
          equipment: Value(equip),
          instructions: Value(how),
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
    await ex('Plank', 'Core', 'Bodyweight',
        'Hold a straight line on your forearms; squeeze your glutes and brace your abs.');
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
      List<({String name, List<_SeedItem> items})> days,
    ) async {
      final rid = await into(routines).insert(
        RoutinesCompanion.insert(
          name: name,
          colorHex: Value(color),
          position: Value(pos),
          restSeconds: Value(rest),
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
          await into(workoutItems).insert(
            WorkoutItemsCompanion.insert(
              workoutId: wid,
              exerciseId: ids[it.name]!,
              position: Value(i++),
              targetSets: Value(it.sets),
              repsMin: Value(it.min),
              repsMax: Value(it.max),
              suggestedWeight: Value(it.w),
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
    ]);

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
