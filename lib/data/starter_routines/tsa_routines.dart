part of '../starter_routines.dart';

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
