/// Starter programs shipped as prescriptions rather than database rows.
///
/// These used to be written into the routines table on first launch. They are a
/// table in the code instead, and the routine library is a screen over it: nine
/// programs nobody chose are nine rows to wade past before finding the one you
/// actually train, and a program that only exists once somebody asks for it
/// cannot be in the way.
///
/// **Code, not rows**, which settles a list of questions at once: there is
/// nothing to migrate, nothing to keep in step with a backup, and no way for a
/// phone to end up with a library different from the build it is running. It is
/// the same argument the colour presets are settled by.
///
/// Adding one copies it — see `AppDatabase.addStarterRoutine`. From that moment
/// it is an ordinary routine of yours: rename it, re-order it, throw it away, and
/// none of it reaches this table or any other copy of it.
///
/// **Every movement named here is in the starter exercise library**, so adding a
/// program writes a routine, its days and its slots and no exercises at all — the
/// history you already have on Bench Press is the history the new program's bench
/// slot is about.
///
/// Pure Dart: no drift, no Flutter, in the manner of the other rule modules.
library;

import 'progression.dart';
import 'schedule.dart' show kNoScheduleMask;
import 'set_scheme.dart';
import 'seed_keys.dart';

part 'starter_routines/basic_routines.dart';
part 'starter_routines/established_routines.dart';
part 'starter_routines/gzclp.dart';
part 'starter_routines/candito.dart';
part 'starter_routines/sheiko.dart';
part 'starter_routines/tsa_routines.dart';

enum ExperienceLevel { beginner, intermediate, advanced }

/// One exercise slot of a shipped program.
class StarterSlot {
  /// A slot that steps at whatever its progression axis steps at by default:
  /// 2.5 kg on a press, a rep on a movement that carries no load.
  const StarterSlot(
    this.exercise, {
    required this.sets,
    this.repsMin = 0,
    this.repsMax,
    this.weightKg,
    this.holdSeconds,
    this.increment,
    this.deload,
    this.successThreshold,
    this.targetRpe,
    this.customSets = const [],
    this.supersetWithPrevious = false,
    this.addWeightAtTopOfRange = false,
    this.gzclTier,
    this.gzclStages = const [],
    this.gzclAmrapTarget = defaultGzclT3AmrapTarget,
  }) : cycle = const [];

  /// A slot on one of the lifts a linear-progression program moves 5 kg a
  /// session — the squat, the deadlift and their variants — rather than the
  /// 2.5 kg the presses take. The back-off is twice the step, as everywhere.
  const StarterSlot.heavy(
    this.exercise, {
    required this.sets,
    required this.repsMin,
    required this.weightKg,
    this.deload = 10,
    this.targetRpe,
    this.gzclTier,
    this.gzclStages = const [],
    this.gzclAmrapTarget = defaultGzclT3AmrapTarget,
  }) : repsMax = null,
       holdSeconds = null,
       increment = 5,
       successThreshold = null,
       cycle = const [],
       customSets = const [],
       supersetWithPrevious = false,
       addWeightAtTopOfRange = false;

  /// A slot whose sets are written out one at a time, each at its own
  /// percentage of [weightKg] — the shape a program that prescribes every set
  /// of every session is made of.
  ///
  /// **It steps by nothing.** A program written out session by session already
  /// carries its own overload in the sessions; a step on top of it would be a
  /// second program running underneath the first. So the rates are zero rather
  /// than absent — the ordinary rates on the slot, set to nothing — and the max
  /// stays where it is put until somebody moves it. Where a program does want
  /// its written-out slots to climb, [increment] says so.
  ///
  /// The set count comes from the rows for the same reason a cycle's does: the
  /// prescription is written out in full, so how many rows it has is how many
  /// sets there are.
  const StarterSlot.custom(
    this.exercise, {
    required this.customSets,
    required this.weightKg,
    this.increment = 0,
    this.deload = 0,
    this.targetRpe,
    this.gzclTier,
    this.gzclStages = const [],
    this.gzclAmrapTarget = defaultGzclT3AmrapTarget,
  }) : sets = 0,
       repsMin = 0,
       repsMax = null,
       holdSeconds = null,
       successThreshold = null,
       cycle = const [],
       supersetWithPrevious = false,
       addWeightAtTopOfRange = false;

  /// A slot that rotates through [cycle] — a week of written-out sets at a
  /// time, every percentage taken from [weightKg] as a training max.
  ///
  /// [increment] is what the max gains when a clean cycle comes round, which is
  /// where a 5/3/1 program's "add 2.5 kg to the presses and 5 to the pulls"
  /// lives. The set count comes from the weeks rather than being stated: a week
  /// is written out in full, so how many rows it has is how many sets there
  /// are.
  const StarterSlot.cycling(
    this.exercise, {
    required this.cycle,
    required this.weightKg,
    required this.increment,
    this.targetRpe,
    this.gzclTier,
    this.gzclStages = const [],
    this.gzclAmrapTarget = defaultGzclT3AmrapTarget,
  }) : sets = 0,
       repsMin = 0,
       repsMax = null,
       holdSeconds = null,
       successThreshold = null,
       deload = null,
       customSets = const [],
       supersetWithPrevious = false,
       addWeightAtTopOfRange = false;

  /// The canonical English name of a movement in the starter library.
  final String exercise;
  final int sets;
  final int repsMin;
  final int? repsMax;

  /// The load to open at, in kilograms, or null for a slot that carries none.
  final double? weightKg;

  /// How long a work interval lasts, in seconds — an interval program's answer
  /// where a strength program has [repsMin]. Null on anything counted in reps.
  ///
  /// Which of the two a slot actually gets is not this table's to decide: the
  /// axis comes from the movement's own measure, so a held movement takes this
  /// and a counted one ignores it. See `AppDatabase.addStarterRoutine`.
  final int? holdSeconds;

  /// The program's own step up and back-off, or null to take the axis's.
  final double? increment;
  final double? deload;

  /// How many clean sessions this slot takes before it steps, or null for the
  /// app's own — one. Three is where a program puts a lift it wants moving once
  /// a month rather than once a week: the shoulder press and the chin-up on
  /// Candito's linear program, which are trained weekly and progressed far
  /// slower than the lifts beside them.
  final int? successThreshold;

  /// Prescribed effort in tenths (75 is RPE 7.5).
  final int? targetRpe;

  /// The weeks this slot rotates through, or empty for a slot that does not —
  /// see [StarterSlot.cycling] and `data/set_scheme.dart`.
  final List<List<CustomSet>> cycle;

  /// The rows this slot is written out as, or empty for a slot that is not —
  /// see [StarterSlot.custom]. A slot never has both these and [cycle]: one
  /// prescription is written out once, the other a week at a time.
  final List<CustomSet> customSets;
  final bool supersetWithPrevious;
  final bool addWeightAtTopOfRange;
  final GzclTier? gzclTier;
  final List<GzclStage> gzclStages;
  final int gzclAmrapTarget;
}

/// One training day of a shipped program.
class StarterDay {
  const StarterDay(this.name, this.items);

  /// The canonical English name — rendered through [kSeedWorkoutKeys], so it
  /// follows the language like every other shipped row.
  final String name;
  final List<StarterSlot> items;
}

/// One program the app ships.
class StarterRoutine {
  const StarterRoutine({
    required this.key,
    required this.name,
    required this.colorHex,
    required this.restSeconds,
    required this.days,
    required this.description,
    this.experienceLevel = ExperienceLevel.beginner,
    this.scheduleDays = kNoScheduleMask,
    this.failureThreshold = defaultFailureThreshold,
  });

  /// A stable id for the program, and what the preview route is addressed by.
  /// Not the seed key: this names the entry in the library, and it may not be
  /// renumbered — a link into the library has to keep opening the same program.
  final String key;

  /// The canonical English name. Screens render `seededName(l10n, seedKey,
  /// name)`, as with every shipped row.
  final String name;

  final String colorHex;
  final int restSeconds;

  /// What the program is, in a sentence or two: who it is for, how often it is
  /// trained, and what it is trying to do. Shown on the preview before anything
  /// is written, and copied onto the routine so it is still there afterwards.
  ///
  /// **The canonical English**, like the name — the screens render it through
  /// `seededDescription` (`util/seed_names.dart`) so it follows the language, and
  /// a description somebody typed over it is shown as they typed it.
  final String description;

  /// The training experience this template assumes. This is browsing metadata;
  /// it is not copied into the user's routine or stored in their database.
  final ExperienceLevel experienceLevel;

  /// The weekdays the program is meant to be trained on — part of the program,
  /// as "this is a Monday/Wednesday/Friday split" is something its author
  /// decided. No reminder comes with it: a notification is asked for.
  final int scheduleDays;

  /// How many missed sessions a slot takes before it backs off. The two
  /// published linear-progression programs allow a third attempt, which is part
  /// of the program rather than a leniency.
  final int failureThreshold;

  final List<StarterDay> days;

  /// Which shipped routine this is, so the library and the copy it makes both
  /// name it in the app's language. Null would mean a program with no
  /// translation, which none of these is.
  String? get seedKey => kSeedRoutineKeys[name];

  /// How many exercise slots the program holds across all of its days.
  int get exerciseCount =>
      days.fold(0, (total, day) => total + day.items.length);
}

/// Monday, Wednesday and Friday — what the three-day programs are written for.
const int _mwf = 1 << 0 | 1 << 2 | 1 << 4;

/// Tuesday, Thursday and Saturday.
const int _tts = 1 << 1 | 1 << 3 | 1 << 5;

/// Tuesday and Friday — the two-day programs, with the weekend clear.
const int _tf = 1 << 1 | 1 << 4;

/// Tuesday and Saturday, so a conditioning program falls between the sessions of
/// a Monday/Wednesday/Friday one rather than on top of them.
const int _ts = 1 << 1 | 1 << 5;

/// Monday, Tuesday, Thursday and Friday — the four-day upper/lower week, each
/// heavy day followed by its variation day and the weekend clear.
const int _mtthf = 1 << 0 | 1 << 1 | 1 << 3 | 1 << 4;

/// Monday, Wednesday, Friday and Saturday — the four-day 5/3/1 week, with one
/// pair of days back to back rather than a session on a Sunday.
const int _mwfs = 1 << 0 | 1 << 2 | 1 << 4 | 1 << 5;

final List<StarterRoutine> kStarterRoutines = [
  _gzclp,
  _fitnessBasicBeginner,
  ..._retiredAndEstablishedRoutines.where(
    (routine) =>
        const {'starting-strength', 'stronglifts-5x5'}.contains(routine.key),
  ),
  _bodyweightfitnessRecommended,
  _dumbbellStopgap,
  ..._retiredAndEstablishedRoutines.where(
    (routine) => const {'531-beginners', 'tsa-beginner'}.contains(routine.key),
  ),
  _ppl,
  ..._retiredAndEstablishedRoutines.where(
    (routine) => const {
      '531-classic',
      '531-bbb',
      '531-fsl',
      'candito-linear-control',
      'candito-linear-hypertrophy',
      'tsa-intermediate-2',
    }.contains(routine.key),
  ),
  ..._retiredAndEstablishedRoutines.where(
    (routine) => routine.key == 'sheiko-29-32',
  ),
];

/// The canonical English description of the program whose copies carry
/// [seedKey], or null for a key no shipped program owns.
///
/// What tells a shipped description apart from one somebody typed over it: the
/// two live in the same column, and only the text itself says which it is. See
/// `seededDescription` in `util/seed_names.dart`.
String? starterDescriptionForSeedKey(String seedKey) {
  for (final program in kStarterRoutines) {
    if (program.seedKey == seedKey) return program.description;
  }
  return null;
}

/// The program [key] names, or null for a key this build does not ship — a link
/// into the library from a build that had a program this one has dropped.
StarterRoutine? starterRoutineByKey(String key) {
  for (final program in kStarterRoutines) {
    if (program.key == key) return program;
  }
  // Old library links remain readable after their templates leave the list.
  for (final program in _retiredAndEstablishedRoutines) {
    if (program.key == key) return program;
  }
  return null;
}

/// The visible or retired program named [name]. Retired names are accepted so
/// existing automation and old app links can still install the same template;
/// only [kStarterRoutines] controls what a new user sees in the library.
StarterRoutine? starterRoutineByName(String name) {
  for (final program in kStarterRoutines) {
    if (program.name == name) return program;
  }
  for (final program in _retiredAndEstablishedRoutines) {
    if (program.name == name) return program;
  }
  return null;
}
