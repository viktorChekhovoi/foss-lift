# Routines & workouts

A programme is three levels deep. You build, edit, reorder, and delete at every
level.

## What it does

The template hierarchy:

```
Routine  "Push / Pull / Legs"   ← the programme; you never train "a routine"
└── Workout  "Push"             ← one training day; this is what you start
    └── Exercise slot  Bench    ← 4 × 6–8 @ 80 kg (see: workout configuration)
```

- A **routine** is a whole programme (Push/Pull/Legs, Upper/Lower, …). It carries
  a name, a colour, a default rest time, and its weekly schedule (see
  [schedule & reminders](08-schedule-and-reminders.md)).
- A **workout** is one training day inside a routine — this is the thing you
  actually **Start**. Workout names need not be unique inside a routine
  (Upper/Lower legitimately has "Upper 1" and "Upper 2").
- An **exercise slot** is one exercise inside a workout, with its own
  configuration (see [workout configuration](03-workout-configuration.md)).
- One routine is the **current** routine — the one Today is about.
- Two demo routines (**PPL** and **Upper/Lower**) are seeded on first launch.

## How to use it

- **See the current routine's days:** the **Today** tab lists them directly.
  Starting a workout is two taps: tap a day → **Start**.
- **Pick / change the current routine:** the **Routines** tab → tap a routine to
  make it current, or **New routine**.
- **Build / edit a routine:** Routines → open a routine → edit → set name, colour,
  default rest, schedule, and the ordered list of workouts (add / reorder /
  delete).
- **Build / edit a day's exercises:** open a workout → edit → add exercises from
  the picker, reorder with up/down, and configure each slot.

## Behaviour & edge cases

- **Editing is split to match the hierarchy.** The routine editor changes routine
  meta and its list of workouts; the workout editor (the "exercise builder")
  changes the exercises inside one day. Renaming/reordering workouts never
  disturbs the exercises inside them, and only workouts you actually removed are
  deleted.
- **You can build a routine's exercises before saving it** — drafts are held in
  memory and written on save.
- **A deleted current routine degrades to "none"** rather than dangling — Today
  falls back to the routine chooser.
- **You never train "a routine".** There is no "build" button next to "start a
  routine"; that screen is for working out, not editing.

## Where it lives

- Screens: `lib/screens/routines_screen.dart`, `routine_detail_screen.dart`,
  `routine_edit_screen.dart`, `workout_detail_screen.dart`,
  `workout_edit_screen.dart`.
- Shared editor: `lib/widgets/workout_items_editor.dart`, `routine_card.dart`.
- Data: `Routines`, `Workouts`, `WorkoutItems` tables in `lib/data/database.dart`.

## Related issues

- [#2 Routine builder](https://github.com/viktorChekhovoi/foss-lift/issues/2) — shipped
- [#7 A routine contains workouts](https://github.com/viktorChekhovoi/foss-lift/issues/7) — shipped
- [#20 Current routine: Today shows its workouts](https://github.com/viktorChekhovoi/foss-lift/issues/20) — shipped
- [#21 Build a routine's exercises without saving first](https://github.com/viktorChekhovoi/foss-lift/issues/21) — shipped
- [#15 Share routines: export / import](https://github.com/viktorChekhovoi/foss-lift/issues/15) — planned
