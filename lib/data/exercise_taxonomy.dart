/// Exercise taxonomy used by the editor and routine wire formats.
///
/// List order is part of the format: append values, but do not reorder or remove them. Unknown values remain valid and are encoded by name.
library;

/// Muscle groups offered by the exercise form, in wire-format order.
const List<String> kMuscleGroups = [
  'Chest',
  'Back',
  'Shoulders',
  'Legs',
  'Arms',
  'Core',
  'Other',
  // Cardio is a category rather than a muscle group, but remains in the frozen list for filtering and routine-code compatibility.
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

/// Whether a movement uses a cardio machine with tracked readouts.
bool cardioMachine(String leadGroup, String equipment) =>
    leadGroup == kCardioGroup && equipment == kMachineEquipment;

/// Separator for multiple group names in a stored column.
const String kGroupSeparator = '\u001f';

/// Muscle groups an exercise trains ([primary]) and assists ([secondary]); [primary] is non-empty and its first entry is [lead].
class MuscleMap {
  /// Normalises blanks, duplicates, and overlaps; an empty primary list uses `Other`.
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

  /// Creates a one-group map for legacy exercises and FLR1 codes.
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
