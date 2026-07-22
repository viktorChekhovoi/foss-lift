# FossLift

An open-source, offline-first **workout tracker** for Android, built with Flutter.

FossLift keeps everything on your device — no account, no server, no telemetry.
You build routines from an exercise library, then run and log them.

## Features

- **Exercise library** — a curated, searchable set of exercises (each with a
  form cue and a demo link), plus your own **custom exercises**.
- **Routine builder** — create, edit, reorder, and delete routines. Per
  exercise: sets, a fixed rep count / a **range** (e.g. 6–8) / **to failure**,
  a rest override, and a suggested weight.
- **Live workout logging** — start a routine, edit weight & reps per set, tick
  sets off, and watch **duration and set count** update live. The rest timer
  uses each exercise's configured rest, with shorter/longer/skip controls.
- **Units** — global **kg / lb**. Weights are stored canonically and converted
  on the fly, so switching units never rewrites your history.
- **Session summary & history** — per-session recap and every finished session,
  newest first.
- **Local database** — all data stored on-device via SQLite (drift).

See the [issue tracker](https://github.com/viktorChekhovoi/foss-lift/issues) for
the full ranked roadmap (progression engine, plate math, progress charts,
sharing, reminders, themes) — `p1`/`p2`/`p3` are the priority tiers.

## Tech stack

| Concern | Choice |
|---|---|
| UI | Flutter (Material 3, custom dark theme) |
| State | [Riverpod](https://riverpod.dev) (`Notifier` / `StreamProvider`) |
| Navigation | [go_router](https://pub.dev/packages/go_router) (stateful shell + tabs) |
| Database | [drift](https://drift.simonbinder.eu) over SQLite |

## Project layout

For a mid-level tour of how everything fits together, see
[`ARCHITECTURE.md`](ARCHITECTURE.md).

```
lib/
├── main.dart                 App entry, ProviderScope, theme, router
├── router.dart               go_router config (tabs + pushed routes)
├── theme/app_theme.dart      Palette & Material theme (see design/mockup.html)
├── data/database.dart        Drift tables, queries, first-run seed
├── data/database.g.dart      Generated (drift codegen)
├── providers/                Riverpod providers
├── state/active_workout.dart In-memory live-session model + controller
├── util/units.dart           kg/lb conversion helpers
└── screens/                  Today · Routines · Detail · Builder · Library ·
                              Exercise · Workout · Summary · History · Profile · Settings
design/
└── mockup.html               Clickable HTML UI mockup — the visual spec
```

## Getting started

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) and an
Android device or emulator.

```bash
flutter pub get
dart run build_runner build   # regenerate database.g.dart after schema changes
flutter run                   # launch on a connected device/emulator
flutter test                  # run unit tests
flutter analyze               # static analysis
```

To build and test on a phone or the Android Studio emulator, see
[`RUNNING.md`](RUNNING.md).

## License

[MIT](LICENSE) © 2026 Viktor Chekhovoi
