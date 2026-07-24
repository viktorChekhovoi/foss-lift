# Foss Lift

An open-source, offline-first **workout tracker** for Android, built with Flutter.

Foss Lift keeps everything on your device — no account, no server, no telemetry.
You build a programme from an exercise library, then run and log it while the app
handles the load: it steps your weights up when you succeed, backs them off when
you miss or come back from a break, and tells you which plates to put on the bar.

## Features

- **Exercise library** — a curated, searchable starter set (~30 exercises, each
  with a form cue and a demo link), plus your own **custom exercises**. Every
  exercise carries how it's measured (**reps** or a **timed hold**), its
  **weight type** (barbell / machine / dumbbell), and an optional bar of its own.
- **Routines, workouts, days** — a programme is three levels deep: a **routine**
  (e.g. Push/Pull/Legs) holds **workouts** (one training day each), and a workout
  holds **exercise slots**. Build, edit, reorder, and delete at every level.
- **Per-slot configuration** — sets, a fixed rep count / a **range** (e.g. 6–8) /
  **to failure** / a **timed hold**, a rest override, and a suggested weight.
- **Automatic progression** — each slot advances on one axis: add **weight**, add
  **reps**, or hold **longer**. Defaults work untouched (+2.5 kg after a clean
  session, −5 kg after two misses) and every rate is configurable. Loading the
  bar past the suggestion counts as progression on its own.
- **Layoff deloads** — measured per workout, so a split where Legs went untrained
  for a month is caught. A long enough gap **offers** a back-off before you start;
  nothing is applied without asking, and the session says why it's lighter.
- **Plate math** — for barbell lifts, the app solves which plates go on each side
  from the rack you actually own (per unit), breaks ties the way a lifter loads a
  bar, and goes gold when the weight you typed can't be built exactly.
- **Live workout logging** — start a day, edit weight & reps per set, tap sets
  off, and watch **duration and set count** update live. The rest timer uses each
  slot's configured rest, with shorter/longer/skip controls.
- **Schedule & reminders** — a routine can name its training weekdays and ask for
  a local notification on them. No server; the nudge never leaves the phone.
- **Units** — global **kg / lb**. Weights are stored canonically in kilograms and
  converted on the fly, so switching units never rewrites your history.
- **History & lifetime totals** — a per-session recap, every finished session
  newest-first, and running totals (volume, reps, sets) on the Today screen.
- **Local database** — all data stored on-device via SQLite (drift).

See the [issue tracker](https://github.com/viktorChekhovoi/foss-lift/issues) for
the ranked roadmap (progress charts & CSV export, routine sharing, colour themes,
a first-run tutorial, a warmup calculator) — `p1`/`p2`/`p3` are the priority
tiers.

## Tech stack

| Concern | Choice |
|---|---|
| UI | Flutter (Material 3, custom dark theme) |
| State | [Riverpod](https://riverpod.dev) (`Notifier` / `StreamProvider`) |
| Navigation | [go_router](https://pub.dev/packages/go_router) (stateful shell + tabs) |
| Database | [drift](https://drift.simonbinder.eu) over SQLite |
| Notifications | [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) (Android, on-device) |

## Project layout

For a mid-level tour of how everything fits together, see
[`ARCHITECTURE.md`](ARCHITECTURE.md).

```
lib/
├── main.dart                 App entry, ProviderScope, theme, router
├── router.dart               go_router config (tabs + pushed routes)
├── theme/app_theme.dart      Palette & Material theme (see design/mockup.html)
├── data/
│   ├── database.dart         Drift tables, queries, first-run seed
│   ├── database.g.dart       Generated (drift codegen)
│   ├── progression.dart      Progression axes + the step/deload rules
│   ├── layoff.dart           Gap → back-off rules for coming back
│   ├── plates.dart           Weight types + which plates load a bar
│   └── schedule.dart         Weekly day mask + when the next reminder falls
├── state/active_workout.dart In-memory live-session model + controller
├── services/reminders.dart   Local notification scheduling (Android)
├── providers/                Riverpod providers
├── util/                     kg/lb conversion + running-total formatting
├── widgets/                  Shared cards, builder chrome, the plate line
└── screens/                  Today · Routines · Detail · Builder · Library ·
                              Exercise · Workout · Summary · History · Profile ·
                              Settings (bar & plates, layoff rules)
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

## Privacy

Foss Lift makes no network connections and collects nothing. See
[`PRIVACY.md`](PRIVACY.md).

## License

[MIT](LICENSE) © 2026 Viktor Chekhovoi
