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
- Carries **your own note** on the movement — the seat setting, the rack pin,
  how far down you take it. Personal, and it never leaves the phone.

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
- **Write a note:** open any exercise → tap **My note** → type. During a workout
  the movements you have written a note on show a note icon beside the name;
  one tap opens it in place, without leaving the session.

## Behaviour & edge cases

- **An exercise has no written instructions.** There was a coaching-cue field;
  it was removed, along with everything anyone had typed into it. A
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

- **Glutes and Forearms are groups of their own.** Both are trained
  deliberately, with their own movements — a hip thrust is not something anyone
  files next to a calf raise — and a group you have to go looking for inside a
  bigger one may as well not exist. Traps stay under Back, because a shrug is
  something you do on a back day. The movements that answer to no single group
  — a kettlebell swing, a power clean, a get-up — are under Other.
- **The group and equipment lists are a wire format.** A shared routine sends
  "muscle group #4" rather than the word, which is most of the reason a routine
  fits in a QR code. Both lists are free to change until the first public
  release; after it, reordering one would silently re-label every code already
  shared.
- **A note is yours, and stays.** It is a fact about your gym — "seat 4, pin 7"
  — so it never travels in a shared routine, and importing a routine never
  overwrites one, not even when you choose **Replace** and every other field on
  the exercise is rewritten. It is not the coaching cue coming back: a cue was
  general advice that travelled badly because it was long; a note is specific to
  one person at one machine and would be actively wrong anywhere else. Available
  on every exercise, starter or custom, and capped at 300 characters. Blank and
  absent are the same thing — a note of only spaces is stored as no note.
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
- [#31 Per-exercise personal notes](https://github.com/viktorChekhovoi/foss-lift/issues/31) — shipped
