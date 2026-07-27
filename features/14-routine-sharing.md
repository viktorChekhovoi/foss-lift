# Sharing a routine

A whole programme — days, slots, rep schemes, progression rates and the custom
exercises it depends on — as one line of text you can paste into a message.

## What it does

- **Export.** Any routine becomes a **routine code**: a versioned, compressed,
  base64 line beginning `FLR1.` It carries the routine's name, colour, default
  rest and training days; every workout in order; every exercise slot with its
  full configuration; and a definition of every exercise the routine references.
- **Two ways out.** Show a QR, or send a `fosslift://routine/…` link. Both carry
  the same code — nothing is uploaded, and none of it touches the network. The
  system share sheet is where "copy" lives; there is no separate copy button and
  no file to save.
- **Import.** A scanned QR, a tapped link or a pasted code lands on a
  confirmation screen. Nothing is written until you accept it.
- **Custom exercises travel with the routine.** A programme built around your own
  "Zercher Squat" arrives complete; the recipient does not need it beforehand.
  What travels is what identifies the movement and how it is loaded — the name,
  muscle group, equipment, weight type and bar — plus a video link, if there is
  a video behind it.
- **A name clash is your call.** If an incoming exercise has the same name as one
  already in the library — and its definition differs — the import asks whether
  to replace yours or keep it. Keeping is the default.

## How to use it

- **Send one:** Routines → open a routine → the share icon → **Show QR** or
  **Send link**.
- **Receive one:** Routines → scroll past **+ New routine** to **IMPORT A
  ROUTINE** → **Scan QR** or **Paste code**. A `fosslift://routine/…` link tapped
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
  shareable as a link. It takes a routine carrying dozens of
  long, genuinely dissimilar custom-exercise descriptions to get there —
  ordinary wordy ones deflate away.
- **The symbol is drawn as large as the screen allows.** Density is the real
  limit on scanning a screen with a camera, so the QR is sized off the screen
  rather than a fixed 220 pixels: every logical pixel per module is one the
  other phone does not have to guess at. It measures the *screen* and not its
  parent, and pins the result with a fixed box, because `QrImageView` asks its
  parent how big it is and a dialog asks its content the same question in a
  form that cannot be answered that way — which is how **Show QR** came to dim
  the screen and paint nothing at all.
- **The paste box owns its own field.** A dialog's controller has to belong to
  something that dies with the dialog: `showDialog`'s future completes when the
  route is *popped*, which is the start of the dismissal and not the end of it,
  so disposing at the await left the field using a dead controller for the
  length of the fade. That threw a red frame on every paste — the one reported
  against invalid codes, though a good code and a plain Cancel did it just as
  much.
- **Every host the app shares needs an Android intent filter**, or the link is
  inert outside the app however well the routing handles it. Routines were
  shareable for a while against a manifest that named only `theme`, so a
  routine link opened nothing; a test now reads the manifest and checks each
  host is listed. Chat apps still show a `fosslift://` link as plain text
  rather than a tappable one — a custom scheme is not auto-linkified the way
  `https` is, and that trade-off is the price of needing no domain and no
  server. Long-pressing and opening it works; an https App Link can be added
  alongside later without invalidating a single code already shared.
- **Progress does not travel.** The success/failure streaks and the sender's
  reminder time are left behind: they are facts about the sender's training and
  their notifications, not about the programme. Everything else — including the
  training-day schedule — comes across.
- **Built-in exercises travel by name.** The starter library is on both phones,
  so a shared routine names them rather than copying their instruction text.
  They are matched case-insensitively on import.
- **Your own notes never travel, and are never overwritten.** The note you keep
  on a movement — the seat setting, the rack pin — is a fact about your gym, so
  it is not in the code you send and it survives an import of someone else's,
  including **Replace**, which rewrites everything else about the exercise. See
  [the exercise library](01-exercise-library.md).
- **An exercise that already exists is reused, never duplicated.** Importing the
  same routine twice gives you two routines and one copy of each exercise.
- **Replacing edits in place.** Choosing **Replace** rewrites the existing
  exercise's definition and keeps its id, so its logged history and every other
  routine pointing at it survive.
- **An import always creates a new routine.** Nothing existing is overwritten,
  and the new routine does not take over Today — the current routine is left
  where it was.
- **A code that will not read is a dead end.** The two failures — not a routine
  code at all (which includes any tag that is not `FLR1`), or damaged in
  transit — each say which, and neither offers a partial import.

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
- Links: `lib/services/deep_links.dart` maps `fosslift://routine/<code>`; the
  intent filter that gets Android to hand one over is in
  `android/app/src/main/AndroidManifest.xml`.

## Related issues

- [#15 Share routines: export / import](https://github.com/viktorChekhovoi/foss-lift/issues/15)
- [#27 Portable theme code](https://github.com/viktorChekhovoi/foss-lift/issues/27) — the same idea, one feature earlier
- [#50 Share links do not open the app, and the QR dialog comes up blank](https://github.com/viktorChekhovoi/foss-lift/issues/50) — shipped, in review
