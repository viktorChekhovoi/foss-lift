# Stage 01 — skipped-sets-and-per-exercise-deload

Source: `feature-requests/skipped-sets-and-timed-deload.md`

## Why this is one stage

The request has two halves — a skipped set stops being a performance failure, and the timed (layoff) deload starts tracking inactivity per exercise instead of per workout — and they are joined by the word "instead". Landing only the first would make skipping strictly free: an exercise nobody trains would hold its targets forever with nothing left to catch it, which is worse than today's behaviour, not better. Landing only the second is coherent but delivers none of the request. There is no ordering between them in code either: the verdict change lives in `ExerciseEntry`/`advanceProgression`, the inactivity change lives in `layoffFor`/`applyLayoffDeload`, and neither reads the other. The two halves share their tests, their catalogue entries and their user-visible copy, so splitting them would duplicate all three and produce a first stage nobody should ship.

Estimated at 17–20 senior developer days, which fits the 10–25 day target for a single stage, including persisted offer handling and upgrade coverage.

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

The last-trained query needs no new history columns. `finish()` already writes a `SessionSets` row only for a set that was logged, so "this exercise was performed in this session" is already recorded, for every session in every shipped install. Query `sessionSets` joined to finished `sessions`, matched on `exerciseId`, and select the latest session by `startedAt`, then `id` to break ties. Its start time measures the gap; its identity distinguishes successive training sessions for offer handling. This uses the same history as `lastLoggedWeight` and the existing `session_sets_exercise_session_set` index. Existing history remains readable; sets whose `exerciseId` is null do not match.

Tracking by exercise rather than by workout slot is the reading to take: the request says "since that exercise was last trained", and a lift that appears in both Push A and Push B has been trained when either of them trained it. Note it in the catalogue entry, because it is a real choice and the alternative is defensible.

That turns one workout-wide offer into a set of per-exercise ones:

- `layoffFor` gains a per-workout form that returns one `LayoffDeload` per eligible slot, carrying the slot id, exercise identity and name, and last-performed session identity. Slots whose exercise has never been performed have no gap and earn nothing, exactly as an untrained workout does today. Reading an offer writes nothing.
- Accepting applies each displayed slot's own percentage and clears its streaks; declining leaves targets and streaks unchanged. Both choices consume those offers as described below. Keep the movement count honest: a bodyweight slot with no target moves nothing, but its displayed offer is still consumed.
- The existing threshold, per-period percentage, period cap, cut cap, rounding and floors are unchanged. Each eligible offer uses the existing arithmetic; eligibility also requires an unhandled inactivity gap.

**Decision: offer once per inactivity gap for each slot.** Accepting or declining (including dismissing the dialog) records that the displayed offer was handled. No further offer or cut is made for that slot until the exercise has a newer finished session with at least one performed working set. Skipping it in later sessions, restarting the app, discarding the newly started workout, or changing deload settings does not rearm the offer. The real last-trained time remains unchanged by either decision: acknowledgement is not training and never resets inactivity. This deliberately replaces the in-scope part of `06.declining-not-recorded`; retaining a stateless decline would repeat the prompt indefinitely.

Persist the handled gap's training timestamp and session id as nullable state on `WorkoutItems`, using the same ordering as the last-trained query. A later performed session rearms the offer; merely falling back to older history after a deletion does not. Store acknowledgement and any accepted target/streak changes in one transaction, scoped to the displayed slot and exercise identities. Reapplying an already handled offer is a no-op. Different slots for the same exercise share the training clock but handle their offers independently, because their targets are independent. Once each has handled that gap, neither can compound a second cut against it.

This requires a schema increment and a new additive `onUpgrade` rung (currently version 18 → 19; use the next version at implementation time). Existing rows start with null acknowledgement; the old build recorded no decisions, so do not fabricate acknowledgements or rewrite historical targets. Preserve this state through `ItemDraft` and `replaceWorkoutItems` when an existing exercise slot is edited or reordered, even though that path replaces row ids. New slots and routine-code imports start unacknowledged, and the state does not travel in routine share codes. Full database backups carry it; old backups upgrade with null state. Regenerate `database.g.dart` with build_runner, keep shipped migration rungs and wire formats intact, and update the table map in `ARCHITECTURE.md`.

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
- `06.offers-back-off-before-session` — the offer names exercises and their own cuts, once per slot's inactivity gap; additional elapsed periods cannot trigger a second offer after that gap is handled.
- `06.declining-not-recorded` — retain the stable id but replace the title and prose: accepting or declining records offer acknowledgement for in-scope slots, without changing last-trained time. Only a newer performed session rearms the offer; one performed working set is enough.
- `06.nothing-applied-without-asking` — accepting atomically records acknowledgement and applies the displayed cuts; declining or dismissing records acknowledgement alone.
- `04.finish-asks-when-sets-are-unlogged` — unlogged working sets are not misses.

Entries to add: a fully skipped exercise holds its targets and streaks and does not reset its inactivity; any performed set counts the exercise as trained; the out-of-scope note that cycle and GZCL slots keep the old verdict rule.

`concepts.yaml` needs at least one new concept for per-exercise inactivity (the existing `progression.layoff-rules` is the thresholds, not the clock) and one for the skipped-set distinction, each with its `code:` list. Link offer acknowledgement to `storage.schema`, `template.item`, the training clock and `progression.layoff-offer`; distinguish it from training activity. Re-check the `uses` lists on every entry above against their own prose — `05.streaks-stored`, `05.loading-bar-past-suggestion-itself`, `06.deload-clears-both-progression-streaks` and `04.board-takes-the-change-where-it-can` all lean on the verdict and may need the new concept added.

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
8. Accepting the offer cuts only the displayed eligible slots, each by its own percentage, clears those slots' streaks, and atomically acknowledges their offers. Declining or dismissing writes only acknowledgement; targets, streaks and last-trained times remain unchanged. Reapplying the same offer cannot cut a target twice.
9. The threshold, per-period percentage, period cap, cut cap, rounding to the 0.5 grid, mode floors and bar floors all produce the same numbers they do today — the existing tests in `test/feature_06_layoff_deloads_test.dart` for the pure rules pass unchanged.
10. A cycle slot and a GZCL slot fully skipped in a session behave exactly as they do on the shipped build.
11. A session snapshot written by the shipped build restores without throwing, including one carrying a layoff notice.
12. `dart run tool/features.dart --check`, `flutter analyze` and `flutter test` are all clean, in one test invocation covering every file touched.
13. `ARCHITECTURE.md` describes the per-exercise gap in its layoff section and the new verdict in its progression section; the two `code:` path failures above are gone.
14. With default 14-day / 10% settings and bench at 80 kg last performed 40 days ago, accept its 20% cut to 64 kg and finish Push with bench fully skipped. Start and finish Push again at days 47 and 54 with bench still skipped: bench has no second offer, stays at 64 kg, and retains its original last-trained time. Repeat with the first offer declined or dismissed: no later offer, bench stays at 80 kg, and its last-trained time still does not change. Cover reopening the app and discarding a session after the decision.
15. After either response, one performed bench working set rearms future eligibility and resets its training time. A start before the next configured threshold offers nothing; a start at the threshold offers one fresh cut. Duplicate bench slots handle that gap independently without applying a cut twice to either target. Editing or reordering the workout, changing deload settings, and restoring a new backup preserve acknowledgement.
16. Upgrading a shipped database or restoring an old backup preserves history, routines, settings and targets and initializes acknowledgement to null; historical performed sets determine the first offer. A backup from the new build retains acknowledgement on restore. Existing routine codes remain readable and do not acquire training state.

## Dependencies

None. This is the first and only stage.

The open question under "Decision to resolve" blocks the partial-exercise verdict and criterion 3, and nothing else.

## Estimated effort

17–20 senior developer days.

| Work | Days |
| --- | --- |
| Resolve the open question; write and validate the catalogue entries and concepts | 1 |
| Verdict rules — `ExerciseEntry`, `advanceProgression`, the cycle/GZCL boundary, the two interacting rules | 2–3 |
| Per-exercise last-trained query, per-slot offer handling, additive migration and editor state preservation | 4–5 |
| `finish()` plumbing and the recap outcome | 1.5–2 |
| Start dialog, session notice, snapshot compatibility, finish-confirm copy, l10n across five locales | 3 |
| Integration tests for the whole acceptance table, repeat offers, upgrades and backup restore, plus unchanged behaviour | 4–5 |
| `flutter analyze`, `ARCHITECTURE.md`, catalogue regeneration, the pre-existing `--check` fix | 1 |

## Key files and modules

**Rules**
- `lib/data/progression.dart` — `SessionVerdict`, `stepProgression`, `stepCycle`; the wider outcome type if one is introduced
- `lib/data/layoff.dart` — `layoffDeload`, `deloadedTarget`; unchanged arithmetic, possibly a new offer shape

**Data**
- `lib/data/database.dart` — `advanceProgression` (~2813), `_advanceGzcl`, `_advanceCycle`, `layoffFor` (~3077), `applyLayoffDeload` (~3096), `lastTrainedAt` (~3203); the new per-exercise query alongside `lastLoggedWeight` (~3379), transactional offer acknowledgement, `WorkoutItems` state and the next additive migration rung.
- `lib/data/database.g.dart` — regenerate with `dart run build_runner build --delete-conflicting-outputs` after the schema change; never edit by hand.
- `lib/widgets/workout_items_editor.dart` — carry acknowledgement through `ItemDraft` and replacement writes for existing exercise slots.
- `lib/services/backup_service.dart`, `lib/data/backup_archive.dart` — verify acknowledgement survives database backup/restore and older schemas upgrade; retain existing archive and routine-code formats.

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
- `test/feature_20_backup_and_restore_test.dart` — upgrade and backup compatibility, including persisted acknowledgement.
- `test/support/harness.dart`, `test/support/seeded.dart` — read before writing; a drift future needs `tester.runAsync`, and a live session never settles
