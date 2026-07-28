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
- **The camera is used twice, and the two uses are not alike.** Scanning a QR
  examines frames and drops them — nothing is kept. Filming a set
  ([set videos](16-set-videos.md)) **writes a file**, and it is the first data
  the app holds that is recognisably a person. So it is fenced:
  - clips live in app-private storage, never the shared gallery, never anywhere
    another app can enumerate them;
  - there is **no upload path and no share sheet** for a clip. Every other
    shareable thing in the app has one; this deliberately does not;
  - recording is the only way one gets in — nothing is imported from the
    gallery, which would need read access to shared storage;
  - **no audio is ever captured**, which also means the app never asks for the
    microphone;
  - the camera is opened only while filming and released immediately after.
- **Clips are the one thing that can fill a phone**, so what they cost is shown
  in Settings with a way to reclaim it — and nothing is ever deleted
  automatically, because every rule that could be would bin the oldest recording
  first. See [set videos](16-set-videos.md).

## Where it lives

- Screens: `lib/screens/about_screen.dart`.
- Database: `lib/data/database.dart` (drift over SQLite).
- Clip storage: `lib/services/set_video_store.dart`.
- Privacy statement: [`../PRIVACY.md`](../PRIVACY.md).
- The offline/on-device principles: [`../ARCHITECTURE.md`](../ARCHITECTURE.md),
  [`../CLAUDE.md`](../CLAUDE.md).

## Related issues

None — this is a foundational constraint, not a tracked feature.
