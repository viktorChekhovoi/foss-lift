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

  /// Held in each hand: the number is *one* dumbbell, not the pair.
  dumbbell;

  String get label => switch (this) {
        WeightType.bar => 'Bar',
        WeightType.machine => 'Machine',
        WeightType.dumbbell => 'Dumbbell',
      };

  /// What the weight column means, said in one line for the picker.
  String get blurb => switch (this) {
        WeightType.bar => 'The whole bar, plates included. Foss Lift works out '
            'what goes on each side.',
        WeightType.machine => 'Whatever the machine reads. Nothing to work out.',
        WeightType.dumbbell => 'One dumbbell, not the pair.',
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

/// The bar and the plates as the user has them, resolved — see
/// [resolvePlateSettings]. Weights are canonical kilograms like everywhere
/// else; the editor converts at the view boundary.
typedef PlateSettings = ({double barKg, List<PlateStack> plates});

/// A standard Olympic bar, in kilograms.
const kDefaultBarKg = 20.0;

/// The same bar as a pounds gym describes it.
const kDefaultBarLb = 45.0;

/// How many of each plate size a gym is assumed to own until told otherwise.
/// Four — two pairs — is enough for the defaults to reach a real working
/// weight without pretending anybody owns ten pairs of 25s.
const kDefaultPlateCount = 4;

/// Two weights within this of each other are the same weight. Plate maths runs
/// on rounded grams, and a pound plate converts to kilograms with a tail on it,
/// so 225 lb has to come out exact rather than ten grams shy of it.
const kPlateToleranceKg = 0.01;

/// The most distinct per-side loads the search will hold at once. A guard
/// against a pathological inventory, not a limit anybody's gym will meet: the
/// standard set with four of everything reaches a few hundred combinations.
const kPlateSearchCap = 20000;

/// The plate sizes a gym stocking kilograms owns.
const _standardKg = <double>[25, 20, 15, 10, 5, 2.5, 1.25];

/// The same rack in pounds. Not a conversion of the list above — a pounds gym
/// owns 45s and 35s, not 55.1s and 44.1s.
const _standardLb = <double>[45, 35, 25, 10, 5, 2.5];

/// The bar to assume for someone who has never said, in kilograms.
double defaultBarKg(String unit) =>
    unit == 'lb' ? toKg(kDefaultBarLb, 'lb') : kDefaultBarKg;

/// The plate rack to assume for someone who has never said, in kilograms.
List<PlateStack> defaultPlatesFor(String unit) => [
      for (final w in unit == 'lb' ? _standardLb : _standardKg)
        (kg: toKg(w, unit), count: kDefaultPlateCount),
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
/// the user has never edited either.
///
/// Unit-derived rather than seeded once at install: a lifter who switches the
/// app to pounds and has never touched the plate screen means 45s and 25s, not
/// the metric rack converted into ugly decimals. The moment they edit anything,
/// the choice is stored and the unit stops deciding for them.
PlateSettings resolvePlateSettings({
  required String unit,
  String? inventory,
  double? barKg,
}) =>
    (
      barKg: barKg ?? defaultBarKg(unit),
      plates: decodePlates(inventory) ?? defaultPlatesFor(unit),
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

  // Grams, so the search runs on integers: a pound plate in kilograms is a
  // number with a tail, and floating-point sums of those do not compare equal
  // to anything.
  final kinds = [
    for (final p in sortedPlates(inventory))
      if (p.kg > 0 && p.count >= 2)
        (kg: p.kg, g: (p.kg * 1000).round(), pairs: p.count ~/ 2),
  ]..removeWhere((k) => k.g <= 0);
  if (kinds.isEmpty) return barOnly();

  final neededG = ((targetG - barG) / 2).round();
  // No point building a stack more than one plate past the target: drop that
  // plate and it is still at least as close.
  final limit = neededG + kinds.first.g;

  // Reachable per-side loads → how many of each kind make them. Keyed by the
  // load so the same weight reached two ways is stored once, keeping the
  // fewest-plates version.
  var reachable = <int, List<int>>{0: List.filled(kinds.length, 0)};
  for (var i = 0; i < kinds.length; i++) {
    final next = Map<int, List<int>>.from(reachable);
    for (final entry in reachable.entries) {
      for (var k = 1; k <= kinds[i].pairs; k++) {
        final sum = entry.key + k * kinds[i].g;
        if (sum > limit) break;
        final counts = [...entry.value];
        counts[i] = k;
        final held = next[sum];
        if (held == null || _betterStack(counts, held)) next[sum] = counts;
      }
    }
    reachable = next;
    if (reachable.length > kPlateSearchCap) break;
  }

  var bestSum = 0;
  var bestCounts = reachable[0]!;
  for (final entry in reachable.entries) {
    if (_closer(entry.key, entry.value, bestSum, bestCounts, neededG)) {
      bestSum = entry.key;
      bestCounts = entry.value;
    }
  }

  final plates = <PlateStack>[];
  var perSide = 0.0;
  for (var i = 0; i < kinds.length; i++) {
    if (bestCounts[i] == 0) continue;
    plates.add((kg: kinds[i].kg, count: bestCounts[i]));
    perSide += kinds[i].kg * bestCounts[i];
  }

  return PlateSolution(
    targetKg: targetKg,
    // From the plate weights themselves rather than the rounded grams, so a
    // stack that makes exactly 225 lb reads as 225 lb and not 224.998.
    achievedKg: bar + 2 * perSide,
    barKg: bar,
    plates: plates,
  );
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
