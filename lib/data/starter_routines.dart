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

/// The four weeks of a 5/3/1 main lift: three working weeks and a deload, every
/// set a percentage of the training max.
///
/// Written once and shared by the four programs below, which differ in what
/// they put *after* the main lift rather than in the main lift itself. The last
/// set of each working week has no upper rep count — that is the "+" set the
/// program is named after, and it is what tells you whether the training max is
/// still honest.
const List<List<CustomSet>> k531Main = [
  [
    CustomSet(reps: 5, percent: 65),
    CustomSet(reps: 5, percent: 75),
    CustomSet(reps: 5, percent: 85, amrap: true),
  ],
  [
    CustomSet(reps: 3, percent: 70),
    CustomSet(reps: 3, percent: 80),
    CustomSet(reps: 3, percent: 90, amrap: true),
  ],
  [
    CustomSet(reps: 5, percent: 75),
    CustomSet(reps: 3, percent: 85),
    CustomSet(reps: 1, percent: 95, amrap: true),
  ],
  [
    CustomSet(reps: 5, percent: 40),
    CustomSet(reps: 5, percent: 50),
    CustomSet(reps: 5, percent: 60),
  ],
];

/// Boring But Big's supplemental work: five sets of ten off the same training
/// max, lighter on the deload week so the deload is one.
const List<List<CustomSet>> k531BigVolume = [
  _bbbWeek,
  _bbbWeek,
  _bbbWeek,
  [
    CustomSet(reps: 10, percent: 40),
    CustomSet(reps: 10, percent: 40),
    CustomSet(reps: 10, percent: 40),
    CustomSet(reps: 10, percent: 40),
    CustomSet(reps: 10, percent: 40),
  ],
];

const List<CustomSet> _bbbWeek = [
  CustomSet(reps: 10, percent: 50),
  CustomSet(reps: 10, percent: 50),
  CustomSet(reps: 10, percent: 50),
  CustomSet(reps: 10, percent: 50),
  CustomSet(reps: 10, percent: 50),
];

/// First Set Last: five sets at whatever the week opened on, so the back-off
/// weight climbs with the week rather than sitting at one percentage. The case
/// a cycle expresses and a plain back-off scheme cannot.
const List<List<CustomSet>> k531FirstSetLast = [
  [
    CustomSet(reps: 5, percent: 65),
    CustomSet(reps: 5, percent: 65),
    CustomSet(reps: 5, percent: 65),
    CustomSet(reps: 5, percent: 65),
    CustomSet(reps: 5, percent: 65),
  ],
  [
    CustomSet(reps: 5, percent: 70),
    CustomSet(reps: 5, percent: 70),
    CustomSet(reps: 5, percent: 70),
    CustomSet(reps: 5, percent: 70),
    CustomSet(reps: 5, percent: 70),
  ],
  [
    CustomSet(reps: 5, percent: 75),
    CustomSet(reps: 5, percent: 75),
    CustomSet(reps: 5, percent: 75),
    CustomSet(reps: 5, percent: 75),
    CustomSet(reps: 5, percent: 75),
  ],
  [
    CustomSet(reps: 5, percent: 40),
    CustomSet(reps: 5, percent: 40),
    CustomSet(reps: 5, percent: 40),
    CustomSet(reps: 5, percent: 40),
    CustomSet(reps: 5, percent: 40),
  ],
];

/// The library, in the order it is offered: the two splits somebody with a year
/// of training would recognise, then the beginner barbell programs, the four
/// that ask for less than a gym, the four 5/3/1 programs, the two Candito
/// Linear programs, and Sheiko #29–32.
final List<StarterRoutine> _retiredAndEstablishedRoutines = [
  StarterRoutine(
    key: 'ppl',
    description:
        'Three sessions a week, each one a different half of what you do: the muscles you push with, the ones you pull with, and legs. The usual next step once a beginner program stops adding weight every session.',
    name: 'Push / Pull / Legs',
    colorHex: 'FF6A3D',
    restSeconds: 120,
    scheduleDays: _mwf,
    days: [
      StarterDay('Push', [
        StarterSlot(
          'Bench Press',
          sets: 4,
          repsMin: 6,
          repsMax: 8,
          weightKg: 80,
        ),
        StarterSlot('Overhead Press', sets: 4, repsMin: 8, weightKg: 50),
        StarterSlot(
          'Incline DB Press',
          sets: 3,
          repsMin: 10,
          repsMax: 12,
          weightKg: 30,
        ),
        StarterSlot('Lateral Raise', sets: 3, repsMin: 15, weightKg: 12),
        StarterSlot(
          'Triceps Pushdown',
          sets: 3,
          repsMin: 12,
          repsMax: 15,
          weightKg: 35,
        ),
      ]),
      StarterDay('Pull', [
        StarterSlot('Deadlift', sets: 3, repsMin: 5, weightKg: 140),
        StarterSlot('Pull-Up', sets: 4, repsMin: 6, repsMax: 10),
        StarterSlot('Barbell Row', sets: 4, repsMin: 8, weightKg: 70),
        StarterSlot(
          'Face Pull',
          sets: 3,
          repsMin: 15,
          repsMax: 20,
          weightKg: 25,
        ),
        StarterSlot(
          'Barbell Curl',
          sets: 3,
          repsMin: 10,
          repsMax: 12,
          weightKg: 30,
        ),
      ]),
      StarterDay('Legs', [
        StarterSlot('Back Squat', sets: 4, repsMin: 6, weightKg: 110),
        StarterSlot('Romanian Deadlift', sets: 3, repsMin: 10, weightKg: 90),
        StarterSlot(
          'Leg Press',
          sets: 3,
          repsMin: 12,
          repsMax: 15,
          weightKg: 180,
        ),
        StarterSlot('Leg Curl', sets: 3, repsMin: 12, weightKg: 45),
        StarterSlot(
          'Calf Raise',
          sets: 4,
          repsMin: 15,
          repsMax: 20,
          weightKg: 60,
        ),
      ]),
    ],
  ),
  // Upper/Lower deliberately repeats a day name — that is legal inside a routine
  // and worth demonstrating.
  StarterRoutine(
    key: 'upper-lower',
    description:
        'Four sessions a week, alternating the upper body and the lower. Each muscle is trained twice a week, and no single session has to cover everything.',
    name: 'Upper / Lower',
    colorHex: '3ED598',
    restSeconds: 150,
    days: [
      StarterDay('Upper 1', [
        StarterSlot('Bench Press', sets: 4, repsMin: 5, weightKg: 80),
        StarterSlot(
          'Barbell Row',
          sets: 4,
          repsMin: 6,
          repsMax: 8,
          weightKg: 70,
        ),
        StarterSlot(
          'Overhead Press',
          sets: 3,
          repsMin: 8,
          repsMax: 10,
          weightKg: 45,
        ),
        StarterSlot(
          'Lat Pulldown',
          sets: 3,
          repsMin: 10,
          repsMax: 12,
          weightKg: 55,
        ),
      ]),
      StarterDay('Lower 1', [
        StarterSlot('Back Squat', sets: 4, repsMin: 5, weightKg: 110),
        StarterSlot(
          'Romanian Deadlift',
          sets: 3,
          repsMin: 8,
          repsMax: 10,
          weightKg: 90,
        ),
        StarterSlot('Leg Curl', sets: 3, repsMin: 12, weightKg: 45),
        StarterSlot(
          'Calf Raise',
          sets: 4,
          repsMin: 15,
          repsMax: 20,
          weightKg: 60,
        ),
      ]),
      StarterDay('Upper 2', [
        StarterSlot(
          'Incline DB Press',
          sets: 4,
          repsMin: 8,
          repsMax: 10,
          weightKg: 30,
        ),
        StarterSlot('Pull-Up', sets: 4, repsMin: 6, repsMax: 10),
        StarterSlot('Lateral Raise', sets: 3, repsMin: 15, weightKg: 12),
        StarterSlot(
          'Hammer Curl',
          sets: 3,
          repsMin: 10,
          repsMax: 12,
          weightKg: 14,
        ),
      ]),
      StarterDay('Lower 2', [
        StarterSlot('Deadlift', sets: 3, repsMin: 5, weightKg: 140),
        StarterSlot(
          'Front Squat',
          sets: 3,
          repsMin: 8,
          repsMax: 10,
          weightKg: 70,
        ),
        StarterSlot(
          'Leg Press',
          sets: 3,
          repsMin: 12,
          repsMax: 15,
          weightKg: 180,
        ),
        StarterSlot('Hanging Leg Raise', sets: 3, repsMin: 10),
      ]),
    ],
  ),
  // The three beginner strength programs. They are linear-progression barbell
  // routines rather than splits, so they carry their own rates: the squat and the
  // deadlift take 5 kg a session where a press takes 2.5, and the two published
  // ones reset only after a third failed session.
  StarterRoutine(
    key: 'starting-strength',
    description:
        "Mark Rippetoe's novice barbell program. Alternate two three-lift workouts three days per week and add weight each session.",
    name: 'Starting Strength',
    colorHex: '4D9DE0',
    restSeconds: 300,
    scheduleDays: _mwf,
    failureThreshold: 3,
    days: [
      StarterDay('Workout A', [
        StarterSlot.heavy('Back Squat', sets: 3, repsMin: 5, weightKg: 60),
        StarterSlot('Bench Press', sets: 3, repsMin: 5, weightKg: 45),
        // One work set. The deadlift is the lift the program deliberately does
        // not do three sets of.
        StarterSlot.heavy('Deadlift', sets: 1, repsMin: 5, weightKg: 70),
      ]),
      StarterDay('Workout B', [
        StarterSlot.heavy('Back Squat', sets: 3, repsMin: 5, weightKg: 60),
        StarterSlot('Overhead Press', sets: 3, repsMin: 5, weightKg: 30),
        // Five triples, trained for speed rather than for load.
        StarterSlot('Power Clean', sets: 5, repsMin: 3, weightKg: 40),
      ]),
    ],
  ),
  StarterRoutine(
    key: 'stronglifts-5x5',
    description:
        'Mehdi Hadim’s three-day novice barbell program. Alternate two workouts built around five sets of five; deadlift remains one set of five.',
    name: 'StrongLifts 5x5',
    colorHex: 'C77DFF',
    restSeconds: 180,
    scheduleDays: _mwf,
    failureThreshold: 3,
    days: [
      StarterDay('Workout A', [
        // Everything but the deadlift takes the ordinary 2.5 kg here — the
        // program is five sets of five on a bar that starts nearly empty.
        StarterSlot('Back Squat', sets: 5, repsMin: 5, weightKg: 40),
        StarterSlot('Bench Press', sets: 5, repsMin: 5, weightKg: 30),
        StarterSlot('Barbell Row', sets: 5, repsMin: 5, weightKg: 30),
      ]),
      StarterDay('Workout B', [
        StarterSlot('Back Squat', sets: 5, repsMin: 5, weightKg: 40),
        StarterSlot('Overhead Press', sets: 5, repsMin: 5, weightKg: 20),
        StarterSlot.heavy('Deadlift', sets: 1, repsMin: 5, weightKg: 60),
      ]),
    ],
  ),
  // Not a published program, so it keeps the app's own back-off rule and trains
  // on the other three days of the week.
  StarterRoutine(
    key: 'full-body-3x',
    description:
        'Three full-body sessions a week, each with a squat or hinge, a press, a pull and some core work. For training three times a week without keeping track of a split.',
    name: 'Full Body 3x',
    colorHex: 'E8C547',
    restSeconds: 120,
    scheduleDays: _tts,
    days: [
      StarterDay('Workout A', [
        StarterSlot.heavy('Back Squat', sets: 3, repsMin: 5, weightKg: 55),
        StarterSlot('Bench Press', sets: 3, repsMin: 5, weightKg: 40),
        StarterSlot('Seated Cable Row', sets: 3, repsMin: 10, weightKg: 45),
        StarterSlot('Hanging Leg Raise', sets: 3, repsMin: 8, repsMax: 12),
      ]),
      StarterDay('Workout B', [
        StarterSlot.heavy(
          'Romanian Deadlift',
          sets: 3,
          repsMin: 8,
          weightKg: 60,
        ),
        StarterSlot(
          'Overhead Press',
          sets: 3,
          repsMin: 6,
          repsMax: 8,
          weightKg: 30,
        ),
        StarterSlot(
          'Lat Pulldown',
          sets: 3,
          repsMin: 10,
          repsMax: 12,
          weightKg: 50,
        ),
        StarterSlot(
          'Cable Crunch',
          sets: 3,
          repsMin: 12,
          repsMax: 15,
          weightKg: 30,
        ),
      ]),
      StarterDay('Workout C', [
        StarterSlot.heavy('Deadlift', sets: 2, repsMin: 5, weightKg: 80),
        StarterSlot(
          'Incline DB Press',
          sets: 3,
          repsMin: 8,
          repsMax: 10,
          weightKg: 22.5,
        ),
        StarterSlot('Chin-Up', sets: 3, repsMin: 5, repsMax: 8),
        StarterSlot('Leg Curl', sets: 3, repsMin: 12, weightKg: 40),
      ]),
    ],
  ),
  // The four that ask for less than a gym. The first asks for the same gym and
  // less of the week: every program above it wants three or four sessions, and
  // somebody with two is not served by training two thirds of one.
  StarterRoutine(
    key: 'two-day-full-body',
    description:
        'Two sessions a week, each with a squat or a hinge, a press, a pull and some core work. For a week that has two training days in it rather than four.',
    name: 'Two-Day Full Body',
    colorHex: '2EC4B6',
    restSeconds: 150,
    scheduleDays: _tf,
    days: [
      StarterDay('Workout A', [
        StarterSlot.heavy('Back Squat', sets: 3, repsMin: 5, weightKg: 60),
        StarterSlot('Bench Press', sets: 3, repsMin: 5, weightKg: 45),
        StarterSlot('Barbell Row', sets: 3, repsMin: 8, weightKg: 40),
        StarterSlot('Hanging Leg Raise', sets: 3, repsMin: 8, repsMax: 12),
      ]),
      StarterDay('Workout B', [
        StarterSlot.heavy('Deadlift', sets: 2, repsMin: 5, weightKg: 70),
        StarterSlot('Overhead Press', sets: 3, repsMin: 5, weightKg: 30),
        StarterSlot(
          'Lat Pulldown',
          sets: 3,
          repsMin: 10,
          repsMax: 12,
          weightKg: 45,
        ),
        StarterSlot('Bulgarian Split Squat', sets: 3, repsMin: 8, repsMax: 12),
      ]),
    ],
  ),
  // Nothing but your own weight. Every slot carries no load, so each one
  // progresses on reps — which is the axis these movements actually move on
  // until the movement itself is made harder.
  StarterRoutine(
    key: 'bodyweight-basics',
    description:
        'Three sessions a week with no equipment beyond a floor and something to hang from. Add reps first; when the top of the range gets easy, move to a harder version of the same movement.',
    name: 'Bodyweight Basics',
    colorHex: '8AC926',
    restSeconds: 90,
    scheduleDays: _mwf,
    days: [
      StarterDay('Workout A', [
        StarterSlot('Push-Up', sets: 4, repsMin: 8, repsMax: 12),
        StarterSlot('Air Squat', sets: 4, repsMin: 15, repsMax: 20),
        StarterSlot('Inverted Row', sets: 4, repsMin: 8, repsMax: 12),
        StarterSlot('Plank', sets: 3, holdSeconds: 45),
      ]),
      StarterDay('Workout B', [
        StarterSlot('Pike Push-Up', sets: 4, repsMin: 6, repsMax: 10),
        StarterSlot('Bodyweight Lunge', sets: 3, repsMin: 10, repsMax: 14),
        StarterSlot('Chin-Up', sets: 4, repsMin: 5, repsMax: 8),
        StarterSlot('Hollow Hold', sets: 3, holdSeconds: 30),
      ]),
      StarterDay('Workout C', [
        StarterSlot('Decline Push-Up', sets: 4, repsMin: 8, repsMax: 12),
        StarterSlot(
          'Single-Leg Glute Bridge',
          sets: 3,
          repsMin: 12,
          repsMax: 15,
        ),
        StarterSlot('Nordic Curl', sets: 3, repsMin: 5, repsMax: 8),
        StarterSlot('Superman Hold', sets: 3, holdSeconds: 30),
      ]),
    ],
  ),
  // One pair of dumbbells. The loads are what a pair of adjustable dumbbells
  // starts at rather than what a gym racks, since that is the equipment the
  // program assumes.
  StarterRoutine(
    key: 'dumbbell-full-body',
    description:
        'Three whole-body sessions a week on one pair of dumbbells. Everything is pressed, pulled or carried with the weight in your hands, so it works in a spare room as well as in a gym.',
    name: 'Dumbbell Full Body',
    colorHex: 'F4845F',
    restSeconds: 120,
    scheduleDays: _tts,
    days: [
      StarterDay('Workout A', [
        StarterSlot(
          'Dumbbell Front Squat',
          sets: 4,
          repsMin: 8,
          repsMax: 10,
          weightKg: 20,
        ),
        StarterSlot(
          'Dumbbell Bench Press',
          sets: 4,
          repsMin: 8,
          repsMax: 10,
          weightKg: 22.5,
        ),
        StarterSlot(
          'Dumbbell Row',
          sets: 4,
          repsMin: 8,
          repsMax: 10,
          weightKg: 24,
        ),
        StarterSlot(
          'Dumbbell Curl',
          sets: 3,
          repsMin: 10,
          repsMax: 12,
          weightKg: 12,
        ),
      ]),
      StarterDay('Workout B', [
        StarterSlot(
          'Dumbbell Romanian Deadlift',
          sets: 4,
          repsMin: 8,
          repsMax: 10,
          weightKg: 24,
        ),
        StarterSlot(
          'Dumbbell Shoulder Press',
          sets: 4,
          repsMin: 8,
          repsMax: 10,
          weightKg: 16,
        ),
        StarterSlot(
          'Renegade Row',
          sets: 3,
          repsMin: 8,
          repsMax: 10,
          weightKg: 14,
        ),
        // Held, so the target is the walk rather than a rep count.
        StarterSlot("Farmer's Carry", sets: 3, holdSeconds: 40, weightKg: 24),
      ]),
      StarterDay('Workout C', [
        StarterSlot(
          'Dumbbell Lunge',
          sets: 3,
          repsMin: 10,
          repsMax: 12,
          weightKg: 16,
        ),
        StarterSlot(
          'Dumbbell Floor Press',
          sets: 4,
          repsMin: 8,
          repsMax: 10,
          weightKg: 22.5,
        ),
        StarterSlot(
          'Dumbbell Pullover',
          sets: 3,
          repsMin: 12,
          repsMax: 15,
          weightKg: 16,
        ),
        StarterSlot(
          'Dumbbell Thruster',
          sets: 3,
          repsMin: 8,
          repsMax: 10,
          weightKg: 14,
        ),
      ]),
    ],
  ),
  // Timed intervals rather than sets of reps. Every movement here is one the
  // library measures in seconds, which is what makes the work period the slot's
  // target — see [StarterSlot.holdSeconds]. The rest between rounds is the
  // routine's default rest, so it is one number for the whole session.
  StarterRoutine(
    key: 'interval-conditioning',
    description:
        'Two conditioning sessions a week, measured in seconds rather than reps: rounds of hard work against the clock with a short rest between them. Meant to be trained alongside a strength program, not instead of one.',
    name: 'Interval Conditioning',
    colorHex: 'FF477E',
    restSeconds: 30,
    scheduleDays: _ts,
    days: [
      StarterDay('Workout A', [
        StarterSlot('Jump Rope', sets: 6, holdSeconds: 40),
        StarterSlot('High Knees', sets: 6, holdSeconds: 20),
        StarterSlot('Mountain Climber', sets: 6, holdSeconds: 30),
        StarterSlot('Shadow Boxing', sets: 4, holdSeconds: 60),
      ]),
      StarterDay('Workout B', [
        StarterSlot('Sprint', sets: 8, holdSeconds: 20),
        StarterSlot('Bear Crawl', sets: 5, holdSeconds: 30),
        StarterSlot('Battle Rope', sets: 6, holdSeconds: 30),
        StarterSlot('Wall Sit', sets: 3, holdSeconds: 45),
      ]),
    ],
  ),
  // ---- The 5/3/1 programs -------------------------------------------------
  //
  // Four templates over the same four training days and the same main-lift
  // cycle, differing only in what follows the main lift. The weight on a
  // cycled slot is a *training max* — nothing in a session is done at it — and
  // the numbers here are placeholders somebody is expected to replace with 90%
  // of their own best single, which each description says.
  StarterRoutine(
    key: '531-classic',
    description:
        'Jim Wendler’s four-day 5/3/1 template. Each day trains one main lift from a 90% training max, followed by two assistance movements.',
    name: '5/3/1 Classic',
    colorHex: '4C8DFF',
    restSeconds: 180,
    scheduleDays: _mwfs,
    days: [
      StarterDay('Press', [
        _main('Overhead Press', 45, 2.5),
        StarterSlot('Chest Dip', sets: 5, repsMin: 12, repsMax: 15),
        StarterSlot('Chin-Up', sets: 5, repsMin: 8, repsMax: 10),
      ]),
      StarterDay('Deadlift', [
        _main('Deadlift', 120, 5),
        StarterSlot('Good Morning', sets: 5, repsMin: 12, weightKg: 40),
        StarterSlot('Hanging Leg Raise', sets: 5, repsMin: 12, repsMax: 15),
      ]),
      StarterDay('Bench', [
        _main('Bench Press', 70, 2.5),
        StarterSlot(
          'Dumbbell Bench Press',
          sets: 5,
          repsMin: 12,
          repsMax: 15,
          weightKg: 24,
        ),
        StarterSlot('Dumbbell Row', sets: 5, repsMin: 10, weightKg: 30),
      ]),
      StarterDay('Squat', [
        _main('Back Squat', 100, 5),
        StarterSlot('Leg Press', sets: 5, repsMin: 15, weightKg: 160),
        StarterSlot('Leg Curl', sets: 5, repsMin: 10, weightKg: 40),
      ]),
    ],
  ),
  StarterRoutine(
    key: '531-bbb',
    description:
        'Jim Wendler’s four-day Boring But Big template. Main 5/3/1 work is followed by five sets of ten at 50% of the training max.',
    name: '5/3/1 Boring But Big',
    colorHex: '7A5CFF',
    restSeconds: 180,
    scheduleDays: _mwfs,
    days: [
      StarterDay('Press', [
        _main('Overhead Press', 45, 2.5),
        _volume('Overhead Press', 45, 2.5),
        StarterSlot('Chin-Up', sets: 5, repsMin: 8, repsMax: 10),
      ]),
      StarterDay('Deadlift', [
        _main('Deadlift', 120, 5),
        _volume('Deadlift', 120, 5),
        StarterSlot('Hanging Leg Raise', sets: 5, repsMin: 12, repsMax: 15),
      ]),
      StarterDay('Bench', [
        _main('Bench Press', 70, 2.5),
        _volume('Bench Press', 70, 2.5),
        StarterSlot('Dumbbell Row', sets: 5, repsMin: 10, weightKg: 30),
      ]),
      StarterDay('Squat', [
        _main('Back Squat', 100, 5),
        _volume('Back Squat', 100, 5),
        StarterSlot('Leg Curl', sets: 5, repsMin: 10, weightKg: 40),
      ]),
    ],
  ),
  StarterRoutine(
    key: '531-fsl',
    description:
        'Jim Wendler’s four-day First Set Last template. Main 5/3/1 work is followed by five sets at the first work-set percentage.',
    name: '5/3/1 First Set Last',
    colorHex: '18C29C',
    restSeconds: 180,
    scheduleDays: _mwfs,
    days: [
      StarterDay('Press', [
        _main('Overhead Press', 45, 2.5),
        _firstSetLast('Overhead Press', 45, 2.5),
        StarterSlot('Chin-Up', sets: 5, repsMin: 8, repsMax: 10),
      ]),
      StarterDay('Deadlift', [
        _main('Deadlift', 120, 5),
        _firstSetLast('Deadlift', 120, 5),
        StarterSlot('Hanging Leg Raise', sets: 5, repsMin: 12, repsMax: 15),
      ]),
      StarterDay('Bench', [
        _main('Bench Press', 70, 2.5),
        _firstSetLast('Bench Press', 70, 2.5),
        StarterSlot('Dumbbell Row', sets: 5, repsMin: 10, weightKg: 30),
      ]),
      StarterDay('Squat', [
        _main('Back Squat', 100, 5),
        _firstSetLast('Back Squat', 100, 5),
        StarterSlot('Leg Curl', sets: 5, repsMin: 10, weightKg: 40),
      ]),
    ],
  ),
  // Three days rather than four, two main lifts a session. Each lift still
  // comes round once a week, so every slot walks its cycle at the same pace as
  // the others — which is what keeps the whole program on one week at a time.
  StarterRoutine(
    key: '531-beginners',
    description:
        'Jim Wendler’s three-day beginner template. Each session trains two main lifts from 90% training maxes, followed by assistance.',
    name: '5/3/1 for Beginners',
    colorHex: 'FFB020',
    restSeconds: 180,
    scheduleDays: _mwf,
    days: [
      StarterDay('Workout A', [
        _main('Back Squat', 100, 5),
        _main('Bench Press', 70, 2.5),
        StarterSlot('Chin-Up', sets: 5, repsMin: 8, repsMax: 10),
      ]),
      StarterDay('Workout B', [
        _main('Deadlift', 120, 5),
        _main('Overhead Press', 45, 2.5),
        StarterSlot('Chest Dip', sets: 5, repsMin: 12, repsMax: 15),
      ]),
      StarterDay('Workout C', [
        _main('Bench Press', 70, 2.5),
        _main('Back Squat', 100, 5),
        StarterSlot('Barbell Row', sets: 5, repsMin: 10, weightKg: 50),
      ]),
    ],
  ),
  // ---- Candito Linear -----------------------------------------------------
  //
  // Jonnie Candito's four-day upper/lower split. Both variants share the two
  // heavy days and differ only in what the other two do, which is why the days
  // below are built from one pair of helpers rather than written twice.
  //
  // **The progression is the program.** Candito adds a little to each lift
  // every week for as long as that works, drops the lift that missed by 15 lb
  // — 7.5 kg — and leaves the rest of the program alone. So the back-off is
  // stated per slot rather than taken from the axis, and the routine's failure
  // threshold is one: the reset is on the next session after a miss, not after
  // a second one.
  //
  // One rule of Candito's does **not** fit and is not pretended to: after the
  // same lift has been reset three times he slows its progression from weekly
  // to fortnightly, which is a rule about a counter the app does not keep.
  // Somebody who has reset three times can halve the step by hand.
  StarterRoutine(
    key: 'candito-linear-control',
    description:
        'Jonnie Candito’s four-day linear program with strength and control days. The control days use paused competition-lift variations for six sets of four.',
    name: 'Candito Linear — Strength/Control',
    colorHex: 'D64550',
    restSeconds: 180,
    scheduleDays: _mtthf,
    // The reset is on the session after the miss. See the note above.
    failureThreshold: 1,
    days: [
      StarterDay('Heavy Lower', _canditoHeavyLower),
      StarterDay('Heavy Upper', _canditoHeavyUpper),
      StarterDay('Control Lower', [
        // Six sets of four at roughly 70% of the heavy day's bar — control
        // work, so the step is the small one on both lifts rather than the
        // 5 kg the heavy squat and deadlift take.
        StarterSlot(
          'Pause Squat',
          sets: 6,
          repsMin: 4,
          weightKg: 70,
          deload: 7.5,
        ),
        StarterSlot(
          'Pause Deadlift',
          sets: 3,
          repsMin: 4,
          weightKg: 85,
          deload: 7.5,
        ),
        StarterSlot('Hanging Leg Raise', sets: 3, repsMin: 10, repsMax: 15),
      ]),
      StarterDay('Control Upper', [
        StarterSlot(
          'Paused Bench Press',
          sets: 6,
          repsMin: 4,
          weightKg: 50,
          deload: 7.5,
        ),
        // The controlled upper-back work of the same day, at the same shape.
        StarterSlot(
          'Chest-Supported Row',
          sets: 6,
          repsMin: 4,
          weightKg: 45,
          deload: 7.5,
        ),
        StarterSlot('Lateral Raise', sets: 3, repsMin: 15, weightKg: 10),
        StarterSlot(
          'Barbell Curl',
          sets: 3,
          repsMin: 10,
          repsMax: 12,
          weightKg: 25,
        ),
      ]),
    ],
  ),
  StarterRoutine(
    key: 'candito-linear-hypertrophy',
    description:
        'Jonnie Candito’s four-day linear program with strength and hypertrophy days. The variation days begin with five sets of eight.',
    name: 'Candito Linear — Strength/Hypertrophy',
    colorHex: 'E07A5F',
    restSeconds: 150,
    scheduleDays: _mtthf,
    failureThreshold: 1,
    days: [
      StarterDay('Heavy Lower', _canditoHeavyLower),
      StarterDay('Heavy Upper', _canditoHeavyUpper),
      StarterDay('Variation Lower', [
        StarterSlot(
          'Front Squat',
          sets: 5,
          repsMin: 8,
          weightKg: 60,
          deload: 7.5,
        ),
        StarterSlot(
          'Romanian Deadlift',
          sets: 5,
          repsMin: 8,
          weightKg: 80,
          deload: 7.5,
        ),
        StarterSlot('Leg Curl', sets: 3, repsMin: 12, weightKg: 40),
      ]),
      StarterDay('Variation Upper', [
        StarterSlot(
          'Incline DB Press',
          sets: 5,
          repsMin: 8,
          weightKg: 24,
          deload: 7.5,
        ),
        StarterSlot(
          'Dumbbell Row',
          sets: 5,
          repsMin: 8,
          weightKg: 28,
          deload: 7.5,
        ),
        StarterSlot('Lateral Raise', sets: 3, repsMin: 15, weightKg: 10),
        StarterSlot(
          'Triceps Pushdown',
          sets: 3,
          repsMin: 12,
          repsMax: 15,
          weightKg: 30,
        ),
      ]),
    ],
  ),
  // ---- Sheiko #29–32 ------------------------------------------------------
  //
  // Boris Sheiko's four numbered blocks, run as the one sixteen-week sequence
  // they were written to be. Transcribed from the classic spreadsheet — the
  // copy distributed by PowerliftingToWin — rather than reconciled across the
  // Sheiko variants that circulate online.
  //
  // **Forty-eight sessions, not a rotation.** The program does not keep a fixed
  // set of slots whose numbers change week to week: the order of the lifts
  // moves, a lift comes round twice inside one session, variations appear for a
  // fortnight and go. A cycle would have to claim these were forty-eight
  // versions of one week, so each is a training day of its own.
  //
  // **The percentages are of the competition max itself**, not of 90% of it as
  // the 5/3/1 programs above are. The opening numbers are the same placeholders
  // those use, and the description says what to replace them with.
  //
  // **Nothing steps.** The overload is already written into the sixteen weeks —
  // see [StarterSlot.custom] — so every percentage slot carries a rate of
  // nothing and the max stays where it is put, including through the max test
  // that closes #32 above 100%.
  //
  // The variations are prescribed off the competition lift's max: the front
  // squats off the squat, the partial deadlifts off the deadlift. That is not
  // stated here — it is what those movements carry in
  // `data/percentage_base.dart`, which is what lets the routine's three maxes
  // be set once each.
  //
  // The days are not keyed for translation. "#29 · W1 · Mon" is the program's
  // own notation rather than a word, and forty-eight keys in five languages
  // would translate three weekday abbreviations at the cost of the other
  // forty-five names saying nothing.
  StarterRoutine(
    key: 'sheiko-29-32',
    description:
        'Boris Sheiko’s #29–32 sequence: sixteen weeks, three days per week, ending with a max test. Percentages use current competition maxes, not 90% training maxes.',
    name: 'Sheiko #29–32',
    colorHex: 'C2185B',
    restSeconds: 240,
    scheduleDays: _mwf,
    days: _sheikoDays,
  ),
  StarterRoutine(
    key: 'tsa-beginner',
    name: 'TSA Beginner Approach',
    description:
        'The Strength Athlete’s nine-week beginner powerlifting program. Train four days per week and choose each RPE-prescribed load in the session.',
    colorHex: '1565C0',
    restSeconds: 180,
    scheduleDays: _mtthf,
    days: _tsaBeginnerDays,
  ),
  StarterRoutine(
    key: 'tsa-intermediate-2',
    name: 'TSA Intermediate 2.0',
    description:
        'The Strength Athlete’s nine-week Intermediate 2.0 powerlifting program. Four weekly sessions combine competition lifts, variations, and RPE-regulated work.',
    colorHex: '6A1B9A',
    restSeconds: 180,
    scheduleDays: _mtthf,
    days: _tsaIntermediateDays,
  ),
];

/// Programs offered by this build. Retired templates remain below as lookup
/// fallbacks for old deep links, but no longer appear in the library.
final StarterRoutine _gzclp = StarterRoutine(
  key: 'gzclp',
  name: 'GZCLP',
  description:
      'Cody Lefever’s novice linear progression. Four rotating sessions train each main lift once as T1 and once as T2, with back work in T3.',
  colorHex: 'E65100',
  restSeconds: 180,
  scheduleDays: _mwfs,
  failureThreshold: 1,
  days: [
    StarterDay('A1', [
      StarterSlot(
        'Back Squat',
        sets: 5,
        repsMin: 3,
        weightKg: 20,
        increment: 5,
        gzclTier: GzclTier.t1,
        gzclStages: gzclpT1Stages,
      ),
      StarterSlot(
        'Bench Press',
        sets: 3,
        repsMin: 10,
        weightKg: 20,
        gzclTier: GzclTier.t2,
        gzclStages: gzclpT2Stages,
      ),
      StarterSlot.custom(
        'Lat Pulldown',
        customSets: const [
          CustomSet(reps: 15, percent: 100),
          CustomSet(reps: 15, percent: 100),
          CustomSet(reps: 15, percent: 100, amrap: true),
        ],
        weightKg: 20,
        increment: 2.5,
        gzclTier: GzclTier.t3,
      ),
    ]),
    StarterDay('B1', [
      StarterSlot(
        'Overhead Press',
        sets: 5,
        repsMin: 3,
        weightKg: 20,
        gzclTier: GzclTier.t1,
        gzclStages: gzclpT1Stages,
      ),
      StarterSlot(
        'Deadlift',
        sets: 3,
        repsMin: 10,
        weightKg: 20,
        increment: 5,
        gzclTier: GzclTier.t2,
        gzclStages: gzclpT2Stages,
      ),
      StarterSlot.custom(
        'Dumbbell Row',
        customSets: const [
          CustomSet(reps: 15, percent: 100),
          CustomSet(reps: 15, percent: 100),
          CustomSet(reps: 15, percent: 100, amrap: true),
        ],
        weightKg: 10,
        increment: 2.5,
        gzclTier: GzclTier.t3,
      ),
    ]),
    StarterDay('A2', [
      StarterSlot(
        'Bench Press',
        sets: 5,
        repsMin: 3,
        weightKg: 20,
        gzclTier: GzclTier.t1,
        gzclStages: gzclpT1Stages,
      ),
      StarterSlot(
        'Back Squat',
        sets: 3,
        repsMin: 10,
        weightKg: 20,
        increment: 5,
        gzclTier: GzclTier.t2,
        gzclStages: gzclpT2Stages,
      ),
      StarterSlot.custom(
        'Lat Pulldown',
        customSets: const [
          CustomSet(reps: 15, percent: 100),
          CustomSet(reps: 15, percent: 100),
          CustomSet(reps: 15, percent: 100, amrap: true),
        ],
        weightKg: 20,
        increment: 2.5,
        gzclTier: GzclTier.t3,
      ),
    ]),
    StarterDay('B2', [
      StarterSlot(
        'Deadlift',
        sets: 5,
        repsMin: 3,
        weightKg: 20,
        increment: 5,
        gzclTier: GzclTier.t1,
        gzclStages: gzclpT1Stages,
      ),
      StarterSlot(
        'Overhead Press',
        sets: 3,
        repsMin: 10,
        weightKg: 20,
        gzclTier: GzclTier.t2,
        gzclStages: gzclpT2Stages,
      ),
      StarterSlot.custom(
        'Dumbbell Row',
        customSets: const [
          CustomSet(reps: 15, percent: 100),
          CustomSet(reps: 15, percent: 100),
          CustomSet(reps: 15, percent: 100, amrap: true),
        ],
        weightKg: 10,
        increment: 2.5,
        gzclTier: GzclTier.t3,
      ),
    ]),
  ],
);

final List<StarterRoutine> kStarterRoutines = [
  _gzclp,
  _ppl,
  _fitnessBasicBeginner,
  ..._retiredAndEstablishedRoutines.where(
    (routine) =>
        const {'starting-strength', 'stronglifts-5x5'}.contains(routine.key),
  ),
  _bodyweightfitnessRecommended,
  _dumbbellStopgap,
  ..._retiredAndEstablishedRoutines.where(
    (routine) => const {
      '531-classic',
      '531-bbb',
      '531-fsl',
      '531-beginners',
      'candito-linear-control',
      'candito-linear-hypertrophy',
      'sheiko-29-32',
      'tsa-beginner',
      'tsa-intermediate-2',
    }.contains(routine.key),
  ),
];

const _threeByFivePlus = [
  CustomSet(reps: 5, percent: 100),
  CustomSet(reps: 5, percent: 100),
  CustomSet(reps: 5, percent: 100, amrap: true),
];

const _fiveByFivePlus = [
  CustomSet(reps: 5, percent: 100),
  CustomSet(reps: 5, percent: 100),
  CustomSet(reps: 5, percent: 100),
  CustomSet(reps: 5, percent: 100),
  CustomSet(reps: 5, percent: 100, amrap: true),
];

final StarterRoutine _ppl = StarterRoutine(
  key: 'ppl-6-day',
  name: 'Push/Pull/Legs',
  description:
      'A six-day barbell push/pull/legs program. Pull, push, and legs repeat each week while deadlift alternates with row and bench alternates with overhead press.',
  colorHex: 'FF6A3D',
  restSeconds: 180,
  scheduleDays: 0x3f,
  days: [
    StarterDay('Pull A', [
      StarterSlot(
        'Deadlift',
        sets: 1,
        repsMin: 5,
        weightKg: 60,
        increment: 5,
        customSets: [CustomSet(reps: 5, percent: 100, amrap: true)],
      ),
      StarterSlot('Lat Pulldown', sets: 3, repsMin: 8, repsMax: 12),
      StarterSlot('Seated Cable Row', sets: 3, repsMin: 8, repsMax: 12),
      StarterSlot('Face Pull', sets: 5, repsMin: 15, repsMax: 20),
      StarterSlot('Hammer Curl', sets: 4, repsMin: 8, repsMax: 12),
      StarterSlot('Dumbbell Curl', sets: 4, repsMin: 8, repsMax: 12),
    ]),
    StarterDay('Push A', [
      StarterSlot(
        'Bench Press',
        sets: 5,
        repsMin: 5,
        weightKg: 20,
        customSets: _fiveByFivePlus,
      ),
      StarterSlot('Overhead Press', sets: 3, repsMin: 8, repsMax: 12),
      StarterSlot('Incline DB Press', sets: 3, repsMin: 8, repsMax: 12),
      StarterSlot('Triceps Pushdown', sets: 3, repsMin: 8, repsMax: 12),
      StarterSlot(
        'Lateral Raise',
        sets: 3,
        repsMin: 15,
        repsMax: 20,
        supersetWithPrevious: true,
      ),
      StarterSlot('Overhead Cable Extension', sets: 3, repsMin: 8, repsMax: 12),
      StarterSlot(
        'Lateral Raise',
        sets: 3,
        repsMin: 15,
        repsMax: 20,
        supersetWithPrevious: true,
      ),
    ]),
    StarterDay('Legs A', [
      StarterSlot(
        'Back Squat',
        sets: 3,
        repsMin: 5,
        weightKg: 20,
        customSets: _threeByFivePlus,
      ),
      StarterSlot('Romanian Deadlift', sets: 3, repsMin: 8, repsMax: 12),
      StarterSlot('Leg Press', sets: 3, repsMin: 8, repsMax: 12),
      StarterSlot('Leg Curl', sets: 3, repsMin: 8, repsMax: 12),
      StarterSlot('Calf Raise', sets: 5, repsMin: 8, repsMax: 12),
    ]),
    StarterDay('Pull B', [
      StarterSlot(
        'Barbell Row',
        sets: 5,
        repsMin: 5,
        weightKg: 20,
        customSets: _fiveByFivePlus,
      ),
      StarterSlot('Lat Pulldown', sets: 3, repsMin: 8, repsMax: 12),
      StarterSlot('Seated Cable Row', sets: 3, repsMin: 8, repsMax: 12),
      StarterSlot('Face Pull', sets: 5, repsMin: 15, repsMax: 20),
      StarterSlot('Hammer Curl', sets: 4, repsMin: 8, repsMax: 12),
      StarterSlot('Dumbbell Curl', sets: 4, repsMin: 8, repsMax: 12),
    ]),
    StarterDay('Push B', [
      StarterSlot(
        'Overhead Press',
        sets: 5,
        repsMin: 5,
        weightKg: 20,
        customSets: _fiveByFivePlus,
      ),
      StarterSlot('Bench Press', sets: 3, repsMin: 8, repsMax: 12),
      StarterSlot('Incline DB Press', sets: 3, repsMin: 8, repsMax: 12),
      StarterSlot('Triceps Pushdown', sets: 3, repsMin: 8, repsMax: 12),
      StarterSlot(
        'Lateral Raise',
        sets: 3,
        repsMin: 15,
        repsMax: 20,
        supersetWithPrevious: true,
      ),
      StarterSlot('Overhead Cable Extension', sets: 3, repsMin: 8, repsMax: 12),
      StarterSlot(
        'Lateral Raise',
        sets: 3,
        repsMin: 15,
        repsMax: 20,
        supersetWithPrevious: true,
      ),
    ]),
    StarterDay('Legs B', [
      StarterSlot(
        'Back Squat',
        sets: 3,
        repsMin: 5,
        weightKg: 20,
        customSets: _threeByFivePlus,
      ),
      StarterSlot('Romanian Deadlift', sets: 3, repsMin: 8, repsMax: 12),
      StarterSlot('Leg Press', sets: 3, repsMin: 8, repsMax: 12),
      StarterSlot('Leg Curl', sets: 3, repsMin: 8, repsMax: 12),
      StarterSlot('Calf Raise', sets: 5, repsMin: 8, repsMax: 12),
    ]),
  ],
);

final StarterRoutine _fitnessBasicBeginner = StarterRoutine(
  key: 'fitness-basic-beginner',
  name: 'Basic Beginner Routine',
  description:
      'A barbell introduction trained three days per week. Alternate two three-lift workouts, add weight after successful sessions, and move to a larger program after no more than three months.',
  colorHex: 'E8C547',
  restSeconds: 180,
  scheduleDays: _mwf,
  days: [
    StarterDay('Workout A', [
      StarterSlot(
        'Barbell Row',
        sets: 3,
        repsMin: 5,
        weightKg: 20,
        customSets: _threeByFivePlus,
      ),
      StarterSlot(
        'Bench Press',
        sets: 3,
        repsMin: 5,
        weightKg: 20,
        customSets: _threeByFivePlus,
      ),
      StarterSlot(
        'Back Squat',
        sets: 3,
        repsMin: 5,
        weightKg: 20,
        increment: 5,
        customSets: _threeByFivePlus,
      ),
    ]),
    StarterDay('Workout B', [
      StarterSlot('Chin-Up', sets: 3, repsMin: 5, customSets: _threeByFivePlus),
      StarterSlot(
        'Overhead Press',
        sets: 3,
        repsMin: 5,
        weightKg: 20,
        customSets: _threeByFivePlus,
      ),
      StarterSlot(
        'Deadlift',
        sets: 3,
        repsMin: 5,
        weightKg: 20,
        increment: 5,
        customSets: _threeByFivePlus,
      ),
    ]),
  ],
);

final StarterRoutine _bodyweightfitnessRecommended = StarterRoutine(
  key: 'bodyweightfitness-recommended',
  name: 'Bodyweight Routine',
  description:
      'A full-body routine trained three days per week. It uses bodyweight progressions and requires places to hang and perform rows; edit each slot when you move to a harder progression.',
  colorHex: '8AC926',
  restSeconds: 90,
  scheduleDays: _mwf,
  days: [
    for (final name in const ['Workout A', 'Workout B', 'Workout C'])
      StarterDay(name, const [
        StarterSlot('Pull-Up', sets: 3, repsMin: 5, repsMax: 8),
        StarterSlot(
          'Air Squat',
          sets: 3,
          repsMin: 5,
          repsMax: 8,
          supersetWithPrevious: true,
        ),
        StarterSlot('Chest Dip', sets: 3, repsMin: 5, repsMax: 8),
        StarterSlot(
          'Nordic Curl',
          sets: 3,
          repsMin: 5,
          repsMax: 8,
          supersetWithPrevious: true,
        ),
        StarterSlot('Inverted Row', sets: 3, repsMin: 5, repsMax: 8),
        StarterSlot(
          'Push-Up',
          sets: 3,
          repsMin: 5,
          repsMax: 8,
          supersetWithPrevious: true,
        ),
        StarterSlot('Ab Wheel Rollout', sets: 3, repsMin: 8, repsMax: 12),
        StarterSlot(
          'Pallof Press',
          sets: 3,
          repsMin: 8,
          repsMax: 12,
          supersetWithPrevious: true,
        ),
        StarterSlot(
          'Back Extension',
          sets: 3,
          repsMin: 8,
          repsMax: 12,
          supersetWithPrevious: true,
        ),
      ]),
  ],
);

final StarterRoutine _dumbbellStopgap = StarterRoutine(
  key: 'dumbbell-stopgap',
  name: 'Dumbbell Beginner Routine',
  description:
      'A two-workout dumbbell routine. Alternate A and B three days per week, using adjustable dumbbells or a rack of increasing weights; plank holds are entered by time.',
  colorHex: 'F4845F',
  restSeconds: 60,
  scheduleDays: _mwf,
  days: const [
    StarterDay('Workout A', [
      StarterSlot(
        'Bulgarian Split Squat',
        sets: 3,
        repsMin: 1,
        repsMax: 10,
        addWeightAtTopOfRange: true,
      ),
      StarterSlot(
        'Dumbbell Floor Press',
        sets: 3,
        repsMin: 1,
        repsMax: 10,
        addWeightAtTopOfRange: true,
      ),
      StarterSlot(
        'Dumbbell Romanian Deadlift',
        sets: 3,
        repsMin: 1,
        repsMax: 10,
        addWeightAtTopOfRange: true,
      ),
      StarterSlot('Plank', sets: 3, holdSeconds: 30),
    ]),
    StarterDay('Workout B', [
      StarterSlot(
        'Bulgarian Split Squat',
        sets: 3,
        repsMin: 1,
        repsMax: 10,
        addWeightAtTopOfRange: true,
      ),
      StarterSlot(
        'Dumbbell Shoulder Press',
        sets: 3,
        repsMin: 1,
        repsMax: 10,
        addWeightAtTopOfRange: true,
      ),
      StarterSlot(
        'Dumbbell Row',
        sets: 3,
        repsMin: 1,
        repsMax: 10,
        addWeightAtTopOfRange: true,
      ),
      StarterSlot('Plank', sets: 3, holdSeconds: 30),
    ]),
  ],
);

StarterSlot _tsa(
  String exercise,
  int sets,
  int reps,
  int rpe, {
  int? repsMax,
}) => StarterSlot(
  exercise,
  sets: sets,
  repsMin: reps,
  repsMax: repsMax,
  targetRpe: rpe,
);

List<StarterDay> get _tsaBeginnerDays {
  const squatReps = [7, 7, 7, 7, 5, 5, 5, 5, 4];
  const squatRpe = [60, 65, 75, 80, 60, 65, 75, 75, 100];
  const deadReps = [4, 4, 3, 2, 3, 3, 2, 2, 3];
  const deadRpe = [70, 75, 75, 75, 75, 80, 75, 75, 100];
  const benchReps = [7, 7, 7, 7, 5, 5, 5, 5, 4];
  const benchRpe = [60, 65, 75, 80, 60, 65, 75, 75, 65];
  return [
    for (var w = 0; w < 9; w++) ...[
      StarterDay('TSA Beginner · W${w + 1} · Day 1', [
        _tsa('Back Squat', w == 4 ? 3 : 4, squatReps[w], squatRpe[w]),
        _tsa('Bench Press', w == 4 ? 4 : 5, benchReps[w], benchRpe[w]),
        _tsa(
          'Dumbbell Bench Press',
          w == 4 ? 2 : 3,
          w < 4 ? 12 - w : 12 - (w - 4),
          w == 4 ? 70 : 80,
        ),
        _tsa(
          'Dumbbell Row',
          w == 4 ? 2 : 3,
          w < 4 ? 12 - w : 12 - (w - 4),
          w == 4 ? 70 : 80,
        ),
        _tsa('Sit-Up', w == 4 ? 2 : 3, 15, w == 4 ? 70 : 80),
      ]),
      StarterDay('TSA Beginner · W${w + 1} · Day 2', [
        _tsa(
          'Pause Deadlift',
          w < 5 ? 4 : (w < 8 ? 3 : 1),
          w < 4 ? 4 : (w < 8 ? 3 : 1),
          w < 4 ? 70 : 75,
        ),
        _tsa(
          'Bench Press',
          w == 4 ? 3 : 4,
          w < 4 ? 8 : (w < 8 ? 6 : 3),
          w == 8 ? 100 : 75,
        ),
        _tsa(
          'Hip Thrust',
          w == 4 ? 2 : 3,
          w < 4 ? 10 - w ~/ 3 : 10 - (w - 4),
          w == 4 ? 70 : 80,
        ),
        _tsa(
          'Triceps Pushdown',
          w == 4 ? 2 : 3,
          w < 4 ? 12 - w : 12 - (w - 4),
          w == 4 ? 70 : 80,
        ),
        _tsa(
          'Dumbbell Curl',
          w == 4 ? 2 : 3,
          w < 4 ? 12 - w : 12 - (w - 4),
          w == 4 ? 70 : 80,
        ),
      ]),
      StarterDay('TSA Beginner · W${w + 1} · Day 3', [
        _tsa(
          'Back Squat',
          w == 4 ? 3 : 4,
          w < 2 ? 5 : (w < 4 ? 4 : 3),
          w == 8 ? 100 : (65 + w * 2).clamp(60, 80),
        ),
        _tsa('Lat Pulldown', w == 4 ? 2 : 3, 15 - w ~/ 2, w == 4 ? 70 : 80),
        _tsa(
          'Dumbbell Shoulder Press',
          w == 4 ? 2 : 3,
          12 - w ~/ 2,
          w == 4 ? 70 : 80,
        ),
        _tsa(
          'Overhead Cable Extension',
          w == 4 ? 2 : 3,
          15 - w ~/ 2,
          w == 4 ? 70 : 80,
        ),
        _tsa('Barbell Curl', w == 4 ? 2 : 3, 15 - w ~/ 2, w == 4 ? 70 : 80),
      ]),
      StarterDay('TSA Beginner · W${w + 1} · Day 4', [
        _tsa('Deadlift', w == 8 ? 1 : 3, deadReps[w], deadRpe[w]),
        _tsa(
          'Paused Bench Press',
          w < 8 ? (w < 4 ? 4 : 5) : 5,
          w < 5 ? 4 : (w < 8 ? 3 : 1),
          w < 4 ? 70 : 75,
        ),
        _tsa(
          'Leg Press',
          w == 4 ? 2 : 3,
          10 - (w > 4 ? w - 4 : 0),
          w == 4 ? 70 : 80,
        ),
        _tsa('Leg Extension', w == 4 ? 2 : 3, 15 - w ~/ 2, w == 4 ? 70 : 80),
      ]),
    ],
  ];
}

List<StarterDay> get _tsaIntermediateDays {
  const topRpe = [70, 75, 80, 85, 70, 70, 80, 90, 95];
  const squatReps = [8, 8, 7, 7, 5, 3, 3, 2, 2];
  const deadReps = [5, 5, 4, 4, 3, 3, 2, 2, 1];
  return [
    for (var w = 0; w < 9; w++) ...[
      StarterDay('TSA Intermediate 2.0 · W${w + 1} · Day 1', [
        _tsa('Back Squat', w == 8 ? 5 : 4, squatReps[w], topRpe[w]),
        _tsa(
          'Bench Press',
          w == 8 ? 5 : 4,
          w < 4 ? 8 - w ~/ 2 : (w < 8 ? 6 - (w - 5) ~/ 2 : 4),
          topRpe[w],
        ),
        _tsa(
          'Close-Grip Bench Press',
          w == 4 ? 2 : 3,
          w < 4 ? 6 : 5,
          w < 4 ? 70 + w * 5 : 70,
        ),
        _tsa('Chest-Supported Row', 4, w < 4 ? 10 : 8, 70),
        _tsa('Face Pull', 3, 30, 70),
      ]),
      StarterDay('TSA Intermediate 2.0 · W${w + 1} · Day 2', [
        _tsa('Deadlift', w == 8 ? 5 : (w < 4 ? 5 : 4), deadReps[w], topRpe[w]),
        _tsa('Bench Press', 5, w < 8 ? 4 : 3, 75 + (w * 2).clamp(0, 15)),
        _tsa('Barbell Row', 3, w < 4 ? 5 : 4, 75),
        _tsa('Back Extension', 3, w < 4 ? 10 : 8, 75),
        _tsa('Pull-Up', 3, w < 2 ? 10 : 8, 85),
      ]),
      StarterDay('TSA Intermediate 2.0 · W${w + 1} · Day 3', [
        _tsa(
          'Back Squat',
          w == 8 ? 1 : (w < 5 ? 6 : 5),
          w < 5 ? 4 : 3,
          w == 8 ? 95 : 75 + w,
        ),
        _tsa('Overhead Press', 3, w < 5 ? 8 : 6, w < 2 ? 70 : 80),
        _tsa('Leg Press', 3, w < 5 ? 8 : 6, 75),
        _tsa('Chest-Supported Row', 3, w < 5 ? 10 : 8, 80),
        _tsa('Dumbbell Curl', 3, w < 5 ? 12 : 10, 75),
      ]),
      StarterDay('TSA Intermediate 2.0 · W${w + 1} · Day 4', [
        _tsa(
          'Bench Press',
          w == 8 ? 1 : 4,
          w < 5 ? 5 : (w < 8 ? 4 : 1),
          topRpe[w],
        ),
        _tsa(
          'Paused Bench Press',
          w == 4 ? 2 : 3,
          w < 5 ? 6 : 5,
          w < 4 ? 70 + w * 5 : 75,
        ),
        _tsa(
          'Pause Deadlift',
          w == 8 ? 1 : (w < 5 ? 4 : 5),
          w < 5 ? 4 : (w < 8 ? 3 : 1),
          w == 8 ? 95 : 75,
        ),
        _tsa('Barbell Row', 3, w < 5 ? 6 : 4, 80),
        _tsa('Lat Pulldown', 3, w < 5 ? 10 : 8, 85),
      ]),
    ],
  ];
}

/// Candito's heavy lower day, shared by both variants: the squat and the
/// deadlift at six reps a set, moving 5 kg a week and dropping 7.5 on the lift
/// that missed.
const List<StarterSlot> _canditoHeavyLower = [
  StarterSlot.heavy(
    'Back Squat',
    sets: 3,
    repsMin: 6,
    weightKg: 100,
    deload: 7.5,
  ),
  StarterSlot.heavy(
    'Deadlift',
    sets: 2,
    repsMin: 6,
    weightKg: 120,
    deload: 7.5,
  ),
  StarterSlot('Leg Curl', sets: 3, repsMin: 12, weightKg: 40),
];

/// The heavy upper day, likewise. The bench and the row move together — a
/// horizontal upper-back movement progresses at the pace the bench does — and
/// the overhead press and the chin-up wait three clean sessions for a step,
/// which at one session a week is Candito's "about once every three weeks".
const List<StarterSlot> _canditoHeavyUpper = [
  StarterSlot('Bench Press', sets: 3, repsMin: 6, weightKg: 70, deload: 7.5),
  StarterSlot('Barbell Row', sets: 3, repsMin: 6, weightKg: 60, deload: 7.5),
  StarterSlot(
    'Overhead Press',
    sets: 3,
    repsMin: 8,
    weightKg: 40,
    deload: 7.5,
    successThreshold: 3,
  ),
  StarterSlot('Chin-Up', sets: 3, repsMin: 8, repsMax: 10, successThreshold: 3),
];

/// Sheiko #29–32's forty-eight sessions, in the order they are trained.
///
/// A table of its own rather than an inline literal, because it is longer than
/// the rest of the library put together and burying the other fifteen programs
/// under it would make the list unreadable. The program that uses it is above,
/// where the other fifteen are, and it says what these are.
final List<StarterDay> _sheikoDays = [
  StarterDay('#29 · W1 · Mon', [
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
      ],
    ),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(5, 60),
        _r(5, 60),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(5, 60),
        _r(4, 70),
        _r(4, 70),
        _r(4, 70),
        _r(4, 70),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#29 · W1 · Wed', [
    StarterSlot.custom(
      'Deadlift to Knees',
      weightKg: 120.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
      ],
    ),
    StarterSlot('Incline Bench Press', sets: 4, repsMin: 6),
    StarterSlot('Chest Dip', sets: 5, repsMin: 5),
    StarterSlot.custom(
      'Block Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(4, 55),
        _r(4, 65),
        _r(4, 75),
        _r(4, 75),
        _r(3, 85),
        _r(3, 85),
        _r(3, 85),
        _r(3, 85),
      ],
    ),
    StarterSlot('Walking Lunge', sets: 5, repsMin: 5),
    StarterSlot('Crunch', sets: 3, repsMin: 10),
  ]),
  StarterDay('#29 · W1 · Fri', [
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(5, 60),
        _r(4, 70),
        _r(3, 75),
        _r(3, 75),
        _r(2, 80),
        _r(2, 80),
        _r(3, 75),
        _r(3, 75),
        _r(4, 70),
        _r(6, 60),
        _r(8, 50),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
      ],
    ),
    StarterSlot('Seated Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#29 · W2 · Mon', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Push-Up', sets: 5, repsMin: 10),
    StarterSlot.custom(
      'Front Squat',
      weightKg: 100.0,
      customSets: [
        _r(3, 45),
        _r(3, 45),
        _r(3, 55),
        _r(3, 55),
        _r(2, 60),
        _r(2, 60),
        _r(2, 60),
        _r(2, 60),
      ],
    ),
    StarterSlot('Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#29 · W2 · Wed', [
    StarterSlot.custom(
      'Deadlift to Knees',
      weightKg: 120.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 75),
        _r(2, 75),
        _r(2, 75),
        _r(2, 75),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(6, 50),
        _r(6, 60),
        _r(6, 60),
        _r(6, 65),
        _r(6, 65),
        _r(6, 65),
        _r(6, 65),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot.custom(
      'Block Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(4, 55),
        _r(4, 65),
        _r(4, 75),
        _r(4, 75),
        _r(4, 80),
        _r(4, 80),
        _r(4, 80),
        _r(4, 80),
      ],
    ),
    StarterSlot('Walking Lunge', sets: 5, repsMin: 5),
  ]),
  StarterDay('#29 · W2 · Fri', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(3, 75),
        _r(5, 65),
        _r(7, 55),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(5, 60),
        _r(5, 60),
        _r(4, 70),
        _r(4, 70),
        _r(4, 70),
        _r(4, 70),
      ],
    ),
    StarterSlot('Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#29 · W3 · Mon', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 55),
        _r(4, 65),
        _r(3, 75),
        _r(3, 75),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Push-Up', sets: 5, repsMin: 10),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot('Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#29 · W3 · Wed', [
    StarterSlot.custom(
      'Deficit Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(3, 50),
        _r(3, 50),
        _r(3, 60),
        _r(3, 60),
        _r(3, 65),
        _r(3, 65),
        _r(3, 65),
        _r(3, 65),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 85),
        _r(2, 85),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot.custom(
      'Block Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(4, 60),
        _r(4, 70),
        _r(4, 70),
        _r(3, 80),
        _r(3, 80),
        _r(2, 90),
        _r(2, 90),
        _r(2, 90),
      ],
    ),
    StarterSlot('Walking Lunge', sets: 5, repsMin: 5),
  ]),
  StarterDay('#29 · W3 · Fri', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Overhead Press', sets: 5, repsMin: 4),
    StarterSlot('Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#29 · W4 · Mon', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 55),
        _r(5, 65),
        _r(4, 75),
        _r(4, 75),
        _r(4, 75),
        _r(4, 75),
        _r(4, 75),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Chest Dip', sets: 5, repsMin: 8),
    StarterSlot.custom(
      'Front Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 40),
        _r(5, 40),
        _r(4, 50),
        _r(4, 50),
        _r(3, 60),
        _r(3, 60),
        _r(3, 60),
      ],
    ),
    StarterSlot('Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#29 · W4 · Wed', [
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
      ],
    ),
    StarterSlot.custom(
      'Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(5, 60),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
  ]),
  StarterDay('#29 · W4 · Fri', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(6, 50),
        _r(5, 60),
        _r(4, 70),
        _r(4, 70),
        _r(3, 80),
        _r(3, 80),
        _r(2, 85),
        _r(2, 85),
        _r(3, 80),
        _r(3, 80),
        _r(4, 70),
        _r(6, 60),
        _r(8, 50),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Chest Dip', sets: 5, repsMin: 8),
    StarterSlot('Seated Good Morning', sets: 5, repsMin: 5),
    StarterSlot('Crunch', sets: 3, repsMin: 10),
  ]),
  StarterDay('#30 · W1 · Mon', [
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(5, 60),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 55),
        _r(4, 65),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
      ],
    ),
    StarterSlot('Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#30 · W1 · Wed', [
    StarterSlot.custom(
      'Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(4, 50),
        _r(4, 60),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(5, 60),
        _r(4, 70),
        _r(4, 70),
        _r(3, 75),
        _r(3, 75),
        _r(2, 80),
        _r(2, 80),
        _r(1, 85),
        _r(1, 85),
        _r(2, 80),
        _r(2, 80),
        _r(3, 75),
        _r(3, 75),
        _r(4, 70),
        _r(6, 65),
        _r(8, 60),
        _r(10, 55),
        _r(12, 50),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 6, repsMin: 4),
    StarterSlot.custom(
      'Block Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(5, 60),
        _r(4, 70),
        _r(4, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(2, 90),
        _r(2, 90),
        _r(2, 90),
        _r(2, 90),
      ],
    ),
    StarterSlot('Walking Lunge', sets: 5, repsMin: 5),
    StarterSlot('Crunch', sets: 3, repsMin: 10),
  ]),
  StarterDay('#30 · W1 · Fri', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
      ],
    ),
    StarterSlot('Chest Dip', sets: 5, repsMin: 6),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(5, 60),
        _r(5, 60),
        _r(4, 70),
        _r(4, 70),
        _r(4, 70),
        _r(4, 70),
      ],
    ),
    StarterSlot('French Press', sets: 5, repsMin: 10),
    StarterSlot('Seated Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#30 · W2 · Mon', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(1, 90),
        _r(1, 90),
        _r(1, 90),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Push-Up', sets: 5, repsMin: 10),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
      ],
    ),
    StarterSlot('Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#30 · W2 · Wed', [
    StarterSlot.custom(
      'Deadlift to Knees',
      weightKg: 120.0,
      customSets: [
        _r(4, 50),
        _r(4, 60),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(5, 60),
        _r(4, 70),
        _r(4, 70),
        _r(3, 75),
        _r(3, 75),
        _r(2, 80),
        _r(2, 80),
        _r(3, 75),
        _r(3, 75),
        _r(5, 70),
        _r(5, 70),
        _r(7, 60),
        _r(9, 50),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot.custom(
      'Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(4, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot('Walking Lunge', sets: 5, repsMin: 5),
  ]),
  StarterDay('#30 · W2 · Fri', [
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
      ],
    ),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(5, 60),
        _r(5, 60),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(4, 55),
        _r(3, 65),
        _r(2, 75),
        _r(2, 75),
        _r(2, 75),
        _r(2, 75),
        _r(2, 75),
      ],
    ),
    StarterSlot('Chest Dip', sets: 5, repsMin: 8),
    StarterSlot('Leg Press', sets: 5, repsMin: 6),
    StarterSlot('Seated Good Morning', sets: 5, repsMin: 6),
  ]),
  StarterDay('#30 · W3 · Mon', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(6, 50),
        _r(6, 60),
        _r(6, 65),
        _r(6, 65),
        _r(6, 65),
        _r(6, 65),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 55),
        _r(5, 65),
        _r(5, 65),
        _r(4, 75),
        _r(4, 75),
        _r(4, 75),
        _r(4, 75),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#30 · W3 · Wed', [
    StarterSlot.custom(
      'Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(4, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(6, 50),
        _r(5, 60),
        _r(4, 70),
        _r(4, 70),
        _r(3, 75),
        _r(3, 75),
        _r(2, 80),
        _r(2, 80),
        _r(1, 85),
        _r(1, 85),
        _r(2, 80),
        _r(2, 80),
        _r(3, 75),
        _r(3, 75),
        _r(5, 70),
        _r(7, 65),
        _r(9, 60),
        _r(11, 55),
        _r(13, 50),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot.custom(
      'Block Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(5, 65),
        _r(5, 75),
        _r(5, 75),
        _r(4, 85),
        _r(4, 85),
        _r(4, 85),
        _r(4, 85),
      ],
    ),
    StarterSlot('Walking Lunge', sets: 5, repsMin: 5),
    StarterSlot('Crunch', sets: 3, repsMin: 10),
  ]),
  StarterDay('#30 · W3 · Fri', [
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(5, 60),
        _r(5, 60),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Seated Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#30 · W4 · Mon', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(2, 85),
        _r(2, 85),
        _r(1, 90),
        _r(1, 90),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(2, 85),
        _r(2, 85),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Chest Dip', sets: 5, repsMin: 8),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
      ],
    ),
    StarterSlot('Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#30 · W4 · Wed', [
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
      ],
    ),
    StarterSlot.custom(
      'Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(4, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 55),
        _r(5, 65),
        _r(4, 75),
        _r(4, 75),
        _r(4, 75),
        _r(4, 75),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Walking Lunge', sets: 5, repsMin: 5),
  ]),
  StarterDay('#30 · W4 · Fri', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(5, 60),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Chest Dip', sets: 5, repsMin: 8),
    StarterSlot('Seated Good Morning', sets: 5, repsMin: 5),
    StarterSlot('Crunch', sets: 3, repsMin: 10),
  ]),
  StarterDay('#31 · W1 · Mon', [
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
      ],
    ),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(5, 60),
        _r(5, 60),
        _r(2, 70),
        _r(4, 70),
        _r(6, 70),
        _r(8, 70),
        _r(7, 70),
        _r(5, 70),
        _r(3, 70),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(6, 50),
        _r(6, 60),
        _r(6, 60),
        _r(6, 65),
        _r(6, 65),
        _r(6, 65),
        _r(6, 65),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(5, 60),
        _r(5, 60),
        _r(4, 65),
        _r(4, 65),
        _r(4, 65),
        _r(4, 65),
      ],
    ),
    StarterSlot('Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#31 · W1 · Wed', [
    StarterSlot.custom(
      'Deadlift to Knees',
      weightKg: 120.0,
      customSets: [
        _r(4, 50),
        _r(4, 60),
        _r(4, 60),
        _r(4, 70),
        _r(4, 70),
        _r(4, 70),
        _r(4, 70),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(5, 60),
        _r(4, 70),
        _r(4, 70),
        _r(3, 75),
        _r(3, 75),
        _r(2, 80),
        _r(2, 80),
        _r(1, 85),
        _r(1, 85),
        _r(2, 80),
        _r(2, 80),
        _r(3, 75),
        _r(3, 75),
        _r(4, 70),
        _r(6, 65),
        _r(8, 60),
        _r(10, 55),
        _r(12, 50),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot.custom(
      'Block Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(5, 60),
        _r(4, 70),
        _r(3, 80),
        _r(3, 80),
        _r(2, 90),
        _r(2, 90),
        _r(2, 90),
        _r(2, 90),
      ],
    ),
    StarterSlot('Walking Lunge', sets: 5, repsMin: 5),
    StarterSlot('Crunch', sets: 3, repsMin: 10),
  ]),
  StarterDay('#31 · W1 · Fri', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
      ],
    ),
    StarterSlot('Chest Dip', sets: 5, repsMin: 6),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 55),
        _r(5, 65),
        _r(4, 75),
        _r(4, 75),
        _r(4, 75),
        _r(4, 75),
      ],
    ),
    StarterSlot('French Press', sets: 5, repsMin: 10),
    StarterSlot('Seated Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#31 · W2 · Mon', [
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(1, 90),
        _r(1, 90),
        _r(1, 90),
      ],
    ),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 55),
        _r(5, 65),
        _r(5, 75),
        _r(5, 75),
        _r(5, 75),
        _r(5, 75),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Leg Press', sets: 5, repsMin: 6),
    StarterSlot('Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#31 · W2 · Wed', [
    StarterSlot.custom(
      'Deficit Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 60),
        _r(3, 65),
        _r(3, 65),
        _r(3, 65),
        _r(3, 65),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(6, 50),
        _r(5, 60),
        _r(4, 70),
        _r(4, 70),
        _r(3, 75),
        _r(3, 75),
        _r(2, 80),
        _r(2, 80),
        _r(1, 85),
        _r(1, 85),
        _r(3, 75),
        _r(5, 65),
        _r(7, 55),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot.custom(
      'Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(3, 55),
        _r(3, 65),
        _r(3, 65),
        _r(3, 75),
        _r(3, 75),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
      ],
    ),
    StarterSlot('Walking Lunge', sets: 5, repsMin: 5),
    StarterSlot('Crunch', sets: 4, repsMin: 10),
  ]),
  StarterDay('#31 · W2 · Fri', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
      ],
    ),
    StarterSlot('Incline Bench Press', sets: 6, repsMin: 4),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(6, 50),
        _r(6, 60),
        _r(6, 65),
        _r(6, 65),
        _r(6, 65),
        _r(6, 65),
      ],
    ),
    StarterSlot('Triceps Pushdown', sets: 5, repsMin: 10),
    StarterSlot('Back Extension', sets: 4, repsMin: 10),
  ]),
  StarterDay('#31 · W3 · Mon', [
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(5, 60),
        _r(5, 70),
        _r(8, 70),
        _r(3, 70),
        _r(6, 70),
        _r(2, 70),
        _r(7, 70),
        _r(4, 70),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 55),
        _r(5, 65),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Walking Lunge', sets: 5, repsMin: 5),
    StarterSlot('Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#31 · W3 · Wed', [
    StarterSlot.custom(
      'Deadlift to Knees',
      weightKg: 120.0,
      customSets: [
        _r(4, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(8, 50),
        _r(7, 55),
        _r(6, 60),
        _r(5, 65),
        _r(4, 70),
        _r(3, 75),
        _r(3, 75),
        _r(2, 80),
        _r(2, 80),
        _r(1, 85),
        _r(1, 85),
        _r(2, 80),
        _r(2, 80),
        _r(3, 75),
        _r(4, 70),
        _r(6, 65),
        _r(8, 60),
        _r(10, 55),
        _r(12, 50),
      ],
    ),
    StarterSlot.custom(
      'Block Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(4, 60),
        _r(4, 70),
        _r(3, 80),
        _r(3, 80),
        _r(2, 90),
        _r(2, 90),
        _r(2, 90),
      ],
    ),
    StarterSlot('Leg Press', sets: 5, repsMin: 5),
    StarterSlot('Crunch', sets: 3, repsMin: 10),
  ]),
  StarterDay('#31 · W3 · Fri', [
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(5, 60),
        _r(5, 60),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Seated Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#31 · W4 · Mon', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(1, 90),
        _r(1, 90),
        _r(1, 90),
        _r(2, 80),
        _r(2, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Chest Dip', sets: 5, repsMin: 8),
    StarterSlot('Walking Lunge', sets: 5, repsMin: 5),
    StarterSlot('Back Extension', sets: 4, repsMin: 10),
  ]),
  StarterDay('#31 · W4 · Wed', [
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(1, 90),
        _r(1, 90),
        _r(1, 90),
        _r(2, 80),
        _r(2, 80),
      ],
    ),
    StarterSlot.custom(
      'Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(1, 90),
        _r(1, 90),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Leg Press', sets: 6, repsMin: 5),
    StarterSlot('Crunch', sets: 3, repsMin: 10),
  ]),
  StarterDay('#31 · W4 · Fri', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(4, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(5, 55),
        _r(5, 65),
        _r(4, 75),
        _r(4, 75),
        _r(4, 75),
        _r(4, 75),
        _r(4, 75),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Chest Dip', sets: 5, repsMin: 8),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(5, 50),
        _r(5, 60),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
        _r(5, 70),
      ],
    ),
    StarterSlot('Seated Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#32 · W1 · Mon', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 75),
        _r(2, 75),
        _r(2, 75),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 75),
        _r(2, 75),
        _r(2, 75),
      ],
    ),
    StarterSlot('Crunch', sets: 3, repsMin: 10),
  ]),
  StarterDay('#32 · W1 · Wed', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 60),
        _r(2, 70),
        _r(2, 70),
        _r(2, 80),
        _r(1, 90),
        _r(1, 95),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(2, 70),
        _r(2, 70),
        _r(2, 80),
        _r(1, 90),
        _r(1, 95),
      ],
    ),
    StarterSlot.custom(
      'Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(3, 50),
        _r(2, 60),
        _r(2, 70),
        _r(2, 70),
        _r(1, 80),
        _r(1, 90),
        _r(1, 95),
      ],
    ),
  ]),
  StarterDay('#32 · W1 · Fri', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 75),
        _r(2, 75),
        _r(2, 75),
        _r(2, 75),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(3, 55),
        _r(3, 65),
        _r(3, 65),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Good Morning', sets: 5, repsMin: 5),
    StarterSlot('Crunch', sets: 3, repsMin: 10),
  ]),
  StarterDay('#32 · W2 · Mon', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(3, 55),
        _r(3, 65),
        _r(3, 65),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
        _r(3, 75),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 4, repsMin: 8),
  ]),
  StarterDay('#32 · W2 · Wed', [
    StarterSlot.custom(
      'Deadlift to Knees',
      weightKg: 120.0,
      customSets: [
        _r(3, 50),
        _r(2, 60),
        _r(2, 60),
        _r(2, 65),
        _r(2, 65),
        _r(1, 70),
        _r(1, 70),
        _r(1, 70),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(2, 85),
        _r(2, 85),
        _r(2, 85),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot.custom(
      'Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot('Crunch', sets: 3, repsMin: 10),
  ]),
  StarterDay('#32 · W2 · Fri', [
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 60),
        _r(3, 70),
        _r(3, 70),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
        _r(3, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(4, 50),
        _r(4, 60),
        _r(4, 70),
        _r(4, 70),
        _r(4, 70),
        _r(4, 70),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 5, repsMin: 10),
    StarterSlot('Good Morning', sets: 5, repsMin: 5),
  ]),
  StarterDay('#32 · W3 · Mon', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(1, 85),
        _r(1, 85),
        _r(1, 85),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 4, repsMin: 8),
    StarterSlot('Crunch', sets: 5, repsMin: 4),
  ]),
  StarterDay('#32 · W3 · Wed', [
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
        _r(2, 80),
      ],
    ),
    StarterSlot('Dumbbell Fly', sets: 4, repsMin: 8),
    StarterSlot.custom(
      'Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 75),
        _r(2, 75),
        _r(2, 75),
        _r(2, 75),
        _r(2, 75),
      ],
    ),
    StarterSlot('Good Morning', sets: 4, repsMin: 5),
  ]),
  StarterDay('#32 · W3 · Fri', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 60),
        _r(2, 70),
        _r(2, 70),
        _r(2, 75),
        _r(2, 75),
        _r(2, 75),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 70),
        _r(3, 70),
        _r(2, 75),
        _r(2, 75),
        _r(2, 75),
        _r(2, 75),
      ],
    ),
    StarterSlot('Crunch', sets: 3, repsMin: 8),
  ]),
  StarterDay('#32 · W4 · Mon', [
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 60),
        _r(2, 70),
        _r(2, 70),
        _r(1, 75),
        _r(1, 75),
        _r(1, 75),
        _r(1, 75),
      ],
    ),
    StarterSlot.custom(
      'Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(3, 50),
        _r(2, 60),
        _r(2, 60),
        _r(2, 70),
        _r(2, 70),
        _r(2, 70),
        _r(2, 70),
      ],
    ),
    StarterSlot('Crunch', sets: 2, repsMin: 8),
  ]),
  StarterDay('#32 · W4 · Wed', [
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 60),
        _r(2, 70),
        _r(2, 70),
        _r(2, 70),
      ],
    ),
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(3, 60),
        _r(2, 70),
        _r(2, 70),
        _r(2, 70),
      ],
    ),
  ]),
  StarterDay('#32 · W4 · Meet', [
    StarterSlot.custom(
      'Bench Press',
      weightKg: 70.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(2, 70),
        _r(2, 70),
        _r(1, 80),
        _r(1, 80),
        _r(1, 90),
        _r(1, 95),
        _r(1, 105),
      ],
    ),
    StarterSlot.custom(
      'Back Squat',
      weightKg: 100.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(2, 70),
        _r(2, 70),
        _r(1, 80),
        _r(1, 80),
        _r(1, 90),
        _r(1, 95),
        _r(1, 105),
      ],
    ),
    StarterSlot.custom(
      'Deadlift',
      weightKg: 120.0,
      customSets: [
        _r(3, 50),
        _r(3, 60),
        _r(2, 70),
        _r(2, 70),
        _r(1, 80),
        _r(1, 80),
        _r(1, 90),
        _r(1, 95),
        _r(1, 105),
      ],
    ),
  ]),
];

/// One written-out row: [reps] reps at [percent]% of the slot's training max.
///
/// A two-letter name because Sheiko is nine hundred of these and the shape of a
/// session — where the reps drop and the percentage climbs — is only legible if
/// a row fits on part of a line.
CustomSet _r(int reps, int percent) => CustomSet(reps: reps, percent: percent);

/// One main lift on the 5/3/1 cycle, opening at a training max of [tm] and
/// gaining [step] each time the cycle comes round.
StarterSlot _main(String exercise, double tm, double step) =>
    StarterSlot.cycling(
      exercise,
      cycle: k531Main,
      weightKg: tm,
      increment: step,
    );

/// The Boring But Big supplemental slot for the same lift, off the same max.
StarterSlot _volume(String exercise, double tm, double step) =>
    StarterSlot.cycling(
      exercise,
      cycle: k531BigVolume,
      weightKg: tm,
      increment: step,
    );

/// The First Set Last supplemental slot for the same lift, off the same max.
StarterSlot _firstSetLast(String exercise, double tm, double step) =>
    StarterSlot.cycling(
      exercise,
      cycle: k531FirstSetLast,
      weightKg: tm,
      increment: step,
    );

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
