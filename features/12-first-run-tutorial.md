# First-run tutorial

A one-time coach-mark tour that runs on first launch.

## What it does

- On first launch, opens on a **welcome card** — what the app is, and the
  choice to take the tour or not.
- Then overlays a guided **coach-mark tour** that points at the key parts of
  the UI to get a new user started.
- Runs **once** — a flag records that it's been seen, so it never reappears.

## How to use it

It appears by itself the first time the app is opened: **Take the tour** to walk
through it, **Not now** to dismiss. Replay it any time from Profile → Help &
tour, which also starts at the welcome.

## Behaviour & edge cases

- **Shown once, then remembered.** `Settings.tutorialSeen` records that the tour
  has run.
- **Anchored to real UI.** The overlay attaches its callouts to on-screen anchors
  rather than hard-coded positions.
- **It covers the live workout, which it cannot point at.** The board, the rest
  timer and the workout in the notification shade are where the app is least
  like every other tracker and the most worth a sentence — and none of them
  exists until a session is running. A tour that started a workout to show you a
  workout would leave you somewhere you did not ask to be, so those steps are
  told rather than pointed at, anchored to the card that leads there.
- **Every anchored step is on the Today tab.** The tour drives no navigation, so
  a step aimed at a screen you have to open would spotlight a rectangle that is
  not there.
- **It introduces itself before it points at anything.** Opening straight into
  an arrow aimed at a card, before the app has said what it is or that a tour is
  happening, reads as a malfunction rather than a greeting. So the first step
  has no anchor at all — a plain dimmed screen and a card in the middle of it —
  and it is the step a replay starts from too.
- **The greeting stacks its two answers.** "Take the tour" over "Not now",
  rather than side by side: they are two long labels in a callout narrower than
  either the phone or the font can be relied on to be. Every later step is a
  short Skip / Back / Next and fits across.
- **Declining ends it cleanly** — the same path as skipping mid-tour, including
  recording that the tour has been seen.

## Where it lives

- Overlay + anchors: `lib/widgets/tutorial.dart`.
- Seen flag: `Settings.tutorialSeen` in `lib/data/database.dart`.

## Related issues

- [#18 Interactive first-run tutorial](https://github.com/viktorChekhovoi/foss-lift/issues/18) — shipped, in review
- [#44 The tour started mid-sentence](https://github.com/viktorChekhovoi/foss-lift/issues/44) — shipped, in review
- [#64 The tour had not mentioned anything added since it was written](https://github.com/viktorChekhovoi/foss-lift/issues/64) — shipped, in review
