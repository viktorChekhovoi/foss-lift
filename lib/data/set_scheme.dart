/// How the sets of one slot differ from one another.
///
/// A slot has a weight, a rep target and a set count, and for most of the app's
/// history every set it produced was a copy of the other two. That is still the
/// default and still what most programs want. This is the exception: the ladders
/// people write down as "3 × 8, drop 10% a set", and the fully written-out
/// prescriptions that are not a ladder at all.
///
/// **One number is still the target.** Every scheme is expressed as a percentage
/// of the slot's own weight, never as a second stored weight, so progression
/// keeps moving exactly one number and the whole ladder moves with it. That is
/// also what lets a scheme survive a unit switch and a share code: a shape
/// travels, and the numbers are computed on arrival.
library;

import '../util/units.dart';

/// The percentage a step of a back-off or a ramp moves by, until somebody says
/// otherwise. Ten percent is what the phrase "back-off sets" usually means.
const int kDefaultSchemePercent = 10;

/// The five shapes a slot's sets can take.
enum SetScheme {
  /// Every set at the slot's weight and rep target. The default.
  flat,

  /// The first set at the slot's weight, each one after it a further
  /// [WorkoutItems.schemePercent] lighter.
  backOff,

  /// The same ladder climbed the other way: the *last* set is the slot's
  /// weight, and the ones before it are lighter.
  ramp,

  /// A row per set, each with its own rep target and its own percentage.
  custom,

  /// Several sets of those rows — a week each — taken one per session. See
  /// [encodeCycleBlocks].
  ///
  /// **Declared last.** The name is what the column stores, so a value may be
  /// added but none may be renamed, dropped or reordered.
  cycle;

  /// Whether this scheme needs the per-set rows to mean anything.
  bool get isCustom => this == SetScheme.custom;

  /// Whether this scheme is written out a set at a time — the two that are.
  ///
  /// What the builder asks when deciding whether to draw rows at all, and what
  /// [resolveSetTargets] asks when deciding where the rows come from.
  bool get isWrittenOut => this == SetScheme.custom || this == SetScheme.cycle;

}

/// One row of a written-out prescription: what to aim for, and at what fraction
/// of the slot's weight.
///
/// The rep target is one of three things, and which it is decides what the set
/// is judged against: a plain count ([reps] alone), a range ([repsMax] as
/// well), or a minimum with no top at all ([amrap]) — the "5+" set 5/3/1 is
/// named after. [goalReps] and [minReps] are how the rest of the app asks,
/// rather than re-deriving the three cases at each reader.
class CustomSet {
  const CustomSet({
    required this.reps,
    required this.percent,
    this.repsMax,
    this.amrap = false,
  });

  /// The bottom of the row: a count, the bottom of a range, or the minimum an
  /// open-ended set has to beat.
  final int reps;

  /// The top of a range, or null for a row that has no top — either because it
  /// is a plain count or because it is [amrap].
  final int? repsMax;

  /// Whether the row has no ceiling: do at least [reps] and keep going.
  ///
  /// Exclusive with [repsMax] by construction — "8–12 or more" asks two
  /// questions — and the constructor is not where that is enforced, because a
  /// row decoded from a column somebody hand-edited still has to read as
  /// *something*. [goalReps] resolves the pair, openness first.
  final bool amrap;

  /// Of the slot's weight, as a whole percentage. 100 is the slot's weight.
  final int percent;

  /// What the row asks for — the number the board opens on and the first tap
  /// claims. The top of a range; the minimum of an open-ended row, which is
  /// the only number it names.
  int get goalReps => amrap ? reps : (repsMax ?? reps);

  /// The number below which the set is a miss. Always the bottom: a range is
  /// met anywhere inside itself, and a plain count is its own floor.
  int get minReps => reps;

  @override
  bool operator ==(Object other) =>
      other is CustomSet &&
      other.reps == reps &&
      other.repsMax == repsMax &&
      other.amrap == amrap &&
      other.percent == percent;

  @override
  int get hashCode => Object.hash(reps, repsMax, amrap, percent);

  @override
  String toString() =>
      '${amrap ? '$reps+' : (repsMax == null ? '$reps' : '$reps-$repsMax')}'
      '×$percent%';
}

/// What one set of a hydrated slot is aiming at.
class SetTarget {
  const SetTarget({
    required this.reps,
    this.weightKg,
    int? minReps,
    this.amrap = false,
  }) : minReps = minReps ?? reps;

  /// The goal — see [CustomSet.goalReps].
  final int reps;

  /// The number below which this set is a miss. [reps] unless the row it came
  /// from was a range, where anywhere inside the range counts.
  final int minReps;

  /// Whether the set has no ceiling — carried so the board can say so.
  final bool amrap;

  /// In kilograms, already snapped and floored — or null for a movement that
  /// carries no load, which has nothing to take a percentage of.
  final double? weightKg;

  @override
  bool operator ==(Object other) =>
      other is SetTarget &&
      other.reps == reps &&
      other.minReps == minReps &&
      other.amrap == amrap &&
      other.weightKg == weightKg;

  @override
  int get hashCode => Object.hash(reps, minReps, amrap, weightKg);

  @override
  String toString() => '$reps @ ${weightKg ?? '—'}';
}

/// The custom rows as one column value: `reps:percent`, comma separated.
///
/// Text rather than a table of its own. These rows only ever mean anything to
/// the slot that owns them, are read and written whole, and are never queried —
/// which is the shape of a value, not of a relation.
///
/// **The grammar grew, and the old shape is still in it.** A row's rep half is
/// `5`, `8-12` or `5+`; a plain count is written exactly as it always was, so
/// every column already on a phone reads unchanged and a slot nobody has given
/// a range to writes the same bytes it used to.
String encodeCustomSets(List<CustomSet> sets) =>
    sets.map((s) => '${_encodeReps(s)}:${s.percent}').join(',');

String _encodeReps(CustomSet s) {
  if (s.amrap) return '${s.reps}+';
  final top = s.repsMax;
  return top == null ? '${s.reps}' : '${s.reps}-$top';
}

/// The inverse, forgiving of anything that is not it.
///
/// A column that will not parse is read as no scheme rather than as an error:
/// the worst case is a slot that trains flat, which is a slot, and the
/// alternative is a workout that will not open.
List<CustomSet> decodeCustomSets(String? encoded) {
  if (encoded == null || encoded.isEmpty) return const [];
  final out = <CustomSet>[];
  for (final part in encoded.split(',')) {
    final halves = part.split(':');
    if (halves.length != 2) return const [];
    final percent = int.tryParse(halves[1]);
    final row = _decodeReps(halves[0]);
    if (percent == null || row == null) return const [];
    out.add(CustomSet(
      reps: row.reps,
      repsMax: row.repsMax,
      amrap: row.amrap,
      percent: percent,
    ));
  }
  return out;
}

/// The rep half of a row: `5`, `8-12` or `5+`. Null for anything that is none
/// of the three.
({int reps, int? repsMax, bool amrap})? _decodeReps(String text) {
  if (text.endsWith('+')) {
    final reps = int.tryParse(text.substring(0, text.length - 1));
    return reps == null ? null : (reps: reps, repsMax: null, amrap: true);
  }
  final dash = text.indexOf('-');
  if (dash >= 0) {
    final reps = int.tryParse(text.substring(0, dash));
    final top = int.tryParse(text.substring(dash + 1));
    if (reps == null || top == null) return null;
    return (reps: reps, repsMax: top, amrap: false);
  }
  final reps = int.tryParse(text);
  return reps == null ? null : (reps: reps, repsMax: null, amrap: false);
}

/// What separates one week of a cycle from the next in the column.
///
/// A character the row grammar cannot produce, so the two levels can share one
/// value without either having to escape the other.
const String kCycleBlockSeparator = '|';

/// A cycle's weeks as one column value: [encodeCustomSets] per week, joined.
///
/// Null for a cycle with nothing in it, so "no cycle" is one value in the
/// database rather than two — the same rule `encodeSparedRates` follows.
String? encodeCycleBlocks(List<List<CustomSet>> blocks) => blocks.isEmpty
    ? null
    : blocks.map(encodeCustomSets).join(kCycleBlockSeparator);

/// The inverse, forgiving on the same terms: a week that will not parse comes
/// back empty rather than taking the cycle with it, because a slot that trains
/// one week flat is still a slot.
List<List<CustomSet>> decodeCycleBlocks(String? encoded) {
  if (encoded == null || encoded.isEmpty) return const [];
  return [
    for (final block in encoded.split(kCycleBlockSeparator))
      decodeCustomSets(block),
  ];
}

/// The week [position] names, wrapping — the week after the last is the first.
///
/// Also the answer to a position left past the end by an edit that shortened
/// the cycle: it lands back inside rather than throwing, so trimming a cycle in
/// the builder cannot leave a slot pointing at a week that is gone.
List<CustomSet> cycleBlockAt(List<List<CustomSet>> blocks, int position) {
  if (blocks.isEmpty) return const [];
  final i = position % blocks.length;
  return blocks[i < 0 ? i + blocks.length : i];
}

/// What each of [sets] sets is aiming at, in order.
///
/// [topWeightKg] is the slot's own suggested weight — the top of every ladder,
/// and null on a movement that carries none. [goalReps] is the slot's rep
/// target, which every scheme but [SetScheme.custom] repeats unchanged.
///
/// Two rules apply to every weight this produces, and they are the two a
/// converted target obeys: it is snapped to the step [unit] counts by, because
/// 90% of 102.5 kg is 92.25 and nobody sets that bar; and it is held at
/// [floorKg], because a set under the empty bar is not a lighter set.
/// A cycle takes its rows from the week [cyclePosition] names rather than from
/// [custom], and its set count from that week rather than from [sets] — a week
/// is written out in full, so how many rows it has *is* how many sets there
/// are. A cycle with no weeks in it falls back to [sets] flat sets, which is
/// what a scheme nobody has filled in should train as.
List<SetTarget> resolveSetTargets({
  required SetScheme scheme,
  required int sets,
  required int goalReps,
  required double? topWeightKg,
  required String unit,
  int percent = kDefaultSchemePercent,
  List<CustomSet> custom = const [],
  List<List<CustomSet>> cycle = const [],
  int cyclePosition = 0,
  double floorKg = 0,
}) {
  final floor = _effectiveFloor(topWeightKg, floorKg);
  final rows = scheme == SetScheme.cycle
      ? cycleBlockAt(cycle, cyclePosition)
      : custom;
  final count = scheme == SetScheme.cycle && rows.isNotEmpty ? rows.length : sets;

  double? weightAt(int wholePercent) {
    final top = topWeightKg;
    if (top == null) return null;
    return _land(top * wholePercent / 100, unit, floor);
  }

  return [
    for (var i = 0; i < count; i++)
      switch (scheme) {
        SetScheme.flat => SetTarget(reps: goalReps, weightKg: weightAt(100)),
        SetScheme.backOff => SetTarget(
            reps: goalReps,
            // Clamped at nothing rather than allowed to go negative: a long
            // slot at a steep percentage runs off the bottom of the ladder, and
            // below zero is not lighter, it is nonsense. The floor above is
            // what it actually lands on.
            weightKg: weightAt(_atLeastNothing(100 - i * percent)),
          ),
        SetScheme.ramp => SetTarget(
            reps: goalReps,
            weightKg: weightAt(_atLeastNothing(100 - (sets - 1 - i) * percent)),
          ),
        // The set count and the rows are edited separately, so they can
        // disagree for a tap or two. A row that is not there yet is the slot's
        // own target at its own weight — a set that reads as unconfigured
        // rather than one that vanishes. A cycle cannot be in that state, since
        // its count comes from its rows, but it reads through the same branch.
        SetScheme.custom || SetScheme.cycle => i < rows.length
            ? SetTarget(
                reps: rows[i].goalReps,
                minReps: rows[i].minReps,
                amrap: rows[i].amrap,
                weightKg: weightAt(_atLeastNothing(rows[i].percent)),
              )
            : SetTarget(reps: goalReps, weightKg: weightAt(100)),
      },
  ];
}

int _atLeastNothing(int percent) => percent < 0 ? 0 : percent;

/// The floor a ladder off [topWeightKg] actually gets.
///
/// The floor is there to stop a *percentage* landing under the bar. It is not a
/// veto on the top weight: dropping a barbell lift to nothing mid-session is how
/// the app says "bodyweight today", and a ladder off that must not be silently
/// loaded back up to an empty bar.
double _effectiveFloor(double? topWeightKg, double floorKg) =>
    (topWeightKg ?? 0) >= floorKg ? floorKg : 0.0;

/// One weight put where every weight this file produces goes: on [unit]'s fine
/// grid, and at or above [floor].
///
/// The grid is fine rather than the step a gym counts by, because a percentage
/// is an instruction and not a suggestion: 65% of a 75 kg training max is 48.75,
/// and a coarse snap would move that set to 50 while the row above still said
/// 65%. It stays a snap rather than nothing at all so a conversion cannot leave
/// a six-decimal tail on a set row.
double _land(double raw, String unit, double floor) {
  final snapped = snapToFineGrid(raw, unit);
  return snapped < floor ? floor : snapped;
}

/// The top of the ladder itself, put on the same grid as the rungs below it.
///
/// The weight an exercise is worked at and the weights of its sets have to
/// describe one bar: a header reading 101 kg over rows reading 100 is two
/// answers to the same question. So the working weight goes through this and
/// the set weights through [resolveSetTargets], and both apply the same two
/// rules — because this *is* what [resolveSetTargets] computes for a set at
/// 100% of the slot's weight.
///
/// Null in, null out: a movement carrying no load has no top to land.
double? resolveTopWeight({
  required double? topWeightKg,
  required String unit,
  double floorKg = 0,
}) {
  final top = topWeightKg;
  if (top == null) return null;
  return _land(top, unit, _effectiveFloor(top, floorKg));
}
