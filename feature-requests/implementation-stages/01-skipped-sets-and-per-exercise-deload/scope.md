# Stage 01 — skipped-sets-and-per-exercise-deload

Source: `feature-requests/skipped-sets-and-timed-deload.md`

## Why this is one stage

The request has two halves — a skipped set stops being a performance failure, and the timed (layoff) deload starts tracking inactivity per exercise instead of per workout — and they are joined by the word "instead". Landing only the first would make skipping strictly free: an exercise nobody trains would hold its targets forever with nothing left to catch it, which is worse than today's behaviour, not better. Landing only the second is coherent but delivers none of the request. There is no ordering between them in code either: the verdict change lives in `ExerciseEntry`/`advanceProgression`, the inactivity change lives in `layoffFor`/`applyLayoffDeload`, and neither reads the other. The two halves share their tests, their catalogue entries and their user-visible copy, so splitting them would duplicate all three and produce a first stage nobody should ship.

Estimated at 17–20 senior developer days, which fits the 10–25 day target for a single stage, including persisted offer handling and upgrade coverage.

## Planning decision: hold clean partial exercises

The feature request asked whether partial exercises should be judged on performed sets alone or hold until complete. This review request adopts Option B, so the decision is resolved for this stage and must be recorded in the catalogue before tests or implementation.

**Decision — Option B.** A performed working set that falls short is still a miss and follows existing performance rules, even if other sets were skipped. Otherwise, if any planned working set was skipped, the exercise neither succeeds nor fails: all normal targets and both streaks hold. With no performed sets it also holds. Only completing every planned set without a shortfall earns a success.

The hold includes adopting a heavier performed load and establishing a previously absent weight target: neither happens in a clean partial exercise. A partial exercise with a recorded shortfall follows the existing miss path, including its existing target-adoption rules. Any performed working set resets inactivity regardless of this progression verdict.

**Recorded alternative — Option A, not selected.** Judging only performed sets would allow two clean sets out of three to earn a success. Option B requires the complete prescription for success, while preserving the request's rule that a recorded shortfall remains a performance miss.

The outcome becomes three-valued (success / miss / neither). Keep the existing two-valued `SessionVerdict` used by cycle and GZCL rules; represent the neutral outcome with a nullable verdict or a wider type that is resolved before calling `stepProgression`. This is an internal representation choice, not an unresolved behaviour.

## Scope

### Progression: a skipped set is not a miss

`ExerciseEntry.succeeded` currently reads `sets.every((s) => s.done && !s.missedGoal)`, so an unlogged set is a miss with no way to tell it from a set that came up short. Replace it with the three-valued outcome above. A fully skipped or clean partial exercise moves nothing: no step, no back-off, no streak change, no write to the slot at all during progression on Finish.

`finish()` in `lib/state/active_workout.dart` passes the outcome to `AppDatabase.advanceProgression`. Make the null case explicit in that signature rather than filtering it out in the caller, because the decision is not the same for every slot:

- Ordinary weight, reps and Advanced (weight + reps) slots take the new rule. This is the scope of the request.
- Cycle slots (`it.runsCycle`) and GZCL slots (`it.gzclTier != null`) keep today's behaviour, because the request puts them out of scope. A cycle's weeks advance on the session, not on the sets in it, and a GZCL ladder stage advances on a missed prescription; both would need their own answer to "what does a skipped session mean", and neither was asked for. Coerce a null outcome to `SessionVerdict.miss` inside `advanceProgression` for those two paths and say so in a comment, so the boundary is legible to the next reader rather than an accident of dispatch order.

Two existing rules need re-checking against the new outcome, and each needs a test:

- **Loading the bar past the suggestion is itself progression** (`05.loading-bar-past-suggestion-itself`). The neutral outcome takes precedence over this rule: a clean partial exercise holds its stored weight even when every performed set exceeds it. For example, one clean 85 kg set out of three planned at 80 kg leaves the target at 80 kg and both streaks unchanged. Fully completed exercises and partial exercises with a recorded shortfall retain existing target-adoption rules, including exclusions for percentage-based prescriptions.
- **A weight slot with no suggested weight takes one from the session** (`05.weight-mode-slot-no-suggested`). `ExerciseEntry.sessionLoadKg` falls back to `workingKg` when nothing was logged. A weight typed onto the board must establish no target when the exercise is fully skipped or clean but partial; the stored target remains null. Once all sets are performed, or a performed set has a shortfall, existing target-establishment and performance rules apply.

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

- `05.verdict-every-planned-set-logged` — replace the skipped-set-as-miss rule with the planning decision: a recorded shortfall is a miss, every planned set performed cleanly is a success, and a fully skipped or clean partial exercise is neutral.
- `05.loading-bar-past-suggestion-itself` — the neutral outcome holds the stored target even when the performed load exceeds it; existing adoption rules continue for success and miss outcomes.
- `05.weight-mode-slot-no-suggested` — fully skipped and clean partial exercises establish no target, including when a working weight was entered.
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
3. For each of Weight, Reps and Weight + Reps, one or two clean sets out of three planned hold every normal target and both streaks, including across repeated partial sessions. A clean partial exercise at a heavier load does not adopt it, and a clean partial exercise with a null target does not establish one. A performed set short on reps or weight is a miss even when other sets are skipped: existing failure thresholds and performance deloads apply, with existing target adoption on that miss path. All planned sets performed use the existing success/miss rules. Cover nonzero success and failure streaks and the Weight + Reps range boundaries.
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

The partial-exercise decision is settled above; no user decision is deferred to implementation.

## Estimated effort

17–20 senior developer days.

| Work | Days |
| --- | --- |
| Record the planning decision; write and validate the catalogue entries and concepts | 1 |
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
