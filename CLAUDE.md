# CLAUDE.md

Guidance for Claude Code when working in this repository.

# Key coding strategy

Do not deviate from these rules. They describe important approaches to writing code and features.

1. NEVER write 'implementation tests'
2. Only write integration tests based on feature descriptions outlined in 'features/'
3. Always notify me when 'features/' is changed at all
4. Aim for high test coverage; 100% is not necessary, but each uncovered line should have good reason for being skipped - e.g., 'this line is for a rare filesystem exception'
5. When implementing any changes, follow the red-green-refactor strategy: 
    1. Take the delta-specification from Github Issues or 'features/'
    2. Spawn an agent with that delta information and other relevant context from 'features/', and have it write integration tests that follow this spec
    3. Write the code to make the tests pass without a focus on efficiency.
    4. Refactor the code while keeping the tests passing to remove code duplication, inefficiencies, and suboptimal practices
6. Do NOT write duplicate code. DO NOT NEVER EVER

## What this is

FossLift — an offline, on-device Flutter workout tracker. No network, no auth,
no telemetry. Read `ARCHITECTURE.md` before touching code; it is the map.
`RUNNING.md` covers building and running on a phone or emulator.
`design/mockup.html` is the visual spec.

## Feature tracking — GitHub Issues

**The backlog lives in GitHub Issues, not in a file.** `features.txt` is a stub
pointing here; do not add features to it.

```bash
gh issue list --label p1              # what's next
gh issue view 8                       # the spec for a feature
gh issue list --state all --label shipped
```

Labels: `p1`/`p2`/`p3` are priority tiers (roughly: next / soon / later).
`area/*` groups by subsystem. `blocked` means another issue must land first —
the blocker is named in the body.

### Before implementing

1. `gh issue view <n>` — the body has the behaviour spec and acceptance
   criteria. Work to those criteria, not to a paraphrase of the title.
2. Check the `blocked` label and any "Depends on #n" line. If the dependency is
   still open, say so rather than working around it.
3. If the spec is ambiguous, ask — then record the answer as an issue comment so
   the next session inherits it.

### While implementing

- Comment on the issue when a non-obvious decision gets made ("kept text entry
  for >12 reps; tap-cycling is too slow"). These comments are the work log; a
  fresh session has no other way to learn what was already tried and rejected.
- If you discover the issue is wrong or incomplete, edit the body. A stale spec
  is worse than no spec.

### After implementing

**Never close an issue.** The user reviews the work and closes it themselves.
Post a completion comment and stop there.

1. Tick the acceptance criteria you actually satisfied. Leave the rest unticked.
2. Post a comment on the issue saying it is ready for review:

   ```bash
   gh issue comment <n> --body "..."
   ```

   The comment covers: what was built, the commit(s) that did it, which
   acceptance criteria are unmet and why, anything the user should check by hand
   on a device, and any decision they might want to overrule.
3. Use a `Refs #<n>` trailer in the commit message — **not** `Closes`/`Fixes`,
   which GitHub auto-closes on a push to `main` and would skip the review.
4. Tell the user the issue is ready for review. Do not close it, and do not ask
   to close it.
5. **Say how to see it in the app.** End with the taps: where to start, what to
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

If something worth doing surfaces mid-task, open an issue for it rather than
silently expanding scope. Label it and tell the user you filed it.

## Out of scope — do not build these

These were considered and explicitly rejected. If one seems necessary, raise it
rather than implementing it.

- Lifetime "routines completed" as a stat — pointless.
- Adding sets during a live workout.
- A "build" button next to "start a routine". That screen is for working out,
  not editing. An edit icon that navigates to the routine/workout editor is fine.

## Nothing has shipped yet — do not write compatibility code

**There are no existing installs.** No phone anywhere holds a FossLift
database, a shared routine code or an exported file. Every user is a fresh
install, today and until the first public release.

So: **change formats in place. Never add a compatibility layer for a past that
does not exist.**

- **The drift schema stays at v1.** Change the table, run build_runner, done.
  Do not bump `schemaVersion` and do not add an `onUpgrade` rung — its only
  possible input is a database that has never existed. A migration written now
  is untestable, unreachable, and a lie about the app's history.
- **Wire formats are not frozen yet.** `kMuscleGroups`, `kEquipmentTypes`, the
  `FLR1` flag bits — reorder, renumber and reuse them freely. Do not leave
  reserved holes, do not renumber around a "codes people may already hold": no
  one holds one.
- **Data loss is not a consideration for shipped data.** There is none. A
  removed column takes nothing with it.

This is the one rule with an expiry date. **On the first public release it
inverts:** the shipped schema becomes v1 for real, every later change is a
migration rung, and every wire format is frozen for good. Anything relying on
this rule should say so where it lives, so it can be found again then. When
the release happens, this section gets rewritten, not deleted.

If a change seems to need compatibility code, you have found a case this rule
did not anticipate — raise it rather than quietly writing the migration.

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

## Commands

```bash
flutter analyze          # lints — must be clean
flutter test             # pure-logic unit tests
flutter run              # see RUNNING.md for device setup
```
