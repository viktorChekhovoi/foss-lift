import 'database.dart';

/// What is being asked of the exercise library: some text, and any number of
/// equipment kinds and muscle groups.
///
/// One value, shared by the library screen and the workout builder's picker, so
/// "a barbell movement for legs" is the same question in both places and the
/// answer cannot drift between them. Search alone was never enough for that
/// question — it means knowing the movement's name before you can find it,
/// which is most of what a library is for.
///
/// **Within a dimension the chosen values are alternatives; across dimensions
/// they narrow.** Arms *and* glutes is one session's worth of browsing rather
/// than two searches, while barbell *and* legs is the pair of facts that finds
/// a squat. An empty set is not a filter that matches nothing — it is one
/// nobody has touched, and it excludes nothing.
class ExerciseFilter {
  const ExerciseFilter({
    this.query = '',
    this.equipment = const {},
    this.muscles = const {},
  });

  /// Free text, matched against the name, the muscle group and the equipment.
  final String query;

  /// The equipment kinds to keep — see [kEquipmentTypes]. Empty means all.
  final Set<String> equipment;

  /// The muscle groups to keep — see [kMuscleGroups]. Empty means all.
  final Set<String> muscles;

  /// Whether this asks anything at all.
  bool get isEmpty =>
      query.trim().isEmpty && equipment.isEmpty && muscles.isEmpty;

  /// How many chips are lit — what a "clear" control has to offer to undo.
  int get facetCount => equipment.length + muscles.length;

  ExerciseFilter withQuery(String value) => ExerciseFilter(
        query: value,
        equipment: equipment,
        muscles: muscles,
      );

  ExerciseFilter toggleEquipment(String kind) => ExerciseFilter(
        query: query,
        equipment: _toggled(equipment, kind),
        muscles: muscles,
      );

  ExerciseFilter toggleMuscle(String group) => ExerciseFilter(
        query: query,
        equipment: equipment,
        muscles: _toggled(muscles, group),
      );

  /// The same search with every chip let go. The text stays: clearing the chips
  /// is undoing the chips.
  ExerciseFilter get withoutFacets => ExerciseFilter(query: query);

  static Set<String> _toggled(Set<String> from, String value) {
    final next = {...from};
    if (!next.remove(value)) next.add(value);
    return next;
  }

  bool matches(Exercise e) {
    if (equipment.isNotEmpty && !equipment.contains(e.equipment)) return false;
    if (muscles.isNotEmpty && !muscles.contains(e.muscleGroup)) return false;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return e.name.toLowerCase().contains(q) ||
        e.muscleGroup.toLowerCase().contains(q) ||
        e.equipment.toLowerCase().contains(q);
  }

  List<Exercise> apply(Iterable<Exercise> all) =>
      [for (final e in all) if (matches(e)) e];
}
