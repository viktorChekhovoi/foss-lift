# FossLift

An open-source, offline-first **workout tracker** for Android, built with Flutter.

FossLift keeps everything on your device — no account, no server, no telemetry.
v1 focuses on the two things you do every session: **run a routine** and **log
your sets**.

## Features (v1)

- **Routines / templates** — reusable workout plans (Push / Pull / Legs seeded to
  start). Each lists its exercises and target sets × reps.
- **Live workout logging** — start a routine, edit weight & reps per set, tick
  sets off, and watch **duration, volume, and set count** update live. A rest
  timer starts automatically after each completed set.
- **Session summary** — duration, total volume, sets, and a per-exercise recap.
- **History** — every finished session, newest first.
- **Local database** — all data stored on-device via SQLite (drift).

## Tech stack

| Concern | Choice |
|---|---|
| UI | Flutter (Material 3, custom dark theme) |
| State | [Riverpod](https://riverpod.dev) (`Notifier` / `StreamProvider`) |
| Navigation | [go_router](https://pub.dev/packages/go_router) (stateful shell + tabs) |
| Database | [drift](https://drift.simonbinder.eu) over SQLite |

## Project layout

```
lib/
├── main.dart                 App entry, ProviderScope, theme, router
├── router.dart               go_router config (tabs + pushed routes)
├── theme/app_theme.dart      Palette & Material theme (see design/mockup.html)
├── data/database.dart        Drift tables, queries, first-run seed
├── data/database.g.dart      Generated (drift codegen)
├── providers/                Riverpod providers
├── state/active_workout.dart In-memory live-session model + controller
└── screens/                  Today · Routines · Detail · Workout · Summary · History · Profile
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

## License

[MIT](LICENSE) © 2026 Viktor Chekhovoi
