# Offline & privacy

Everything is on-device. No network, no account, no telemetry.

## What it does

- **Makes no network connections and collects nothing** — no account, no server,
  no analytics.
- **Stores all data on-device** in a local SQLite database (drift).
- The only "notification" is a **local** one, scheduled on-device (see
  [schedule & reminders](08-schedule-and-reminders.md)); it never leaves the
  phone.
- **Says so, once, on an About screen** — what the app does with your data, the
  licence, and an address to report a bug to.

## How to use it

Nothing to configure — it's the whole design of the app. There's no sign-in and
no connectivity requirement; the app works fully offline.

**About:** Profile → **About Foss Lift**. **Report a bug** opens a pre-addressed
draft in whatever handles mail; the address is printed underneath as well, and
long-pressing it copies it, so a phone with no mail app still leaves you
something to act on.

## Behaviour & edge cases

- **The UI never touches SQLite directly** — screens watch providers, providers
  call the single `AppDatabase`. (An architectural rule, but it's why there's one
  well-defined place all data lives.)
- **Reminders are the only platform integration**, and they're on-device and
  Android-only.
- **The three outward hand-offs are all to another app you can see:** a demo
  link to the browser, a share code to the system share sheet, and a bug report
  to a mail app. None of them is the app talking to a server — it holds no
  network permission to do so with.
- **The promise is stated once**, on About, rather than repeated as reassurance
  on every screen that shares something. See the UI-text rule in `CLAUDE.md`.

## Where it lives

- Screens: `lib/screens/about_screen.dart`.
- Database: `lib/data/database.dart` (drift over SQLite).
- Privacy statement: [`../PRIVACY.md`](../PRIVACY.md).
- The offline/on-device principles: [`../ARCHITECTURE.md`](../ARCHITECTURE.md),
  [`../CLAUDE.md`](../CLAUDE.md).

## Related issues

None — this is a foundational constraint, not a tracked feature.
