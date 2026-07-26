# Workout configuration (per-slot)

Every exercise slot in a workout is configured on its own, in the exercise
builder.

## What it does

For each exercise slot you set:

- **Sets** — how many working sets.
- **Target**, one of:
  - a **fixed rep count** (e.g. 5),
  - a **rep range** (e.g. 6–8),
  - **to failure**, or
  - a **timed hold** in seconds (for *held* exercises).
- **Rest override** — a rest time for this slot, overriding the routine default.
- **Suggested weight** — the starting working weight.
- **Progression rates** — the axis and the step/back-off numbers (see
  [progression](05-progression.md)): increment, success threshold, deload amount,
  failure threshold.

## How to use it

Open a workout → **edit** → tap an exercise slot to open its config sheet.
The **progression axis comes first** in the sheet, because it decides whether
everything below asks for **reps** or for **seconds**. Set sets, the rep
range / hold / to-failure, the rest override, the weight, and the step/back-off
rates. Reorder slots with up/down; add more from the exercise picker.

## Behaviour & edge cases

- **Which targets are offered depends on the exercise's measure**, not the
  programme. A *counted* exercise offers weight & reps; a *held* one offers only a
  timed hold. The builder never offers "a deadlift progressed by time".
- **A rep range keeps its width** as progression moves it (6–8 steps to 7–9, not
  6–9).
- **A set is measured in reps *or* seconds, never both.** A timed set stores
  seconds and leaves reps at zero, so lifetime reps never count a 45-second plank
  as 45 of anything.
- **Defaults work untouched:** +2.5 kg after one clean session, −5 kg after two
  misses in a row.

## Where it lives

- Screen: `lib/screens/workout_edit_screen.dart` (the `_ItemConfigSheet`).
- Shared chrome: `lib/widgets/builder_widgets.dart`, `workout_items_editor.dart`.
- Data: `WorkoutItems` columns in `lib/data/database.dart`.

## Related issues

- [#3 Sets × reps configuration](https://github.com/viktorChekhovoi/foss-lift/issues/3) — shipped
- [#4 Rest timers](https://github.com/viktorChekhovoi/foss-lift/issues/4) — shipped
- [#10 Progression modes](https://github.com/viktorChekhovoi/foss-lift/issues/10) — shipped
- [#11 Progression and regression rates](https://github.com/viktorChekhovoi/foss-lift/issues/11) — shipped
