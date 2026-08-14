/// The programs the app ships, as prescriptions rather than as rows.
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
  })  : increment = null,
        deload = null,
        cycle = const [];

  /// A slot on one of the lifts a linear-progression program moves 5 kg a
  /// session — the squat, the deadlift and their variants — rather than the
  /// 2.5 kg the presses take. The back-off is twice the step, as everywhere.
  const StarterSlot.heavy(
    this.exercise, {
    required this.sets,
    required this.repsMin,
    required this.weightKg,
  })  : repsMax = null,
        holdSeconds = null,
        increment = 5,
        deload = 10,
        cycle = const [];

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
  })  : sets = 0,
        repsMin = 0,
        repsMax = null,
        holdSeconds = null,
        deload = null;

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

  /// The weeks this slot rotates through, or empty for a slot that does not —
  /// see [StarterSlot.cycling] and `data/set_scheme.dart`.
  final List<List<CustomSet>> cycle;
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
  _bbbWeek, _bbbWeek, _bbbWeek,
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
/// that ask for less than a gym, and the four 5/3/1 programs.
final List<StarterRoutine> kStarterRoutines = [
  StarterRoutine(
    key: 'ppl',
    description: 'Three sessions a week, each one a different half of what you do: the muscles you push with, the ones you pull with, and legs. The usual next step once a beginner program stops adding weight every session.',
    name: 'Push / Pull / Legs',
    colorHex: 'FF6A3D',
    restSeconds: 120,
    scheduleDays: _mwf,
    days: [
      StarterDay('Push', [
        StarterSlot('Bench Press', sets: 4, repsMin: 6, repsMax: 8, weightKg: 80),
        StarterSlot('Overhead Press', sets: 4, repsMin: 8, weightKg: 50),
        StarterSlot('Incline DB Press',
            sets: 3, repsMin: 10, repsMax: 12, weightKg: 30),
        StarterSlot('Lateral Raise', sets: 3, repsMin: 15, weightKg: 12),
        StarterSlot('Triceps Pushdown',
            sets: 3, repsMin: 12, repsMax: 15, weightKg: 35),
      ]),
      StarterDay('Pull', [
        StarterSlot('Deadlift', sets: 3, repsMin: 5, weightKg: 140),
        StarterSlot('Pull-Up', sets: 4, repsMin: 6, repsMax: 10),
        StarterSlot('Barbell Row', sets: 4, repsMin: 8, weightKg: 70),
        StarterSlot('Face Pull', sets: 3, repsMin: 15, repsMax: 20, weightKg: 25),
        StarterSlot('Barbell Curl',
            sets: 3, repsMin: 10, repsMax: 12, weightKg: 30),
      ]),
      StarterDay('Legs', [
        StarterSlot('Back Squat', sets: 4, repsMin: 6, weightKg: 110),
        StarterSlot('Romanian Deadlift', sets: 3, repsMin: 10, weightKg: 90),
        StarterSlot('Leg Press', sets: 3, repsMin: 12, repsMax: 15, weightKg: 180),
        StarterSlot('Leg Curl', sets: 3, repsMin: 12, weightKg: 45),
        StarterSlot('Calf Raise', sets: 4, repsMin: 15, repsMax: 20, weightKg: 60),
      ]),
    ],
  ),
  // Upper/Lower deliberately repeats a day name — that is legal inside a routine
  // and worth demonstrating.
  StarterRoutine(
    key: 'upper-lower',
    description: 'Four sessions a week, alternating the upper body and the lower. Each muscle is trained twice a week, and no single session has to cover everything.',
    name: 'Upper / Lower',
    colorHex: '3ED598',
    restSeconds: 150,
    days: [
      StarterDay('Upper 1', [
        StarterSlot('Bench Press', sets: 4, repsMin: 5, weightKg: 80),
        StarterSlot('Barbell Row', sets: 4, repsMin: 6, repsMax: 8, weightKg: 70),
        StarterSlot('Overhead Press',
            sets: 3, repsMin: 8, repsMax: 10, weightKg: 45),
        StarterSlot('Lat Pulldown',
            sets: 3, repsMin: 10, repsMax: 12, weightKg: 55),
      ]),
      StarterDay('Lower 1', [
        StarterSlot('Back Squat', sets: 4, repsMin: 5, weightKg: 110),
        StarterSlot('Romanian Deadlift',
            sets: 3, repsMin: 8, repsMax: 10, weightKg: 90),
        StarterSlot('Leg Curl', sets: 3, repsMin: 12, weightKg: 45),
        StarterSlot('Calf Raise', sets: 4, repsMin: 15, repsMax: 20, weightKg: 60),
      ]),
      StarterDay('Upper 2', [
        StarterSlot('Incline DB Press',
            sets: 4, repsMin: 8, repsMax: 10, weightKg: 30),
        StarterSlot('Pull-Up', sets: 4, repsMin: 6, repsMax: 10),
        StarterSlot('Lateral Raise', sets: 3, repsMin: 15, weightKg: 12),
        StarterSlot('Hammer Curl',
            sets: 3, repsMin: 10, repsMax: 12, weightKg: 14),
      ]),
      StarterDay('Lower 2', [
        StarterSlot('Deadlift', sets: 3, repsMin: 5, weightKg: 140),
        StarterSlot('Front Squat', sets: 3, repsMin: 8, repsMax: 10, weightKg: 70),
        StarterSlot('Leg Press', sets: 3, repsMin: 12, repsMax: 15, weightKg: 180),
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
    description: "Mark Rippetoe's beginner barbell program: two alternating "
        'workouts of three lifts each, three days a week, adding weight every '
        'session for as long as that keeps working. Long rests — it is heavy on '
        'purpose.',
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
    description: 'Five sets of five, across five lifts and two alternating workouts, three days a week. The same idea as Starting Strength with more sets and a lighter start.',
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
    description: 'Three full-body sessions a week, each with a squat or hinge, a press, a pull and some core work. For training three times a week without keeping track of a split.',
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
        StarterSlot.heavy('Romanian Deadlift', sets: 3, repsMin: 8, weightKg: 60),
        StarterSlot('Overhead Press',
            sets: 3, repsMin: 6, repsMax: 8, weightKg: 30),
        StarterSlot('Lat Pulldown',
            sets: 3, repsMin: 10, repsMax: 12, weightKg: 50),
        StarterSlot('Cable Crunch',
            sets: 3, repsMin: 12, repsMax: 15, weightKg: 30),
      ]),
      StarterDay('Workout C', [
        StarterSlot.heavy('Deadlift', sets: 2, repsMin: 5, weightKg: 80),
        StarterSlot('Incline DB Press',
            sets: 3, repsMin: 8, repsMax: 10, weightKg: 22.5),
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
    description: 'Two sessions a week, each with a squat or a hinge, a press, a pull and some core work. For a week that has two training days in it rather than four.',
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
        StarterSlot('Lat Pulldown',
            sets: 3, repsMin: 10, repsMax: 12, weightKg: 45),
        StarterSlot('Bulgarian Split Squat', sets: 3, repsMin: 8, repsMax: 12),
      ]),
    ],
  ),
  // Nothing but your own weight. Every slot carries no load, so each one
  // progresses on reps — which is the axis these movements actually move on
  // until the movement itself is made harder.
  StarterRoutine(
    key: 'bodyweight-basics',
    description: 'Three sessions a week with no equipment beyond a floor and something to hang from. Add reps first; when the top of the range gets easy, move to a harder version of the same movement.',
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
        StarterSlot('Single-Leg Glute Bridge',
            sets: 3, repsMin: 12, repsMax: 15),
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
    description: 'Three whole-body sessions a week on one pair of dumbbells. Everything is pressed, pulled or carried with the weight in your hands, so it works in a spare room as well as in a gym.',
    name: 'Dumbbell Full Body',
    colorHex: 'F4845F',
    restSeconds: 120,
    scheduleDays: _tts,
    days: [
      StarterDay('Workout A', [
        StarterSlot('Dumbbell Front Squat',
            sets: 4, repsMin: 8, repsMax: 10, weightKg: 20),
        StarterSlot('Dumbbell Bench Press',
            sets: 4, repsMin: 8, repsMax: 10, weightKg: 22.5),
        StarterSlot('Dumbbell Row',
            sets: 4, repsMin: 8, repsMax: 10, weightKg: 24),
        StarterSlot('Dumbbell Curl',
            sets: 3, repsMin: 10, repsMax: 12, weightKg: 12),
      ]),
      StarterDay('Workout B', [
        StarterSlot('Dumbbell Romanian Deadlift',
            sets: 4, repsMin: 8, repsMax: 10, weightKg: 24),
        StarterSlot('Dumbbell Shoulder Press',
            sets: 4, repsMin: 8, repsMax: 10, weightKg: 16),
        StarterSlot('Renegade Row', sets: 3, repsMin: 8, repsMax: 10, weightKg: 14),
        // Held, so the target is the walk rather than a rep count.
        StarterSlot("Farmer's Carry", sets: 3, holdSeconds: 40, weightKg: 24),
      ]),
      StarterDay('Workout C', [
        StarterSlot('Dumbbell Lunge',
            sets: 3, repsMin: 10, repsMax: 12, weightKg: 16),
        StarterSlot('Dumbbell Floor Press',
            sets: 4, repsMin: 8, repsMax: 10, weightKg: 22.5),
        StarterSlot('Dumbbell Pullover',
            sets: 3, repsMin: 12, repsMax: 15, weightKg: 16),
        StarterSlot('Dumbbell Thruster',
            sets: 3, repsMin: 8, repsMax: 10, weightKg: 14),
      ]),
    ],
  ),
  // Timed intervals rather than sets of reps. Every movement here is one the
  // library measures in seconds, which is what makes the work period the slot's
  // target — see [StarterSlot.holdSeconds]. The rest between rounds is the
  // routine's default rest, so it is one number for the whole session.
  StarterRoutine(
    key: 'interval-conditioning',
    description: 'Two conditioning sessions a week, measured in seconds rather than reps: rounds of hard work against the clock with a short rest between them. Meant to be trained alongside a strength program, not instead of one.',
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
    description: 'Four sessions a week, one main lift each: three working sets off a training max, the last of them for as many reps as you have. Two assistance movements follow. Set each training max to 90% of your best single before you start.',
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
        StarterSlot('Dumbbell Bench Press',
            sets: 5, repsMin: 12, repsMax: 15, weightKg: 24),
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
    description: 'The same four sessions, with five sets of ten of the main lift at half the training max after it. The most work of the four and the one that adds size. Set each training max to 90% of your best single before you start.',
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
    description: "The same four sessions, with five sets of five of the main lift at the week's own opening percentage after it. Less volume than Boring But Big and heavier, because the back-off weight climbs as the week does. Set each training max to 90% of your best single before you start.",
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
    description: 'The four lifts folded into three sessions a week, two of them a session. For somebody whose linear progression has stopped adding weight but who does not want four days in the gym. Set each training max to 90% of your best single before you start.',
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
];

/// One main lift on the 5/3/1 cycle, opening at a training max of [tm] and
/// gaining [step] each time the cycle comes round.
StarterSlot _main(String exercise, double tm, double step) =>
    StarterSlot.cycling(exercise, cycle: k531Main, weightKg: tm, increment: step);

/// The Boring But Big supplemental slot for the same lift, off the same max.
StarterSlot _volume(String exercise, double tm, double step) => StarterSlot.cycling(
    exercise, cycle: k531BigVolume, weightKg: tm, increment: step);

/// The First Set Last supplemental slot for the same lift, off the same max.
StarterSlot _firstSetLast(String exercise, double tm, double step) =>
    StarterSlot.cycling(exercise,
        cycle: k531FirstSetLast, weightKg: tm, increment: step);

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
  return null;
}
