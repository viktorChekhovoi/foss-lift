/// Groups adjacent workout slots into supersets.
///
/// A slot joins the immediately preceding slot, so each group is a consecutive run represented by a list of booleans.
library;

/// Returns the groups [joined] describes as lists of indices, in order.
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

/// Returns the group containing [index], or an empty list for an invalid index.
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

/// Clears the invalid join on the first slot.
List<bool> normaliseJoins(List<bool> joined) => [
      for (var i = 0; i < joined.length; i++) i > 0 && joined[i],
    ];
