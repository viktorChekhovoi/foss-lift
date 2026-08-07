import 'package:drift/drift.dart';

import '../services/set_video_store.dart';
import '../theme/theme_id.dart';
import '../util/units.dart';
import '../util/video_links.dart';
import 'db_open.dart';
import 'exercise_stats.dart';
import 'layoff.dart';
import 'plates.dart';
import 'progression.dart';
import 'schedule.dart';
import 'set_scheme.dart';
import 'seed_keys.dart';
import 'warmup.dart';

export 'exercise_stats.dart';
export 'exercise_taxonomy.dart';
export 'layoff.dart';
export 'plates.dart';
export 'progression.dart';
export 'schedule.dart';
export 'set_scheme.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// The longest a routine, workout or exercise may be named.
///
/// The schema enforces it on every one of those tables, which makes an
/// over-long name a failed write rather than a truncated one — so every field
/// that feeds them caps typing at this length instead of letting the insert
/// find out. Long enough for the longest real movement name and short enough
/// to stay on one line of a card.
const int kMaxNameLength = 80;

/// The exercise library (Bench Press, Squat, …). Ships with a curated set;
/// users can add their own ([isCustom] == true).
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The canonical English name. What a routine code carries, what history
  /// denormalises, and what an importer matches on — see `seedKey` for what is
  /// actually rendered.
  TextColumn get name => text().withLength(min: 1, max: kMaxNameLength)();

  /// Which movement of the starter library this is, or null for one you added.
  ///
  /// A screen renders `seededName(l10n, seedKey, name)` rather than `name`, so
  /// the whole starter library follows a language switch instead of being
  /// frozen at whatever the phone was set to on install day. Seeded exercises
  /// cannot be renamed (see [isCustom]), so unlike a routine or a training day
  /// this key is never cleared. See `util/seed_names.dart`.
  TextColumn get seedKey => text().nullable()();
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
  /// only reading that is never wrong for something that carries a weight. It
  /// is deliberately not [WeightType.none] — almost every movement is loaded,
  /// so a movement nobody has classified is loaded too.
  ///
  /// [WeightType.none] is stored like any other value, and means the movement
  /// carries nothing: a push-up, a plank. Nothing downstream offers it a
  /// weight.
  TextColumn get weightType =>
      textEnum<WeightType>().withDefault(const Constant('machine'))();

  /// What you need to remember about this movement at your gym: the seat
  /// setting, the rack pin, how far down you take it, which cable stack sticks.
  ///
  /// Personal, and deliberately so. This is not the coaching cue that used to
  /// live here and was deleted — that was general advice, which travels badly
  /// because it is long and because the demo link says it better. A note is
  /// specific to one person at one gym, which is why it never travels at all:
  /// "seat 4, pin 7" is not merely useless on someone else's machine, it is
  /// wrong. Nothing puts this in a routine code.
  ///
  /// Capped at 300 characters, which is a couple of settings and a reminder —
  /// past that it stops being something you can read between sets.
  TextColumn get notes => text().nullable().withLength(max: 300)();

  /// What *this* movement's bar weighs, in kg, when the gym's default is wrong
  /// for it. Null — the usual case — means the default from settings.
  ///
  /// Per exercise rather than app-wide because a gym is not one bar: the EZ
  /// curl bar is 10, the trap bar 25, the Smith carriage counterweighted to
  /// something else again, and every one of them is a fact about the movement
  /// you do on it. Ignored unless [weightType] is [WeightType.bar].
  RealColumn get barWeight => real().nullable()();
}

/// A training program ("PPL", "Upper/Lower"). A routine is a container: the
/// thing you actually train is one of its [Workouts].
class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: kMaxNameLength)();

  /// Which demo program this is, or null for one of your own.
  ///
  /// Cleared the moment the routine is renamed — a program you have named is
  /// yours, and must not revert to "Push / Pull / Legs" on the next language
  /// switch. See `util/seed_names.dart`.
  TextColumn get seedKey => text().nullable()();
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
  TextColumn get name => text().withLength(min: 1, max: kMaxNameLength)();

  /// Which training day of a demo program this is, or null. Cleared on
  /// rename, for the same reason as [Routines.seedKey].
  TextColumn get seedKey => text().nullable()();
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

  /// The top of every ladder this slot produces — see [SetScheme]. Null on a
  /// movement that carries no load.
  RealColumn get suggestedWeight => real().nullable()();

  // -- Set scheme ----------------------------------------------------------
  // How the sets differ from one another. Flat — every set alike — is the
  // default and what most programs want; see `data/set_scheme.dart`.

  TextColumn get scheme =>
      textEnum<SetScheme>().withDefault(const Constant('flat'))();

  /// What one rung of a back-off or a ramp moves by, as a whole percentage of
  /// [suggestedWeight]. Ignored by the other two schemes.
  IntColumn get schemePercent =>
      integer().withDefault(const Constant(kDefaultSchemePercent))();

  /// The written-out rows of a [SetScheme.custom] slot, encoded — see
  /// `encodeCustomSets`. Null on every other scheme, and on a custom slot
  /// nobody has filled in yet.
  TextColumn get customSets => text().nullable()();

  // -- Progression ---------------------------------------------------------
  // Which number goes up when the sets go well, by how much, and how long it
  // takes. Defaults are the weight case, so an exercise nobody has configured
  // behaves like the barbell program everyone expects.

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

  /// The seed key of the training day this was, or null. Denormalised beside
  /// [name] for the same two reasons the sets denormalise theirs: the template
  /// may be edited or deleted, and the name still has to follow the language.
  TextColumn get seedKey => text().nullable()();

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

  /// The seed key of the movement, copied alongside its name and for the same
  /// reason: a logged set has to stay readable after a library edit, *and* has
  /// to follow a language switch. Null for a movement you added yourself, whose
  /// name is the only answer there is.
  TextColumn get exerciseSeedKey => text().nullable()();
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

  /// The clip filmed of this set, as a path **relative** to the app support
  /// directory (`set_videos/<id>.mp4`). Null on a set nobody filmed, which is
  /// nearly all of them.
  ///
  /// Relative, never absolute: the iOS app-container path carries a UUID that
  /// changes on reinstall and on restore from backup, so an absolute path works
  /// on Android and silently dangles on iOS. See `SetVideoStore`.
  ///
  /// One column rather than a table: one clip per set is the feature, and
  /// several angles of the same set is not.
  TextColumn get videoPath => text().nullable()();
}

/// A single-row key/value store for app-wide preferences (always id == 1).
class Settings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// 'kg' or 'lb'. Weights are stored in kg; this only affects display/input.
  ///
  /// **Null means the question has not been asked yet**, which is not the same
  /// as kilograms: a fresh install opens on the first-run unit choice, and this
  /// column is what says whether it still has to. Everything that only wants to
  /// *display* a weight reads null as kilograms, so nothing downstream has to
  /// cope with a missing unit.
  TextColumn get weightUnit => text().nullable()();

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
  /// first run and should never be ambushed by it mid-program. Re-running the
  /// tour from the help menu does not clear it.
  BoolColumn get tutorialSeen => boolean().withDefault(const Constant(false))();

  /// The user's own text-size nudge, *on top of* the phone's setting.
  ///
  /// 1.0 means "whatever the system says", which is the default and the right
  /// answer for most people — Android's own text size is system-wide and
  /// already discoverable. This exists for the gap it leaves: wanting this app
  /// larger without enlarging everything else, or wanting it smaller to fit
  /// more of a workout on screen.
  ///
  /// It multiplies the system scale rather than replacing it, and the product
  /// is clamped — see `kTextScaleChoices` and `resolveTextScale`. A control
  /// that can produce a layout nobody has checked is not an accessibility
  /// feature.
  RealColumn get textScale => real().withDefault(const Constant(1.0))();

  /// Which colour theme is active: a preset slug (`ignition`, `graphite`, …),
  /// `custom:<n>` naming a row of [CustomThemes], or null. Null means the
  /// default preset, so an install that never touched the setting looks exactly
  /// as it always did.
  ///
  /// Nothing keeps this in step with [CustomThemes] except [deleteCustomTheme],
  /// which clears it when it removes the row it names. A slug left dangling by
  /// any other route resolves to the default rather than to nothing — see
  /// `resolvePalette`.
  TextColumn get themePresetId => text().nullable()();

  /// The height a set clip is filmed at, in pixels: 480 or 720.
  ///
  /// 720 by default. 1080 is deliberately not on offer — it is roughly two and
  /// a half times the bytes of 720 for a judgement (depth, bar path) that 720
  /// already answers, and video is the only thing this app stores that can fill
  /// a phone. See `kVideoHeights`.
  IntColumn get videoHeight =>
      integer().withDefault(const Constant(kDefaultVideoHeight))();

  /// The hard stop on one clip, in seconds: 60 or 180.
  ///
  /// Recording ends itself here rather than warning. The failure mode that
  /// fills a phone is a recording nobody stopped — you rack the bar, walk off,
  /// and the app films the ceiling. 60 covers any straight set; the longer step
  /// exists for a 20-rep squat set or a held exercise.
  IntColumn get videoMaxSeconds =>
      integer().withDefault(const Constant(kDefaultVideoSeconds))();

  /// The language the user picked, as `uk` or `pt_BR` — see `util/locales.dart`.
  ///
  /// Null means "follow the phone", which is the default and the right answer
  /// for almost everybody: the phone has already been asked this question. It
  /// exists for the gap that leaves — a phone kept in one language by an
  /// employer or a habit, and an app you would rather read in another.
  TextColumn get localeTag => text().nullable()();

  /// How many warm-up rungs every exercise in a session opens with, before the
  /// live stepper touches it — see `warmup.dart`.
  ///
  /// The settings stepper holds it between 1 and [kMaxWarmupSets]. Zero is not
  /// on offer there: skipping the ramp is a decision about the movement you are
  /// on, which the session's own stepper already makes.
  ///
  /// **Declared last on purpose.** `ALTER TABLE … ADD COLUMN` appends, so a
  /// database that climbed the v2 rung carries this column at the end. Adding it
  /// here rather than beside the other counts keeps a fresh install and an
  /// upgraded one on exactly the same table, right down to the column order.
  IntColumn get warmupSets =>
      integer().withDefault(const Constant(kDefaultWarmupSets))();

  @override
  Set<Column> get primaryKey => {id};
}

/// The colour themes the user owns: the ones they built and the ones they
/// imported. Presets are code, not rows — only a palette somebody can edit,
/// rename or delete lives here.
///
/// **The palette JSON is the whole row.** A theme's name lives inside it
/// (`AppPalette.name`) rather than in a column of its own: a palette already
/// carries its name, that name is what a share code sends, and a second copy in
/// a column would be a second thing to keep in step for no gain. Listing the
/// themes parses the JSON either way, to draw their swatches.
///
/// **No migration rung, and none needed.** This table replaced the single
/// `Settings.customTheme` column outright, before the first release and while
/// the schema was still edited in place, so no install has ever held the old
/// shape. It is a table like any other now — a change to it needs a rung, as
/// everything else does.
class CustomThemes extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The palette as `AppPalette.toJson` writes it.
  TextColumn get palette => text()();
}

/// The one live session, mirrored to disk so that Android killing the process
/// cannot lose a workout somebody is halfway through.
///
/// **This is not a database-backed session.** The live workout is still held in
/// memory and still writes its history only on Finish — see
/// `state/active_workout.dart`. This is a crash snapshot beside it: one row,
/// rewritten on every mutation, read once on launch, deleted on finish or
/// discard. Nothing but the launch restore ever reads it, and no query joins it
/// to anything, so a stale row is inert rather than wrong.
///
/// The session is one JSON blob rather than a set of columns because it is
/// opaque to SQL by design: it is never filtered, sorted or aggregated, only
/// written whole and read whole. See `state/session_snapshot.dart` for the shape.
class LiveSessions extends Table {
  /// Always 1. One session can be live at a time, so the row is a slot.
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// The session as `encodeSession` writes it.
  TextColumn get payload => text()();

  /// When the snapshot was taken, which is what the clocks are rebuilt against:
  /// the workout's elapsed time and any running rest both have to account for
  /// however long the app was dead. See `decodeSession`.
  DateTimeColumn get savedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The bars the gym racks: a row each, with a name and what it weighs.
///
/// A fresh install starts with the common ones (see `namedBars`). Those are
/// **fixed**: an Olympic bar weighs 20 kg and an EZ curl bar weighs 10, and
/// neither is a preference — the weight is what the plate maths trusts and what
/// a shared routine carries to a phone where this row does not exist, so
/// renaming or re-weighing one would quietly change what somebody else's code
/// resolves to. Anything you add is yours to rename and re-weigh. Either can be
/// deleted, because a gym may simply not rack a trap bar.
///
/// [isCustom] is what tells them apart. False for the seeded rows, true for
/// anything added since — the same shape [Exercises.isCustom] uses for the
/// starter library, and enforced in [AppDatabase.editBar] rather than only by
/// hiding the pencil.
///
/// **A bar is referred to by its weight, not by its id.** `Settings.barWeight`
/// (the app-wide default) and `Exercises.barWeight` (one movement's own bar)
/// hold kilograms, because the weight is what the plate maths needs and the only
/// thing a shared routine can carry to another phone, where this row does not
/// exist. Two bars in one list may therefore not weigh the same, or a reference
/// could not tell them apart — see [AppDatabase.addBar]. Editing a bar's weight
/// or deleting it moves those references with it: see [AppDatabase.editBar] and
/// [AppDatabase.deleteBar].
///
/// **Kept per unit** for the same reason as the plate rack: an Olympic bar is
/// 20 kg in a metric gym and 45 lb in a pounds one, two round numbers that are
/// not the same weight. [unit] says which gym's list a row belongs to; the
/// weight itself is canonical kilograms like every other weight in the app.
class Bars extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `kg` or `lb` — which unit's list this bar is on.
  TextColumn get unit => text().withLength(min: 2, max: 2)();

  TextColumn get name => text().withLength(min: 1, max: kMaxNameLength)();

  /// Which of the bars the app ships with this is, or null for one you added.
  ///
  /// The seeded bars are fixed — [isCustom] false, unrenameable — so unlike a
  /// routine or a training day this key is never cleared. See
  /// `util/seed_names.dart`.
  TextColumn get seedKey => text().nullable()();

  /// What the bar weighs, in kilograms.
  RealColumn get weightKg => real()();

  /// Whether you added this bar. False for the seeded ones, which are fixed —
  /// see the class comment.
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
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

/// Reading a weight back as the bar it is: references to a bar are weights (see
/// [Bars]), and a screen showing one wants the name.
/// Whether this movement's loading is a fact rather than a setting.
///
/// Both halves matter: a movement you made is yours to reclassify however you
/// described it, and a seeded one is fixed only where its own name states the
/// implement — see [loadingNamedBy]. Everything else stays a choice, because how
/// a movement is loaded is specific to the movement and the gym rather than
/// derivable from a word in a taxonomy.
extension FixedLoading on Exercise {
  bool get loadingIsFixed => !isCustom && loadingNamedBy(name) != null;
}

extension BarAtWeight on List<Bar> {
  /// The bar in this list weighing [kg], or null. Matched within
  /// [kPlateToleranceKg] — a pounds bar in kilograms has a tail on it.
  Bar? atWeight(double kg) {
    for (final b in this) {
      if ((b.weightKg - kg).abs() <= kPlateToleranceKg) return b;
    }
    return null;
  }
}

/// How a set clip is filmed: the height in pixels and the hard stop on its
/// length in seconds. Both come from `Settings`; see `set_video_store.dart` for
/// the values on offer and why.
typedef VideoSetting = ({int height, int maxSeconds});

/// One seeded exercise slot (first-run starter programs only).
class _SeedItem {
  /// A slot that steps at whatever its progression axis steps at by default:
  /// 2.5 kg on a press, a rep on a movement that carries no load.
  const _SeedItem(
    this.name, {
    required this.sets,
    required this.min,
    this.max,
    this.w,
  }) : inc = null,
       deload = null;

  /// A slot on one of the lifts a linear-progression program moves 5 kg a
  /// session — the squat, the deadlift and their variants — rather than the
  /// 2.5 kg the presses take. The back-off is twice the step, as everywhere.
  const _SeedItem.heavy(
    this.name, {
    required this.sets,
    required this.min,
    required this.w,
  }) : max = null,
       inc = 5,
       deload = 10;

  /// The canonical English name of a movement in [_starterLibrary].
  final String name;
  final int sets;
  final int min;
  final int? max;

  /// The load to open at, in kilograms, or null for a slot that carries none.
  final double? w;

  /// The program's own step up and back-off, or null to take the axis's.
  final double? inc;
  final double? deload;
}

/// The curated starter library, as muscle group → movement → equipment.
///
/// The groups are the seven of [kMuscleGroups] and no finer: hip thrusts sit
/// under Legs, wrist curls under Arms, and traps under Back, because a shrug is
/// something you do on a back day and nobody goes looking for a Traps heading.
/// The movements that answer to no single group — a swing, a clean, a get-up —
/// are under Other.
///
/// Each group aims to cover the movement patterns that matter in it, at every
/// kind of loading a gym offers, without turning the picker into a catalogue.
/// How a movement is loaded follows from its equipment — see [_seedWeightType]
/// for that rule and the handful of movements whose equipment does not settle
/// it.
/// The demo video for each starter movement, as a bare YouTube id.
///
/// **Ids, not URLs.** Eleven characters is what identifies a video, and it is
/// also what travels inside a shared routine — a full URL would not fit the
/// budget and a search URL, which is what these used to be, carries no video to
/// travel at all (see `youTubeVideoId`).
///
/// **Where they come from.** Four large exercise libraries carry most of it —
/// Muscle & Strength, Renaissance Periodization, PureGym and Bodybuilding.com —
/// with a handful from other long-established publishers where none of the four
/// had a clean demo. The rule was a back catalogue with no reason to be deleted:
/// a demo that disappears is worse than the search that always worked, and the
/// app asks for no network permission, so it can never notice a dead one.
///
/// **Checking them.** Every id here resolved live when it was added. To re-check
/// the lot, ask YouTube's oEmbed endpoint for each — it answers with the title
/// and channel for a live video and fails for a dead one:
///
/// ```
/// curl -s "https://www.youtube.com/oembed?url=https://youtu.be/<id>&format=json"
/// ```
///
/// The comment beside each is the video's own title, so a re-check can tell
/// "this is gone" from "this is now something else".
const Map<String, String> _starterDemos = {
  'Bench Press': 'tuwHzzPdaGc', // Barbell Bench Press — Muscle & Strength
  'Incline Bench Press':
      'uIzbJX5EVIY', // Incline Bench Press — Muscle & Strength
  'Decline Bench Press':
      'oIgci8aNsG0', // Decline Bench Press — Muscle & Strength
  'Dumbbell Bench Press':
      'dGqI0Z5ul4k', // Dumbbell Bench Press — Muscle & Strength
  'Incline DB Press':
      '8nNi8jbbUPE', // Incline Dumbbell Bench Press — Muscle & Strength
  'Dumbbell Fly': '-lcbvOddoi8', // Flat Dumbbell Fly — Muscle & Strength
  'Machine Chest Press':
      'NwzUje3z0qY', // Machine Chest Press — Renaissance Periodization
  'Pec Deck': 'O-OBCfyh9Fw', // Pec Deck Flye — Renaissance Periodization
  'Cable Fly':
      'QcTcWpkn_bw', // How To Do A Cable Fly/ Cable Crossover — PureGym
  'Push-Up': 'KEFQyLkDYtI', // Pushup — Muscle & Strength
  'Chest Dip': 'FG1ENBFsdHU', // Dip (Parallel Bars) — Muscle & Strength
  'Deadlift': 'wjsu6ceEkAQ', // Conventional Deadlift — Muscle & Strength
  'Barbell Row': 'paCfxhgW6bI', // Bent Over Barbell Row — Muscle & Strength
  'Barbell Shrug': '6hNudn7Peco', // Barbell Shrug — Muscle & Strength
  'Dumbbell Row':
      'YZgVEy6cmaY', // Bent Over Dumbbell Row Unilateral — Muscle & Strength
  'T-Bar Row': 'kHW23afzaUs', // Chest Supported T Bar Row — Muscle & Strength
  'Chest-Supported Row':
      '0UBRfiO4zDs', // Chest Supported Row — Renaissance Periodization
  'Lat Pulldown':
      'iKrKgWR9wbY', // Lat Pulldown (Double Overhand) — Muscle & Strength
  'Seated Cable Row':
      'xQNrFHEMhI4', // Seated Cable Row | Exercise Guide — Bodybuilding.com
  'Straight-Arm Pulldown':
      'gDtXrJWPdlY', // Cable Straight Arm Pulldown — Muscle & Strength
  'Face Pull':
      'tkLTR4b6cAk', // Face Pull - Shoulder Exercise - Bodybuilding.com — Bodybuilding.com
  'Pull-Up':
      'WXMKjV11lAk', // Pullups -  Back Exercise - Bodybuilding.com — Bodybuilding.com
  'Chin-Up': '1EJ3A3rEtlo', // Chin-up — Muscle & Strength
  'Inverted Row': 'KOaCM1HMwU0', // Inverted Row — Renaissance Periodization
  'Back Extension':
      'BZMnTSobIAQ', // Hyperextension Bodyweight — Muscle & Strength
  'Overhead Press': 'j7ULT6dznNc', // Overhead Press — Muscle & Strength
  'Push Press':
      'ChTn_TLDA5o', // Push Press - Shoulder Exercise - Bodybuilding.com — Bodybuilding.com
  'Upright Row':
      'um3VVzqunPU', // Barbell Upright Row — Renaissance Periodization
  'Dumbbell Shoulder Press':
      'FRxZ6wr5bpA', // Seated Dumbbell Press (Bilateral) — Muscle & Strength
  'Arnold Press': 'hmnZKRpYaV8', // Seated Arnold Press — Muscle & Strength
  'Lateral Raise':
      'E3abEP8SIh0', // Side Lateral Raise | Exercise Guide — Bodybuilding.com
  'Front Raise':
      '-t7fuZ0KhDA', // How To: Dumbbell Front Raise — ScottHermanFitness
  'Rear Delt Fly': 'Fgz_FdzDukE', // Bent Over Rear Delt Fly — Muscle & Strength
  'Machine Shoulder Press':
      'WvLMauqrnK8', // Machine Shoulder Press — Renaissance Periodization
  'Reverse Pec Deck':
      '6yMdhi2DVao', // How To Properly Use The Rear Delt Fly Machine (+ BONUS TIP) — Mind Pump TV
  'Cable Lateral Raise':
      'Fv-eAW1uKDI', // Single Arm Cable Lateral Raise (Crossbody) — Muscle & Strength
  'Back Squat': 'R2dMsNhN3DE', // Barbell Back Squat — Muscle & Strength
  'Front Squat': '9xAkoz95IFE', // Front Squat (Parallel) — Muscle & Strength
  'Sumo Deadlift': 'pfSMst14EFk', // Sumo Deadlift — Renaissance Periodization
  'Romanian Deadlift': 'CkrqLaDGvOA', // Stiff Leg Deadlift — Muscle & Strength
  'Good Morning': '8sGgyquE1Bs', // Standing Goodmorning — Muscle & Strength
  'Goblet Squat': 'zBV3ceGyAxw', // How To Do A Goblet squat — PureGym
  'Bulgarian Split Squat':
      'uqI3GVwfToU', // Dumbbell Bulgarian Split Squat — Muscle & Strength
  'Walking Lunge': 'uRSsOoZG9z8', // Dumbbell Walking Lunge — Muscle & Strength
  'Step-Up': 'DxUNi119Qzs', // How To Do A Dumbbell Step Up — PureGym
  'Leg Press': 'sEM_zo9w2ss', // Leg Press — Muscle & Strength
  'Hack Squat': '63tboDKQksc', // Machine Hack Squat — Muscle & Strength
  'Leg Curl': 'n5WDXD_mpVY', // Lying Leg Curl — Renaissance Periodization
  'Leg Extension': '0fl1RRgJ83I', // Seated Leg Extension — Muscle & Strength
  'Calf Raise':
      'g_E7_q1z2bo', // Hammer Strength Select Standing Calf Raise — Hammer Strength
  'Seated Calf Raise':
      'Yh5TXz99xwY', // Seated Calf Raise (Toes Neutral) — Muscle & Strength
  'Hip Thrust': 'EF7jXP17DPE', // Barbell Hip Thrust — Renaissance Periodization
  'Glute Bridge': 'DQv1IMQDbE4', // How To Do A Barbell Glute Bridge — PureGym
  'Hip Abduction': '7pbZA7ncuq8', // Machine Abductor — Muscle & Strength
  'Cable Pull-Through':
      'pv8e6OSyETE', // Cable Pull Through — Renaissance Periodization
  'Glute Kickback': 'aX0U98L4Ywk', // Donkey Kicks — Muscle & Strength
  'Barbell Curl':
      'JnLFSFurrqQ', // Barbell Curl Normal Grip — Renaissance Periodization
  'Preacher Curl':
      'sxA__DoLsgo', // EZ Bar Preacher Curl — Renaissance Periodization
  'Close-Grip Bench Press':
      'j-NhORwJDb4', // Bench Press (Close Grip) — Muscle & Strength
  'Skull Crusher': 'K6MSN4hCDM4', // EZ Bar Skullcrusher — Muscle & Strength
  'Dumbbell Curl':
      'av7-8igSXTs', // How to Do Standing Dumbbell Curls — LIVESTRONG
  'Hammer Curl': 'XOEL4MgekYE', // Hammer Curl — Renaissance Periodization
  'Incline Dumbbell Curl':
      'UeleXjsE-98', // Incline Dumbbell Curl — Muscle & Strength
  'Triceps Pushdown':
      '6Fzep104f0s', // Cable Triceps Pushdown — Renaissance Periodization
  'Overhead Cable Extension':
      'NRENeEgaIgA', // Overhead Rope Tricep Extension — Muscle & Strength
  'Cable Curl':
      'L9GwtjwAM8Y', // How To: Standing Cable Double-Bicep Curl — ScottHermanFitness
  'Triceps Dip':
      '6kALZikXxLc', // How to Do a Tricep Dip | Boot Camp Workout — Howcast
  'Reverse Curl':
      'X5df_LHBVKQ', // How To Do Reverse Curls (Pronated Bicep Curl) — PureGym
  'Wrist Curl': '3VLTzIrnb5g', // How To Do Wrist Curls — PureGym
  'Reverse Wrist Curl':
      'krZ6pWGZ8xo', // How to Do Dumbbell Reverse Wrist Curls — LIVESTRONG
  'Dead Hang': 'ShkBXOGK7A8', // How Hanging Transforms Your Body — FitnessFAQs
  'Cable Crunch':
      '3qjoXDTuyOE', // Cable Crunch - Abs / Core Exercise - Bodybuilding.com — Bodybuilding.com
  'Pallof Press': 'HXrLaqNIkTs', // How To Do A Pallof Press — PureGym
  'Machine Crunch': '-OUSBPnHvsQ', // Machine Crunch — Renaissance Periodization
  'Ab Wheel Rollout':
      'rqiTPdK1c_I', // Ab Wheel- How to PROPERLY Use an Ab Wheel | MIND PUMP — Mind Pump TV
  'Plank': 'q4rDeHYMcIg', // How To Do A Plank — PureGym
  'Side Plank': 'Oe9Tp9SvTCE', // How To Do A Side Plank — PureGym
  'Hollow Hold':
      'hf00_b2sRdc', // How to Perfect Your Hollow Hold | Form Check | Men's Health — Men's Health
  'Hanging Leg Raise':
      '7FwGZ8qY5OU', // Hanging Straight Leg Raise — Renaissance Periodization
  'Crunch':
      'MKmrqcoCZ-M', // How to Do a Stomach Crunch Properly | Gym Workout — Howcast
  'Reverse Crunch': 'XY8KzdDcMFg', // How To Do A Reverse Crunch — PureGym
  'Russian Twist': '99T1EfpMwPA', // How To Do A Russian Twist — PureGym
  'Dead Bug':
      '4XLEnwUr1d8', // Dead Bug - Abdominal / Core Exercise Guide — Bodybuilding.com
  'Power Clean':
      'SoEKmdSXUBw', // Learn How to Power Clean | Cassie & Tyra — Bodybuilding.com
  'Kettlebell Swing': '4JzSjWen6uI', // How To Do A Kettlebell Swing — PureGym
  'Turkish Get-Up':
      'bm9M6y4QFoM', // Deconstructing The Turkish Get Up — Bodybuilding.com
  "Farmer's Carry":
      '8OtwXwrJizk', // How To Do A Farmer's Walk (Farmer's Carry) — PureGym
};

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
    // The glute movements, filed here rather than under a heading of their own.
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
    // The forearm and grip movements. Programd for the part that gives out
    // first, and still an arm day either way.
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

/// The starters whose equipment does not say how they are loaded, because their
/// equipment is `Other`.
///
/// A kettlebell is a weight in one hand, which is a dumbbell as far as the
/// weight column is concerned; an ab wheel is your own body on a wheel.
const Map<String, WeightType> _starterLoadings = {
  'Kettlebell Swing': WeightType.dumbbell,
  'Turkish Get-Up': WeightType.dumbbell,
  'Ab Wheel Rollout': WeightType.none,
};

/// How a starter movement is loaded: what its equipment implies, unless it is
/// one of the few [_starterLoadings] names it by hand.
///
/// The equipment carries almost all of it — a barbell lift is a bar, a dumbbell
/// lift is a dumbbell, a cable stack and a machine both read as a machine, and a
/// bodyweight movement carries nothing at all. What is left is the `Other`
/// shelf, where the word says nothing about the load.
WeightType _seedWeightType(String name, String equipment) =>
    _starterLoadings[name] ?? weightTypeForEquipment(equipment);

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

// A slot's target in words — "4 × 6–8", "3 × Failure" — is formatted by
// `util/target_label.dart`, not here: it is words, and this layer cannot see
// the string catalogue.

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
    CustomThemes,
    LiveSessions,
    Bars,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For unit tests: pass an in-memory `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.e);

  /// The current schema version, and the top of the migration ladder.
  ///
  /// **v1 is the shipped shape, and it is real.** Installed databases exist, so
  /// every schema change from here is an `onUpgrade` rung that takes the version
  /// before it to the version after. A rung that has shipped is never edited and
  /// never renumbered: its input is a database on somebody's phone, and
  /// rewriting the ladder makes that phone climb the wrong steps.
  ///
  /// Everything at v1 was settled before the first release, when the schema was
  /// still edited in place — which is why the ladder starts at v1 rather than
  /// below it.
  ///
  /// - **v2** — `Settings.warmup_sets`, the default warm-up rung count.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seed();
    },
    onUpgrade: (m, from, to) async {
      // One `if` per rung, climbed in order: a phone two releases behind runs
      // every rung between where it is and here.
      //
      // **The DDL is written out rather than derived.** `m.addColumn` builds
      // its statement from the column as the *current* code declares it, so a
      // later edit to `Settings.warmupSets` — a different default, a different
      // type — would silently rewrite this rung, and a phone upgrading from v1
      // after that edit would land on a different shape than one that upgraded
      // before it. The literal below is the v2 shape and stays the v2 shape.
      if (from < 2) {
        await m.database.customStatement(
          'ALTER TABLE "settings" ADD COLUMN "warmup_sets" '
          'INTEGER NOT NULL DEFAULT 3',
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // ---- Exercise library --------------------------------------------------

  Stream<List<Exercise>> watchExercises() {
    return (select(exercises)..orderBy([
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

  /// Rewrites a custom exercise in place.
  ///
  /// Only the ones you made. A starter exercise's name and classification are
  /// shared vocabulary — a routine code that says "Bench Press" means the
  /// movement everyone else calls that, and renaming it locally would quietly
  /// break that agreement. What *is* yours about a starter exercise (its
  /// loading, its bar, your note) has its own writer.
  ///
  /// The `isCustom` guard is in the WHERE clause rather than checked first, so
  /// a starter exercise is a no-op rather than a race.
  Future<void> updateCustomExercise(
    int id, {
    required String name,
    required String muscle,
    required String equipment,
    required String? videoUrl,
    required ExerciseMeasure measure,
    required WeightType weightType,
  }) {
    return (update(
      exercises,
    )..where((e) => e.id.equals(id) & e.isCustom.equals(true))).write(
      ExercisesCompanion(
        name: Value(name),
        muscleGroup: Value(muscle),
        equipment: Value(equipment),
        videoUrl: Value(videoUrl),
        measure: Value(measure),
        weightType: Value(weightType),
      ),
    );
  }

  /// Reclassifies how an exercise is loaded.
  ///
  /// Editable almost everywhere, because how a movement is loaded is specific to
  /// the movement and the gym: a skull crusher takes a bar, dumbbells or a
  /// machine, and a chest-supported row is often plate-loaded. Refused only where
  /// the movement's own name states the implement — a seeded "Barbell Curl" is
  /// loaded on a bar, and any other answer leaves the name contradicting the
  /// weight column. See [loadingNamedBy], and [FixedLoading] for the same
  /// question asked of a row.
  ///
  /// Enforced here as well as by the screen not offering it, the way
  /// [updateCustomExercise] guards a starter's name.
  Future<void> setExerciseWeightType(int id, WeightType type) async {
    final e = await (select(
      exercises,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (e == null || e.loadingIsFixed) return;
    await (update(exercises)..where((t) => t.id.equals(id))).write(
      ExercisesCompanion(weightType: Value(type)),
    );
  }

  /// Writes this movement's personal note, or clears it.
  ///
  /// Blank and absent are the same state — a note of nothing but spaces is
  /// stored as null, so no screen downstream has to ask whether an empty-looking
  /// note is empty or merely blank. Editable for every exercise, starter or
  /// custom, for the same reason the bar weight is: it is a fact about your gym.
  Future<void> setExerciseNotes(int id, String? text) {
    final trimmed = text?.trim();
    return (update(exercises)..where((e) => e.id.equals(id))).write(
      ExercisesCompanion(
        notes: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
      ),
    );
  }

  /// Gives one exercise a bar of its own, in kg. Null hands it back to the
  /// default on the settings screen.
  Future<void> setExerciseBarWeight(int id, double? kg) =>
      (update(exercises)..where((e) => e.id.equals(id))).write(
        ExercisesCompanion(barWeight: Value(kg)),
      );

  // ---- Routines -----------------------------------------------------------

  Stream<List<RoutineWithCount>> watchRoutines() {
    final count = workouts.id.count();
    final query =
        select(routines).join([
            leftOuterJoin(workouts, workouts.routineId.equalsExp(routines.id)),
          ])
          ..addColumns([count])
          ..groupBy([routines.id])
          ..orderBy([OrderingTerm(expression: routines.position)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => RoutineWithCount(r.readTable(routines), r.read(count) ?? 0),
          )
          .toList(),
    );
  }

  Future<Routine> routineById(int id) =>
      (select(routines)..where((r) => r.id.equals(id))).getSingle();

  // ---- Workouts (the days inside a routine) -------------------------------

  Stream<List<WorkoutWithCount>> watchWorkoutsForRoutine(int routineId) {
    final count = workoutItems.id.count();
    final query =
        select(workouts).join([
            leftOuterJoin(
              workoutItems,
              workoutItems.workoutId.equalsExp(workouts.id),
            ),
          ])
          ..where(workouts.routineId.equals(routineId))
          ..addColumns([count])
          ..groupBy([workouts.id])
          ..orderBy([OrderingTerm(expression: workouts.position)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => WorkoutWithCount(r.readTable(workouts), r.read(count) ?? 0),
          )
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
    return (update(workouts)..where((w) => w.id.equals(id))).write(
      // Naming a day makes it yours: the seed key goes, so the name stops
      // following the language.
      WorkoutsCompanion(name: Value(name), seedKey: const Value(null)),
    );
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
          final before = existing.firstWhere((w) => w.id == workoutId);
          await (update(workouts)..where((w) => w.id.equals(workoutId))).write(
            WorkoutsCompanion(
              name: Value(d.name),
              // Renaming a day through the builder makes it yours, exactly as
              // [renameWorkout] does. A draft that came back with the name it
              // was given leaves the key alone, so a demo day survives a save
              // that only reordered the routine.
              seedKey: before.name == d.name
                  ? const Value.absent()
                  : const Value(null),
              position: Value(i),
            ),
          );
        }
        ids.add(workoutId);

        final items = d.items;
        if (items != null) {
          await (delete(
            workoutItems,
          )..where((it) => it.workoutId.equals(workoutId))).go();
          for (final it in items) {
            await into(
              workoutItems,
            ).insert(it.copyWith(workoutId: Value(workoutId)));
          }
        }
      }
      return ids;
    });
  }

  // ---- Workout items ------------------------------------------------------

  Stream<List<WorkoutItemView>> watchItemsForWorkout(int workoutId) {
    final query =
        select(workoutItems).join([
            innerJoin(
              exercises,
              exercises.id.equalsExp(workoutItems.exerciseId),
            ),
          ])
          ..where(workoutItems.workoutId.equals(workoutId))
          ..orderBy([OrderingTerm(expression: workoutItems.position)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => WorkoutItemView(
              r.readTable(workoutItems),
              r.readTable(exercises),
            ),
          )
          .toList(),
    );
  }

  Future<List<WorkoutItemView>> itemsForWorkout(int workoutId) async {
    final query =
        select(workoutItems).join([
            innerJoin(
              exercises,
              exercises.id.equalsExp(workoutItems.exerciseId),
            ),
          ])
          ..where(workoutItems.workoutId.equals(workoutId))
          ..orderBy([OrderingTerm(expression: workoutItems.position)]);

    final rows = await query.get();
    return rows
        .map(
          (r) => WorkoutItemView(
            r.readTable(workoutItems),
            r.readTable(exercises),
          ),
        )
        .toList();
  }

  Future<int> _nextRoutinePosition() async {
    final maxPos = routines.position.max();
    final row = await (selectOnly(
      routines,
    )..addColumns([maxPos])).map((r) => r.read(maxPos)).getSingleOrNull();
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
  ///
  /// [seedKey] is the same kind of whole answer: null — the default — is what
  /// naming a routine yourself means, and the editor passes the routine's
  /// existing key back only when it saved the name it was given. Saving a demo
  /// routine after changing nothing but its colour must not cost it the key
  /// that makes it follow the language.
  Future<void> updateRoutineMeta(
    int id, {
    required String name,
    required String color,
    required int restSeconds,
    int scheduleDays = kNoScheduleMask,
    int? reminderMinutes,
    String? seedKey,
  }) {
    return (update(routines)..where((r) => r.id.equals(id))).write(
      RoutinesCompanion(
        name: Value(name),
        seedKey: Value(seedKey),
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
    final query =
        select(routines).join([
            leftOuterJoin(
              sessions,
              sessions.routineId.equalsExp(routines.id) &
                  sessions.endedAt.isNotNull(),
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
          seedKey: routine.seedKey,
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
      await (delete(
        workoutItems,
      )..where((i) => i.workoutId.equals(workoutId))).go();
      for (final it in items) {
        await into(workoutItems).insert(it);
      }
    });
  }

  // ---- Progression --------------------------------------------------------

  Future<WorkoutItem?> workoutItemById(int id) =>
      (select(workoutItems)..where((i) => i.id.equals(id))).getSingleOrNull();

  /// The lightest weight the slot's movement can be loaded to — its own bar, the
  /// gym's default bar, or nothing at all where there is no bar under it.
  ///
  /// Resolved exactly as the board and the builder resolve it (see
  /// [loadFloorKg]), because a target stored below a movement's own bar is a
  /// target nobody can train to, whichever of the three wrote it.
  Future<double> _loadFloorFor(WorkoutItem it) async {
    // Tolerant of a movement that is no longer there: a slot with nothing to
    // name its bar has no bar, which is the same answer as a machine.
    final exercise = await (select(
      exercises,
    )..where((e) => e.id.equals(it.exerciseId))).getSingleOrNull();
    if (exercise == null || !exercise.weightType.loadedPerSide) return 0;
    final row =
        await (select(settings)..where((s) => s.id.equals(1))).getSingleOrNull();
    return loadFloorKg(
      type: exercise.weightType,
      defaultBarKg: row?.barWeight ?? defaultBarKg(row?.weightUnit ?? 'kg'),
      barKg: exercise.barWeight,
    );
  }

  /// Advances one exercise slot after a session, per its own progression rules.
  ///
  /// [success] is the whole exercise's verdict for the session, not one set's —
  /// see `ExerciseEntry.succeeded`. [performedWeight] is the load actually
  /// carried through every set of it, which on the weight axis is allowed to
  /// raise the target on its own — see below. Returns how far the target
  /// moved, in the mode's own unit, counted from where it was before.
  ///
  /// [sessionWeight] is the load the session carried for a slot that has **no**
  /// stored target — the weight typed onto the board, or the sets logged at one.
  /// It establishes the target rather than moving it, which is why it is a
  /// separate argument from [performedWeight]: a slot that already has a target
  /// is only ever raised by weight that was actually lifted.
  ///
  /// The slot may be gone (the workout was edited while the session was in
  /// progress), in which case there is nothing to advance and nothing to say.
  Future<double> advanceProgression(
    int itemId, {
    required bool success,
    double? performedWeight,
    double? sessionWeight,
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
        final floorKg = await _loadFloorFor(it);
        // A slot with no suggested weight and no weight worked today is a
        // bodyweight movement nobody ever put a number on. Inventing one out of
        // a step up would tell them to load 2.5 kg onto a push-up. A weight the
        // session did carry is a number, though, and it becomes the target the
        // step is taken from.
        final from = it.suggestedWeight ?? sessionWeight;
        if (from != null) {
          // Held at the bar as it is read, not only as it is written: a target
          // that drifted under its own bar on an older build is corrected here
          // rather than being stepped on from where it wrongly sat — which is
          // also what stops the climb back to the bar being reported as a step
          // up that never happened.
          final stored = from < floorKg ? floorKg : from;
          // Loading the bar past the suggestion *is* the progression: the step
          // is applied to what you actually carried, not to a number the
          // template has been left behind by. Only upwards — coming down
          // mid-session is a deload, and the failure path is what answers it.
          final base = performedWeight != null && performedWeight > stored
              ? performedWeight
              : stored;
          final to = advanceTarget(base, step.delta, mode, floorKg: floorKg);
          if (to != it.suggestedWeight) {
            patch = patch.copyWith(suggestedWeight: Value(to));
          }
          moved = to - stored;
        }
      case ProgressionMode.reps:
        if (step.delta != 0) {
          final from = it.repsMin;
          final to = advanceTarget(from.toDouble(), step.delta, mode).round();
          patch = patch.copyWith(
            repsMin: Value(to),
            // A range keeps its width: 6–8 becomes 7–9, not 7–8.
            repsMax: Value(
              it.repsMax == null ? null : it.repsMax! + (to - from),
            ),
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

    await (update(
      workoutItems,
    )..where((i) => i.id.equals(itemId))).write(patch);
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
      final items = await (select(
        workoutItems,
      )..where((i) => i.workoutId.equals(workoutId))).get();

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
              final to = deloadedTarget(
                from,
                percent,
                mode,
                floorKg: await _loadFloorFor(it),
              );
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
                repsMax: Value(
                  it.repsMax == null ? null : it.repsMax! + (to - from),
                ),
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
        await (update(
          workoutItems,
        )..where((i) => i.id.equals(it.id))).write(patch);
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
    final row =
        await (select(sessions)
              ..where(
                (s) => s.workoutId.equals(workoutId) & s.endedAt.isNotNull(),
              )
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
    String? seedKey,
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
          seedKey: Value(seedKey),
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

  // ---- Set clips ----------------------------------------------------------

  /// Every clip path any set points at. What the orphan sweep is measured
  /// against: a file on disk that is not in here has nothing referring to it.
  Future<Set<String>> allVideoPaths() async {
    final q = selectOnly(sessionSets)
      ..addColumns([sessionSets.videoPath])
      ..where(sessionSets.videoPath.isNotNull());
    final rows = await q.get();
    return {for (final r in rows) ?r.read(sessionSets.videoPath)};
  }

  /// The same, kept current — the storage screen watches it so deleting a clip
  /// updates the total without a reload.
  Stream<List<String>> watchVideoPaths() {
    final q = selectOnly(sessionSets)
      ..addColumns([sessionSets.videoPath])
      ..where(sessionSets.videoPath.isNotNull());
    return q.watch().map(
      (rows) => [for (final r in rows) ?r.read(sessionSets.videoPath)],
    );
  }

  /// Forgets the clip on set [setId], leaving the set itself exactly as it was.
  /// Deleting the file is the caller's job — see `SetVideoStore` — and happens
  /// after this, so a crash strands a file rather than a dead reference.
  Future<void> clearSetVideo(int setId) =>
      (update(sessionSets)..where((s) => s.id.equals(setId))).write(
        const SessionSetsCompanion(videoPath: Value(null)),
      );

  /// Forgets every clip, leaving every set exactly as it was. The files are
  /// the caller's to remove afterwards — an orphan sweep with no grace does it.
  Future<void> clearAllSetVideos() =>
      (update(sessionSets)..where((s) => s.videoPath.isNotNull())).write(
        const SessionSetsCompanion(videoPath: Value(null)),
      );

  /// Every clip belonging to one exercise, newest first, each carrying the set
  /// and session it came from. This is the per-exercise film reel: your squat
  /// over months, in one list.
  ///
  /// Matched on `exerciseId`, like the rest of the exercise history, so a
  /// movement renamed in the library keeps its clips.
  Stream<List<ExerciseSetEntry>> watchExerciseClips(int exerciseId) {
    return watchExerciseSetHistory(exerciseId).map(
      (sets) => [
        for (final s in sets.reversed)
          if (s.videoPath != null) s,
      ],
    );
  }

  /// How the camera is set up for a set clip: the height to film at and the
  /// hard stop on its length.
  Stream<VideoSetting> watchVideoSetting() {
    return (select(
      settings,
    )..where((s) => s.id.equals(1))).watchSingleOrNull().map(
      (s) => (
        height: s?.videoHeight ?? kDefaultVideoHeight,
        maxSeconds: s?.videoMaxSeconds ?? kDefaultVideoSeconds,
      ),
    );
  }

  Future<void> setVideoHeight(int height) =>
      _writeSettings(SettingsCompanion(videoHeight: Value(height)));

  Future<void> setVideoMaxSeconds(int seconds) =>
      _writeSettings(SettingsCompanion(videoMaxSeconds: Value(seconds)));

  // ---- Exercise history ---------------------------------------------------

  /// Every completed-session set of one exercise, oldest first, each flattened
  /// with the date and name of the session it belongs to.
  ///
  /// Read-only: it drives the per-exercise progress chart and never writes
  /// anything. Matched on `exerciseId` rather than the
  /// denormalised name, so a movement renamed in the library still gathers its
  /// whole history; sets logged before the id was recorded (there are none from
  /// this app, but a hand-edited DB could hold some) simply do not match.
  /// Live, unfinished sessions are excluded — a set only counts once its
  /// session is finished, the same rule the lifetime totals use.
  Stream<List<ExerciseSetEntry>> watchExerciseSetHistory(int exerciseId) {
    final query =
        select(sessionSets).join([
            innerJoin(sessions, sessions.id.equalsExp(sessionSets.sessionId)),
          ])
          ..where(
            sessionSets.exerciseId.equals(exerciseId) &
                sessions.endedAt.isNotNull(),
          )
          ..orderBy([
            OrderingTerm(expression: sessions.startedAt),
            OrderingTerm(expression: sessionSets.setNumber),
          ]);

    return query.watch().map(
      (rows) => rows.map((r) {
        final set = r.readTable(sessionSets);
        final session = r.readTable(sessions);
        return ExerciseSetEntry(
          setId: set.id,
          sessionId: set.sessionId,
          date: session.startedAt,
          sessionName: session.name,
          setNumber: set.setNumber,
          weightKg: set.weight,
          reps: set.reps,
          seconds: set.seconds,
          done: set.done,
          videoPath: set.videoPath,
        );
      }).toList(),
    );
  }

  /// The weight this phone last logged for [exerciseId], in kg, or null if it
  /// has never trained the movement — or trained it carrying nothing.
  ///
  /// What an imported routine puts on a slot: a shared program carries the
  /// prescription but never the sender's weights, so the load has to come from
  /// the history that is actually here. See `routine_import.dart`.
  Future<double?> lastLoggedWeight(int exerciseId) async {
    final query =
        select(sessionSets).join([
            innerJoin(sessions, sessions.id.equalsExp(sessionSets.sessionId)),
          ])
          ..where(
            sessionSets.exerciseId.equals(exerciseId) &
                sessionSets.done.equals(true) &
                sessionSets.weight.isBiggerThanValue(0) &
                sessions.endedAt.isNotNull(),
          )
          ..orderBy([
            OrderingTerm(
                expression: sessions.startedAt, mode: OrderingMode.desc),
            OrderingTerm(
                expression: sessionSets.setNumber, mode: OrderingMode.desc),
          ])
          ..limit(1);

    final row = await query.getSingleOrNull();
    return row?.readTable(sessionSets).weight;
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
    final volumeExp = (sessionSets.weight * sessionSets.reps.cast<double>())
        .total();
    final repsExp = sessionSets.reps.sum();
    final setsExp = sessionSets.id.count();

    final q =
        selectOnly(sessionSets).join([
            innerJoin(
              sessions,
              sessions.id.equalsExp(sessionSets.sessionId),
              useColumns: false,
            ),
          ])
          ..addColumns([volumeExp, repsExp, setsExp])
          ..where(sessionSets.done.equals(true) & sessions.endedAt.isNotNull());

    return q.watchSingle().map(
      (row) => LifetimeTotals(
        volumeKg: row.read(volumeExp) ?? 0,
        reps: row.read(repsExp) ?? 0,
        sets: row.read(setsExp) ?? 0,
      ),
    );
  }

  // ---- Settings -----------------------------------------------------------

  Stream<String> watchWeightUnit() {
    return (select(settings)..where((s) => s.id.equals(1)))
        .watchSingleOrNull()
        .map((s) => s?.weightUnit ?? 'kg');
  }

  /// Whether the unit has been stored yet. False for the moment between a fresh
  /// install's first launch and [seedWeightUnit] answering for it — see
  /// `unitSeedProvider`, and the holding frame in `main.dart` that waits on it.
  Stream<bool> watchUnitChosen() {
    return (select(settings)..where((s) => s.id.equals(1)))
        .watchSingleOrNull()
        .map((s) => s?.weightUnit != null);
  }

  /// Stores [unit] as the app's, but only on an install that has none.
  ///
  /// This is the first launch guessing from the phone's region. It is
  /// deliberately not [setWeightUnit]: that one is a *switch*, with a dialog in
  /// front of it and a pass over every template behind it, and neither means
  /// anything on a database with nothing in it yet.
  ///
  /// The write-once rule is the point. The phone's region is a guess and the
  /// stored unit is an answer, so once there is an answer the guess stops being
  /// asked — moving abroad, or switching the app's language, must not silently
  /// re-unit a training log somebody has been keeping.
  Future<void> seedWeightUnit(String unit) async {
    final row =
        await (select(settings)..where((s) => s.id.equals(1))).getSingleOrNull();
    if (row?.weightUnit != null) return;
    await _writeSettings(SettingsCompanion(weightUnit: Value(unit)));
  }

  /// Stores the chosen unit and moves the templates over with it.
  ///
  /// Two things follow a switch, and both are about the numbers the user is
  /// about to *act on* rather than the ones they already lifted:
  ///
  /// * **The step rates.** A slot still sitting on the old unit's default takes
  ///   the new unit's default, so switching to pounds gives 5 lb steps and not
  ///   5.51. A rate that was set deliberately is left alone — it converts, like
  ///   every other stored kilogram.
  /// * **The suggested weight.** Converted exactly, 100 kg is 220.46 lb, which
  ///   is not a bar anybody sets; it is snapped to the nearest step in the new
  ///   unit instead.
  ///
  /// **Nothing else is rewritten.** Logged sets keep the kilograms they were
  /// lifted at, their goal weights with them, and the bars and plates the gym
  /// owns weigh what they weigh in any unit.
  Future<void> setWeightUnit(String unit) {
    return transaction(() async {
      final row =
          await (select(settings)..where((s) => s.id.equals(1))).getSingleOrNull();
      final was = row?.weightUnit ?? 'kg';
      await _writeSettings(SettingsCompanion(weightUnit: Value(unit)));
      if (was == unit) return;

      for (final item in await select(workoutItems).get()) {
        final mode = item.progression;
        var patch = const WorkoutItemsCompanion();
        var moved = false;
        if (isDefaultIncrement(item.increment, mode, was)) {
          patch = patch.copyWith(
              increment: Value(defaultIncrementFor(mode, unit)));
          moved = true;
        }
        if (isDefaultDeload(item.deload, mode, was)) {
          patch = patch.copyWith(deload: Value(defaultDeloadFor(mode, unit)));
          moved = true;
        }
        final weight = item.suggestedWeight;
        if (weight != null && weight > 0) {
          final snapped = snapToUnitStep(weight, unit);
          if (snapped != weight) {
            patch = patch.copyWith(suggestedWeight: Value(snapped));
            moved = true;
          }
        }
        if (!moved) continue;
        await (update(workoutItems)..where((i) => i.id.equals(item.id)))
            .write(patch);
      }
    });
  }

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

  /// The user's text-size nudge. 1.0 — follow the phone — until they say
  /// otherwise.
  Stream<double> watchTextScale() {
    return (select(settings)..where((s) => s.id.equals(1)))
        .watchSingleOrNull()
        .map((s) => s?.textScale ?? 1.0);
  }

  Future<void> setTextScale(double scale) =>
      _writeSettings(SettingsCompanion(textScale: Value(scale)));

  /// The language the app renders in, or null on an install where first run has
  /// not answered yet.
  ///
  /// That null is the only one there is: `localeTagProvider` resolves the
  /// phone's list against the catalogues we ship and writes the answer back the
  /// first time it sees it, so a stored language is a choice from then on rather
  /// than a standing deference to the phone.
  Stream<String?> watchLocaleTag() {
    return (select(settings)..where((s) => s.id.equals(1)))
        .watchSingleOrNull()
        .map((s) => s?.localeTag);
  }

  /// Picks the language. There is no unsetting it — one of the five is always
  /// chosen, and the way out of a language is choosing another.
  Future<void> setLocaleTag(String tag) =>
      _writeSettings(SettingsCompanion(localeTag: Value(tag)));

  /// The layoff rules, falling back to the defaults if the settings row has
  /// somehow not been written yet.
  Stream<LayoffSettings> watchLayoffSettings() {
    return (select(
      settings,
    )..where((s) => s.id.equals(1))).watchSingleOrNull().map(_layoffOf);
  }

  Future<LayoffSettings> layoffSettings() async {
    final row = await (select(
      settings,
    )..where((s) => s.id.equals(1))).getSingleOrNull();
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

  /// How many warm-up rungs a session opens each exercise with.
  Stream<int> watchDefaultWarmupSets() {
    return (select(settings)..where((s) => s.id.equals(1)))
        .watchSingleOrNull()
        .map(_warmupSetsOf);
  }

  /// The same, read once — what [ActiveWorkoutController.start] seeds from.
  Future<int> defaultWarmupSets() async {
    final row = await (select(
      settings,
    )..where((s) => s.id.equals(1))).getSingleOrNull();
    return _warmupSetsOf(row);
  }

  int _warmupSetsOf(Setting? s) => s?.warmupSets ?? kDefaultWarmupSets;

  Future<void> setDefaultWarmupSets(int sets) =>
      _writeSettings(SettingsCompanion(warmupSets: Value(sets)));

  /// The bar and plate setup as stored — nulls and all. Resolve it against the
  /// current unit with [resolvePlateSettings] before using it; see
  /// `plateSettingsProvider`.
  Stream<StoredPlateSetup> watchPlateSetup() {
    return (select(
      settings,
    )..where((s) => s.id.equals(1))).watchSingleOrNull().map(
      (s) => (
        kgRack: s?.plateInventory,
        lbRack: s?.plateInventoryLb,
        barKg: s?.barWeight,
      ),
    );
  }

  /// Picks the bar weighing [kg] as the app-wide default.
  Future<void> setBarWeight(double kg) =>
      _writeSettings(SettingsCompanion(barWeight: Value(kg)));

  // ---- Bars ---------------------------------------------------------------
  //
  // The gym's bars as rows — see [Bars] for the model, in particular why a bar
  // is referred to by its weight rather than by its id.

  /// The bars on [unit]'s list, lightest first.
  Stream<List<Bar>> watchBars(String unit) => _barsFor(unit).watch();

  /// The same list, read once.
  Future<List<Bar>> barsFor(String unit) => _barsFor(unit).get();

  SimpleSelectStatement<$BarsTable, Bar> _barsFor(String unit) => select(bars)
    ..where((b) => b.unit.equals(unit))
    ..orderBy([(b) => OrderingTerm(expression: b.weightKg)]);

  /// Adds a bar to [unit]'s list. False — and nothing written — when a bar on
  /// that list already weighs this much: references are weights, so two of them
  /// could not be told apart.
  Future<bool> addBar({
    required String unit,
    required String name,
    required double kg,
  }) async {
    if (await _barAt(unit, kg) != null) return false;
    await into(bars).insert(
      BarsCompanion.insert(
        unit: unit,
        name: name.trim(),
        weightKg: kg,
        isCustom: const Value(true),
      ),
    );
    return true;
  }

  /// Renames and re-weighs a bar of your own, moving everything that pointed at
  /// its old weight — exercises with a bar of their own, the app-wide default —
  /// onto the new one.
  ///
  /// False when another bar on the same list already weighs [kg], and false for
  /// one of the seeded bars, which are fixed — see [Bars]. The screen does not
  /// offer the pencil on those, so getting here with one is a bug rather than a
  /// refusal anybody sees.
  Future<bool> editBar(
    int id, {
    required String name,
    required double kg,
  }) async {
    final bar = await (select(
      bars,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
    if (bar == null || !bar.isCustom) return false;
    if (await _barAt(bar.unit, kg, except: id) != null) return false;
    await (update(bars)..where((b) => b.id.equals(id))).write(
      BarsCompanion(name: Value(name.trim()), weightKg: Value(kg)),
    );
    if ((bar.weightKg - kg).abs() > kPlateToleranceKg) {
      await _repointBar(bar.weightKg, kg);
    }
    return true;
  }

  /// Deletes a bar. Exercises that used it fall back to the default, and if it
  /// *was* the default, that falls back to the standard bar for the unit —
  /// nothing is left pointing at a bar the gym no longer has.
  Future<void> deleteBar(int id) async {
    final bar = await (select(
      bars,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
    if (bar == null) return;
    await (delete(bars)..where((b) => b.id.equals(id))).go();
    await _repointBar(bar.weightKg, null);
  }

  /// The bar on [unit]'s list weighing [kg], or null. Within
  /// [kPlateToleranceKg], because a pounds bar's kilograms have a tail on them.
  Future<Bar?> _barAt(String unit, double kg, {int? except}) async {
    for (final b in await barsFor(unit)) {
      if (b.id != except && (b.weightKg - kg).abs() <= kPlateToleranceKg) {
        return b;
      }
    }
    return null;
  }

  /// Moves every reference to a bar of [fromKg] onto [toKg] — or, when that is
  /// null, off it: an exercise falls back to the default and the default falls
  /// back to the standard bar for the unit.
  Future<void> _repointBar(double fromKg, double? toKg) async {
    final lo = fromKg - kPlateToleranceKg;
    final hi = fromKg + kPlateToleranceKg;
    await (update(exercises)..where((e) => e.barWeight.isBetweenValues(lo, hi)))
        .write(ExercisesCompanion(barWeight: Value(toKg)));
    await (update(settings)
          ..where((s) => s.id.equals(1) & s.barWeight.isBetweenValues(lo, hi)))
        .write(SettingsCompanion(barWeight: Value(toKg)));
  }

  /// Stores the rack for [unit] — the racks are kept apart, see
  /// [resolvePlateSettings].
  Future<void> setPlateInventory(List<PlateStack> plates, String unit) {
    final encoded = Value(encodePlates(plates));
    return _writeSettings(
      unit == 'lb'
          ? SettingsCompanion(plateInventoryLb: encoded)
          : SettingsCompanion(plateInventory: encoded),
    );
  }

  /// Forgets the rack for [unit], so the standard one stands in again. The
  /// other unit's rack is left alone — it was never the thing being reset.
  Future<void> resetPlateInventory(String unit) => _writeSettings(
    unit == 'lb'
        ? const SettingsCompanion(plateInventoryLb: Value(null))
        : const SettingsCompanion(plateInventory: Value(null)),
  );

  /// Forgets the configured default bar.
  Future<void> resetBarWeight() =>
      _writeSettings(const SettingsCompanion(barWeight: Value(null)));

  /// The selected theme's id as stored: a preset slug, `custom:<n>`, or null
  /// for "nothing chosen", which follows the system brightness. Resolving it
  /// into a palette lives in `app_theme.dart` (`resolvePalette`); the UI reads
  /// the result via `activePaletteProvider`.
  Stream<String?> watchThemePresetId() {
    return (select(settings)..where((s) => s.id.equals(1)))
        .watchSingleOrNull()
        .map((s) => s?.themePresetId);
  }

  /// The user's own themes, oldest first — the order they were built or
  /// imported in, which is the order the picker lists them in.
  Stream<List<CustomTheme>> watchCustomThemes() => (select(
    customThemes,
  )..orderBy([(t) => OrderingTerm(expression: t.id)])).watch();

  // ---- The live session's crash snapshot ----------------------------------
  //
  // See [LiveSessions]. Three calls: one to mirror, one to read back on launch,
  // one to forget. Nothing else in the app touches this table.

  /// Mirrors the live session to disk, replacing whatever was there.
  ///
  /// **Written as a statement rather than through the table's API, on purpose:
  /// this write must not notify anything.** A drift insert tells the update
  /// machinery a table changed, every open stream that could be affected re-runs
  /// its query, and every one of them is a query nobody asked for — the snapshot
  /// is read exactly once, on launch, and never watched. A session logs a set
  /// every couple of minutes and edits a weight in between; waking the whole app's
  /// streams each time would be a real cost for no reader at all.
  ///
  /// The id is spelled out because SQLite ignores a default on a single-column
  /// integer primary key and hands out a fresh row id instead, which would stack
  /// snapshots up rather than replacing the one slot.
  Future<void> saveLiveSession(String payload, {DateTime? at}) =>
      customStatement(
        'INSERT INTO live_sessions (id, payload, saved_at) VALUES (1, ?, ?) '
        'ON CONFLICT(id) DO UPDATE SET payload = excluded.payload, '
        'saved_at = excluded.saved_at',
        [payload, (at ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000],
      );

  /// The snapshot left by the last run, or null if there is none.
  Future<LiveSession?> loadLiveSession() =>
      (select(liveSessions)..where((t) => t.id.equals(1))).getSingleOrNull();

  /// Forgets the snapshot — the session was finished or thrown away. A statement
  /// again, and for the same reason as [saveLiveSession].
  Future<void> clearLiveSession() =>
      customStatement('DELETE FROM live_sessions');

  /// Writes a consistent copy of the whole database to [path], for a backup.
  ///
  /// **`VACUUM INTO`, not a file copy.** The database is open and being written
  /// to while this runs, and SQLite keeps recent writes in a journal beside the
  /// main file until they are checkpointed — so copying the file on its own can
  /// produce a database that is missing the last thing you logged, or one that
  /// is torn between the two. `VACUUM INTO` is SQLite's own answer: it walks the
  /// live database under a read transaction and writes a compact, complete copy
  /// of it, with nothing to reassemble afterwards.
  ///
  /// The path is bound rather than pasted into the statement — a temporary
  /// directory on iOS has a container UUID in it, and a path is not something to
  /// be quoting by hand.
  Future<void> snapshotTo(String path) =>
      customStatement('VACUUM INTO ?', [path]);

  /// Selects a shipped preset, or `custom:<n>` for one of the user's own, as
  /// the active theme. Passing null falls back to the system default. Nothing
  /// stored in [CustomThemes] is touched, so switching away and back is
  /// lossless.
  Future<void> setThemePreset(String? presetId) =>
      _writeSettings(SettingsCompanion(themePresetId: Value(presetId)));

  /// Adds a theme the user built or imported and selects it, in one write.
  /// Returns its row id. [json] comes from `AppPalette.toJson`.
  ///
  /// Adding, never replacing: an imported code arrives alongside whatever is
  /// already here rather than over the top of it.
  Future<int> addCustomTheme(String json) => transaction(() async {
    final id = await into(
      customThemes,
    ).insert(CustomThemesCompanion.insert(palette: json));
    await setThemePreset(customThemeId(id));
    return id;
  });

  /// Rewrites theme [id]'s palette and selects it. Saving a theme you were
  /// editing is also a request to look at it.
  Future<void> updateCustomTheme(int id, String json) => transaction(() async {
    await (update(customThemes)..where((t) => t.id.equals(id))).write(
      CustomThemesCompanion(palette: Value(json)),
    );
    await setThemePreset(customThemeId(id));
  });

  /// Removes theme [id], and — if it was the selected one — the selection with
  /// it, so the app falls back to the system default rather than being left
  /// pointing at a row that is gone.
  Future<void> deleteCustomTheme(int id) => transaction(() async {
    await (delete(customThemes)..where((t) => t.id.equals(id))).go();
    final selected = await (select(
      settings,
    )..where((s) => s.id.equals(1))).getSingleOrNull();
    if (selected?.themePresetId == customThemeId(id)) {
      await setThemePreset(null);
    }
  });

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
      // The unit is deliberately left null: an install that has never been
      // asked which unit it trains in is the whole trigger for the first-run
      // question. See `Settings.weightUnit`.
      const SettingsCompanion(id: Value(1)),
      mode: InsertMode.insertOrIgnore,
    );

    // The bars a gym is assumed to rack, both units' lists at once: the unit can
    // be switched at any time and the list for the other one should be there
    // when it is, the same way the plate rack is.
    for (final unit in const ['kg', 'lb']) {
      for (final b in namedBars(unit)) {
        await into(bars).insert(
          BarsCompanion.insert(
            unit: unit,
            name: b.name,
            seedKey: Value(kSeedBarKeys[b.name]),
            weightKg: b.weight,
          ),
        );
      }
    }

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
          // What the screens actually render from — see `seed_names.dart`.
          seedKey: Value(kSeedExerciseKeys[name]),
          muscleGroup: Value(muscle),
          equipment: Value(equip),
          measure: Value(measure),
          weightType: Value(_seedWeightType(name, equip)),
          // A specific video, in the canonical short form — see
          // [_starterDemos]. These were YouTube *searches*, which meant a
          // results page to pick from rather than a demo, and no id for a
          // shared routine to carry.
          videoUrl: Value(
            _starterDemos[name] == null
                ? null
                : youTubeUrl(_starterDemos[name]!),
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

    // Five starter programs, each split into its training days. Upper/Lower
    // deliberately repeats a day name — that is legal and worth demonstrating.
    Future<int> routine(
      String name,
      String color,
      int pos,
      int rest,
      List<({String name, List<_SeedItem> items})> days, {
      int schedule = kNoScheduleMask,
      int fails = defaultFailureThreshold,
    }) async {
      final rid = await into(routines).insert(
        RoutinesCompanion.insert(
          name: name,
          seedKey: Value(kSeedRoutineKeys[name]),
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
            seedKey: Value(kSeedWorkoutKeys[day.name]),
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
            it.w == null ? ProgressionMode.reps : ProgressionMode.weight,
          );
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
              increment: Value(it.inc ?? mode.defaultIncrement),
              deload: Value(it.deload ?? mode.defaultDeload),
              failureThreshold: Value(fails),
            ),
          );
        }
      }
      return rid;
    }

    final ppl = await routine('Push / Pull / Legs', 'FF6A3D', 0, 120, [
      (
        name: 'Push',
        items: [
          _SeedItem('Bench Press', sets: 4, min: 6, max: 8, w: 80),
          _SeedItem('Overhead Press', sets: 4, min: 8, max: null, w: 50),
          _SeedItem('Incline DB Press', sets: 3, min: 10, max: 12, w: 30),
          _SeedItem('Lateral Raise', sets: 3, min: 15, max: null, w: 12),
          _SeedItem('Triceps Pushdown', sets: 3, min: 12, max: 15, w: 35),
        ],
      ),
      (
        name: 'Pull',
        items: [
          _SeedItem('Deadlift', sets: 3, min: 5, max: null, w: 140),
          _SeedItem('Pull-Up', sets: 4, min: 6, max: 10, w: null),
          _SeedItem('Barbell Row', sets: 4, min: 8, max: null, w: 70),
          _SeedItem('Face Pull', sets: 3, min: 15, max: 20, w: 25),
          _SeedItem('Barbell Curl', sets: 3, min: 10, max: 12, w: 30),
        ],
      ),
      (
        name: 'Legs',
        items: [
          _SeedItem('Back Squat', sets: 4, min: 6, max: null, w: 110),
          _SeedItem('Romanian Deadlift', sets: 3, min: 10, max: null, w: 90),
          _SeedItem('Leg Press', sets: 3, min: 12, max: 15, w: 180),
          _SeedItem('Leg Curl', sets: 3, min: 12, max: null, w: 45),
          _SeedItem('Calf Raise', sets: 4, min: 15, max: 20, w: 60),
        ],
      ),
      // Mondays, Wednesdays and Fridays — a schedule on one of the two demo
      // routines and none on the other, so both states of the setting are
      // visible before anyone has configured anything. No reminder either way:
      // notifications are asked for, never assumed.
    ], schedule: 1 << 0 | 1 << 2 | 1 << 4);

    await routine('Upper / Lower', '3ED598', 1, 150, [
      (
        name: 'Upper 1',
        items: [
          _SeedItem('Bench Press', sets: 4, min: 5, max: null, w: 80),
          _SeedItem('Barbell Row', sets: 4, min: 6, max: 8, w: 70),
          _SeedItem('Overhead Press', sets: 3, min: 8, max: 10, w: 45),
          _SeedItem('Lat Pulldown', sets: 3, min: 10, max: 12, w: 55),
        ],
      ),
      (
        name: 'Lower 1',
        items: [
          _SeedItem('Back Squat', sets: 4, min: 5, max: null, w: 110),
          _SeedItem('Romanian Deadlift', sets: 3, min: 8, max: 10, w: 90),
          _SeedItem('Leg Curl', sets: 3, min: 12, max: null, w: 45),
          _SeedItem('Calf Raise', sets: 4, min: 15, max: 20, w: 60),
        ],
      ),
      (
        name: 'Upper 2',
        items: [
          _SeedItem('Incline DB Press', sets: 4, min: 8, max: 10, w: 30),
          _SeedItem('Pull-Up', sets: 4, min: 6, max: 10, w: null),
          _SeedItem('Lateral Raise', sets: 3, min: 15, max: null, w: 12),
          _SeedItem('Hammer Curl', sets: 3, min: 10, max: 12, w: 14),
        ],
      ),
      (
        name: 'Lower 2',
        items: [
          _SeedItem('Deadlift', sets: 3, min: 5, max: null, w: 140),
          _SeedItem('Front Squat', sets: 3, min: 8, max: 10, w: 70),
          _SeedItem('Leg Press', sets: 3, min: 12, max: 15, w: 180),
          _SeedItem('Hanging Leg Raise', sets: 3, min: 10, max: null, w: null),
        ],
      ),
    ]);

    // The three beginner strength programs. They are linear-progression
    // barbell routines rather than splits, so they carry their own rates: the
    // squat and the deadlift take 5 kg a session where a press takes 2.5, and
    // the two published ones reset only after a third failed session — the
    // extra attempt is part of the program, not a leniency.
    await routine('Starting Strength', '4D9DE0', 2, 300, [
      (
        name: 'Workout A',
        items: [
          _SeedItem.heavy('Back Squat', sets: 3, min: 5, w: 60),
          _SeedItem('Bench Press', sets: 3, min: 5, w: 45),
          // One work set. The deadlift is the lift the program deliberately
          // does not do three sets of.
          _SeedItem.heavy('Deadlift', sets: 1, min: 5, w: 70),
        ],
      ),
      (
        name: 'Workout B',
        items: [
          _SeedItem.heavy('Back Squat', sets: 3, min: 5, w: 60),
          _SeedItem('Overhead Press', sets: 3, min: 5, w: 30),
          // Five triples, trained for speed rather than for load.
          _SeedItem('Power Clean', sets: 5, min: 3, w: 40),
        ],
      ),
    ], schedule: 1 << 0 | 1 << 2 | 1 << 4, fails: 3);

    await routine('StrongLifts 5x5', 'C77DFF', 3, 180, [
      (
        name: 'Workout A',
        items: [
          // Everything but the deadlift takes the ordinary 2.5 kg here — the
          // program is five sets of five on a bar that starts nearly empty.
          _SeedItem('Back Squat', sets: 5, min: 5, w: 40),
          _SeedItem('Bench Press', sets: 5, min: 5, w: 30),
          _SeedItem('Barbell Row', sets: 5, min: 5, w: 30),
        ],
      ),
      (
        name: 'Workout B',
        items: [
          _SeedItem('Back Squat', sets: 5, min: 5, w: 40),
          _SeedItem('Overhead Press', sets: 5, min: 5, w: 20),
          _SeedItem.heavy('Deadlift', sets: 1, min: 5, w: 60),
        ],
      ),
    ], schedule: 1 << 0 | 1 << 2 | 1 << 4, fails: 3);

    // Not a published program, so it keeps the app's own back-off rule and
    // trains on the other three days of the week.
    await routine('Full Body 3x', 'E8C547', 4, 120, [
      (
        name: 'Workout A',
        items: [
          _SeedItem.heavy('Back Squat', sets: 3, min: 5, w: 55),
          _SeedItem('Bench Press', sets: 3, min: 5, w: 40),
          _SeedItem('Seated Cable Row', sets: 3, min: 10, w: 45),
          _SeedItem('Hanging Leg Raise', sets: 3, min: 8, max: 12),
        ],
      ),
      (
        name: 'Workout B',
        items: [
          _SeedItem.heavy('Romanian Deadlift', sets: 3, min: 8, w: 60),
          _SeedItem('Overhead Press', sets: 3, min: 6, max: 8, w: 30),
          _SeedItem('Lat Pulldown', sets: 3, min: 10, max: 12, w: 50),
          _SeedItem('Cable Crunch', sets: 3, min: 12, max: 15, w: 30),
        ],
      ),
      (
        name: 'Workout C',
        items: [
          _SeedItem.heavy('Deadlift', sets: 2, min: 5, w: 80),
          _SeedItem('Incline DB Press', sets: 3, min: 8, max: 10, w: 22.5),
          _SeedItem('Chin-Up', sets: 3, min: 5, max: 8),
          _SeedItem('Leg Curl', sets: 3, min: 12, w: 40),
        ],
      ),
    ], schedule: 1 << 1 | 1 << 3 | 1 << 5);

    // Give Today something to be about on first launch.
    await setActiveRoutineId(ppl);
  }
}

/// The database this build opens — a file on a phone, browser storage on the
/// web. Which one is decided at compile time; see `db_open.dart`.
QueryExecutor _openConnection() => openAppDatabase();
