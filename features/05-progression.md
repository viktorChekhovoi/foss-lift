# Automatic progression

Each exercise slot advances on one axis: add weight, add reps, or hold longer.
Success steps it up; misses back it off.

## What it does

- Every slot progresses along a single **axis** (`ProgressionMode`):
  - **weight** — add load at a fixed rep target,
  - **reps** — add reps at a fixed load,
  - **time** — hold longer.
- **Defaults work untouched:** +2.5 kg after one clean session, −5 kg after two
  misses in a row. Every rate is configurable per slot.
- **Loading the bar past the suggestion is itself progression** — beating the
  stored target raises it, even before a step is formally "earned".

## How to use it

Progression is automatic — you configure the rates in the
[workout builder](03-workout-configuration.md) and it runs on **Finish**. What it
did is shown on the [post-session recap](10-history-and-stats.md).

## Behaviour & edge cases

- **The axis is constrained by the exercise's measure**, not chosen freely: a
  *counted* exercise can use weight or reps; a *held* one can only use time.
- **The verdict is "every planned set logged and none short."** A skipped set is a
  miss; finishing at a reduced weight is a miss.
- **On the weight axis, the step is applied to the *lightest* logged set** — the
  load carried through the whole exercise. One heavy set among lighter ones is a
  heavy single, not a new working weight.
- **Streaks are stored** (consecutive successes/failures), because the target
  moves and a past session can only be judged against the goal that was live that
  day. Editing a workout in the builder can't forgive a pending back-off.
- **A weight-mode slot with no suggested weight has no target to move** — nothing
  happens, rather than inventing "load 2.5 kg onto a push-up".

## Where it lives

- Pure rules: `lib/data/progression.dart` (`stepProgression` / `advanceTarget`).
- Applied by `AppDatabase.advanceProgression(...)` in `lib/data/database.dart`.
- Recorded for the recap via `ProgressionReport` / `lastProgressionProvider` in
  `lib/state/active_workout.dart`.

## Related issues

- [#10 Progression modes](https://github.com/viktorChekhovoi/foss-lift/issues/10) — shipped
- [#11 Progression and regression rates](https://github.com/viktorChekhovoi/foss-lift/issues/11) — shipped
- [#23 Say what progression did after a session](https://github.com/viktorChekhovoi/foss-lift/issues/23) — shipped, in review
