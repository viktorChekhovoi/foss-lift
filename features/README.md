# FossLift — Feature Catalogue

What the app **does today**, one page per feature area. This is the living
description of shipped behaviour — the answer to "how does X work?" and "what
happens when the user taps Y?".

> **This is not the backlog.** Planned and unbuilt work lives in
> [GitHub Issues](https://github.com/viktorChekhovoi/foss-lift/issues)
> (`features.txt` points there). When a backlog issue ships, its behaviour is
> written up here. For *how the code fits together*, read
> [`../ARCHITECTURE.md`](../ARCHITECTURE.md); this folder is about behaviour, not
> structure.

## How each page is laid out

Every feature page follows the same shape: a one-line summary, **What it does**,
**How to use it** (the literal taps), **Behaviour & edge cases** (the decisions
worth knowing), **Where it lives** (code pointers), and **Related issues**.

## The catalogue

| # | Feature | In one line |
|---|---------|-------------|
| 01 | [Exercise library](01-exercise-library.md) | A searchable starter library plus your own custom exercises |
| 02 | [Routines & workouts](02-routines-and-workouts.md) | The three-level programme: routine → workout → exercise slot |
| 03 | [Workout configuration](03-workout-configuration.md) | Per-slot sets, reps/range/failure/hold, rest, weight, progression rates |
| 04 | [Live workout session](04-live-session.md) | Start a day, log sets, rest timer, warm-ups, resume a collapsed session |
| 05 | [Automatic progression](05-progression.md) | Weights/reps/hold step up on success, back off on misses |
| 06 | [Layoff deloads](06-layoff-deloads.md) | A long gap offers a back-off before you start — per workout |
| 07 | [Plate math](07-plate-math.md) | Which plates go on the bar, from the rack you actually own |
| 08 | [Schedule & reminders](08-schedule-and-reminders.md) | Name a routine's training days and get a local notification |
| 09 | [Units (kg / lb)](09-units.md) | A global unit toggle with a confirm dialog; history is never rewritten |
| 10 | [History & stats](10-history-and-stats.md) | Post-session recap, session history, lifetime totals, per-exercise charts |
| 11 | [Colour themes](11-themes.md) | Preset / custom / light / high-contrast themes, import & export |
| 12 | [First-run tutorial](12-first-run-tutorial.md) | A one-time coach-mark tour on first launch |
| 13 | [Offline & privacy](13-offline-and-privacy.md) | No network, no account, no telemetry — everything is on-device |

## App map (where features live on screen)

The app is a four-tab shell — **Today · Routines · History · Profile** — with
everything else pushed on top.

- **Today** — the current routine's training days (tap a day → **Start**), plus
  lifetime totals. When no routine is current, it shows a routine chooser.
- **Routines** — every routine; pick the current one or make a new one.
- **History** — every finished session, newest first; tap one for its recap.
- **Profile** — stats and the entry points into **Settings** (units, bar &
  plates, layoff rules, theme).
