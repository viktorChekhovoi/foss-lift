# Layoff deloads

Come back from a long break and the app offers a lighter start — measured per
workout, never applied without asking.

## What it does

- Watches the gap since a **workout** was last trained (not "the routine").
- When the gap is long enough, **offers** a back-off before the session starts:
  whole periods away, each worth a percentage, stacking up to a cap.
- The cut lands somewhere trainable (down to the half kilo, never below the
  mode's floor) and the session says why it's lighter.

## How to use it

- **Set the rules:** Profile → Settings → the layoff **days** threshold and
  **percent** per period. These are app-wide.
- **When it triggers:** open a workout that's been untrained for a while → tap
  **Start** → a dialog offers the deload. **Accept** to start lighter, or
  **decline** to start at the weight you left.

## Behaviour & edge cases

- **Per workout, not per routine.** A split where Push comes round weekly but
  Legs hasn't been touched since spring catches Legs exactly — "the routine" was
  trained throughout.
- **Nothing is applied without asking.** Accepting moves the template and draws
  the first set at the new weight; the cut is carried into the session as a
  notice shown for its whole length ("why is this lighter?" occurs to people
  mid-set).
- **Declining is not recorded.** Training today resets the gap by itself, so the
  question can't come back to nag.
- **A deload clears both progression streaks** — sessions either side of a month
  off aren't "consecutive" in any sense the progression rules mean.
- **The thresholds are app-wide**, unlike per-slot progression rates: a layoff is
  something that happened to *you*, not to one exercise.

## Where it lives

- Pure rules: `lib/data/layoff.dart` (`layoffDeload` / `deloadedTarget`).
- Applied by `applyLayoffDeload(...)` in `lib/data/database.dart`.
- Offered on Start in `lib/screens/workout_detail_screen.dart`.
- Settings: `lib/screens/settings_screen.dart`.

## Related issues

- [#12 Deload after missed workouts](https://github.com/viktorChekhovoi/foss-lift/issues/12) — shipped
