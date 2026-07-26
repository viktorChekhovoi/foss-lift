# Schedule & reminders

A routine can name the weekdays it's meant to be trained on, and ask for a local
notification on them.

## What it does

- Stores which **day of the week** a routine is trained on (a day mask).
- Optionally fires **one local notification per routine** at a chosen time on
  those days.
- Everything is on-device — no server, nothing leaves the phone.

## How to use it

Open a routine → **edit** → set its **training days** and, optionally, a
**reminder time**. Leave the reminder off and no notification is scheduled.

## Behaviour & edge cases

- **The next reminder is computed, not stored.** It's the next scheduled day
  strictly after now, skipping today if the routine was already trained today,
  and wrapping a week for a once-weekly schedule.
- **Reminders re-sync from a single place.** A schedule edit, a finished session,
  and a fresh launch all converge on the same pending notification — the app
  cancels and re-lays the next reminder on every sync.
- **Scheduled inexactly on purpose.** An exact alarm needs a permission Android 14
  makes the user grant by hand, and a nudge to go to the gym doesn't need to land
  on the second.
- **Android-only.** The service is a no-op off Android, so tests never touch a
  platform channel. Android needs `RECEIVE_BOOT_COMPLETED`, the plugin's
  receivers, and core-library desugaring (see `RUNNING.md`).

## Where it lives

- Pure decision: `lib/data/schedule.dart` (`nextReminderAt`).
- Service: `lib/services/reminders.dart` (`ReminderService`).
- Wired via `reminderSyncProvider`, watched in `lib/main.dart`.
- Edited in `lib/screens/routine_edit_screen.dart`.

## Related issues

- [#17 Routine frequency, workout-time tracking and reminders](https://github.com/viktorChekhovoi/foss-lift/issues/17) — planned/partial
