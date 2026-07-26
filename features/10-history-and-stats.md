# History & stats

A recap when you finish, every past session on record, running lifetime totals,
and a per-exercise progress chart.

## What it does

- **Post-session recap** (the "progress screen" after Finish): a "Workout logged"
  headline, the session name, stat tiles (duration, sets done, …), a
  **Progression** section saying what each exercise's target did, and the sets you
  logged grouped by exercise.
- **Session history:** every finished session, newest first; tap one to reopen its
  recap.
- **Lifetime totals:** running **volume, reps, and sets** on the Today screen.
- **Per-exercise progress chart:** a movement's logged sets over time, with 1RM /
  chart maths.

## How to use it

- **The recap appears automatically** when you tap **Finish** on a live session.
- **Browse history:** the **History** tab → tap a session for its recap (the
  button reads **Back**, and no progression banner shows, when reopened from
  history).
- **Lifetime totals:** the **Today** tab shows them.
- **Per-exercise chart:** open an exercise → **progress**.

## Behaviour & edge cases

- **The progression banner belongs to the session just finished** — it's read once
  and cleared, so reopening the same session from History doesn't show it again.
  Bodyweight slots with no target are omitted.
- **Lifetime totals sum the logged sets**, not a stored tally, so old history
  counts and no cached number can fall out of step with the sets beneath it.
- **Deleting a routine/workout template never erases the history** of having
  trained it — session IDs are deliberately not foreign keys, and set rows store
  the exercise name denormalised.
- **Timed sets don't inflate rep/volume totals** — a plank's seconds aren't
  counted as reps.

## Where it lives

- Screens: `lib/screens/summary_screen.dart`, `history_screen.dart`,
  `exercise_progress_screen.dart`.
- Chart maths: `lib/data/exercise_stats.dart` (pure).
- Data: `Sessions` / `SessionSets` tables, `watchLifetimeTotals()`,
  `watchExerciseSetHistory()` in `lib/data/database.dart`.
- Formatting: `lib/util/format.dart` (`fmtTotal`).

## Related issues

- [#6 Lifetime totals: volume, reps and sets](https://github.com/viktorChekhovoi/foss-lift/issues/6) — shipped
- [#23 Say what progression did after a session](https://github.com/viktorChekhovoi/foss-lift/issues/23) — shipped, in review
- [#14 Per-exercise progress visualisation](https://github.com/viktorChekhovoi/foss-lift/issues/14) — shipped, in review
