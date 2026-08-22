part of '../starter_routines.dart';

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
