# Exercise library

A curated, searchable starter set of exercises, plus custom exercises you create.

## What it does

- Ships a starter library of ~30 exercises, each with a **form cue** and a
  **demo-video link**.
- Is **searchable** by name, and each exercise opens a detail page with its
  instructions and demo link.
- Lets you **add your own custom exercises**, which sit alongside the starter set.
- Every exercise carries three facts about the movement itself, not about any
  routine that uses it:
  - **Measure** — *counted* (done for reps) or *held* (a timed hold, e.g. a
    plank). This decides which progression axes a slot can ever use.
  - **Weight type** — *barbell*, *machine*, or *dumbbell*. This decides whether a
    plate breakdown is shown (only barbell lifts get one).
  - **Bar** — an optional bar weight of its own (e.g. a 10 kg EZ curl bar),
    overriding the app-wide default bar.

## How to use it

- **Browse / search:** open the library from **Profile** (or via the exercise
  picker while building a workout). Type in the search box to filter.
- **Add a custom exercise:** Library → **＋** (FAB) → fill in name, muscle group,
  equipment, measure, and optional instructions/video → Save.
- **Edit a movement's facts:** open any exercise → its detail screen lets you set
  the **weight type** and its **own bar weight** — for *every* exercise, not just
  custom ones (whether your gym's bench has a 20 kg bar is something the starter
  library can't know).

## Behaviour & edge cases

- **Weight type is seeded from equipment:** Barbell → bar, Dumbbell → dumbbell,
  everything else (bodyweight included) → machine. You can override it afterward.
- **Measure is fixed at creation** for custom exercises; in the starter library
  only the Plank is *held*. A held exercise offers only the *time* progression
  axis; a counted one offers *weight* and *reps*.
- **History survives library edits.** Logged sets store the exercise name
  denormalised, so renaming or deleting an exercise never rewrites past sessions.

## Where it lives

- Screens: `lib/screens/library_screen.dart`, `exercise_form_screen.dart`,
  `exercise_detail_screen.dart`.
- Data: the `Exercises` table and the first-run seed in `lib/data/database.dart`;
  `ExerciseMeasure` / `WeightType` types.

## Related issues

- [#1 Exercise library](https://github.com/viktorChekhovoi/foss-lift/issues/1) — shipped
- [#13 Weight types and plate math](https://github.com/viktorChekhovoi/foss-lift/issues/13) — shipped
- [#16 Exercise library export / import](https://github.com/viktorChekhovoi/foss-lift/issues/16) — planned
