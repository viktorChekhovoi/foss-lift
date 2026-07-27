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
  What travels is what identifies the movement and how it is loaded — the name,
  muscle group, equipment, weight type and bar — plus a video link, if there is
  a video behind it.
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
- **There is nothing wordy left to carry.** An exercise used to hold a coaching
  cue, which was both the largest field on the row and the largest thing in a
  routine code; it was removed from the app entirely. Dropping it
  took a custom exercise from about 55 characters on the wire to a handful. See
  [the exercise library](01-exercise-library.md).
- **A video link travels as its id.** Any YouTube URL — `watch?v=`, `youtu.be`,
  `/shorts/`, `/embed/`, with or without timestamps, playlists and tracking
  parameters — is reduced to its eleven-character id and rebuilt as
  `https://youtu.be/<id>` at the other end. A link with no video behind it does
  not travel at all: the starter library's demo links are YouTube *searches*, and
  a search costs ninety characters to say nothing.
- **Names are capped at 200 UTF-8 bytes** on the wire — generous next to the 80
  the app itself enforces, so a legal name never loses characters here first,
  and bounded so a corrupt code cannot claim a megabyte of routine name. A
  longer one is cut rather than refused.
- **Defaults are not transmitted.** A slot only spends bytes on the fields that
  differ from the app's defaults, and the increment/deload defaults are read per
  progression mode — so the common routine encodes small. The PPL demo routine
  encodes to 421 characters, well inside a QR code.
- **A QR is offered whenever one can hold the routine.** The ceiling is the
  standard's, not an invented one: 2,331 bytes in a version-40 symbol at medium
  error correction, 2,953 at low. A routine that outgrows medium is painted at
  low rather than refused — a symbol with less redundancy still scans, and the
  alternative is no symbol. Past 2,953 the QR is withheld with an explanation
  rather than rendered as an unscannable smudge; the code is still perfectly
  shareable as a link, a copy or a file. It takes a routine carrying dozens of
  long, genuinely dissimilar custom-exercise descriptions to get there —
  ordinary wordy ones deflate away.
- **The symbol is drawn as large as the screen allows.** Density is the real
  limit on scanning a screen with a camera, so the QR takes the available width
  rather than a fixed 220 pixels: every logical pixel per module is one the
  other phone does not have to guess at.
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
- What a QR can hold, and what error correction it can afford:
  `lib/util/qr_capacity.dart` — read by both the codec (whether to offer one)
  and the widget (how to paint it).
- Landing an import: `lib/data/routine_import.dart` (which exercises are new,
  which clash) + `AppDatabase.importSharedRoutine`.
- Screens: `lib/screens/routine_share_screen.dart`,
  `lib/screens/routine_import_screen.dart`; the scanner is
  `lib/screens/scan_screen.dart`, shared with themes.
- Links: `lib/services/deep_links.dart` maps `fosslift://routine/<code>`.

## Related issues

- [#15 Share routines: export / import](https://github.com/viktorChekhovoi/foss-lift/issues/15)
- [#27 Portable theme code](https://github.com/viktorChekhovoi/foss-lift/issues/27) — the same idea, one feature earlier
