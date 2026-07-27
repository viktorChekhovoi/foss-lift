# Exercise library

A curated, searchable starter set of exercises, plus custom exercises you create.

## What it does

- Ships a starter library of ~85 exercises, each with a **demo-video link**.
- Is **searchable** by name, and each exercise opens a detail page with its
  facts and demo link.
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
  equipment, measure, and an optional demo link → Save. Paste a YouTube link in
  any shape you like.
- **Edit a movement's facts:** open any exercise → its detail screen lets you set
  the **weight type** and its **own bar weight** — for *every* exercise, not just
  custom ones (whether your gym's bench has a 20 kg bar is something the starter
  library can't know).

## Behaviour & edge cases

- **An exercise has no written instructions.** There was a coaching-cue field;
  it was removed in schema v2, along with everything anyone had typed into it. A
  paragraph of technique advice is not what an exercise row is for, and the demo
  link does the same job better. The movement is identified by its name and its
  facts — muscle group, equipment, how it is loaded, how it is measured.
- **A YouTube demo link is tidied on the way in.** Any form of it — `watch?v=`,
  `youtu.be`, `/shorts/`, `/embed/`, with timestamps, playlists and tracking
  parameters — is stored as `https://youtu.be/<id>`. None of the rest identifies
  the video, and the short form is small enough to travel inside a shared
  routine.
- **A link to anywhere else is kept exactly as typed.** Someone's own upload or
  a private clip is not ours to rewrite, and it still opens from the exercise
  screen. It just will not travel when the exercise is shared — nor will a
  YouTube *search* link, which names no video. See
  [sharing a routine](14-routine-sharing.md).

- **Six muscle groups have to hold everything.** The group and equipment lists
  are a wire format — a shared routine sends "muscle group #4" rather than the
  word — so they cannot grow to suit the library. Glute work is filed under
  Legs, traps under Back, forearms under Arms, and the movements that belong to
  no one group (a carry, a kettlebell swing, a power clean) under Other.
- **Weight type is seeded from equipment:** Barbell → bar, Dumbbell → dumbbell,
  everything else (bodyweight included) → machine. You can override it afterward.
- **Measure is fixed at creation** for custom exercises; in the starter library
  the *held* movements are the ones with no rep to count — Plank, Side Plank,
  Hollow Hold, Dead Hang and Farmer's Carry. A held exercise offers only the
  *time* progression axis; a counted one offers *weight* and *reps*.
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
- [#16 Expand the seeded exercise library](https://github.com/viktorChekhovoi/foss-lift/issues/16) — shipped
