# First-run tutorial

A one-time coach-mark tour that runs on first launch.

## What it does

- On first launch, overlays a guided **coach-mark tour** that points at the key
  parts of the UI to get a new user started.
- Runs **once** — a flag records that it's been seen, so it never reappears.

## How to use it

It appears by itself the first time the app is opened. To see it again, reset
app data (a fresh install / cleared storage) so the "seen" flag is unset.

## Behaviour & edge cases

- **Shown once, then remembered.** `Settings.tutorialSeen` records that the tour
  has run.
- **Anchored to real UI.** The overlay attaches its callouts to on-screen anchors
  rather than hard-coded positions.

## Where it lives

- Overlay + anchors: `lib/widgets/tutorial.dart`.
- Seen flag: `Settings.tutorialSeen` in `lib/data/database.dart`.

## Related issues

- [#18 Interactive first-run tutorial](https://github.com/viktorChekhovoi/foss-lift/issues/18) — shipped, in review
