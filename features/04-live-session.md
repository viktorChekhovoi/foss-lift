# Live workout session

Start a day, log each set, run the rest timer, and finish — all in memory until
you're done.

## What it does

- **Starts a training day** and hydrates set rows from the template.
- **Logs sets by tapping.** Each row shows a goal (reps or seconds) and a weight;
  tapping cycles the logged value, and you can edit weight/reps directly.
- **Tracks duration and set count live** — a 1-second timer ticks the elapsed
  time; the set counter updates as you log.
- **Runs a rest timer** using each slot's configured rest, with
  shorter / longer / skip controls.
- **Suggests warm-up sets** for barbell/weighted lifts — an ascending ramp toward
  the working weight, landing only on loads the gym can actually be set to —
  kept separate from the working sets.
- **Survives being collapsed** — leave the session and a "Resume workout" pill
  floats over every other screen.
- **On Finish**, writes only the completed sets, advances progression, and opens
  the [post-session recap](10-history-and-stats.md).

## How to use it

- **Start:** Today → tap a day → **Start workout**. (If a [layoff
  deload](06-layoff-deloads.md) is offered, accept or decline it here first.)
- **Log a set:** tap the set row to cycle its value (goal → one fewer → … → 0 →
  untouched); type a different weight or rep count to override.
- **Rest:** logging a set starts the rest banner; use shorter / longer / skip.
- **Warm-ups:** expand the collapsed warm-up group above the working sets; adjust
  the number of warm-up sets with its stepper.
- **Leave and come back:** the down-arrow collapses the session (it keeps
  running); tap the **Resume workout** pill to return.
- **Finish:** tap Finish → the recap screen appears.

## Behaviour & edge cases

- **The live session is in memory** and only writes to the DB on Finish, so
  editing sets is instant and a mid-session crash can't leave half-saved rows.
- **A session only ends by finishing it.** Collapsing never discards it.
- **Warm-ups are never persisted** — they're suggestions, not history, so logging
  them can't distort volume or lifetime totals. They ride alongside the working
  sets and are excluded from every working-set aggregate (verdict, volume, set
  count). The group carries a liability disclaimer.
- **Warm-up rest is shorter between rungs, full before the work.** 45 s between
  warm-up sets — that's changing the plates and catching your breath — but after
  the *last* rung the exercise's own rest runs instead, because the next thing
  you do is the working set and a warm-up is not meant to be fatigue you lift
  through.
- **Every warm-up rung is a load the gym can be set to.** A ramp of percentages
  is useless if nobody can build the numbers, so each step lands on the nearest
  *cheap* real load rather than the exact percentage:
  - **Barbell — starts on the empty bar**, and each later rung is a weight the
    plates can make, preferring the fewest plates per side. 225 lb over a 45 lb
    bar gives **45 → 115 → 185** at the default three, and **45 → 95 → 135 →
    185** at four: one pair a step, in the sizes a lifter reaches for. (In a
    metric gym, 80 kg over a 20 kg bar gives 20 → 40 → 60.)
  - **Dumbbell — the increments a gym stocks bells in**: multiples of 5 lb, or
    2.5 kg in a metric gym.
  - **Machine/cable — multiples of 5**, which is how a stack is labelled, in
    either unit.
  - The ramp starts on the empty bar for a barbell and at ~40% of the work for
    anything else (a dumbbell has no empty bar to stand on). **85% of the work
    is a hard ceiling** — snapping onto a loadable weight rounds down past it,
    never up, so the last warm-up can't turn into a first working set. Reps fall
    off as the load climbs (8 → 5 → 3 → 2 by fraction of the work), so an 80 kg
    bench warms up 20×8, 40×5, 60×3.
  - **A step will only stray a tenth of the working weight to find a cheaper
    load.** Cheapness breaks a tie between neighbouring loads; it is never worth
    warming up 50 kg lighter than intended for the sake of one pair of plates.
  - Where a coarse grid puts two steps on the same load the duplicate is
    dropped, so a light lift gets a shorter ramp than asked for rather than one
    that stalls or steps backward.
- **One warm-up set is a middle-of-the-road set, not the empty bar.** Dial the
  stepper to 1 and you get a single rung around halfway between the bar and the
  ceiling — heavy enough to actually warm you up, light enough to be safe: 40 kg
  for an 80 kg bench, 70 for a 140 kg squat, 115 lb for a 225 lb squat. With one
  set there is no ramp to open, so the "starts on the empty bar" rule doesn't
  apply — it resumes at two rungs and up. **A light lift still collapses to the
  bar on its own**, at any set count, because there is nothing between the bar
  and the work to put in: a 25 kg lift over a 20 kg bar warms up with the empty
  bar and nothing else.
- **The ramp's shape follows published practice, as fractions of the working
  weight** (not of 1RM): three sets by default because 2–4 is where the research
  lands for a compound lift and more starts costing fatigue; 40–50% / 60–70% /
  70–80% for the loads; 8–10 / 4–6 / 1–3 for the reps; 45–60 s between rungs. The
  stepper goes to six for a heavy lift starting from an empty bar, but six is a
  choice the user makes, not a suggestion. Sources are cited in
  `lib/data/warmup.dart`.
- **A tap cycles differently for timed sets** — goal ⇄ untouched, since nobody
  taps a plank down a second at a time.
- **A missed set** is one that fell short on reps/seconds *or* weight (deloading
  to finish counts as a miss) — this feeds progression.
- **Finish order matters:** sets are saved *before* progression advances, so a
  template never steps up without the history to justify it.

## Where it lives

- State: `lib/state/active_workout.dart` (`SetEntry` / `ExerciseEntry` /
  `ActiveWorkout` + `ActiveWorkoutController`).
- Warm-up ramp: `lib/data/warmup.dart`; the loads it may land on come from
  `loadLadder` in `lib/data/plates.dart`.
- Screens/widgets: `lib/screens/workout_screen.dart`,
  `lib/widgets/resume_workout_bar.dart`.

## Related issues

- [#8 StrongLifts-style set logging](https://github.com/viktorChekhovoi/foss-lift/issues/8) — shipped
- [#9 Suggest the next workout, but allow choosing any](https://github.com/viktorChekhovoi/foss-lift/issues/9) — shipped
- [#26 Workout should persist until manually ended](https://github.com/viktorChekhovoi/foss-lift/issues/26) — shipped
- [#25 Warmup calculator](https://github.com/viktorChekhovoi/foss-lift/issues/25) — shipped, in review
