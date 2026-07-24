/// The warm-up ramp: given the weight you are working up to, what lighter sets
/// prime the movement first, and for how many reps each.
///
/// Deliberately free of drift and Flutter, like the other rule modules
/// ([progression], [plates], [layoff]). A warm-up is a suggestion, not logged
/// history — it never touches the database, so keeping the arithmetic on its
/// own where it can be read and tested is the whole of it.
library;

/// One suggested warm-up set. [weightKg] is canonical kilograms like every
/// weight in the app; the UI converts at the view boundary. [reps] drops as the
/// weight climbs — a warm-up primes the movement, it does not pre-fatigue it.
typedef WarmupSet = ({double weightKg, int reps});

/// How many warm-up sets an exercise gets before the user touches the count.
/// Three is the common ramp — light, medium, near — and covers most working
/// weights without turning the screen into a spreadsheet.
const kDefaultWarmupSets = 3;

/// The most warm-up sets the live session will let you dial up to. Past this a
/// ramp is warming you down, not up.
const kMaxWarmupSets = 6;

/// Rest after a warm-up set, in seconds — deliberately shorter than a working
/// set's rest. You are priming the movement, not recovering from it, so the
/// clock is a nudge to keep moving rather than the full recovery a heavy set
/// earns.
const kWarmupRestSeconds = 45;

/// The reps to suggest at a given fraction of the working weight. Monotonic by
/// design: the heavier the warm-up, the fewer reps.
int warmupReps(double fractionOfWorking) {
  if (fractionOfWorking < 0.50) return 8;
  if (fractionOfWorking < 0.65) return 5;
  if (fractionOfWorking < 0.78) return 3;
  return 2;
}

/// A ramp of [sets] warm-up sets climbing toward [workingKg].
///
/// The heaviest warm-up sits a clear margin below the working weight (never at
/// or above it — that is the work, not a warm-up), and the lightest starts at
/// the empty bar for a barbell ([barKg] > 0) or around 40% for anything else.
/// Weights are rounded to [roundingKg] so the ramp lands on numbers a rack can
/// build; the caller's plate solver turns each into a per-side breakdown.
///
/// Returns an empty list when there is nothing to ramp: a zero (or negative)
/// [sets] or [workingKg], or a working weight barely above where the ramp would
/// begin (an empty-bar squat has no warm-up below the bar). Rounding can push
/// two neighbouring steps onto the same load — those collisions are dropped, so
/// a very light working weight yields fewer sets than asked rather than a ramp
/// that stalls or steps backward.
List<WarmupSet> computeWarmups({
  required double workingKg,
  double barKg = 0,
  int sets = kDefaultWarmupSets,
  double roundingKg = 2.5,
}) {
  if (sets <= 0 || workingKg <= 0) return const [];
  final bar = barKg < 0 ? 0.0 : barKg;
  final step = roundingKg <= 0 ? 2.5 : roundingKg;

  // The heaviest warm-up stays a rounding step below the work; the lightest
  // starts at the bar, or ~40% when there is no bar to stand on. If the work is
  // not clearly above that start, there is no room for a ramp.
  final ceiling = workingKg - step;
  final floor = bar > 0 ? bar : workingKg * 0.40;
  if (ceiling <= floor) return const [];

  const topFraction = 0.85;
  final top = workingKg * topFraction <= ceiling
      ? workingKg * topFraction
      : ceiling;

  double fractionAt(int i) {
    final lo = floor / workingKg;
    final hi = top / workingKg;
    if (sets == 1) return (lo + hi) / 2;
    return lo + (hi - lo) * i / (sets - 1);
  }

  double roundKg(double kg) => (kg / step).round() * step;

  final out = <WarmupSet>[];
  double? last;
  for (var i = 0; i < sets; i++) {
    final frac = fractionAt(i);
    var w = roundKg(workingKg * frac);
    // Never below the empty bar — the bar itself is a legitimate first warm-up,
    // even when it does not sit on the rounding grid (a 45 lb bar in kg).
    if (bar > 0 && w < bar) w = bar;
    if (w <= 0) continue;
    if (w >= workingKg - 1e-9) continue; // that is the working set, not a warm-up
    if (last != null && w <= last + 1e-9) continue; // rounding collision
    out.add((weightKg: w, reps: warmupReps(frac)));
    last = w;
  }
  return out;
}
