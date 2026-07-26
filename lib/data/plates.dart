/// What a weight is actually made of: how an exercise is loaded, and — for a
/// barbell — which plates go on each side of it.
///
/// Free of drift and Flutter like the other rule modules. The arithmetic is
/// small but fiddly (halves, pairs, an inventory that runs out), and it is the
/// kind of thing you want to be able to read on its own.
library;

import '../util/units.dart';

/// How the load on an exercise is arranged, and therefore what the number in
/// the weight column *means*.
///
/// A property of the movement, not of the programme — the same way
/// [ExerciseMeasure] is. Bench Press is loaded on a bar wherever it appears.
enum WeightType {
  /// Loaded on a bar: the number is the bar plus everything on it, and it can
  /// be resolved into a per-side stack of plates.
  bar,

  /// Whatever the machine reads — a stack pin, a selectorised weight, a plate
  /// hung off one arm. The number is the number and there is nothing to work
  /// out.
  machine,

  /// A dumbbell: the number is the one in your hand. Whether the movement uses
  /// one of them or two is the exercise's business, not the weight's — a
  /// one-arm row and a pair of curls both log what is on the dumbbell.
  dumbbell;

  String get label => switch (this) {
        WeightType.bar => 'Bar',
        WeightType.machine => 'Machine',
        WeightType.dumbbell => 'Dumbbell',
      };

  /// Whether a weight of this type breaks down into a per-side plate load.
  bool get loadedPerSide => this == WeightType.bar;
}

/// The weight type an exercise should start on, given its equipment.
///
/// Only a starting point: the user can change it afterwards, and needs to for
/// the awkward cases (an EZ-bar with its own weight, a Smith machine, a trap
/// bar). Everything that is not obviously a bar or a pair of dumbbells is a
/// machine — including bodyweight, where there is no bar to break down either.
WeightType weightTypeForEquipment(String equipment) =>
    switch (equipment.toLowerCase()) {
      'barbell' => WeightType.bar,
      'dumbbell' => WeightType.dumbbell,
      _ => WeightType.machine,
    };

/// So many plates of one size. Used both for the inventory ("I own four 20s")
/// and for a solved stack ("two 20s go on each side").
typedef PlateStack = ({double kg, int count});

/// A load the gym can actually be set to, and what it costs to set up: plates
/// per side on a bar, and zero for a dumbbell or a stack, where you pick a
/// number off the rack and there is nothing to load.
///
/// A ladder of these is what stops a suggested weight being arithmetic nobody
/// can build — see [loadLadder] and the warm-up ramp that consumes it.
typedef LoadRung = ({double kg, int cost});

/// The bar and the plates as the user has them, resolved — see
/// [resolvePlateSettings]. Weights are canonical kilograms like everywhere
/// else; the editor converts at the view boundary.
typedef PlateSettings = ({double barKg, List<PlateStack> plates});

/// A standard Olympic bar, in kilograms.
const kDefaultBarKg = 20.0;

/// The same bar as a pounds gym describes it.
const kDefaultBarLb = 45.0;

/// How many of a plate size a gym is assumed to own until told otherwise, and
/// how many are added when you put a new size on the rack.
///
/// Two — one pair — because that is the smallest amount of a plate that is any
/// use, and claiming more of the odd sizes than a gym has is how you get a
/// breakdown asking for four 35s.
const kDefaultPlateCount = 2;

/// How many of the *workhorse* plate a gym is assumed to own: the 45s in a
/// pounds gym, the 20s in a metric one. Everything heavy is built out of these
/// and every rack has a pile of them, so five pairs is the realistic default
/// where one pair is right for the rest.
const kDefaultBigPlateCount = 10;

/// The increment a gym buys dumbbells in, named in the unit it counts by: a
/// pounds gym's rack climbs in 5s, a metric one's in 2.5s.
///
/// Matches how commercial racks are actually sold — hex sets run 2.5–30 kg in
/// 2.5 kg steps, and their pounds equivalents go up in 2.5s to 30 lb and 5s
/// above that. The light end of a rack is therefore finer than this, and above
/// 30 kg some racks are coarser; one step is the honest compromise, because
/// suggesting a bell nobody stocks is worse than suggesting the one beside it.
const kDumbbellStepLb = 5.0;
const kDumbbellStepKg = 2.5;

/// The increment a machine's stack moves in — five of whatever the gym counts
/// in.
///
/// The *finest* common increment rather than the typical one: selectorised
/// stacks are built from 5, 10, 15 or 20 lb plates depending on the machine, and
/// there is no way to know which from here. A suggestion on a 5 grid is always
/// within one pin of something the machine can do.
const kStackStepLb = 5.0;
const kStackStepKg = 5.0;

/// Two weights within this of each other are the same weight. Plate maths runs
/// on rounded grams, and a pound plate converts to kilograms with a tail on it,
/// so 225 lb has to come out exact rather than ten grams shy of it.
const kPlateToleranceKg = 0.01;

/// The most distinct per-side loads the search will hold at once. A guard
/// against a pathological inventory, not a limit anybody's gym will meet: the
/// standard rack reaches a few hundred combinations.
const kPlateSearchCap = 20000;

/// One entry of a standard rack, in the unit it is named in rather than in
/// kilograms — a pounds gym owns 45s, not 20.41s.
typedef _Stock = ({double size, int count});

/// The rack a gym stocking kilograms owns: a pair of everything and a pile of
/// 20s, heaviest first.
const _standardKg = <_Stock>[
  (size: 25, count: kDefaultPlateCount),
  (size: 20, count: kDefaultBigPlateCount),
  (size: 15, count: kDefaultPlateCount),
  (size: 10, count: kDefaultPlateCount),
  (size: 5, count: kDefaultPlateCount),
  (size: 2.5, count: kDefaultPlateCount),
  (size: 1.25, count: kDefaultPlateCount),
];

/// The same rack in pounds. Not a conversion of the list above — a pounds gym
/// owns 45s and 35s, not 55.1s and 44.1s, and it owns a lot of the 45s.
const _standardLb = <_Stock>[
  (size: 45, count: kDefaultBigPlateCount),
  (size: 35, count: kDefaultPlateCount),
  (size: 25, count: kDefaultPlateCount),
  (size: 10, count: kDefaultPlateCount),
  (size: 5, count: kDefaultPlateCount),
  (size: 2.5, count: kDefaultPlateCount),
];

/// The bar to assume for someone who has never said, in kilograms.
double defaultBarKg(String unit) =>
    unit == 'lb' ? toKg(kDefaultBarLb, 'lb') : kDefaultBarKg;

/// The plate rack to assume for someone who has never said, in kilograms.
List<PlateStack> defaultPlatesFor(String unit) => [
      for (final p in unit == 'lb' ? _standardLb : _standardKg)
        (kg: toKg(p.size, unit), count: p.count),
    ];

/// A plate or bar weight for display: up to two decimals, no trailing zeros.
///
/// `fmtWeight` rounds to one decimal, which is right for a logged set and wrong
/// here — a 1.25 kg plate that reads "1.3" is a plate nobody can find on the
/// rack, and a stack of them adds up to a number that does not match the bar.
String fmtPlateWeight(double kg) =>
    kg.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

/// The stored plate setup as a string for the settings row.
String encodePlates(List<PlateStack> plates) =>
    plates.map((p) => '${p.kg}x${p.count}').join(';');

/// The inverse of [encodePlates]. Null in, null out — "never configured", which
/// is what makes the defaults follow the chosen unit.
///
/// Deliberately forgiving: a malformed entry is dropped rather than throwing.
/// A plate inventory is not worth crashing a workout tracker over, and the
/// worst case of dropping one is a breakdown that offers fewer plates than the
/// gym has.
List<PlateStack>? decodePlates(String? raw) {
  if (raw == null) return null;
  final out = <PlateStack>[];
  for (final part in raw.split(';')) {
    if (part.trim().isEmpty) continue;
    final bits = part.split('x');
    if (bits.length != 2) continue;
    final kg = double.tryParse(bits[0].trim());
    final count = int.tryParse(bits[1].trim());
    if (kg == null || count == null || kg <= 0 || count <= 0) continue;
    out.add((kg: kg, count: count));
  }
  return sortedPlates(out);
}

/// Heaviest first, which is the order they go on the bar and the order the
/// editor lists them in.
List<PlateStack> sortedPlates(List<PlateStack> plates) =>
    [...plates]..sort((a, b) => b.kg.compareTo(a.kg));

/// The bar and plates to use, falling back to the standard set for [unit] when
/// the user has never edited it.
///
/// **The rack is kept per unit** — [kgRack] and [lbRack] are separate — because
/// a rack is a set of *sizes*, not a set of weights. Adding a 30 kg plate to a
/// metric rack and then reading it in pounds gives 66.14, a plate nobody owns
/// and nobody can find; a pounds gym stocks 45s. So each unit remembers its own
/// rack and the standard one stands in until it is edited, rather than one rack
/// being converted into decimals the other unit cannot use.
///
/// (The values inside a rack are still canonical kilograms like every other
/// weight in the app. It is which rack you are looking at that follows the
/// unit, not what the numbers mean.)
PlateSettings resolvePlateSettings({
  required String unit,
  String? kgRack,
  String? lbRack,
  double? barKg,
}) =>
    (
      barKg: barKg ?? defaultBarKg(unit),
      plates: decodePlates(unit == 'lb' ? lbRack : kgRack) ??
          defaultPlatesFor(unit),
    );

/// What to load on a bar to reach a weight — or the closest the plates in the
/// gym can get to it.
class PlateSolution {
  const PlateSolution({
    required this.targetKg,
    required this.achievedKg,
    required this.barKg,
    required this.plates,
  });

  /// The weight that was asked for, in kg.
  final double targetKg;

  /// The weight the bar will actually come to once loaded, in kg. Equal to
  /// [targetKg] whenever the plates allow it.
  final double achievedKg;

  /// The bar's own weight, in kg.
  final double barKg;

  /// What goes on *one* side, heaviest first. Empty means the bar alone.
  final List<PlateStack> plates;

  /// The load on each side of the bar, in kg.
  double get perSideKg => (achievedKg - barKg) / 2;

  /// Whether the gym can make the weight that was asked for. False is not an
  /// error — it is the answer, and [achievedKg] is the nearest thing to it.
  bool get exact => (achievedKg - targetKg).abs() <= kPlateToleranceKg;

  /// The target is lighter than the empty bar: a distinct case from "we could
  /// not quite make it", and one only the user can resolve.
  bool get belowBar => targetKg < barKg - kPlateToleranceKg;
}

/// Which plates make [targetKg] on a [barKg] bar, given the plates in
/// [inventory].
///
/// Plates go on in pairs, so an odd plate in the inventory is stock the bar
/// cannot use and is ignored. The search is exhaustive rather than greedy:
/// greedy is only correct when every plate divides the next one up, which a
/// real rack (45/35/25 in pounds, a lone 1.25 in kilograms) does not do. When
/// nothing reaches the target exactly the nearest achievable load is returned
/// — preferring the lighter of two equally-close options, and the smaller
/// number of plates between two equal loads, because carrying four 1.25s to
/// make what two 2.5s would is nobody's idea of help.
PlateSolution solvePlates({
  required double targetKg,
  required double barKg,
  required List<PlateStack> inventory,
}) {
  final bar = barKg < 0 ? 0.0 : barKg;
  PlateSolution barOnly() => PlateSolution(
        targetKg: targetKg,
        achievedKg: bar,
        barKg: bar,
        plates: const [],
      );

  final targetG = (targetKg * 1000).round();
  final barG = (bar * 1000).round();
  if (targetG <= barG) return barOnly();

  final kinds = _pairKinds(inventory);
  if (kinds.isEmpty) return barOnly();

  final neededG = ((targetG - barG) / 2).round();
  // No point building a stack more than one plate past the target: drop that
  // plate and it is still at least as close.
  final reachable = _reachablePerSide(kinds, neededG + kinds.first.g);

  var bestSum = 0;
  var bestCounts = reachable[0]!;
  for (final entry in reachable.entries) {
    if (_closer(entry.key, entry.value, bestSum, bestCounts, neededG)) {
      bestSum = entry.key;
      bestCounts = entry.value;
    }
  }

  final best = _stack(kinds, bestCounts);
  return PlateSolution(
    targetKg: targetKg,
    achievedKg: bar + 2 * best.perSideKg,
    barKg: bar,
    plates: best.plates,
  );
}

/// Every load a [barKg] bar can be built to with [inventory], up to [maxKg] —
/// ascending, each paired with the plates per side it costs.
///
/// The empty bar is always the first rung: it is a load like any other, and it
/// is the one a warm-up starts on. Where two stacks make the same weight only
/// the better one is kept (see [_betterStack]), so a rung's cost is the fewest
/// plates it will ever need.
List<LoadRung> barLoadLadder({
  required double barKg,
  required List<PlateStack> inventory,
  required double maxKg,
}) {
  final bar = barKg < 0 ? 0.0 : barKg;
  final ladder = <LoadRung>[(kg: bar, cost: 0)];
  final kinds = _pairKinds(inventory);
  final limitG = ((maxKg - bar) / 2 * 1000).round();
  if (kinds.isEmpty || limitG <= 0) return ladder;

  for (final entry in _reachablePerSide(kinds, limitG).entries) {
    if (entry.key == 0) continue; // the empty bar, already the first rung
    final s = _stack(kinds, entry.value);
    ladder.add((kg: bar + 2 * s.perSideKg, cost: _plates(entry.value)));
  }
  return ladder..sort((a, b) => a.kg.compareTo(b.kg));
}

/// Loads on a fixed [stepKg] grid up to [maxKg], ascending — a rack of
/// dumbbells or a machine's stack, where the gym chose the increments and no
/// two settings cost anything different to reach.
List<LoadRung> gridLoadLadder({
  required double stepKg,
  required double maxKg,
}) {
  if (stepKg <= 0 || maxKg < stepKg) return const [];
  final rungs = ((maxKg + kPlateToleranceKg) / stepKg).floor();
  // Multiplied out rather than accumulated, so the hundredth rung of a
  // pound-derived grid is still exactly a hundred of them.
  return [for (var i = 1; i <= rungs; i++) (kg: stepKg * i, cost: 0)];
}

/// The loads an exercise of [type] can actually be set to at this gym, up to
/// [maxKg]: what a suggested weight — a warm-up rung — has to land on.
///
/// [barKg] and [inventory] are only read for a bar. Everything else comes off a
/// rack in whole increments of whatever the gym counts in, so [unit] decides
/// them: [kDumbbellStepLb] and [kStackStepLb] in a pounds gym, their metric
/// counterparts otherwise.
List<LoadRung> loadLadder({
  required WeightType type,
  required String unit,
  required double maxKg,
  double barKg = 0,
  List<PlateStack> inventory = const [],
}) =>
    switch (type) {
      WeightType.bar =>
        barLoadLadder(barKg: barKg, inventory: inventory, maxKg: maxKg),
      WeightType.dumbbell => gridLoadLadder(
          stepKg: unit == 'lb' ? toKg(kDumbbellStepLb, 'lb') : kDumbbellStepKg,
          maxKg: maxKg,
        ),
      WeightType.machine => gridLoadLadder(
          stepKg: unit == 'lb' ? toKg(kStackStepLb, 'lb') : kStackStepKg,
          maxKg: maxKg,
        ),
    };

/// The inventory as the search wants it: pairs only — an odd plate is stock the
/// bar cannot use — heaviest first, and in whole grams.
///
/// Grams so the search runs on integers: a pound plate in kilograms is a number
/// with a tail, and floating-point sums of those do not compare equal to
/// anything.
List<_Kind> _pairKinds(List<PlateStack> inventory) => [
      for (final p in sortedPlates(inventory))
        if (p.kg > 0 && p.count >= 2)
          (kg: p.kg, g: (p.kg * 1000).round(), pairs: p.count ~/ 2),
    ]..removeWhere((k) => k.g <= 0);

/// One plate size the search may draw on: its weight, the same in grams, and
/// how many pairs of it the gym owns.
typedef _Kind = ({double kg, int g, int pairs});

/// Per-side loads in grams → how many of each kind makes them, for every load
/// up to [limitG]. Keyed by the load, so the same weight reached two ways is
/// stored once — the [_betterStack] way.
Map<int, List<int>> _reachablePerSide(List<_Kind> kinds, int limitG) {
  var reachable = <int, List<int>>{0: List.filled(kinds.length, 0)};
  for (var i = 0; i < kinds.length; i++) {
    final next = Map<int, List<int>>.from(reachable);
    for (final entry in reachable.entries) {
      for (var k = 1; k <= kinds[i].pairs; k++) {
        final sum = entry.key + k * kinds[i].g;
        if (sum > limitG) break;
        final counts = [...entry.value];
        counts[i] = k;
        final held = next[sum];
        if (held == null || _betterStack(counts, held)) next[sum] = counts;
      }
    }
    reachable = next;
    if (reachable.length > kPlateSearchCap) break;
  }
  return reachable;
}

/// The stack [counts] describes: what goes on one side, heaviest first, and
/// what it weighs.
///
/// Summed from the plate weights themselves rather than the rounded grams, so a
/// stack that makes exactly 225 lb reads as 225 lb and not 224.998.
({List<PlateStack> plates, double perSideKg}) _stack(
  List<_Kind> kinds,
  List<int> counts,
) {
  final plates = <PlateStack>[];
  var perSideKg = 0.0;
  for (var i = 0; i < kinds.length; i++) {
    if (counts[i] == 0) continue;
    plates.add((kg: kinds[i].kg, count: counts[i]));
    perSideKg += kinds[i].kg * counts[i];
  }
  return (plates: plates, perSideKg: perSideKg);
}

int _plates(List<int> counts) => counts.fold(0, (a, b) => a + b);

/// Whether one way of making a load beats another: fewer plates first, then the
/// heavier ones ([counts] runs heaviest to lightest).
///
/// The second half is what makes 40 kg a side read as 25 + 15 rather than
/// 20 + 20 — the order a lifter loads a bar in, and the order they would think
/// of it. It only ever chooses between stacks that weigh exactly the same.
bool _betterStack(List<int> counts, List<int> other) {
  final n = _plates(counts);
  final m = _plates(other);
  if (n != m) return n < m;
  for (var i = 0; i < counts.length; i++) {
    if (counts[i] != other[i]) return counts[i] > other[i];
  }
  return false;
}

/// Whether the candidate load beats the incumbent: closer to the target first,
/// then lighter — err under the weight you asked for rather than over it —
/// and only then on how the stack is made up.
bool _closer(
  int sum,
  List<int> counts,
  int bestSum,
  List<int> bestCounts,
  int neededG,
) {
  final d = (sum - neededG).abs();
  final best = (bestSum - neededG).abs();
  if (d != best) return d < best;
  if (sum != bestSum) return sum < bestSum;
  return _betterStack(counts, bestCounts);
}
