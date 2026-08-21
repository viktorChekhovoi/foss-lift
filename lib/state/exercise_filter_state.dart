/// Session-scoped exercise filters, kept independently for each surface.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise_filter.dart';

/// Facets selected for one surface; search text remains local to its field.
class ExerciseFilterFacets extends Notifier<ExerciseFilter> {
  @override
  ExerciseFilter build() => const ExerciseFilter();

  /// Takes the dimensions of [next] and drops whatever text came with it.
  void keep(ExerciseFilter next) => state = next.withQuery('');
}

/// What the library screen is narrowed to.
final libraryFilterProvider =
    NotifierProvider<ExerciseFilterFacets, ExerciseFilter>(
      ExerciseFilterFacets.new,
    );

/// What the builder's exercise picker is narrowed to.
final pickerFilterProvider =
    NotifierProvider<ExerciseFilterFacets, ExerciseFilter>(
      ExerciseFilterFacets.new,
    );
