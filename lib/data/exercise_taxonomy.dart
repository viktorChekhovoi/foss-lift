/// The vocabulary an exercise is described with.
///
/// Two closed-ish lists that started life in the custom-exercise form and are
/// now also a wire format: a shared routine sends "muscle group #4" rather than
/// the word, which is most of the reason an ordinary routine still fits in a QR
/// code. Order is therefore **frozen** — appending is fine, reordering silently
/// re-labels every routine code already shared, and codes have been shared.
///
/// A value outside these lists is still legal everywhere. The library accepts
/// whatever an exercise carries, and a routine code falls back to spelling an
/// unknown word out in full.
library;

/// The muscle groups offered in the exercise form, in display order.
///
/// Seven, and no finer. A hip thrust is filed under Legs and a wrist curl under
/// Arms: the movements are all still in the library, but a group of its own for
/// each of them is a heading to scroll past on the way to the one you wanted.
/// `Other` is last because it is where the movements that answer to no single
/// group go, not because it is a group anyone picks first.
const List<String> kMuscleGroups = [
  'Chest',
  'Back',
  'Shoulders',
  'Legs',
  'Arms',
  'Core',
  'Other',
  // Not a muscle, and deliberately in the list anyway — as `Other` already is.
  // Conditioning work is what a sprint, a burpee or two minutes on a rope is
  // *for*, and filing it under the muscles it happens to use put it in the way
  // of somebody narrowing to Legs to pick a squat while leaving it findable by
  // nobody at all: there is no filter on how a set is measured. It is the last
  // entry because this list is a wire format — see the note above.
  'Cardio',
];

/// The equipment kinds offered in the exercise form, in display order.
const List<String> kEquipmentTypes = [
  'Barbell',
  'Dumbbell',
  'Machine',
  'Cable',
  'Bodyweight',
  'Other',
];

/// The group a movement done on a cardio console files under.
const String kCardioGroup = 'Cardio';

/// The equipment such a movement is described as.
const String kMachineEquipment = 'Machine';

/// Whether a movement classified this way is done on a console that reports
/// speed, incline, resistance and distance — a treadmill, a rower, a stair
/// climber.
///
/// **Derived, never stored.** Both halves already travel in a routine code as
/// indexes into the frozen lists above, so a treadmill shared with somebody
/// arrives as a treadmill without a flag of its own being added to the format —
/// and a movement built for the machine a particular gym has earns the readouts
/// by being classified, with nothing else to find and tick.
///
/// [leadGroup] is the group the movement files under ([MuscleMap.lead]), not any
/// group it merely touches: a jump squat assists Legs and is still conditioning
/// done on the floor. A burpee is Cardio and bodyweight, so it answers false —
/// there is no console to read.
bool cardioMachine(String leadGroup, String equipment) =>
    leadGroup == kCardioGroup && equipment == kMachineEquipment;

/// What separates group names inside one stored column.
///
/// A unit separator rather than a comma: a group name is usually one of
/// [kMuscleGroups], but a routine code may spell out a word this build has never
/// heard of, and there is nothing stopping that word containing a comma.
const String kGroupSeparator = '\u001f';

/// Which muscle groups a movement trains, and which it only assists.
///
/// One group was never the truth about a compound lift — it was the truth about
/// where to file it. So the two facts are kept apart: [primary] is what the
/// movement is for, [secondary] is what it works on the way. A bench press is
/// Chest and Arms, and it assists Shoulders.
///
/// [primary] is ordered and never empty, and its first entry is the [lead] — the
/// one group the library files the movement under, a history rollup counts it
/// under, and an FLR1 routine code carries. Everything else about the map is a
/// set: order within [secondary] is display order and nothing more.
class MuscleMap {
  /// Normalises on the way in, because the inputs are a chip row, a stored
  /// column and a decoded routine code, and none of the three can be trusted to
  /// have kept the invariants: blanks go, duplicates go (the first position
  /// wins), a group claimed as primary is not also secondary, and a map with no
  /// primary at all takes `Other` rather than being illegal to hold.
  factory MuscleMap({
    required List<String> primary,
    List<String> secondary = const [],
  }) {
    final first = _clean(primary);
    if (first.isEmpty) first.add('Other');
    return MuscleMap._(
      List.unmodifiable(first),
      List.unmodifiable(_clean(secondary)..removeWhere(first.contains)),
    );
  }

  /// The one-group map an exercise from before the update carries, and the one
  /// an FLR1 code means.
  factory MuscleMap.single(String group) => MuscleMap(primary: [group]);

  const MuscleMap._(this.primary, this.secondary);

  /// The groups the movement trains. Never empty; the first is the [lead].
  final List<String> primary;

  /// The groups it works without being for them. May be empty, and shares
  /// nothing with [primary].
  final List<String> secondary;

  /// Where the movement files — see the class comment.
  String get lead => primary.first;

  /// The primaries past the [lead]: what a storage column, a routine code and a
  /// migration each have to write separately from it.
  List<String> get extraPrimary => primary.sublist(1);

  /// Every group the movement has anything to do with, trained ones first.
  List<String> get all => [...primary, ...secondary];

  /// Whether [group] is one the movement is for.
  bool trains(String group) => primary.contains(group);

  /// Whether [group] is one the movement reaches at all.
  bool touches(String group) => trains(group) || secondary.contains(group);

  static List<String> _clean(List<String> groups) {
    final out = <String>[];
    for (final g in groups) {
      final t = g.replaceAll(kGroupSeparator, '').trim();
      if (t.isNotEmpty && !out.contains(t)) out.add(t);
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is MuscleMap &&
      _same(primary, other.primary) &&
      _same(secondary, other.secondary);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(primary),
    Object.hashAll(secondary),
  );

  @override
  String toString() => secondary.isEmpty
      ? 'MuscleMap(${primary.join(', ')})'
      : 'MuscleMap(${primary.join(', ')} + ${secondary.join(', ')})';

  static bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
