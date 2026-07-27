# Exercise library

A curated, searchable starter set of exercises, plus custom exercises you create.

## What it does

- Ships a starter library of ~85 exercises, each with a **demo-video link**.
- Is **searchable** by name and **filterable** by muscle group and equipment, so
  "a barbell movement for legs" does not require knowing it is called a squat.
  Each exercise opens a detail page with its facts and demo link.
- Lets you **add your own custom exercises**, which sit alongside the starter
  set, and **edit them afterwards** — every fact on the form stays changeable.
- Every exercise carries three facts about the movement itself, not about any
  routine that uses it:
  - **Measure** — *counted* (done for reps) or *held* (a timed hold, e.g. a
    plank). This decides which progression axes a slot can ever use.
  - **Weight type** — *barbell*, *machine*, or *dumbbell*. This decides whether a
    plate breakdown is shown (only barbell lifts get one).
  - **Bar** — an optional bar of its own, overriding the app-wide default.
    Chosen **by name** from the bars a gym racks (Olympic, women's Olympic, EZ
    curl, trap, safety squat, Smith carriage), or typed as a number.
- Carries **your own note** on the movement — the seat setting, the rack pin,
  how far down you take it. Personal, and it never leaves the phone.

## How to use it

- **Browse / search:** open the library from **Profile** (or via the exercise
  picker while building a workout). Type in the search box, tap chips to narrow
  by muscle group and equipment, or both — they compose.
- **Add a custom exercise:** Library → **＋** (FAB) → fill in name, muscle group,
  equipment, measure, and an optional demo link → Save. Paste a YouTube link in
  any shape you like. The builder's picker offers **New exercise** at the top of
  its list, and hands the movement you make straight back to the slot you were
  filling.
- **Choose a bar by name:** open any exercise → **Bar weight** → pick the bar,
  or **Something else** to type a weight. The same list sets the app-wide
  default under Settings → Default bar.
- **Edit a movement's facts:** open any exercise → its detail screen lets you set
  the **weight type** and its **own bar weight** — for *every* exercise, not just
  custom ones (whether your gym's bench has a 20 kg bar is something the starter
  library can't know).
- **Edit a custom exercise outright:** open one you made → the pencil in the app
  bar reopens the creation form on what you stored. The pencil is absent on a
  starter exercise.
- **Write a note:** open any exercise → tap **My note** → type. During a workout
  the movements you have written a note on show a note icon beside the name;
  one tap opens it in place, without leaving the session.

## Behaviour & edge cases

- **Chips within a row are alternatives; the two rows narrow.** Arms *and*
  glutes is one session's worth of browsing rather than two searches, while
  barbell *and* legs is the pair of facts that finds a squat. A row nobody has
  touched excludes nothing, and the chips compose with whatever is typed in the
  search box.
- **Muscle groups lead, equipment follows, and both stay on screen.** Six
  equipment chips already fill a phone's width, so one long strip would push the
  whole muscle vocabulary off to the right — and browsing by muscle is the
  commoner way in. Splitting them also settles the one collision: *Other* is
  both a kind of equipment and a muscle group, and which is which is now a
  matter of which row it is in.
- **The picker can create what it cannot find.** Leaving the builder to make a
  movement and coming back to start over is a dead end people work around by
  picking something close enough, so **New exercise** sits at the top of the
  picker and the movement it makes comes back selected.
- **A named bar is a weight with a label on the way in.** Nothing new is stored:
  the bars are a front end on the same `barWeight`, and a gym with something odd
  still types a number. The weights are the common sizes, not a specification —
  an EZ bar runs 5.5–13.5 kg and a Smith carriage anywhere from 6 to 32 — so
  every one of them is a starting point you can overrule. A pounds gym gets the
  round pounds number (a 45 lb Olympic bar), not a converted kilo.
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
- **Only a custom exercise is editable in full.** A starter exercise's name and
  classification are shared vocabulary — a routine code that says "Bench Press"
  means the movement everyone else calls that, and a local rename would quietly
  break that agreement. What *is* yours about a starter exercise (its loading,
  its bar, your note) is editable on its detail screen. The rule is enforced in
  the database writer, not only by hiding the pencil.
- **A name stops at 80 characters where it is typed**, on exercises, workouts
  and routines alike. That is the schema's own limit, so a longer name would be
  a failed write rather than a truncated one.
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
- Filtering: `lib/data/exercise_filter.dart` (the question) and
  `lib/widgets/exercise_filters.dart` (the chips), shared with the builder's
  `ExercisePicker` in `lib/widgets/builder_widgets.dart`.
- Named bars: `namedBars()` in `lib/data/plates.dart`; the picker is `askBar` in
  `lib/widgets/builder_widgets.dart`.
- Data: the `Exercises` table and the first-run seed in `lib/data/database.dart`;
  `ExerciseMeasure` / `WeightType` types.

## Related issues

- [#1 Exercise library](https://github.com/viktorChekhovoi/foss-lift/issues/1) — shipped
- [#13 Weight types and plate math](https://github.com/viktorChekhovoi/foss-lift/issues/13) — shipped
- [#16 Expand the seeded exercise library](https://github.com/viktorChekhovoi/foss-lift/issues/16) — shipped
- [#31 Per-exercise personal notes](https://github.com/viktorChekhovoi/foss-lift/issues/31) — shipped
- [#42 Filters, inline creation, and named bars](https://github.com/viktorChekhovoi/foss-lift/issues/42) — shipped, in review
