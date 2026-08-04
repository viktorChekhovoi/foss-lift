# CLAUDE.md

Guidance for Claude Code when working in this repository.

# Key coding strategy

Do not deviate from these rules. They describe important approaches to writing code and features.

1. NEVER write 'implementation tests'
2. Only write integration tests based on feature descriptions outlined in 'features/'
3. Always notify me when 'features/' is changed at all — say which entry ids were added, reworded or deleted. Every feature now starts there, so this is a summary of the change, not an alarm.
4. Aim for high test coverage; 100% is not necessary, but each uncovered line should have good reason for being skipped - e.g., 'this line is for a rare filesystem exception'
5. When implementing any changes, follow **feature → red → green → refactor**:
    1. **Feature.** Write the spec into `features/catalogue/*.yaml` first — one entry per behaviour, phrased as what the app will do, tagged with its `screen` and its `defines`/`uses` concepts. Take the delta from the GitHub issue or user description. If the issue is ambiguous, resolve it before writing the entry, and record the answer as an issue comment.
       Run `dart run tool/features.dart --check` and fix what it rejects. The entries are now the specification.
       **Do not skip to step 2 with the spec in your head.** An entry written afterwards describes whatever got built, which is not a specification — it is a changelog with the disagreements edited out.
    2. **Red.** Spawn an agent with those entries and other relevant context from 'features/', and have it write integration tests that follow them. The tests must fail, and you must see them fail — a test that passes before the code exists is testing nothing.
    3. **Green.** Write the code to make the tests pass without a focus on efficiency.
    4. **Refactor.** Improve the code while keeping the tests passing, to remove code duplication, inefficiencies, and suboptimal practices.
    5. Regenerate the pages (`dart run tool/features.dart`) and tick the issue's acceptance criteria. The HTML is gitignored — do not commit it.
6. Do NOT write duplicate code. DO NOT NEVER EVER
7. For every change, assume this app has users on the shipped build. Their data has to survive the update, and formats already in the wild have to keep being readable — see "The app has shipped" below. If a change cannot be made without breaking that, say so and wait rather than deciding for me.
8. When a change alters behaviour that is already catalogued, **edit that entry in place**. Never add a second entry describing the new behaviour beside the old one — the catalogue is what the app does now, not a changelog.
9. **Keep the concept graph honest.** `defines`/`uses` in `features/catalogue/*.yaml` are load-bearing, not decoration: they are how anyone answers "if I change this, what else has to move?", and a missing link is a silent answer of "nothing". So whenever you touch an entry or add one:
    - Tag every concept the described behaviour actually depends on, not just the obvious one. If the prose leans on bar weight, plate math, units or the progression step, those belong in `uses` even when the entry is filed under another section.
    - `defines` means the concept lives here — one entry per concept, and defining subsumes using it. Never list a concept in both columns of the same entry.
    - A concept that does not exist yet gets added to `concepts.yaml` in the same change. Do not reach for an approximate existing concept because it is already there.
    - When behaviour moves or grows, re-check the links you did not touch. An entry whose `uses` list stopped matching its own prose is worse than an untagged one, because the graph now asserts something false.
    - `dart run tool/features.dart --check` catches an unknown concept and an unused one. It cannot catch a link you failed to write — that check is yours, and it is the one that matters.

## Key writing style guide
Use clear, natural, moderately formal English. Assume the reader is a competent developer who is unfamiliar with this project.

### Style requirements:

* Prefer active voice and concrete verbs.
* Use technical terminology when it is more precise than a simpler substitute.
* Keep sentences concise, but vary their length and structure naturally.
* Explain why something matters ONLY when the reason is not obvious.
* Address the reader as “you” only for instructions.
* Use imperative verbs for procedural steps.
* Make each paragraph serve one clear purpose.
* Preserve important implementation details, limitations, and tradeoffs.

### Avoid:

* Marketing language such as “powerful,” “robust,” “seamless,” or “cutting-edge.”
* Empty transitions such as “Additionally,” “Furthermore,” and “It is worth noting that.”
* Phrases such as “This section will explain,” “Whether you are…,” or “By following these steps…”
* Repeating the same point in the introduction, body, and conclusion.
* Excessive bullet lists when ordinary paragraphs would read better.
* Artificially simplified sentences or definitions of concepts the intended reader is expected to know.
* Claims that are not supported by the source material.
* Invented benefits, behavior, configuration, or implementation details.

The result should sound like it was written and edited by an engineer who understands the project.

Before returning the section, silently remove redundant sentences, generic filler, unnecessary adjectives, and any statements that merely announce what the text is about.

### Line breaks

**Hard-wrap commit messages. Hard-wrap nothing else.** A commit message is read in a terminal at a fixed width, so it is filled to 72–78 columns by hand. Everywhere else, write one line per paragraph, per bullet and per list item, however long it runs, and let the renderer wrap it.

That means no column fill in GitHub issue bodies, issue comments, PR descriptions, release notes, markdown docs, YAML strings or code comments that render anywhere. A hard-wrapped paragraph in a web textarea breaks in the wrong places at every window width, and every later edit means rewrapping the paragraph around it.

Existing files that are already filled stay as they are — rewrapping one is a diff with no content in it. Write new text unwrapped, and unwrap a paragraph when you are already rewriting it.

## What this is

FossLift — an offline, on-device Flutter workout tracker. No network, no auth,
no telemetry. Read `ARCHITECTURE.md` before touching code; it is the map.
`RUNNING.md` covers building and running on a phone or emulator.
`design/mockup.html` is the visual spec.

## Feature tracking

**You never file issues.** The GitHub backlog is mine to write. Do not run `gh
issue create`, do not edit an issue body, do not close an issue. If something
worth doing surfaces mid-task, tell me about it in your reply and let me decide
whether it becomes an issue — the only exception is when I explicitly ask you to
open one.

Work comes from what I tell you, and from issues I point you at. `features.txt`
is a stub; do not add features to it.

`features/` is the catalogue of what the app does, as YAML. Issues and my
instructions are the deltas; the catalogue is the result. It is written
**before** the code — see rule 5 above.

The source is `features/catalogue/*.yaml`, `concepts.yaml` and `screens.yaml`.
**The HTML there is generated and gitignored — never edit it, never commit it.**
A fresh clone has none until you run `dart run tool/features.dart`; `--check`
validates the source without writing. `features/README.md` has the entry format
and the `defines`/`uses` concept graph.

Reading the backlog is fine and often useful:

```bash
gh issue list --label p1              # what's next
gh issue view 8                       # the spec for a feature
gh issue list --state all --label shipped
```

Labels: `p1`/`p2`/`p3` are priority tiers (roughly: next / soon / later).
`area/*` groups by subsystem. `blocked` means another issue must land first —
the blocker is named in the body.

### Before implementing

1. If I named an issue, `gh issue view <n>` — the body has the behaviour spec
   and acceptance criteria. Work to those criteria, not to a paraphrase of the
   title.
2. Check the `blocked` label and any "Depends on #n" line. If the dependency is
   still open, say so rather than working around it.
3. If the spec is ambiguous, ask me. Record the answer in the catalogue entry you
   write in step 5.1, which is where the next session will look for it.

### While implementing

Keep a note of non-obvious decisions ("kept text entry for >12 reps;
tap-cycling is too slow") and put them in your reply to me. Do not write them to
the issue.

### After implementing

1. Use a `Refs #<n>` trailer in the commit message when the work traces to an
   issue — **not** `Closes`/`Fixes`, which GitHub auto-closes on a push to
   `main` and would skip my review.
2. Report to me: what was built, the commit(s) that did it, which acceptance
   criteria are unmet and why, anything I should check by hand on a device, and
   any decision I might want to overrule.
3. **Say how to see it in the app.** End with the taps: where to start, what to
   tap in order, and what should be on screen at the end. Include how to reach
   any state the feature needs (a barbell exercise with a weight set, a workout
   left untrained for a fortnight) — a feature nobody can find is a feature
   nobody reviewed. Green tests are not this; they prove the logic, not that the
   thing is reachable and reads well on a phone.

   ```
   Profile → Settings → Bar & plates → tap "Bar weight" → 15 → Save.
   Then Today → Push → Start: Bench Press should read 20 kg/side over a 15 kg bar.
   ```

### New ideas

If something worth doing surfaces mid-task, tell the user about it rather than
silently expanding scope. Do not open an issue for it unless they ask.

## Out of scope — do not build these

These were considered and explicitly rejected. If one seems necessary, raise it
rather than implementing it.

- Lifetime "routines completed" as a stat — pointless.
- Adding sets during a live workout.
- A "build" button next to "start a routine". That screen is for working out,
  not editing. An edit icon that navigates to the routine/workout editor is fine.
- A live contrast ratio in the colour picker. Designing a palette to a number is
  what the two high-contrast presets are for, and they are already checked
  against WCAG so nobody has to do it by hand. The preview's binary "this text is
  hard to read on this background" warning stays — that is guidance; a running
  ratio would make the picker an accessibility workbench it is not meant to be.

## The app has shipped — every change must install cleanly as an update

**There are existing installs.** Phones hold FossLift databases, shared routine
codes and exported files that this repository has to keep being able to read.
An update that loses somebody's training log is not a bug to fix in the next
build; the log is gone.

So: **every change is an upgrade path.** Someone on the shipped build must be
able to install the new one on top and find their history, their routines and
their settings where they left them.

- **The drift schema climbs.** Changing a table means bumping `schemaVersion`
  and adding an `onUpgrade` rung that takes the previous version to the new one.
  Never edit a rung that has shipped and never renumber one — the input to a
  migration is a real database on a real phone, and rewriting history in the
  ladder means the phone climbs the wrong steps. Adding a nullable column or one
  with a default is the cheap case; anything that drops or retypes a column
  needs the rung to carry the data across, not just the shape.
- **Wire formats are frozen.** `kMuscleGroups`, `kEquipmentTypes` and the `FLR1`
  flag bits are append-only: add at the end, never reorder, never renumber,
  never reuse a retired slot. Somebody is holding a code that was written
  against the old numbering, and it has to keep decoding. A format that genuinely
  cannot be extended gets a new version tag (`FLR2`) with the old reader kept
  beside it, not a redefinition of the old one.
- **Data loss is a consideration.** A removed column takes what was in it. If a
  feature goes, decide explicitly what happens to what it stored — migrated into
  its replacement, or dropped on purpose and said so.
- **Say so if an upgrade cannot be clean.** Some changes genuinely cannot
  preserve everything. That is a decision for me to make, not one to make
  quietly inside a commit: raise it, say what would be lost, and wait.

If I tell you a particular change may break compatibility, take that as given
for that change and note it in the commit. Otherwise the rule above holds.

Comments in the source still describe the pre-release period in places — the
frozen-from-first-release notes on the flag bits, and the `schemaVersion`
comment. Those are now history rather than instructions; the rule above is what
applies.

## Writing UI text

**Label the control. Do not explain the concept.** This is a rule about screens,
not about source comments — comments explain as much as they need to.

The recurring failure is a caption that teaches the user a noun they can already
see: "No workouts yet — a routine is made of training days, like Push, Pull and
Legs." They opened the routine builder. They know. Write "No workouts yet."

Apply this on sight, without being asked again:

- **Cut any sentence that defines a word the screen already shows.** If the
  label says "Training days", nothing underneath needs to say what a training
  day is.
- **Cut reassurance nobody asked for.** "None of this touches the network",
  "nothing is written until you save", "you can switch back at any time" — say
  it once in About, or not at all. Repeated on every screen it reads as
  nervousness.
- **One line, or none.** A helper paragraph under a control is a sign the
  control is wrong. Fix the control.
- **Prefer the shorter word.** "the gym default" → "default". "Someone shared
  one" → "Import a routine".
- **A warning that changes what someone does is not a caption** and stays: the
  unit-switch dialog, the contrast warning in the theme preview, "this is not
  medical advice" on the warm-up ramp.

## Conventions

- **UI never touches SQLite directly.** Screens watch Riverpod providers;
  providers call methods on the single `AppDatabase`.
- **Weights are stored in kilograms.** kg/lb is a display concern only — see
  `lib/util/units.dart`. Never rewrite stored history on a unit switch.
- **The live workout is in-memory** (`lib/state/active_workout.dart`) and only
  writes to the DB on Finish. Keep it that way.
- `lib/data/database.g.dart` is generated. Never edit it; run
  `dart run build_runner build --delete-conflicting-outputs` after schema
  changes.
- Update the table list in `ARCHITECTURE.md` when the drift schema changes.
- **Android today, iOS later — write nothing that assumes otherwise.** There is
  no `ios/` directory yet, but the port is planned, so new code has to survive
  it. In particular: **never store an absolute path** (the iOS app-container
  path contains a UUID that changes on reinstall and restore, so an absolute
  path works on Android and silently dangles on iOS), and gate platform-specific
  features on `Platform.is*` so they degrade rather than crash — as
  `Reminders.supported` does. See issue #33.

## Commands

```bash
flutter analyze          # lints — must be clean
flutter test             # pure-logic unit tests
flutter run              # see RUNNING.md for device setup
```
