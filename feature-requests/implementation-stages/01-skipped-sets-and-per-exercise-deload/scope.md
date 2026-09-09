# Stage 01 — skipped-sets-and-per-exercise-deload

Source: `feature-requests/skipped-sets-and-timed-deload.md`

## Why this is one stage

The request has two halves — a skipped set stops being a performance failure, and the timed (layoff) deload starts tracking inactivity per exercise instead of per workout — and they are joined by the word "instead". Landing only the first would make skipping strictly free: an exercise nobody trains would hold its targets forever with nothing left to catch it, which is worse than today's behaviour, not better. Landing only the second is coherent but delivers none of the request. There is no ordering between them in code either: the verdict change lives in `ExerciseEntry`/`advanceProgression`, the inactivity change lives in `layoffFor`/`applyLayoffDeload`, and neither reads the other. The two halves share their tests, their catalogue entries and their user-visible copy, so splitting them would duplicate all three and produce a first stage nobody should ship.

Estimated at 14–18 senior developer days, which fits the 10–25 day target for a single stage.

## Decision to resolve before writing the catalogue entries

The feature request leaves one question open, and the catalogue entry is the specification, so it has to be answered before step 5.1 of the workflow:

> For a partially completed exercise, should normal progression evaluate only the performed sets, or hold the exercise's targets and progression streaks until all planned sets are performed?

Ask the user, and record the answer in the entry you write. The rest of the stage does not depend on the answer and can proceed while it is outstanding — only the partial-exercise verdict and the tests covering row 2 of the acceptance table are blocked by it.

**Option A — judge the performed sets.** Three of three sets clean is a success; two of three clean, one skipped, is also a success and steps the target up. Simple to state, but it lets an exercise progress on two thirds of the prescribed work, and repeated partial sessions climb the target on volume nobody did.

**Option B — hold until the exercise is complete.** A performed set that falls short is still a miss, because the request keeps that rule explicitly ("A recorded performance shortfall remains subject to the normal performance rules"). Otherwise, if any planned set was skipped, the session neither succeeds nor fails: the target holds and both streaks stay where they were.

Option B is the recommendation. It satisfies every stated requirement without inventing one, it reuses the same "do not advance" mechanism the fully-skipped case already needs, and it keeps the meaning of the success streak — consecutive sessions where the programme was done as written — intact. Option A quietly redefines that streak.

Either way the outcome becomes three-valued (success / miss / neither), because the fully-skipped case alone requires a state that moves nothing. Do not add the third value to `SessionVerdict`, which is persisted-adjacent and consumed by the cycle and GZCL paths; make `ExerciseEntry.verdict` nullable, or introduce a wider outcome type in `lib/data/progression.dart` that collapses to `SessionVerdict` before it reaches `stepProgression`.

## Scope

### Progression: a skipped set is not a miss

`ExerciseEntry.succeeded` currently reads `sets.every((s) => s.done && !s.missedGoal)`, so an unlogged set is a miss with no way to tell it from a set that came up short. Replace it with the three-valued outcome above. An exercise with no performed sets moves nothing: no step, no back-off, no streak change, no write to the slot at all.

`finish()` in `lib/state/active_workout.dart` passes the outcome to `AppDatabase.advanceProgression`. Make the null case explicit in that signature rather than filtering it out in the caller, because the decision is not the same for every slot:

- Ordinary weight, reps and Advanced (weight + reps) slots take the new rule. This is the scope of the request.
- Cycle slots (`it.runsCycle`) and GZCL slots (`it.gzclTier != null`) keep today's behaviour, because the request puts them out of scope. A cycle's weeks advance on the session, not on the sets in it, and a GZCL ladder stage advances on a missed prescription; both would need their own answer to "what does a skipped session mean", and neither was asked for. Coerce a null outcome to `SessionVerdict.miss` inside `advanceProgression` for those two paths and say so in a comment, so the boundary is legible to the next reader rather than an accident of dispatch order.

Two existing rules need re-checking against the new outcome, and each needs a test:

- **Loading the bar past the suggestion is itself progression** (`05.loading-bar-past-suggestion-itself`). It reads `performedWeight`, which is null when nothing was logged, so a fully skipped exercise is already inert. A *partial* session that loaded the bar past the suggestion still raises the target under both options — decide it deliberately and write it into the entry.
- **A weight slot with no suggested weight takes one from the session** (`05.weight-mode-slot-no-suggested`). `ExerciseEntry.sessionLoadKg` falls back to `workingKg` when nothing was logged, so today a slot with no stored target, a weight typed onto the board and every set skipped establishes that weight as its target and applies a miss to it. Under the new rule it must establish nothing. The window is narrow — it needs a slot that has never had a suggested weight — but it is exactly the "do not record the exercise as completed or failed" case.

### Timed deload: inactivity per exercise

`layoffFor(workoutId)` reads `lastTrainedAt(workoutId)`, which is the start time of the most recent finished session filed against that workout. Completing any part of a workout therefore resets the clock for every exercise in it, which is the behaviour the request removes.

The replacement needs no schema change and no migration. `finish()` already writes a `SessionSets` row only for a set that was logged, so "this exercise was performed in this session" is already recorded, for every session in every shipped install. Per-exercise last-trained is a query over `sessionSets` joined to `sessions` where `endedAt` is not null, matched on `exerciseId` and taking `max(sessions.startedAt)` — the same shape as the existing `lastLoggedWeight`, and covered by the existing `session_sets_exercise_session_set` index. Existing history reads correctly under it. Match on `exerciseId` as the rest of the exercise history does; sets whose `exerciseId` is null (a hand-edited database — this app writes none) do not match, which is the caveat `watchExerciseSetHistory` already documents.

Tracking by exercise rather than by workout slot is the reading to take: the request says "since that exercise was last trained", and a lift that appears in both Push A and Push B has been trained when either of them trained it. Note it in the catalogue entry, because it is a real choice and the alternative is defensible.

That turns one workout-wide offer into a set of per-exercise ones:

- `layoffFor` gains a per-workout form that returns one `LayoffDeload` per slot that earned a cut, carrying the slot id and the exercise name. Slots whose exercise has never been performed have no gap and earn nothing, exactly as an untrained workout does today.
- `applyLayoffDeload(workoutId, percent)` becomes a per-slot application: each slot is cut by its own percentage and has its own streaks cleared. Keep the return value honest — it counts slots that actually moved, and a bodyweight slot with no target still moves nothing.
- The existing threshold, per-period percentage, period cap, cut cap, rounding and floors are unchanged. Only the gap each slot is measured against changes.

### Session start, notice and recap

`startWorkout` in `lib/widgets/start_workout.dart` shows one dialog and applies one percentage. It now has to describe a set of exercises with, in general, different cuts. Keep it one dialog with one accept and one decline — the request says the accept-or-decline behaviour is unchanged — and have it name the exercises it proposes to cut and by how much. `startWorkoutLayoffBody` currently says "reduce every target in this workout by {percent}%", which stops being true; it needs rewriting rather than reusing.

`LayoffNotice` is `({int percent, int days})` and is carried into the session and shown for its length. If it grows to describe several exercises, `_readNotice` in `lib/state/session_snapshot.dart` must keep reading the old two-key map: that snapshot is on disk on shipped phones, and its reader casts with `as int` today, so a shape change without a compatibility path throws on the first resumed session after the update. A snapshot written by the old build has to restore.

The recap already renders a "held" outcome with a note. Give a fully skipped exercise an honest line there — held, with a reason — or leave it out of the report entirely. Do not let it render as a miss.

`04.finish-asks-when-sets-are-unlogged` describes the confirmation dialog as reporting sets that "count as misses for progression". That sentence becomes false. Both the catalogue entry and the dialog copy need to change; the dialog itself stays, since counting unlogged sets before finishing is still worth doing.

New and changed strings go in `lib/l10n/short/` or `lib/l10n/long/` by the three-word rule in `lib/l10n/README.md`, for all five locales (en, es, pt, pt_BR, uk), then `dart run tool/l10n.dart` and `flutter gen-l10n`.

### Catalogue

Written first, per rule 5 of `CLAUDE.md`. Edit in place; do not add a second entry beside the old one.

Entries to rewrite:

- `05.verdict-every-planned-set-logged` — "A skipped set or reduced-weight set is a miss" is the sentence this feature deletes. It has to distinguish the two and state the new outcome, including the answer to the open question above.
- `05.weight-mode-slot-no-suggested` — a session that performed nothing establishes no target.
- `06.watches-gap-since-workout-was` — the gap is per exercise, not per workout.
- `06.offers-back-off-before-session` — the offer names exercises and their own cuts.
- `06.declining-not-recorded` — "Training the workout resets its inactivity gap" becomes per exercise, and one performed set is enough.
- `04.finish-asks-when-sets-are-unlogged` — unlogged working sets are not misses.

Entries to add: a fully skipped exercise holds its targets and streaks and does not reset its inactivity; any performed set counts the exercise as trained; the out-of-scope note that cycle and GZCL slots keep the old verdict rule.

`concepts.yaml` needs at least one new concept for per-exercise inactivity (the existing `progression.layoff-rules` is the thresholds, not the clock) and one for the skipped-set distinction, each with its `code:` list. Re-check the `uses` lists on every entry above against their own prose — `05.streaks-stored`, `05.loading-bar-past-suggestion-itself`, `06.deload-clears-both-progression-streaks` and `04.board-takes-the-change-where-it-can` all lean on the verdict and may need the new concept added.

### Pre-existing catalogue failure

`dart run tool/features.dart --check` does not pass on `main` today. It reports two problems, both from the l10n source split:

```
section 18: "lib/l10n/app_en.arb" no longer exists
concept ui.string-catalogue: "lib/l10n/app_en.arb" no longer exists
```

Fix them in this stage — the paths are now `lib/l10n/short/app_en.arb` and `lib/l10n/long/app_en.arb` — so that a green `--check` means something. Mention it in the commit as a pre-existing fix, not as part of the feature.

## Acceptance criteria

Each row of the acceptance table in the feature request is an integration test, written from the catalogue entries and seen to fail before the code exists.

1. An exercise whose planned sets are all skipped comes out of Finish with its `suggestedWeight`, `repsMin`/`repsMax`, `holdSeconds`, `repsTarget`, `successStreak` and `failStreak` byte-for-byte as they went in, and does not appear in the recap as a success or a miss.
2. Skipping the whole exercise repeatedly never produces a performance deload, however many sessions it takes — the failure streak does not advance.
3. A partially performed exercise behaves as the resolved decision says. Under Option B: all performed sets clean and at least one skipped holds the target and both streaks; a performed set that fell short of reps or came down in weight is still a miss and still advances the failure streak.
4. A performed set that misses its target is still distinguishable from a skipped set — the existing `missedGoal` and `underWeight` behaviour is unchanged, and a test asserts the two produce different outcomes from the same session shape.
5. Finishing a workout with squats performed and bench press entirely skipped leaves bench press's last-trained time where it was, and moves squats'.
6. Performing one set of three of an exercise resets that exercise's inactivity timer.
7. An exercise skipped across enough sessions to pass the configured threshold is offered the configured cut when its workout is next started, at the percentage the existing rule produces for its own gap, while an exercise trained throughout is offered nothing.
8. Accepting the offer cuts only the slots that earned it, each by its own percentage, clears those slots' streaks, and leaves the others alone. Declining writes nothing.
9. The threshold, per-period percentage, period cap, cut cap, rounding to the 0.5 grid, mode floors and bar floors all produce the same numbers they do today — the existing tests in `test/feature_06_layoff_deloads_test.dart` for the pure rules pass unchanged.
10. A cycle slot and a GZCL slot fully skipped in a session behave exactly as they do on the shipped build.
11. A session snapshot written by the shipped build restores without throwing, including one carrying a layoff notice.
12. `dart run tool/features.dart --check`, `flutter analyze` and `flutter test` are all clean, in one test invocation covering every file touched.
13. `ARCHITECTURE.md` describes the per-exercise gap in its layoff section and the new verdict in its progression section; the two `code:` path failures above are gone.

## Dependencies

None. This is the first and only stage.

The open question under "Decision to resolve" blocks the partial-exercise verdict and criterion 3, and nothing else.

## Estimated effort

14–18 senior developer days.

| Work | Days |
| --- | --- |
| Resolve the open question; write and validate the catalogue entries and concepts | 1 |
| Verdict rules — `ExerciseEntry`, `advanceProgression`, the cycle/GZCL boundary, the two interacting rules | 2–3 |
| Per-exercise last-trained query, per-slot offer and per-slot application | 3 |
| `finish()` plumbing and the recap outcome | 1.5–2 |
| Start dialog, session notice, snapshot compatibility, finish-confirm copy, l10n across five locales | 3 |
| Integration tests for the whole acceptance table, plus the unchanged-behaviour tests | 3–4 |
| `flutter analyze`, `ARCHITECTURE.md`, catalogue regeneration, the pre-existing `--check` fix | 1 |

## Key files and modules

**Rules**
- `lib/data/progression.dart` — `SessionVerdict`, `stepProgression`, `stepCycle`; the wider outcome type if one is introduced
- `lib/data/layoff.dart` — `layoffDeload`, `deloadedTarget`; unchanged arithmetic, possibly a new offer shape

**Data**
- `lib/data/database.dart` — `advanceProgression` (~2813), `_advanceGzcl`, `_advanceCycle`, `layoffFor` (~3077), `applyLayoffDeload` (~3096), `lastTrainedAt` (~3203); the new per-exercise query alongside `lastLoggedWeight` (~3379). No schema change and no `onUpgrade` rung: `SessionSets` already records which exercises a session performed.

**Session**
- `lib/state/active_workout.dart` — `SetEntry.done`/`missedGoal`/`underWeight`, `ExerciseEntry.succeeded`/`verdict`/`performedWeight`/`sessionLoadKg`, `finish()`, `LayoffNotice`, `ProgressionOutcome`
- `lib/state/session_snapshot.dart` — `_readNotice` and the notice writer; the on-disk compatibility path

**UI**
- `lib/widgets/start_workout.dart` — the layoff dialog and what accepting applies
- `lib/screens/workout_screen.dart` — `_SessionNotice`, the finish confirmation dialog
- `lib/screens/summary_screen.dart` — the recap row for a held or skipped exercise

**Catalogue and copy**
- `features/catalogue/04-live-session.yaml`, `05-progression.yaml`, `06-layoff-deloads.yaml`, `features/concepts.yaml`
- `lib/l10n/short/app_{en,es,pt,pt_BR,uk}.arb`, `lib/l10n/long/app_{en,es,pt,pt_BR,uk}.arb`
- `ARCHITECTURE.md`

**Tests**
- `test/feature_05_progression_test.dart`, `test/feature_06_layoff_deloads_test.dart`, `test/feature_04_live_session_test.dart`, `test/feature_04_session_continuity_test.dart`, `test/feature_22_cycles_test.dart`
- `test/support/harness.dart`, `test/support/seeded.dart` — read before writing; a drift future needs `tester.runAsync`, and a live session never settles
