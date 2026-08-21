/// Computes suggested warm-up loads and reps without touching persisted data.
library;

import 'dart:math' as math;

import 'plates.dart';

/// One suggested warm-up set in canonical kilograms.
typedef WarmupSet = ({double weightKg, int reps});

/// Default number of warm-up sets.
const kDefaultWarmupSets = 3;

/// Resolves an exercise-specific count against the app-wide setting; a non-positive app-wide value disables warm-ups.
int warmupCountFor(int appWide, int? exerciseOwn) =>
    appWide <= 0 ? 0 : (exerciseOwn ?? appWide);

/// Maximum warm-up sets supported by the live session.
const kMaxWarmupSets = 6;

/// Rest after a warm-up set, in seconds.
const kWarmupRestSeconds = 45;

/// Starting fraction for ramps without a bar floor.
const kWarmupStartFraction = 0.40;

/// Maximum warm-up fraction of the working weight.
const kWarmupTopFraction = 0.85;

/// Maximum fraction by which a rung may differ from its ideal step.
const kWarmupSnapFraction = 0.10;

/// Suggests reps for a warm-up fraction.
int warmupReps(double fractionOfWorking) {
  if (fractionOfWorking < 0.50) return 8;
  if (fractionOfWorking < 0.65) return 5;
  if (fractionOfWorking < 0.78) return 3;
  return 2;
}

/// Builds a ramp of [sets] loadable warm-up sets toward [workingKg]; returns an empty list when no ramp is possible.
List<WarmupSet> computeWarmups({
  required double workingKg,
  required List<LoadRung> ladder,
  double barKg = 0,
  int sets = kDefaultWarmupSets,
}) {
  if (sets <= 0 || workingKg <= 0) return const [];
  final bar = barKg < 0 ? 0.0 : barKg;
  final start = bar > 0 ? bar : workingKg * kWarmupStartFraction;

  // Keep rungs within the ramp's starting floor and hard upper ceiling.
  final ceiling = workingKg * kWarmupTopFraction;
  final usable = [
    for (final r in ladder)
      if (r.kg >= start - kPlateToleranceKg &&
          r.kg < workingKg - kPlateToleranceKg)
        r,
  ]..sort((a, b) => a.kg.compareTo(b.kg));
  if (usable.isEmpty) return const [];
  // Keep the first usable rung even when it exceeds the ceiling.
  final rungs = [
    for (final r in usable)
      if (r.kg <= ceiling + kPlateToleranceKg || r.kg <= usable.first.kg) r,
  ];

  // Spread the ramp between the lightest rung and the ceiling.
  final floor = rungs.first.kg;
  final top = ceiling.clamp(floor, rungs.last.kg);
  final gap = sets == 1 ? top - floor : (top - floor) / (sets - 1);

  // How far a step may stray to find a cheaper load: half a step, and never
  // more than [kWarmupSnapFraction] of the work.
  final window = math.min(gap / 2, workingKg * kWarmupSnapFraction);

  final out = <WarmupSet>[];
  double? last;
  for (var i = 0; i < sets; i++) {
    // A single warm-up uses the midpoint; multiple sets are evenly spaced.
    final ideal = sets == 1 ? floor + gap / 2 : floor + gap * i;
    final pick = _pickRung(rungs, ideal: ideal, window: window, above: last);
    if (pick == null) continue; // nothing left between here and the work
    out.add((weightKg: pick, reps: warmupReps(pick / workingKg)));
    last = pick;
  }
  return out;
}

/// The load to use for one step of a ramp: the cheapest rung within [window] of
/// [ideal], or — when the ladder has nothing that close — the nearest rung
/// there is. Rungs at or below [above] are already behind us and ignored.
///
/// Null when every rung is behind us, which is how a ramp comes back shorter
/// than it was asked for.
double? _pickRung(
  List<LoadRung> rungs, {
  required double ideal,
  required double window,
  double? above,
}) {
  final open = [
    for (final r in rungs)
      if (above == null || r.kg > above + kPlateToleranceKg) r,
  ];
  if (open.isEmpty) return null;
  final near = [
    for (final r in open)
      if ((r.kg - ideal).abs() <= window + kPlateToleranceKg) r,
  ];
  final candidates = near.isNotEmpty ? near : open;
  candidates.sort(_byFitness(ideal, cheapestFirst: near.isNotEmpty));
  return candidates.first.kg;
}

/// Orders the rungs that could serve one step of the ramp.
///
/// [cheapestFirst] is the normal case: among the loads near the step, the one
/// that costs the fewest plates wins. When nothing is near the step there is no
/// cheapness to trade for, so the closest load wins instead. Ties go to the
/// lighter rung either way — a warm-up that misses should miss light.
int Function(LoadRung, LoadRung) _byFitness(
  double ideal, {
  required bool cheapestFirst,
}) =>
    (a, b) {
      final cost = a.cost.compareTo(b.cost);
      if (cheapestFirst && cost != 0) return cost;
      final near =
          (a.kg - ideal).abs().compareTo((b.kg - ideal).abs());
      if (near != 0) return near;
      if (cost != 0) return cost;
      return a.kg.compareTo(b.kg);
    };
