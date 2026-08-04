/// The warm-up ramp: given the weight you are working up to, what lighter sets
/// prime the movement first, and for how many reps each.
///
/// Deliberately free of drift and Flutter, like the other rule modules
/// ([progression], [plates], [layoff]). A warm-up is a suggestion, not logged
/// history — it never touches the database, so keeping the arithmetic on its
/// own where it can be read and tested is the whole of it.
///
/// **Where the numbers come from.** The shape is the one every strength
/// program uses: start with the empty bar, take even jumps, drop the reps as
/// the load climbs, and never let the last warm-up become a working set
/// (Starting Strength, "Our warm-up is…a warm-up"; the same source's own worked
/// example divides the gap between bar and work into equal jumps). The
/// constants are the middle of the published advice, expressed as fractions of
/// the **working weight** rather than of 1RM:
///
/// - 2–4 warm-up sets for a compound lift; past four the fatigue starts to cost
///   more than the priming (JSCR 2021, via Fit Records' summary) — hence
///   [kDefaultWarmupSets] of three, and a stepper that goes to six only because
///   a heavy lift over an empty bar genuinely needs the rungs.
/// - First set 40–50% of the working weight, middle 60–70%, an optional last at
///   70–80% — hence [kWarmupStartFraction] and the [kWarmupTopFraction] ceiling.
/// - 8–10 reps on the first, 4–6 in the middle, 1–3 at the top — hence the
///   buckets in [warmupReps].
/// - 45–60 s between warm-up sets, then the exercise's normal rest before the
///   first working set — see `ExerciseEntry.restAfterWarmup`.
///
/// It is still a suggestion, not a prescription, and the screen says so.
library;

import 'dart:math' as math;

import 'plates.dart';

/// One suggested warm-up set. [weightKg] is canonical kilograms like every
/// weight in the app; the UI converts at the view boundary. [reps] drops as the
/// weight climbs — a warm-up primes the movement, it does not pre-fatigue it.
typedef WarmupSet = ({double weightKg, int reps});

/// How many warm-up sets an exercise gets before the user touches the count.
/// Three is the common ramp — light, medium, near — and covers most working
/// weights without turning the screen into a spreadsheet.
///
/// It is where the app starts, not where it stays: `Settings.warmupSets` holds
/// the count a session seeds every exercise with, and this is that column's
/// default.
const kDefaultWarmupSets = 3;

/// The most warm-up sets the live session will let you dial up to. Past this a
/// ramp is warming you down, not up.
const kMaxWarmupSets = 6;

/// Rest after a warm-up set, in seconds — deliberately shorter than a working
/// set's rest. You are priming the movement, not recovering from it, so the
/// clock is a nudge to keep moving rather than the full recovery a heavy set
/// earns.
const kWarmupRestSeconds = 45;

/// Where a ramp starts when there is no empty bar to start on: a dumbbell or a
/// stack has no natural floor, and 40% of the work is light enough to be free.
const kWarmupStartFraction = 0.40;

/// Where the ramp finishes — a hard ceiling, not a target, so the last warm-up
/// is still a warm-up and not a first working set. Snapping a step onto a
/// loadable weight may land under this; it may never land over it.
const kWarmupTopFraction = 0.85;

/// How far from an ideal step the ramp will reach to find a load that is cheaper
/// to set up, as a fraction of the working weight.
///
/// A tenth is worth one pair of plates and no more. Without a cap in absolute
/// terms, a short ramp has enormous gaps between its steps and a window half a
/// gap wide swallows the whole ladder — the empty bar is free, so it wins every
/// step it can see, and a single warm-up before a heavy squat comes back as an
/// empty bar. Cheapness is a tie-breaker between nearby loads, not a reason to
/// warm up 50 kg lighter than intended.
const kWarmupSnapFraction = 0.10;

/// The reps to suggest at a given fraction of the working weight. Monotonic by
/// design: the heavier the warm-up, the fewer reps.
int warmupReps(double fractionOfWorking) {
  if (fractionOfWorking < 0.50) return 8;
  if (fractionOfWorking < 0.65) return 5;
  if (fractionOfWorking < 0.78) return 3;
  return 2;
}

/// A ramp of [sets] warm-up sets climbing toward [workingKg], using only loads
/// from [ladder] — the weights this gym can actually be set to, see
/// [loadLadder].
///
/// **A barbell ramp starts on the empty bar.** Pass the bar as [barKg] and the
/// first rung is the bar itself; everything above it is a load the plates can
/// build, chosen to need as few of them as possible. That is what makes a ramp
/// toward 225 lb read *45 → 95 → 135 → 185* — one pair a step, in sizes a
/// lifter reaches for — rather than the arithmetically even 81/117/153/189,
/// which is four plates a side and a trip to the rack between every set.
/// Without a bar ([barKg] `<= 0`, a dumbbell or a machine) the ramp starts at
/// [kWarmupStartFraction] of the work instead, and every rung lands on the
/// increment the gym stocks.
///
/// **A single warm-up set is the exception**: with [sets] of one there is no ramp
/// to open, so it lands mid-range rather than on the bar — heavy enough to warm
/// you up, light enough to be safe (40 kg for an 80 kg bench, 70 for a 140 kg
/// squat). A working weight light enough that the bar is the only rung available
/// still gets the bar, at any count.
///
/// Returns an empty list when there is nothing to ramp: a zero (or negative)
/// [sets] or [workingKg], an empty [ladder], or a working weight at or below
/// where the ramp would begin (an empty-bar squat has no warm-up below the
/// bar). Two neighbouring steps can also want the same rung — a light working
/// weight on a coarse grid — and those collisions are dropped, so the ramp
/// comes back shorter than asked rather than stalling or stepping backward.
List<WarmupSet> computeWarmups({
  required double workingKg,
  required List<LoadRung> ladder,
  double barKg = 0,
  int sets = kDefaultWarmupSets,
}) {
  if (sets <= 0 || workingKg <= 0) return const [];
  final bar = barKg < 0 ? 0.0 : barKg;
  final start = bar > 0 ? bar : workingKg * kWarmupStartFraction;

  // The rungs this ramp may use: at or above where it starts, and no heavier
  // than [kWarmupTopFraction] of the work. The ceiling is *hard* — snapping to
  // the nearest loadable weight must not push the last warm-up up to 88% of a
  // set you still have to do four of.
  final ceiling = workingKg * kWarmupTopFraction;
  final usable = [
    for (final r in ladder)
      if (r.kg >= start - kPlateToleranceKg &&
          r.kg < workingKg - kPlateToleranceKg)
        r,
  ]..sort((a, b) => a.kg.compareTo(b.kg));
  if (usable.isEmpty) return const [];
  // The empty bar survives the ceiling regardless: on a working weight barely
  // above the bar it is the only warm-up there is, and it is still the one to
  // start on.
  final rungs = [
    for (final r in usable)
      if (r.kg <= ceiling + kPlateToleranceKg || r.kg <= usable.first.kg) r,
  ];

  // The ramp spans the lightest usable rung to the ceiling, or as close to it
  // as the ladder reaches.
  final floor = rungs.first.kg;
  final top = ceiling.clamp(floor, rungs.last.kg);
  final gap = sets == 1 ? top - floor : (top - floor) / (sets - 1);

  // How far a step may stray to find a cheaper load: half a step, and never
  // more than [kWarmupSnapFraction] of the work.
  final window = math.min(gap / 2, workingKg * kWarmupSnapFraction);

  final out = <WarmupSet>[];
  double? last;
  for (var i = 0; i < sets; i++) {
    // One warm-up sits in the middle of the ramp rather than at the bottom of
    // it; more than one steps evenly from floor to top.
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
