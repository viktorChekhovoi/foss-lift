/// Where a filter you set is kept, so that it stays set.
///
/// The two dimensions used to be `setState` state on the screen showing them,
/// which meant the choice died with the widget: leaving the library and coming
/// back, or taking one movement out of the builder's picker and opening it
/// again for the next, both handed back the whole library. Re-ticking Legs is
/// the same filter set twice, and a list that has quietly stopped hiding things
/// is exactly as confusing as one that has quietly started.
///
/// **A provider per surface, and they are independent.** The library and the
/// picker each keep their own: a picker that opened pre-narrowed by something
/// done on another screen reads as a bug rather than as a convenience.
///
/// **Session-lifetime, not stored.** Nothing here reaches the database — the
/// filter comes back for as long as the app is running and starts empty on a
/// cold launch, which is what a browsing choice is.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise_filter.dart';

/// The muscle groups and equipment kinds one surface is narrowed to.
///
/// The search text is deliberately *not* kept here. It has a text field showing
/// it, and a query that outlived the box it was typed into would narrow the
/// list with nothing on screen saying so — the failure this whole provider
/// exists to fix. The two buttons say what they are narrowed to; an empty
/// search box says the search is empty, and it has to stay true.
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
