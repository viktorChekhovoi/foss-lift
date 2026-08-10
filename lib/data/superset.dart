/// Which slots of a workout are trained together.
///
/// A **superset** is two or more exercises performed back to back — a set of
/// each, then the rest, then round again. The app stores that as a join between
/// a slot and the one above it (`WorkoutItems.supersetWithPrevious`), not as a
/// group id, and this file is the arithmetic that turns a list of joins into
/// groups.
///
/// **A join is between neighbours, so a group is always a run of consecutive
/// slots.** That is the whole reason for the shape: a group id would let a
/// workout claim that slots one and four are a superset with slots two and three
/// in between, which is not a thing anybody can perform, and every screen would
/// then have to decide what to draw for it. Here the representation cannot
/// express it. Reordering a workout re-forms the groups by itself, and the only
/// rule to enforce is that the first slot has nothing above it to join to —
/// [normaliseJoins].
///
/// Pure Dart on purpose, like the other rule modules: it takes a list of bools
/// and hands back lists of indices, so the template editor, the duration
/// estimate, the day screen and the live session all group the same way without
/// any of them owning the answer.
library;

/// The groups [joined] describes, as lists of indices into it, in order.
///
/// `joined[i]` is "slot i is supersetted with slot i − 1". Element 0 is ignored:
/// nothing is above it. A slot that is joined to nothing and has nothing joined
/// to it comes back as a group of one, so callers can walk groups without a
/// special case for the ordinary exercise — which is nearly every exercise.
///
/// ```
/// joined: [false, true, true, false, true]
/// groups: [[0, 1, 2], [3, 4]]
/// ```
List<List<int>> supersetGroups(List<bool> joined) {
  final groups = <List<int>>[];
  for (var i = 0; i < joined.length; i++) {
    if (i > 0 && joined[i]) {
      groups.last.add(i);
    } else {
      groups.add([i]);
    }
  }
  return groups;
}

/// The group slot [index] belongs to — the indices of every slot trained in the
/// same round, itself included, in order. `[index]` alone for an ordinary slot.
List<int> supersetGroupAt(List<bool> joined, int index) {
  if (index < 0 || index >= joined.length) return const [];
  var first = index;
  while (first > 0 && joined[first]) {
    first--;
  }
  final group = [first];
  for (var i = first + 1; i < joined.length && joined[i]; i++) {
    group.add(i);
  }
  return group;
}

/// Whether slot [index] is trained as part of a group of more than one.
bool inSuperset(List<bool> joined, int index) =>
    supersetGroupAt(joined, index).length > 1;

/// [joined] with the one impossible claim removed: the first slot cannot be
/// joined to the slot above it, because there is not one.
///
/// Applied on the way to the database and on the way onto a screen rather than
/// trusted from either. A join survives its row being dragged, and dragging a
/// joined row to the top is the ordinary way a workout ends up asserting this.
List<bool> normaliseJoins(List<bool> joined) => [
      for (var i = 0; i < joined.length; i++) i > 0 && joined[i],
    ];
