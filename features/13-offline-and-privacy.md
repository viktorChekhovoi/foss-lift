# Offline & privacy

Everything is on-device. No network, no account, no telemetry.

## What it does

- **Makes no network connections and collects nothing** — no account, no server,
  no analytics.
- **Stores all data on-device** in a local SQLite database (drift).
- The only "notification" is a **local** one, scheduled on-device (see
  [schedule & reminders](08-schedule-and-reminders.md)); it never leaves the
  phone.

## How to use it

Nothing to configure — it's the whole design of the app. There's no sign-in and
no connectivity requirement; the app works fully offline.

## Behaviour & edge cases

- **The UI never touches SQLite directly** — screens watch providers, providers
  call the single `AppDatabase`. (An architectural rule, but it's why there's one
  well-defined place all data lives.)
- **Reminders are the only platform integration**, and they're on-device and
  Android-only.

## Where it lives

- Database: `lib/data/database.dart` (drift over SQLite).
- Privacy statement: [`../PRIVACY.md`](../PRIVACY.md).
- The offline/on-device principles: [`../ARCHITECTURE.md`](../ARCHITECTURE.md),
  [`../CLAUDE.md`](../CLAUDE.md).

## Related issues

None — this is a foundational constraint, not a tracked feature.
