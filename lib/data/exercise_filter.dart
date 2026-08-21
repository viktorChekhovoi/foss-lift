import 'database.dart';

/// Display words used when filtering an exercise.
typedef ExerciseWords = ({
  String name,
  List<String> muscleGroups,
  String equipment,
});

/// Text, equipment, and muscle filters shared by the library and workout builder. Values within a facet are alternatives; facets narrow together.
class ExerciseFilter {
  const ExerciseFilter({
    this.query = '',
    this.equipment = const {},
    this.muscles = const {},
  });

  /// Free text matched against the displayed and canonical exercise words.
  final String query;

  /// The equipment kinds to keep — see [kEquipmentTypes]. Empty means all.
  final Set<String> equipment;

  /// The muscle groups to keep — see [kMuscleGroups]. Empty means all.
  ///
  /// A movement is kept when it works one of them at all, trained or assisted:
  /// the question being asked of this control is "what have I got that hits
  /// this", and answering with only the movements filed under the group would
  /// leave out most of what does.
  final Set<String> muscles;

  /// Whether this asks anything at all.
  bool get isEmpty =>
      query.trim().isEmpty && equipment.isEmpty && muscles.isEmpty;

  /// Number of selected facet values.
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

  /// The filter with facet selections cleared, preserving [query].
  ExerciseFilter get withoutFacets => ExerciseFilter(query: query);

  static Set<String> _toggled(Set<String> from, String value) {
    final next = {...from};
    if (!next.remove(value)) next.add(value);
    return next;
  }

  /// Whether [e] survives the filter. Facets use canonical values; text also searches translated values supplied through [shown].
  bool matches(Exercise e, {ExerciseWords? shown}) {
    if (equipment.isNotEmpty && !equipment.contains(e.equipment)) return false;
    final worked = e.muscles.all;
    if (muscles.isNotEmpty && !worked.any(muscles.contains)) return false;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    for (final word in [
      e.name,
      ...worked,
      e.equipment,
      if (shown != null) ...[shown.name, ...shown.muscleGroups, shown.equipment],
    ]) {
      if (word.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  /// Returns [all] entries that match this filter.
  List<Exercise> apply(
    Iterable<Exercise> all, {
    ExerciseWords Function(Exercise)? shown,
  }) =>
      [
        for (final e in all)
          if (matches(e, shown: shown?.call(e))) e,
      ];
}
