/// The vocabulary an exercise is described with.
///
/// Two closed-ish lists that started life in the custom-exercise form and are
/// now also a wire format: a shared routine sends "muscle group #4" rather than
/// the word, which is most of the reason an ordinary routine still fits in a QR
/// code. Order is therefore **frozen from the first public release** —
/// appending is fine, reordering silently re-labels every routine code already
/// shared. Until that release no code has been shared, so both lists are still
/// free to change shape.
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
