part of '../starter_routines.dart';

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
    experienceLevel: ExperienceLevel.intermediate,
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
    experienceLevel: ExperienceLevel.intermediate,
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
    experienceLevel: ExperienceLevel.intermediate,
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
    experienceLevel: ExperienceLevel.intermediate,
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
    experienceLevel: ExperienceLevel.intermediate,
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
    experienceLevel: ExperienceLevel.advanced,
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
    experienceLevel: ExperienceLevel.intermediate,
    name: 'TSA Intermediate 2.0',
    description:
        'The Strength Athlete’s nine-week Intermediate 2.0 powerlifting program. Four weekly sessions combine competition lifts, variations, and RPE-regulated work.',
    colorHex: '6A1B9A',
    restSeconds: 180,
    scheduleDays: _mtthf,
    days: _tsaIntermediateDays,
  ),
];

/// The First Set Last supplemental slot for the same lift, off the same max.
StarterSlot _firstSetLast(String exercise, double tm, double step) =>
    StarterSlot.cycling(
      exercise,
      cycle: k531FirstSetLast,
      weightKg: tm,
      increment: step,
    );
