# Plate math

For barbell lifts, the app works out which plates go on each side — from the rack
you actually own.

## What it does

- Solves the plate breakdown for a target weight: **what goes on one side**, what
  the bar will actually come to, and whether that's the weight you asked for.
- Shows it under an exercise as a line like `30 kg/side · 25 + 5 · bar 20`,
  re-solving the moment you type a different weight.
- Uses the bar for the exercise (its own, or the app-wide default, or the
  standard bar for the unit) and the **rack you own** (per unit).

## How to use it

- **The line appears automatically** on the live session for barbell lifts,
  describing the *next* set's weight.
- **Set the default bar:** Profile → Settings → Bar & plates → **Bar weight**.
- **Set a bar for one exercise:** open the exercise → its detail screen.
- **Edit the rack:** Profile → Settings → **plates** — step plate pair counts up
  and down. There's one rack per unit.

## Behaviour & edge cases

- **The search is exhaustive, not greedy.** Greedy is only correct when every
  plate divides the next one up, which a real rack (45/35/25 lb; a lone 1.25 kg)
  does not.
- **Nothing is snapped.** A weight the plates can't build is still yours to type;
  the line goes **gold** with the nearest buildable load. **Green** is the weight
  you asked for. `belowBar` is the separate case of asking for less than the empty
  bar.
- **Ties break the way a lifter loads a bar:** fewest plates first, then the
  heaviest — 40 kg/side is 25 + 15, not 20 + 20, and never 10 + 5 + 2.5 + 2.5.
- **The rack is pairs.** Plates go on two at a time; an odd plate is ignored. The
  assumed rack is a pair of every size plus a pile of the workhorse plate (45s in
  a pounds gym, 20s in a metric one).
- **One rack per unit.** A rack is a set of *sizes*, not weights — each unit
  remembers its own, and the standard rack stands in until you edit it.
- **Only a bar gets a line.** A machine's number is the number; a dumbbell's is
  whatever's in your hand.

## Where it lives

- Solver: `lib/data/plates.dart` (`solvePlates` → `PlateSolution`).
- The line: `lib/widgets/plate_line.dart`.
- Settings: `lib/screens/bar_settings_screen.dart`,
  `plate_inventory_screen.dart`.

## Related issues

- [#13 Weight types and plate math](https://github.com/viktorChekhovoi/foss-lift/issues/13) — shipped
