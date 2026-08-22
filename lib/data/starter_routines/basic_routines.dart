part of '../starter_routines.dart';

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
  experienceLevel: ExperienceLevel.intermediate,
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
