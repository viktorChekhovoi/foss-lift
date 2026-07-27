# Sharing a routine

A whole programme — days, slots, rep schemes, progression rates and the custom
exercises it depends on — as one line of text you can paste into a message.

## What it does

- **Export.** Any routine becomes a **routine code**: a versioned, compressed,
  base64 line beginning `FLR1.` It carries the routine's name, colour, default
  rest and training days; every workout in order; every exercise slot with its
  full configuration; and a definition of every exercise the routine references.
- **Four ways out.** Show a QR, send a `fosslift://routine/…` link, copy the
  code, or save it as a file. All four carry the same code — nothing is
  uploaded, and none of it touches the network.
- **Import.** A scanned QR, a tapped link, a pasted code or a saved file lands on
  a confirmation screen. Nothing is written until you accept it.
- **Custom exercises travel with the routine.** A programme built around your own
  "Zercher Squat" arrives complete; the recipient does not need it beforehand.
- **A name clash is your call.** If an incoming exercise has the same name as one
  already in the library — and its definition differs — the import asks whether
  to replace yours or keep it. Keeping is the default.

## How to use it

- **Send one:** Routines → open a routine → the share icon → **Show QR**,
  **Send link**, **Copy code** or **Save file**.
- **Receive one:** Routines → scroll past **+ New routine** to **SOMEONE SHARED
  ONE** → **Scan QR** or **Paste code**. A `fosslift://routine/…` link tapped
  anywhere on the phone opens the same screen.
- **Decide on clashes:** the confirmation screen lists every exercise that will
  be added, and every one whose name you already use. Each clash has a
  **Replace** switch, off by default.

## Behaviour & edge cases

- **The code is the whole routine.** There is no server, no id to look up, and
  nothing to expire. A code shared in 2026 still imports in 2030.
- **Defaults are not transmitted.** A slot only spends bytes on the fields that
  differ from the app's defaults, and the increment/deload defaults are read per
  progression mode — so the common routine encodes small. The PPL demo routine
  encodes to 421 characters, well inside a QR code.
- **A QR is offered only when it will scan.** Past
  `RoutineCode.qrLinkLimit` characters the code is still perfectly shareable as a
  link, a copy or a file, but the QR is withheld with an explanation rather than
  rendered as an unscannable smudge. A routine with several long custom
  exercises is the case that trips this.
- **Progress does not travel.** The success/failure streaks and the sender's
  reminder time are left behind: they are facts about the sender's training and
  their notifications, not about the programme. Everything else — including the
  training-day schedule — comes across.
- **Built-in exercises travel by name.** The starter library is on both phones,
  so a shared routine names them rather than copying their instruction text.
  They are matched case-insensitively on import.
- **An exercise that already exists is reused, never duplicated.** Importing the
  same routine twice gives you two routines and one copy of each exercise.
- **Replacing edits in place.** Choosing **Replace** rewrites the existing
  exercise's definition and keeps its id, so its logged history and every other
  routine pointing at it survive.
- **An import always creates a new routine.** Nothing existing is overwritten,
  and the new routine does not take over Today — the current routine is left
  where it was.
- **A damaged or newer-format code is a dead end.** The three failures — not a
  code, made by a newer version, damaged in transit — each say what to do, and
  none of them offers a partial import.

## Where it lives

- Wire format: `lib/data/routine_code.dart` (`FLR1`), on the shared primitives in
  `lib/data/share_code.dart` (varints, checksums, base64, version tags) that the
  theme code uses too.
- Landing an import: `lib/data/routine_import.dart` (which exercises are new,
  which clash) + `AppDatabase.importSharedRoutine`.
- Screens: `lib/screens/routine_share_screen.dart`,
  `lib/screens/routine_import_screen.dart`; the scanner is
  `lib/screens/scan_screen.dart`, shared with themes.
- Links: `lib/services/deep_links.dart` maps `fosslift://routine/<code>`.

## Related issues

- [#15 Share routines: export / import](https://github.com/viktorChekhovoi/foss-lift/issues/15)
- [#27 Portable theme code](https://github.com/viktorChekhovoi/foss-lift/issues/27) — the same idea, one feature earlier
