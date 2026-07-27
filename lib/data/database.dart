import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'exercise_stats.dart';
import 'layoff.dart';
import 'plates.dart';
import 'progression.dart';
import 'schedule.dart';

export 'exercise_stats.dart';
export 'exercise_taxonomy.dart';
export 'layoff.dart';
export 'plates.dart';
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
  TextColumn get videoUrl => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  /// Whether the movement is counted or held — see [ExerciseMeasure]. Decides
  /// which progression axes a workout may put it on.
  TextColumn get measure =>
      textEnum<ExerciseMeasure>().withDefault(const Constant('reps'))();

  /// How the load is arranged — see [WeightType]. Decides what the weight
  /// column *means*, and so whether it can be broken down into plates.
  ///
  /// Defaults to [WeightType.machine]: the number is the number, which is the
  /// only reading that is never wrong.
  TextColumn get weightType =>
      textEnum<WeightType>().withDefault(const Constant('machine'))();

  /// What *this* movement's bar weighs, in kg, when the gym's default is wrong
  /// for it. Null — the usual case — means the default from settings.
  ///
  /// Per exercise rather than app-wide because a gym is not one bar: the EZ
  /// curl bar is 10, the trap bar 25, the Smith carriage counterweighted to
  /// something else again, and every one of them is a fact about the movement
  /// you do on it. Ignored unless [weightType] is [WeightType.bar].
  RealColumn get barWeight => real().nullable()();
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
  /// day. Zero means "no goal recorded", which a set logged outside a template
  /// can legitimately be.
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

  /// The plates a metric gym owns, encoded — see `plates.dart`.
  ///
  /// Null means the user has never edited it, which is not the same as owning
  /// no plates: it lets the standard rack stand in.
  TextColumn get plateInventory => text().nullable()();

  /// The same for a gym stocking pounds. A separate rack rather than a
  /// conversion of [plateInventory]: see [resolvePlateSettings] for why.
  TextColumn get plateInventoryLb => text().nullable()();

  /// What the bar weighs by default, in kg — an exercise may override it with
  /// `Exercises.barWeight`. Null falls back to the standard bar for the chosen
  /// unit, for the same reason as [plateInventory].
  RealColumn get barWeight => real().nullable()();

  /// Whether the first-run tutorial has already been shown. False on a fresh
  /// install, so the coach marks run exactly once; set true when the tour is
  /// completed or skipped. An upgrade marks it true — an existing user is not a
  /// first run and should never be ambushed by it mid-programme. Re-running the
  /// tour from the help menu does not clear it.
  BoolColumn get tutorialSeen => boolean().withDefault(const Constant(false))();

  /// Which colour theme is active: a preset slug (`ignition`, `graphite`, …),
  /// `custom`, or null. Null means the default preset, so an install that never
  /// touched the setting looks exactly as it always did.
  TextColumn get themePresetId => text().nullable()();

  /// The user's own custom palette, serialised as JSON — see `AppPalette`. Kept
  /// even while a preset is active, so switching to Custom brings back what was
  /// last built rather than a blank slate.
  TextColumn get customTheme => text().nullable()();

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

/// The plate setup exactly as the settings row holds it: every value may be
/// null, meaning "never configured" rather than "empty". One rack per unit —
/// see [resolvePlateSettings].
typedef StoredPlateSetup = ({String? kgRack, String? lbRack, double? barKg});

/// The colour-theme choice as the settings row holds it: the selected id (a
/// preset slug, `custom`, or null for the default preset) and the user's custom
/// palette JSON, if they have built one. Resolved into a palette by
/// `resolvePalette` in `app_theme.dart`.
typedef ThemeSetting = ({String? presetId, String? customJson});

/// One seeded exercise slot (first-run demo data only).
typedef _SeedItem = ({String name, int sets, int min, int? max, double? w});

/// The curated starter library, as muscle group → movement → equipment.
///
/// Glutes and Forearms are groups in their own right — see
/// `exercise_taxonomy.dart` for why. Traps stay under Back, because a shrug is
/// something you do on a back day and nobody goes looking for a Traps heading.
/// The movements that answer to no single group — a swing, a clean, a get-up —
/// are under Other.
///
/// Each group aims to cover the movement patterns that matter in it, at every
/// kind of loading a gym offers, without turning the picker into a catalogue.
/// How a movement is loaded is left to `weightTypeForEquipment`, and its demo
/// link to a YouTube search, which cannot rot the way a video id can.
const Map<String, Map<String, String>> _starterLibrary = {
  'Chest': {
    'Bench Press': 'Barbell',
    'Incline Bench Press': 'Barbell',
    'Decline Bench Press': 'Barbell',
    'Dumbbell Bench Press': 'Dumbbell',
    'Incline DB Press': 'Dumbbell',
    'Dumbbell Fly': 'Dumbbell',
    'Machine Chest Press': 'Machine',
    'Pec Deck': 'Machine',
    'Cable Fly': 'Cable',
    'Push-Up': 'Bodyweight',
    'Chest Dip': 'Bodyweight',
  },
  'Back': {
    'Deadlift': 'Barbell',
    'Barbell Row': 'Barbell',
    'Barbell Shrug': 'Barbell',
    'Dumbbell Row': 'Dumbbell',
    'T-Bar Row': 'Machine',
    'Chest-Supported Row': 'Machine',
    'Lat Pulldown': 'Cable',
    'Seated Cable Row': 'Cable',
    'Straight-Arm Pulldown': 'Cable',
    'Face Pull': 'Cable',
    'Pull-Up': 'Bodyweight',
    'Chin-Up': 'Bodyweight',
    'Inverted Row': 'Bodyweight',
    'Back Extension': 'Bodyweight',
  },
  'Shoulders': {
    'Overhead Press': 'Barbell',
    'Push Press': 'Barbell',
    'Upright Row': 'Barbell',
    'Dumbbell Shoulder Press': 'Dumbbell',
    'Arnold Press': 'Dumbbell',
    'Lateral Raise': 'Dumbbell',
    'Front Raise': 'Dumbbell',
    'Rear Delt Fly': 'Dumbbell',
    'Machine Shoulder Press': 'Machine',
    'Reverse Pec Deck': 'Machine',
    'Cable Lateral Raise': 'Cable',
  },
  'Legs': {
    'Back Squat': 'Barbell',
    'Front Squat': 'Barbell',
    'Sumo Deadlift': 'Barbell',
    'Romanian Deadlift': 'Barbell',
    'Good Morning': 'Barbell',
    'Goblet Squat': 'Dumbbell',
    'Bulgarian Split Squat': 'Dumbbell',
    'Walking Lunge': 'Dumbbell',
    'Step-Up': 'Dumbbell',
    'Leg Press': 'Machine',
    'Hack Squat': 'Machine',
    'Leg Curl': 'Machine',
    'Leg Extension': 'Machine',
    'Calf Raise': 'Machine',
    'Seated Calf Raise': 'Machine',
  },
  'Glutes': {
    'Hip Thrust': 'Barbell',
    'Glute Bridge': 'Bodyweight',
    'Hip Abduction': 'Machine',
    'Cable Pull-Through': 'Cable',
    'Glute Kickback': 'Cable',
  },
  'Arms': {
    'Barbell Curl': 'Barbell',
    'Preacher Curl': 'Barbell',
    'Close-Grip Bench Press': 'Barbell',
    'Skull Crusher': 'Barbell',
    'Dumbbell Curl': 'Dumbbell',
    'Hammer Curl': 'Dumbbell',
    'Incline Dumbbell Curl': 'Dumbbell',
    'Triceps Pushdown': 'Cable',
    'Overhead Cable Extension': 'Cable',
    'Cable Curl': 'Cable',
    'Triceps Dip': 'Bodyweight',
  },
  'Forearms': {
    // Reverse Curl earns its place here rather than in Arms: the forearm is
    // what gives out first, which is the whole reason anyone programmes it.
    'Reverse Curl': 'Barbell',
    'Wrist Curl': 'Dumbbell',
    'Reverse Wrist Curl': 'Dumbbell',
    "Farmer's Carry": 'Dumbbell',
    'Dead Hang': 'Bodyweight',
  },
  'Core': {
    'Cable Crunch': 'Cable',
    'Pallof Press': 'Cable',
    'Machine Crunch': 'Machine',
    'Ab Wheel Rollout': 'Other',
    'Plank': 'Bodyweight',
    'Side Plank': 'Bodyweight',
    'Hollow Hold': 'Bodyweight',
    'Hanging Leg Raise': 'Bodyweight',
    'Crunch': 'Bodyweight',
    'Reverse Crunch': 'Bodyweight',
    'Russian Twist': 'Bodyweight',
    'Dead Bug': 'Bodyweight',
  },
  // Whole-body movements that would be a lie in any single group.
  'Other': {
    'Power Clean': 'Barbell',
    'Kettlebell Swing': 'Other',
    'Turkish Get-Up': 'Other',
  },
};

/// The starters with no rep to count, so the clock is the only thing that can
/// go up. Everything else in [_starterLibrary] is measured in reps.
const Set<String> _heldStarters = {
  'Plank',
  'Side Plank',
  'Hollow Hold',
  'Dead Hang',
  "Farmer's Carry",
};

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
/// the set is exactly the failure progression needs to see. A set that recorded
/// no goal at all — zero reps to beat and no suggested weight — never reads as
/// a failure, since there was nothing to fall short of.
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

  /// Still v1, and staying there until the app ships.
  ///
  /// Nothing is installed anywhere, so there is no older database in the world
  /// to climb a ladder from. A schema change is made by editing the table and
  /// regenerating — not by appending a migration step whose only possible input
  /// is a database that has never existed. There was a v2 here once, for
  /// dropping the coaching cue from `Exercises`; it was carrying a rung nobody
  /// could ever stand on, and the column is simply absent now.
  ///
  /// **This changes on the first public release.** From that build onward the
  /// shipped shape is v1 for real, every later change is a rung, and none of
  /// them may be rewritten.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

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
    String? videoUrl,
    ExerciseMeasure measure = ExerciseMeasure.reps,
    WeightType weightType = WeightType.machine,
  }) {
    return into(exercises).insert(
      ExercisesCompanion.insert(
        name: name,
        muscleGroup: Value(muscle),
        equipment: Value(equipment),
        videoUrl: Value(videoUrl),
        isCustom: const Value(true),
        measure: Value(measure),
        weightType: Value(weightType),
      ),
    );
  }

  /// Reclassifies how an exercise is loaded. Editable for every exercise, not
  /// just custom ones: whether the gym's bench has a 20 kg bar or a 15 kg one
  /// is a fact about the gym, and the starter library cannot know it.
  Future<void> setExerciseWeightType(int id, WeightType type) =>
      (update(exercises)..where((e) => e.id.equals(id)))
          .write(ExercisesCompanion(weightType: Value(type)));

  /// Gives one exercise a bar of its own, in kg. Null hands it back to the
  /// default on the settings screen.
  Future<void> setExerciseBarWeight(int id, double? kg) =>
      (update(exercises)..where((e) => e.id.equals(id)))
          .write(ExercisesCompanion(barWeight: Value(kg)));

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

  // ---- Exercise history ---------------------------------------------------

  /// Every completed-session set of one exercise, oldest first, each flattened
  /// with the date and name of the session it belongs to.
  ///
  /// Read-only: it drives the per-exercise progress chart and the CSV export
  /// and never writes anything. Matched on `exerciseId` rather than the
  /// denormalised name, so a movement renamed in the library still gathers its
  /// whole history; sets logged before the id was recorded (there are none from
  /// this app, but a hand-edited DB could hold some) simply do not match.
  /// Live, unfinished sessions are excluded — a set only counts once its
  /// session is finished, the same rule the lifetime totals use.
  Stream<List<ExerciseSetEntry>> watchExerciseSetHistory(int exerciseId) {
    final query = select(sessionSets).join([
      innerJoin(sessions, sessions.id.equalsExp(sessionSets.sessionId)),
    ])
      ..where(sessionSets.exerciseId.equals(exerciseId) &
          sessions.endedAt.isNotNull())
      ..orderBy([
        OrderingTerm(expression: sessions.startedAt),
        OrderingTerm(expression: sessionSets.setNumber),
      ]);

    return query.watch().map(
          (rows) => rows.map((r) {
            final set = r.readTable(sessionSets);
            final session = r.readTable(sessions);
            return ExerciseSetEntry(
              sessionId: set.sessionId,
              date: session.startedAt,
              sessionName: session.name,
              setNumber: set.setNumber,
              weightKg: set.weight,
              reps: set.reps,
              seconds: set.seconds,
              done: set.done,
            );
          }).toList(),
        );
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

  /// Whether the first-run tutorial has been shown. False triggers it once on a
  /// genuine first run; replaying it from the help menu does not touch this.
  Stream<bool> watchTutorialSeen() {
    return (select(settings)..where((s) => s.id.equals(1)))
        .watchSingleOrNull()
        .map((s) => s?.tutorialSeen ?? false);
  }

  Future<void> setTutorialSeen(bool seen) =>
      _writeSettings(SettingsCompanion(tutorialSeen: Value(seen)));

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

  /// The bar and plate setup as stored — nulls and all. Resolve it against the
  /// current unit with [resolvePlateSettings] before using it; see
  /// `plateSettingsProvider`.
  Stream<StoredPlateSetup> watchPlateSetup() {
    return (select(settings)..where((s) => s.id.equals(1)))
        .watchSingleOrNull()
        .map((s) => (
              kgRack: s?.plateInventory,
              lbRack: s?.plateInventoryLb,
              barKg: s?.barWeight,
            ));
  }

  Future<void> setBarWeight(double kg) =>
      _writeSettings(SettingsCompanion(barWeight: Value(kg)));

  /// Stores the rack for [unit] — the racks are kept apart, see
  /// [resolvePlateSettings].
  Future<void> setPlateInventory(List<PlateStack> plates, String unit) {
    final encoded = Value(encodePlates(plates));
    return _writeSettings(unit == 'lb'
        ? SettingsCompanion(plateInventoryLb: encoded)
        : SettingsCompanion(plateInventory: encoded));
  }

  /// Forgets the rack for [unit], so the standard one stands in again. The
  /// other unit's rack is left alone — it was never the thing being reset.
  Future<void> resetPlateInventory(String unit) => _writeSettings(unit == 'lb'
      ? const SettingsCompanion(plateInventoryLb: Value(null))
      : const SettingsCompanion(plateInventory: Value(null)));

  /// Forgets the configured default bar.
  Future<void> resetBarWeight() =>
      _writeSettings(const SettingsCompanion(barWeight: Value(null)));

  /// The active colour theme choice as stored: the selected id (a preset slug,
  /// `custom`, or null for the default preset) and the user's custom palette
  /// JSON, if any. Resolving these into a palette lives in `app_theme.dart`
  /// (`resolvePalette`); the UI reads it via `activePaletteProvider`.
  Stream<ThemeSetting> watchThemeSetting() {
    return (select(settings)..where((s) => s.id.equals(1)))
        .watchSingleOrNull()
        .map((s) => (presetId: s?.themePresetId, customJson: s?.customTheme));
  }

  /// Selects a shipped preset (or `custom`) as the active theme. Passing null
  /// falls back to the default preset. The stored custom palette is left
  /// untouched, so switching away from and back to Custom is lossless.
  Future<void> setThemePreset(String? presetId) =>
      _writeSettings(SettingsCompanion(themePresetId: Value(presetId)));

  /// Stores the user's custom palette (JSON from `AppPalette.toJson`) and makes
  /// it the active theme in one write. The `custom` slug matches
  /// `kCustomThemeId` in `app_theme.dart` — the id a self-built palette carries.
  Future<void> setCustomTheme(String json) => _writeSettings(SettingsCompanion(
        customTheme: Value(json),
        themePresetId: const Value('custom'),
      ));

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

    // A curated starter library. Each ships with a demo link (a YouTube
    // search, so the link never rots).
    final ids = <String, int>{};
    final measures = <String, ExerciseMeasure>{};
    Future<int> ex(
      String name,
      String muscle,
      String equip, {
      ExerciseMeasure measure = ExerciseMeasure.reps,
    }) async {
      measures[name] = measure;
      return ids[name] ??= await into(exercises).insert(
        ExercisesCompanion.insert(
          name: name,
          muscleGroup: Value(muscle),
          equipment: Value(equip),
          measure: Value(measure),
          // The equipment already says how these are loaded — a barbell lift
          // is a bar, a dumbbell lift is a dumbbell, and the cables, machines
          // and bodyweight movements are all "the number is the number".
          weightType: Value(weightTypeForEquipment(equip)),
          videoUrl: Value(
            'https://www.youtube.com/results?search_query='
            '${Uri.encodeQueryComponent('$name proper form')}',
          ),
        ),
      );
    }

    for (final group in _starterLibrary.entries) {
      for (final movement in group.value.entries) {
        await ex(
          movement.key,
          group.key,
          movement.value,
          measure: _heldStarters.contains(movement.key)
              ? ExerciseMeasure.time
              : ExerciseMeasure.reps,
        );
      }
    }

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
