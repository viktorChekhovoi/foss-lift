# Text size

The app follows the phone's text setting, and can be nudged on top of it.

## What it does

- **Follows the system text size.** Android's own setting is system-wide and
  already discoverable; the app renders at whatever it says.
- **Offers a nudge of its own** — Smaller / Default / Larger / Largest — for
  wanting *this* app bigger without enlarging everything else, or smaller to fit
  more of a workout on screen.
- **Holds the result in a range every screen is checked at**, so no combination
  of the two produces a layout nobody has seen.

## How to use it

Profile → Settings → **Text size**. Each chip is drawn at the size it selects,
because how big the words get is the only thing the control is about.

The phone's own setting is under Android's display settings and needs nothing
here — **Default** means "whatever the phone says".

## Behaviour & edge cases

- **The nudge multiplies the phone's setting; it does not replace it.** Somebody
  who has already set their phone large should not have to set it again here,
  and should not lose that choice by touching this one.
- **The product is clamped to 0.85×–2.0×.** Two multiplied scales reach sizes
  nobody has looked at — a phone at 2.0 and the app at Largest is 2.6 — and a
  control that can produce an unchecked layout is not an accessibility feature.
  2.0 is the ceiling because 2.0 is what the sweep covers; the floor is where
  the set rows stop being readable across a gym.
- **Every screen is swept at every scale, and overflow fails the build.** Most
  of the app's text carries a hard-coded `fontSize` and several layouts are
  built from fixed widths, so "it survives a large font" is not something anyone
  can hold in their head. The feature test mounts each screen at 1.0×, 1.3× and
  2.0× on a 360 dp viewport and fails on any render overflow.
- **The dialogs and sheets are swept too**, and they are the tighter case: a
  dialog is bounded on both axes by its own insets, and none of it is on screen
  for the screen sweep to see. Covered at 1.0× and 2.0× — overflow only grows
  with scale, so what holds at the ceiling holds below it — and reached the way
  a user reaches them, by opening the real control on the real screen. That is
  where the stepper and the to-failure checkbox turned up.
- **Where a row runs out of width, the label gives and the control does not.**
  A section heading ellipsises before its action is pushed off the edge; the
  warm-up group's "· 3 sets" gives before the word "WARM-UP"; the live board's
  "WORKING SETS" gives before the weight beside it; a number stepper's value
  ellipsises before either of its buttons, because a stepper you cannot press is
  not a stepper. All of them are the same rule: the part that only names things
  yields to the part you touch.

## Where it lives

- The arithmetic: `lib/util/text_scale.dart` (`resolveTextScale`,
  `kTextScaleChoices`, and the two bounds).
- Applied once, at the app root in `lib/main.dart`, so every route inherits it.
- Stored as `Settings.textScale`; read through `textScaleProvider`.

## Related issues

- [#46 Text does not scale](https://github.com/viktorChekhovoi/foss-lift/issues/46) — shipped, in review
