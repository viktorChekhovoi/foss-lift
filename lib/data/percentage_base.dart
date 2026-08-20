/// Which lift a movement's percentages are taken from.
///
/// A front squat in a powerlifting program is prescribed at a percentage of the
/// *squat*, not of the front squat, and a deficit deadlift at a percentage of
/// the deadlift. The percentage arithmetic does not care — it takes whatever
/// number the slot carries — but the person filling those numbers in does: a
/// sixteen-week program can put the same three maxes on a hundred slots, and
/// typing each of them one slot at a time is a reason not to run the program.
///
/// So the base is a fact about the movement, stated once here, and the routine's
/// training-max screen groups its slots by it. Nothing in the resolver consults
/// this and no program is named in it: it is what the movement is a version of,
/// which is true of a front squat whether or not anybody ever ships a program
/// that uses one.
///
/// **A table in the code, not a column.** The mapping is the app's claim about
/// the starter library rather than the user's about their gym, and putting it in
/// the database would mean a migration rung, a wire format that has to carry it,
/// and a value that could drift between two phones running the same build — for
/// a fact that is the same on every one of them. The cost is that a movement you
/// build yourself is its own base; the training-max screen still gathers its
/// slots under it, which is one field instead of one per slot.
///
/// Pure Dart: no drift, no Flutter, in the manner of the other rule modules.
library;

/// Movement → the lift its percentages are of, for the movements that are a
/// version of another lift. Every movement absent from this map is its own base,
/// which is nearly all of them.
///
/// **Only the variations that are genuinely prescribed off another max.** A
/// front squat and a deficit deadlift are; a Romanian deadlift and an incline
/// bench are trained off their own numbers even in programs that write them
/// beside the competition lift, and listing them here would quietly overwrite a
/// weight somebody had set.
///
/// The three paused competition lifts are deliberately **not** here. They are
/// trained off their own bar and carry their own history — a paused squat at
/// 70% is not a squat — and the programs that ship them prescribe a weight
/// rather than a fraction of one.
const Map<String, String> kPercentageBases = {
  // The squat variation. A front squat at 60% means 60% of the back squat —
  // it is the same programs' shorthand, and it is why nobody is ever asked for
  // a front-squat max.
  'Front Squat': 'Back Squat',
  // The pulls that change where the bar starts or stops. All three are the
  // deadlift done over part of its range, and all three are written as
  // percentages of the whole one.
  'Deadlift to Knees': 'Deadlift',
  'Block Deadlift': 'Deadlift',
  'Deficit Deadlift': 'Deadlift',
};

/// The lift [exercise]'s percentages come from — itself, unless it is a version
/// of something else.
///
/// Total by construction: a movement nobody has classified, and every movement
/// somebody built, is its own base. That is the honest answer rather than a
/// fallback, since there is nothing else it could be a percentage of.
String percentageBaseFor(String exercise) =>
    kPercentageBases[exercise] ?? exercise;
