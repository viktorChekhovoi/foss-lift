part of '../starter_routines.dart';

/// Programs offered by this build. Retired templates remain below as lookup
/// fallbacks for old deep links, but no longer appear in the library.
final StarterRoutine _gzclp = StarterRoutine(
  key: 'gzclp',
  name: 'GZCLP',
  description:
      'Cody Lefever’s novice linear progression. Four rotating sessions pair heavy main lifts with moderate secondary lifts and higher-rep assistance work.',
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
