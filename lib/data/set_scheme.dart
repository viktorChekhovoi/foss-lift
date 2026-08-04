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

/// The four shapes a slot's sets can take.
enum SetScheme {
  /// Every set at the slot's weight and rep target. The default.
  flat,

  /// The first set at the slot's weight, each one after it a further
  /// [WorkoutItems.schemePercent] lighter.
  backOff,

  /// The same ladder climbed the other way: the *last* set is the slot's
  /// weight, and the ones before it are lighter.
  ramp,

  /// A row per set, each with its own rep count and its own percentage.
  custom;

  /// Whether this scheme needs the per-set rows to mean anything.
  bool get isCustom => this == SetScheme.custom;
}

/// One row of a [SetScheme.custom] prescription: what to aim for, and at what
/// fraction of the slot's weight.
class CustomSet {
  const CustomSet({required this.reps, required this.percent});

  final int reps;

  /// Of the slot's weight, as a whole percentage. 100 is the slot's weight.
  final int percent;

  @override
  bool operator ==(Object other) =>
      other is CustomSet && other.reps == reps && other.percent == percent;

  @override
  int get hashCode => Object.hash(reps, percent);

  @override
  String toString() => '$reps×$percent%';
}

/// What one set of a hydrated slot is aiming at.
class SetTarget {
  const SetTarget({required this.reps, this.weightKg});

  final int reps;

  /// In kilograms, already snapped and floored — or null for a movement that
  /// carries no load, which has nothing to take a percentage of.
  final double? weightKg;

  @override
  bool operator ==(Object other) =>
      other is SetTarget && other.reps == reps && other.weightKg == weightKg;

  @override
  int get hashCode => Object.hash(reps, weightKg);

  @override
  String toString() => '$reps @ ${weightKg ?? '—'}';
}

/// The custom rows as one column value: `reps:percent`, comma separated.
///
/// Text rather than a table of its own. These rows only ever mean anything to
/// the slot that owns them, are read and written whole, and are never queried —
/// which is the shape of a value, not of a relation.
String encodeCustomSets(List<CustomSet> sets) =>
    sets.map((s) => '${s.reps}:${s.percent}').join(',');

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
    final reps = int.tryParse(halves[0]);
    final percent = int.tryParse(halves[1]);
    if (reps == null || percent == null) return const [];
    out.add(CustomSet(reps: reps, percent: percent));
  }
  return out;
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
List<SetTarget> resolveSetTargets({
  required SetScheme scheme,
  required int sets,
  required int goalReps,
  required double? topWeightKg,
  required String unit,
  int percent = kDefaultSchemePercent,
  List<CustomSet> custom = const [],
  double floorKg = 0,
}) {
  final floor = _effectiveFloor(topWeightKg, floorKg);

  double? weightAt(int wholePercent) {
    final top = topWeightKg;
    if (top == null) return null;
    return _land(top * wholePercent / 100, unit, floor);
  }

  return [
    for (var i = 0; i < sets; i++)
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
        // rather than one that vanishes.
        SetScheme.custom => i < custom.length
            ? SetTarget(
                reps: custom[i].reps,
                weightKg: weightAt(_atLeastNothing(custom[i].percent)),
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

/// One weight put where every weight this file produces goes: on the step
/// [unit] counts by, and at or above [floor].
double _land(double raw, String unit, double floor) {
  final snapped = snapToUnitStep(raw, unit);
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
