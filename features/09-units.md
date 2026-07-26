# Units (kg / lb)

A single global unit toggle. Weights are stored canonically in kilograms and
converted on the fly.

## What it does

- One app-wide setting: **kg** or **lb**.
- Every weight in the app is displayed in the chosen unit; the plate rack you see
  follows the unit too.
- **Switching units pops a confirm dialog** first.

## How to use it

Profile → Settings → tap **kg** or **lb**. Tapping the unit you're already on
does nothing (it isn't a switch). Tapping the other one opens a confirmation
dialog before it takes effect.

## Behaviour & edge cases

- **History is never rewritten.** Weights are stored in kilograms, so switching is
  pure display arithmetic — a 100 kg squat reads as 220.5 lb, which is not a bar
  anybody loads. That's exactly why the switch **confirms first**: the dialog says
  what to go and check, rather than letting the surprise be found mid-set.
- **Each unit has its own plate rack.** A rack is a set of *sizes*, not weights;
  the values inside stay canonical kilograms, but *which* rack you see follows the
  unit (see [plate math](07-plate-math.md)).

## Where it lives

- Conversion helpers: `lib/util/units.dart` (pure functions).
- Toggle + confirm dialog: `lib/screens/settings_screen.dart` (`_switchUnit`).
- Read via `weightUnitProvider` (`.value ?? 'kg'`).

## Related issues

- [#5 Units of measurement (kg/lb)](https://github.com/viktorChekhovoi/foss-lift/issues/5) — shipped
