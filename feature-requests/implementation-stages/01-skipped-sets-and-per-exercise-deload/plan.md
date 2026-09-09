# Stage 01 implementation plan — skipped sets and per-exercise deload

Scope: `feature-requests/implementation-stages/01-skipped-sets-and-per-exercise-deload/scope.md`. Source request: `feature-requests/skipped-sets-and-timed-deload.md`.

This plan says what to change and where, in what order, and what each test has to assert. It does not restate the scope's behaviour decisions — read the scope first; the acceptance criteria numbered 1–21 there are the definition of done and are referenced by number below.

## Standing constraints

- The workflow is **feature → red → green → refactor** (`CLAUDE.md` rule 5). The catalogue is written and `--check`-clean before any test is written, and the tests are seen failing before any `lib/` change.
- **Edit catalogue entries in place** (rule 8). The only new entries are the two the scope names; everything else is a rewrite of an existing id.
- **The app has shipped.** Every schema change is an additive rung; shipped rungs are never edited or renumbered; `FLR1`/`FLR2` and `FLB1` are untouched by this stage.
- **One test invocation** covering every file touched, per the "Running the tests" section of `CLAUDE.md`. Redirect to a file and read it; never pipe through `tail`.
- `lib/data/database.g.dart` is regenerated with build_runner, never hand-edited.

## Planning default carried into the work

The partial-exercise rule is the scope's **flagged planning default — hold clean partial exercises** — not a user-confirmed choice. Write it into the catalogue entry prose as the app's behaviour (the catalogue states what the app does), and record the provenance and the departure from the original "confirm before implementing" requirement in the implementation summary reported back to the user, not in the catalogue and not in a GitHub issue.

---

## Step 0 — the pre-existing `--check` failure (separate commit)

`dart run tool/features.dart --check` fails on `main` today with two stale paths, both from the l10n source split:

- `features/catalogue/18-language.yaml` line 8: `lib/l10n/app_en.arb` → `lib/l10n/short/app_en.arb` and `lib/l10n/long/app_en.arb`.
- `features/concepts.yaml` line 632, concept `ui.string-catalogue`: same substitution in its `code:` list.

Land this first, on its own, and say in the commit message that it is a pre-existing fix rather than part of the feature. A green `--check` has to mean something before the catalogue work starts.

---

## Step 1 — catalogue and concepts (the specification)

Files: `features/catalogue/04-live-session.yaml`, `05-progression.yaml`, `06-layoff-deloads.yaml`, `features/concepts.yaml`.

### New concepts (`features/concepts.yaml`, `progression` area)

| id | what | code |
| --- | --- | --- |
| `progression.skipped-set` | A planned set that was never logged, told apart from one that came up short. | `lib/data/progression.dart`, `lib/state/active_workout.dart` |
| `progression.exercise-inactivity` | The gap since an exercise itself was last performed, wherever it was trained. | `lib/data/database.dart`, `lib/data/layoff.dart` |
| `progression.layoff-eligibility` | Whether a slot has established training and may be offered a timed cut. | `lib/data/database.dart` |
| `progression.layoff-baseline` | The pre-cut target retained for a gap, and the training identity it belongs to. | `lib/data/database.dart`, `lib/data/layoff.dart` |

Each needs exactly one `defines` site among the entries below (a concept `--check` reports as "used by N items, described by none" is a hole, and one listed in both columns of an entry is a rule-9 violation).

### Corrected metadata (criterion 20)

- Section 06 `code:` — add `lib/data/database.dart`; replace `lib/screens/workout_detail_screen.dart` with `lib/widgets/start_workout.dart`; keep `lib/data/layoff.dart` and `lib/screens/exercise_settings_screen.dart`.
- Section 06 `where:` — locate `layoffFor` / `applyLayoffDeload` in `lib/data/database.dart` and point "Offered on Start" at `lib/widgets/start_workout.dart`. Keep `screen: workout-detail`: the workout detail screen is where the offer appears, and it delegates to the shared entry point; source ownership and surface are different metadata.
- `progression.layoff-offer.code` — `lib/widgets/start_workout.dart` and `lib/data/database.dart`, replacing the workout detail screen.
- `progression.layoff-rules.code` — add `lib/data/database.dart` beside `lib/data/layoff.dart`.
- Re-read each touched concept's `what` against its new ownership. `--check` finds a missing file; it cannot find an existing file credited with the wrong job, and that check is the point of criterion 20.

### Entries to rewrite in place

`05.automatic`, `05.verdict-every-planned-set-logged`, `05.loading-bar-past-suggestion-itself`, `05.weight-mode-slot-no-suggested`, `05.target-never-stored-below-its-bar`, `06.watches-gap-since-workout-was`, `06.offers-back-off-before-session`, `06.declining-not-recorded`, `06.nothing-applied-without-asking`, `06.set-rules`, `04.finish-asks-when-sets-are-unlogged` — content per the scope's "Entries to rewrite" list. Ids and titles stay stable (`06.declining-not-recorded` keeps both explicitly).

### Entries to add

- In section 05: a fully skipped in-scope exercise holds its targets and both streaks — `defines: [progression.skipped-set]`.
- In section 06: any performed working set counts the exercise as trained, and a slot must establish training before an offer — `defines: [progression.exercise-inactivity, progression.layoff-eligibility]` split across this entry and the rewritten `06.watches-gap-since-workout-was` so no concept is defined twice.
- `progression.layoff-baseline` is defined by the rewritten `06.offers-back-off-before-session` (repeated accepts calculate from the retained baseline).

Put the mode exclusions **inside** the existing verdict and layoff entries. Do not add a second verdict entry.

### Re-check `uses` on entries not otherwise touched

`05.streaks-stored`, `05.loading-bar-past-suggestion-itself`, `06.deload-clears-both-progression-streaks`, `04.board-takes-the-change-where-it-can` all lean on the verdict; add `progression.skipped-set` where the prose now depends on it. Entries whose behaviour depends on the schema (`06.nothing-applied-without-asking`, the eligibility entry) need `storage.schema`, `template.item`, `history.session-record` and `session.finish` in `uses`.

**Gate:** `dart run tool/features.dart --check` clean. Report the added/reworded entry ids to the user (`CLAUDE.md` rule 3) as part of the final summary.

---

## Step 2 — red: the tests

Written from the entries above, by an agent given the entries and `test/support/harness.dart` plus an existing feature test. Every test must be seen failing before Step 3 starts.

### `test/feature_05_progression_test.dart` — verdict (criteria 1–4, 17, 19)

- A fully skipped in-scope exercise through a real `finish()`: snapshot `suggestedWeight`, `repsMin`, `repsMax`, `repsTarget`, `successStreak`, `failStreak` immediately before and after and compare field by field, including a legacy 15 kg target under a 20 kg bar (criteria 1, 17).
- Repeat the skip across enough sessions to cross `failureThreshold` twice: the failure streak never advances and no deload lands (criterion 2).
- One and two clean sets of three planned, for each of Weight, Reps and Weight + Reps, repeated across sessions: every target and both streaks hold; a clean partial at 85 kg over an 80 kg target does not adopt 85; a clean partial on a slot with a null `suggestedWeight` establishes nothing even with a working weight typed on the board (criterion 3, and the `05.loading-bar-past-suggestion-itself` / `05.weight-mode-slot-no-suggested` interactions).
- A performed set short on reps, and a performed set at reduced weight, each with the other sets skipped: still a miss, with the existing thresholds, deloads and target adoption (criteria 3, 4). Assert the skipped and the short session produce **different** outcomes from the same session shape (criterion 4).
- Nonzero incoming success and failure streaks, and the Weight + Reps range boundaries (goal at `repsMin` and at `repsMax`).
- The legacy-bar-floor sequence of criterion 17: skip, then clean-partial, then a complete clean session at 20 kg with a success threshold not yet reached — the stored target corrects to 20 kg and the recap reports no 5 kg step. Plus the miss path and an accepted layoff, which keep their existing floor correction.
- Recap shape (criterion 19): squats completed + bench fully skipped → squat outcome present, no bench row, with bench tested with and without a target and with pending streaks; one clean bench set → a held row whose note is the incomplete-sets reason and not a streak note; null target → still no row; no reportable outcomes → no progression panel while the summary and the performed-set history remain.

### `test/feature_06_layoff_deloads_test.dart` — clock, offers, baselines (criteria 5–9, 14–16, 21)

The pure-rule groups at the top of this file (`layoffDeload`, `deloadedTarget`) **stay byte-for-byte** — criterion 9 is that they pass unchanged. The "measured per workout through the database" group is rewritten against the new per-exercise behaviour; the workout-clock cases move to excluded-mode slots.

- Per-exercise clock: finish with squats performed and bench skipped — bench's last-performed time is where it was, squats' has moved (criterion 5); one set of three resets that exercise's clock (criterion 6).
- Offer eligibility: an exercise skipped past the threshold is offered its own gap's cut; an exercise trained throughout is offered nothing (criterion 7).
- Accept/decline (criterion 8): accepting moves only the displayed eligible slots, clears their streaks and stores baseline + gap identity in one transaction; decline and dismissal write nothing at all; neither suppresses the next Start; replaying an accepted offer is a no-op; a stale offer whose target, axis or training identity moved is refused until recomputed.
- Applied results and notice (criteria 14, 18): accept offers at 10%, 20% and 30% with different gaps, where only the 10% target moves and the others already meet their capped or floored targets. Assert the returned results identify only that changed slot with its before/after target, percentage and gap; the session notice uses that slot's 10% and gap and reports one exercise. All-zero movement and replay return no changed results and create no new-cut notice. Also cover several changed slots so the notice's maxima and count come only from committed changes.
- The full day-by-day table of criterion 14, against a fixed `now` as the existing file already does: 80 kg bench, accepts at 14/28/42 → 72/64/56; accept at day 40 → 64, re-accept same day → 64 with zero movement reported; day 42 → 56 not 44.5; days 54/56/100/200/400 still offered; declines only, then accept at day 400 → 56; every response leaves the real last-trained time alone. Cover app restart (reopen the database), session discard, the boundary immediately before and at each percentage change, and gaps beyond `kMaxLayoffPeriods`.
- Criterion 15: a performed set after an accept or decline starts a fresh gap and clears the baseline; a start before the next threshold offers nothing and at the threshold cuts from the current target; duplicate bench slots keep independent baselines; reorder, unrelated edits and new-backup restore preserve baseline and identity; a manual target or axis edit clears only the baseline, exercised **separately** through `replaceWorkoutItems` and through the live board's `_editSlot` → `itemUpdate` → `updateWorkoutItem`; saving unchanged settings or changing only rest preserves it in both paths; changing deload settings preserves the baseline, never increases a target and never compounds; disabling deloads offers nothing. Repeat the bounded-reduction assertions for Reps with a range and for Weight + Reps, including floors and a target already at the cap.
- Criterion 21, first-training eligibility: bench performed 200 days ago in another routine; a new Push workout with 80 kg bench gets no offer on first Start and keeps 80 kg. Repeat for a slot added to an already trained workout, a routine-code import, a library routine, a re-added (duplicate) slot and a delete-and-recreate, including with the old routine deleted. Starting, discarding and finishing with every bench working set skipped leave each slot ineligible. Then save one bench working set anywhere: existing bench slots become eligible together, their gap starts at that session, nothing is offered before 14 days and an offer appears at 14. Training bench elsewhere resets the clock; training another exercise does not. Reorder and unrelated builder edits preserve the flag; a newly created duplicate does not inherit it.
- Criterion 10's mixed workout lives here too, or in `feature_22`: skipped bench keeps its exercise gap while skipped plank keeps the workout gap and its offer; only applicable slots are cut; finishing resets plank's gap as before.

### `test/feature_22_cycles_test.dart` and `test/feature_04_live_session_test.dart` — excluded modes (criterion 10)

Fully skipped and clean partial Time slots keep their misses, failure streaks and threshold-triggered `holdSeconds` deloads. Cycle and GZCL slots keep their verdict dispatch, week/stage advancement and T3 final-AMRAP trigger. RPE slots keep the `finish()` bypass.

### `test/feature_04_session_continuity_test.dart` — snapshot (criterion 11)

A snapshot written in the shipped two-key notice shape (`{'percent': int, 'days': int}`) restores without throwing, and one with no notice at all still restores. Add the new shape's round trip beside it.

### `test/feature_20_backup_and_restore_test.dart` — upgrade and backup (criterion 16)

Build a pre-v19 database from `kSchemaV1` plus raw SQL rows the way `feature_13` and `feature_21` already do, open it through `AppDatabase` and assert the migration: history, routines, settings and targets unchanged; baseline and gap identity null everywhere; `layoffEligible` true only where a finished session filed against that slot's own workout contains a performed set with that exercise id. Cover a trained slot, a slot whose only history is in an unrelated or deleted workout, a never-trained workout and duplicate slots. Read complete `WorkoutItem` rows after upgrading so a missing column fails the test. Then a backup taken from the new build retains `layoffEligible`, `layoffBaseline`, `layoffBaselineSession` and `layoffBaselineAt` on restore, including false/true eligibility and a non-null timestamp that round-trips at Unix-second precision; an existing routine code still decodes and acquires no training state.

### `test/feature_15_text_size_test.dart` and `test/feature_18_language_test.dart` — copy and layout (criterion 18)

- Both `settingsDeloadOnNote` and `settingsDeloadOffNote` asserted through `l10nFor(locale)` in en, es, pt, pt_BR and uk, with interpolated settings; the settings surface swept at 2× for overflow.
- The **Start dialog opened for real** — the existing screen sweep never opens it. Seed ten or more eligible slots with differing cuts and long exercise names, mount at 360 × 780 dp, at 1.0×, 1.3× and 2.0×, in all five locales: no overflow, no clipped label, scroll to the final offer and verify its targets, and reach and activate accept and decline in separate runs.
- Assert the dialog distinguishes a total reduction from a fresh cut, and that decline and dismissal leave storage unchanged.

Harness reminders that will otherwise cost a run each: wrap drift reads in `tester.runAsync`; tap async handlers inside `runAsync` then `pump()`; never `pumpAndSettle` a tree holding a live session; override `setVideoStoreProvider` for anything reaching `SetVideoStore`.

---

## Step 3 — green: the code

### 3.1 The verdict — `lib/data/progression.dart`, `lib/state/active_workout.dart`

- Keep `SessionVerdict` two-valued. The neutral outcome is `null` — no new enum value, because cycle and GZCL rules must keep taking a total function of two cases.
- `ExerciseEntry`: replace `succeeded`/`verdict` with the three-valued reading. `verdict` becomes `SessionVerdict?`: `miss` when any performed set is `missedGoal`, `success` when every planned set is done and none short, `null` otherwise (no performed sets, or a clean partial). Add the two readable predicates the recap needs — "any working set performed" and "every planned set performed" — and keep them off `warmups`, which are not persisted and never part of an aggregate.
- Rewrite the doc comments on `succeeded`/`verdict`: today they state "skipping a set is a miss", which becomes false for in-scope slots and stays true for the excluded ones.
- `ProgressionMove` gains a third field so `finish()` can tell "held, nothing written" from "moved zero": `({double moved, ProgressionMode axis, bool held})`. Update the handful of call sites.

### 3.2 The boundary — one predicate, `lib/data/database.dart`

Add a getter beside `runsCycle` in `extension WorkoutItemTarget`:

```
bool get takesSkipAwareRules =>
    gzclTier == null && !runsCycle && targetRpe == null &&
    progression != ProgressionMode.time;
```

This is the single definition of "in scope" and both Finish and Start read it, which is what the scope means by using the same boundary in both places. RPE's Finish bypass stays where it is in `finish()`; the predicate covers RPE for the offer side.

### 3.3 `advanceProgression` — `lib/data/database.dart` (~2813)

Widen the parameter to `SessionVerdict? verdict`. The method already reads the row, so it owns the decision:

- `gzclTier != null`, `runsCycle`, or `progression == ProgressionMode.time` → coerce `null` to `SessionVerdict.miss` and dispatch exactly as today. Nothing else in those paths changes.
- Otherwise, `null` → return `(moved: 0, axis: it.progression, held: true)` **without writing anything**: no streak write, no bar-floor correction, no `sessionWeight` establishment, no adoption of a heavier `performedWeight`. This is where criteria 1, 3 and 17's deferral all land, and it is one early return rather than three guards further down.
- A non-null verdict keeps every existing rule, including the read-side bar floor and the percentage-prescription exclusion.

### 3.4 `finish()` and the recap — `lib/state/active_workout.dart` (~1934)

- Pass `e.verdict` straight through (now nullable). Keep the `usesRpe` bypass above it.
- When the move comes back `held` and the exercise has **no** performed working set: `continue` before the `workoutItemById` read-back. The scope forbids reading the slot back solely to build a recap row that is not going to exist.
- When `held` with at least one performed set: read the slot back, and if the axis target is null omit it under the existing targetless rule, otherwise emit a neutral outcome.
- `ProgressionOutcome` gains a flag (a `bool heldIncomplete`, or a small `ProgressionHold` enum if a second reason ever appears) that the summary renders as "not all planned sets were performed". Do not pass the streaks through in a way that lets `_heldNote` claim a pending step or back-off for a session that earned neither.
- `finish()` already sets `lastProgressionProvider` to null when `outcomes` is empty, so an all-skipped session produces no report at all. Confirm `summary_screen.dart` draws no header or empty panel for an empty list on the other route into it (a report with outcomes that the screen filters), and fix it there if it does.

### 3.5 Schema v19 — `lib/data/database.dart` + regenerate

Four columns on `WorkoutItems`:

| column | type | meaning |
| --- | --- | --- |
| `layoffEligible` | bool, default false | this slot has established training since it was created |
| `layoffBaseline` | real, nullable | the pre-cut target retained for the current gap, in the slot's own axis unit |
| `layoffBaselineSession` | int, nullable | id of the performed session the baseline's gap started from |
| `layoffBaselineAt` | DateTime, nullable | that session's `startedAt` |

One real column rather than one per axis: only in-scope slots ever carry a baseline, so it is a weight or a rep count, and the rate columns beside it are already reals for the same reason. Both halves of the training identity are stored because the identifying session can be **deleted** — comparing the current last-performed `(startedAt, id)` against the stored pair lets "a newer session started a new gap" (clear) be told from "history fell back to something older" (keep), which the scope requires and an id alone cannot answer.

Bump `schemaVersion` to 19, add the ladder comment in the same voice as v14–v18, and add one `if (from < 19)` rung:

1. Execute each statement below through `m.database.customStatement`, using literal DDL rather than `m.addColumn`, for the reason the v2 comment gives:

   ```sql
   ALTER TABLE "workout_items" ADD COLUMN "layoff_eligible" INTEGER NOT NULL DEFAULT 0 CHECK ("layoff_eligible" IN (0, 1));
   ALTER TABLE "workout_items" ADD COLUMN "layoff_baseline" REAL NULL;
   ALTER TABLE "workout_items" ADD COLUMN "layoff_baseline_session" INTEGER NULL;
   ALTER TABLE "workout_items" ADD COLUMN "layoff_baseline_at" INTEGER NULL;
   ```

   The boolean uses the existing v4/v8/v9 INTEGER-and-CHECK representation. This database does not enable `storeDateTimeValuesAsText`: `layoff_baseline_at` stores Unix seconds as an INTEGER, matching drift's DateTime mapping, never TEXT or milliseconds.

2. One `UPDATE workout_items SET layoff_eligible = 1 WHERE EXISTS (SELECT 1 FROM session_sets ss JOIN sessions s ON s.id = ss.session_id WHERE s.ended_at IS NOT NULL AND s.workout_id = workout_items.workout_id AND ss.exercise_id = workout_items.exercise_id AND ss.done = 1)` — the documented compatibility fallback. It is a workout-plus-exercise match because shipped history carries no slot id and no slot creation time; it must not be described anywhere as proving when a particular duplicate slot was first trained.
3. Nothing else. No historical row is touched, no target is rewritten, and no baseline is fabricated.

Then `dart run build_runner build --delete-conflicting-outputs`.

### 3.6 The per-exercise clock — `lib/data/database.dart`

Add `lastPerformedFor(int exerciseId)` beside `lastLoggedWeight` (~3379), returning `({DateTime startedAt, int sessionId})?`: `sessionSets` inner-joined to `sessions`, `exerciseId` matched, `sessionSets.done` true, `sessions.endedAt` not null, ordered by `startedAt` desc then `sessions.id` desc, limit 1. No new columns and no new index — this is the shape `session_sets_exercise_session_set` already serves, and rows with a null `exerciseId` simply do not match. `lastTrainedAt(workoutId)` stays exactly as it is; it is now the excluded-slot clock.

### 3.7 Establishing eligibility — `saveSession`

Inside the existing transaction, after the set rows are inserted: select the still-ineligible slots whose `exerciseId` is among the distinct exercise ids just written — in **every** workout, not only this one, because the clock is global and eligibility travels with it — filter them in Dart with `takesSkipAwareRules` from §3.2, and update that set of ids to true. Filtering in Dart rather than restating the predicate as a SQL `WHERE` keeps one definition of "in scope"; `runsCycle` decodes `cycleBlocks`, which SQL cannot do faithfully, so a SQL restatement would drift from the real boundary.

Consequences that are deliberate: an unfinished, discarded or fully skipped session writes no rows and so establishes nothing; warm-ups are never persisted and so cannot establish it; a slot later flipped onto the weight axis from Time arrives ineligible and waits for its next training, which is the conservative answer and matches "an axis edit is not training".

### 3.8 The offer — `lib/data/layoff.dart` + `lib/data/database.dart`

`layoffDeload` and `deloadedTarget` do not change. Add the offer shape to `layoff.dart` beside them:

```
typedef LayoffOffer = ({
  int itemId, int exerciseId, String exerciseName, String? exerciseSeedKey,
  LayoffDeload deload, ProgressionMode axis,
  double? currentTarget, double? proposedTarget, double? baseline,
  int? gapSessionId, DateTime? gapStartedAt,
  bool perExercise,
});
```

`layoffOffersFor(int workoutId, {DateTime? now})` in `database.dart`, beside `layoffFor`:

- Read the settings once; a zero threshold or zero percent returns an empty list before any query.
- For each slot of the workout: in-scope slots need `layoffEligible` **and** a `lastPerformedFor` hit — either alone is not enough, which is what stops a new slot inheriting a 200-day-old cut and what stops a never-performed exercise being offered one. Excluded slots use `lastTrainedAt(workoutId)`, exactly as today.
- Gap in calendar days via the existing `daysBetween`; percentage via the existing `layoffDeload`. Period and threshold are **derived on every read** — neither is persisted, and there is no next-offer boundary.
- The proposal is `deloadedTarget(baseline, percent, axis, floorKg: _loadFloorFor(it))` where `baseline` is the retained one when its stored identity still matches the current gap, and the slot's current target otherwise. A stored baseline whose identity is **older** than the current last-performed session is stale (a newer session started a new gap) and is ignored; one whose identity is newer than what history now shows (because a session was deleted) is kept.
- A slot with nothing to cut — a bodyweight slot with a null `suggestedWeight` — produces no offer, so the movement count stays honest.
- Reading writes nothing. Keep the existing test that proves it.

`layoffFor(workoutId)` stays as the workout-clock helper, both because excluded slots need it and because section 06's `where:` names it.

### 3.9 Acceptance — `applyLayoffDeload`

Change its signature to `Future<List<AppliedLayoff>> applyLayoffDeload(List<LayoffOffer> accepted)` and keep the name, which section 06's corrected `where:` points at. Define the result beside `LayoffOffer` in `lib/data/layoff.dart`:

```dart
typedef AppliedLayoff = ({
  int itemId, int exerciseId, ProgressionMode axis,
  double beforeTarget, double afterTarget,
  int totalPercent, int gapDays,
});
```

Return one result per slot whose target actually changed, after the transaction commits. `beforeTarget` and `afterTarget` are the persisted axis values read and written in that transaction; `totalPercent` and `gapDays` come from that slot's validated accepted offer. The percentage describes its capped total baseline reduction, while the target pair shows the actual change after rounding and floors. The list length replaces the old movement count. One transaction:

- Re-read each slot and drop the offer if its target, axis or training identity has moved since the offer was built — a stale offer is recomputed, not applied.
- Apply the proposed target, clear both streaks, and for an in-scope slot store `layoffBaseline` (the pre-cut target, only if there is not already a live baseline for this gap) with `layoffBaselineSession` / `layoffBaselineAt` from the offer, all in the same write.
- Excluded slots take the cut and store no baseline.
- Collect only slots whose target actually moved. A capped or floored proposal that already matches the target, a streak-only reset, a rejected stale offer or a replay contributes no result; an empty result list reports zero movement. Do not return results for a rolled-back transaction.

Factor the per-slot axis cut into one private helper so there is exactly one place that turns `(target, percent, axis, floor)` into a companion — rule 6.

### 3.10 Baseline invalidation on slot edits — one shared rule, two save paths

`lib/widgets/workout_items_editor.dart`:

- `ItemDraft` carries `layoffEligible`, `layoffBaseline`, `layoffBaselineSession`, `layoffBaselineAt`, populated by `ItemDraft.fromView`. A draft built for a **new** slot gets the defaults (ineligible, no baseline), which is what makes a re-added or re-created slot start false without any extra code.
- Add one shared helper — `layoffStateFor(draft, {defaultBarKg, loaded})` — that compares the effective persisted target and axis before and after the edit and returns companion values for `layoffEligible`, `layoffBaseline`, `layoffBaselineSession` and `layoffBaselineAt`. Clear only `layoffBaseline`, `layoffBaselineSession` and `layoffBaselineAt` on an actual target/axis change, preserving eligibility; preserve all state otherwise. `ItemDraft` needs to remember the target/axis it was loaded with so the comparison is against storage, not against a sibling draft.
- `itemCompanions` (→ `replaceWorkoutItems`) and `itemUpdate` (→ `updateWorkoutItem`) both call that helper. Carry eligibility explicitly through replacement writes. `itemUpdate` writes only the fields it names, so name `layoffBaseline`, `layoffBaselineSession` and `layoffBaselineAt` with explicit `Value(null)` when invalidating; omitting them would retain stale state. Preserve `layoffEligible` on an unchanged exercise identity.
- Eligibility is carried through, never cleared by an edit: reorder, rename and rest-only edits preserve everything; replacing the exercise identity produces a different slot and starts both flag and baseline fresh.

`lib/screens/workout_screen.dart` `_editSlot` needs no new logic — it already round-trips through `ItemDraft.fromView` and `itemUpdate`, so putting the rule in the helper covers it. Verify the live working-weight control still writes only `suggestedWeight` through its own path (`database.dart` ~2299) and is **not** treated as a prescription edit.

`lib/data/routine_import.dart` and `addStarterRoutine`: imported, copied and library-added slots take the column defaults. Nothing to add beyond confirming they insert through `WorkoutItemsCompanion.insert` without touching the new fields, and that no routine-code field bit is added — the share format does not move in this stage.

### 3.11 Start dialog and notice — `lib/widgets/start_workout.dart`, `lib/state/*`

- `startWorkout` calls `layoffOffersFor`, shows the dialog when the list is non-empty, and on accept awaits `applyLayoffDeload(offers)`. Build the notice from the returned `AppliedLayoff` results; the displayed offers alone cannot identify which targets actually changed.
- `_LayoffDialog` becomes a list: one row per offer with the exercise name (through `seededName`), its current target and its proposed target, and the **total** reduction against the retained baseline where there was an earlier cut — 64 kg after an earlier 72 kg is 20% off 80 kg, not a fresh 20%. A row already at its capped target says so rather than promising another cut.
- Constrain the content to the viewport and make the list scrollable inside the dialog, with both actions outside the scroll area so they stay reachable; names and target labels wrap rather than clip. This is what criterion 18's sweep asserts.
- Dismissal stays distinct from decline through the nullable `showDialog<bool>` result: `null` is dismissal, `false` is decline, and both write nothing.
- `LayoffNotice` widens to `({int percent, int days, int exercises})`. For a non-empty applied-result list, derive `percent` as the maximum returned `totalPercent`, `days` as the maximum returned `gapDays` and `exercises` as the list length. Never include percentages or gaps from accepted offers whose targets did not move. An empty result leaves the notice null. The copy must describe a total reduction of up to that percentage across the changed exercises, without implying a uniform percentage, a shared gap or a fresh cut of that percentage from already reduced targets.
- `lib/state/session_snapshot.dart` `_readNotice` must read the **old two-key map** without throwing: it casts with `as int` today, so a shipped snapshot would throw on the first resumed session after the update. Read each key defensively, default the new count, and return null on anything unrecognisable. Write all three keys going forward.
- `lib/screens/workout_screen.dart` `_SessionNotice` composes the line from the widened notice.

### 3.12 Copy — `lib/l10n/short/`, `lib/l10n/long/`, five locales each

- `startWorkoutLayoffBody` is rewritten: "reduce every target in this workout by {percent}%" stops being true. It becomes the dialog's intro, with the per-exercise rows as their own key(s) and a separate key for a total-reduction row.
- `startWorkoutDeload(percent)` is the accept label and a single percent is now wrong for a mixed list; replace with a percent-free short label.
- `startWorkoutDeloadNotice` takes the widened notice.
- `sessionFinishUnloggedBody` drops "an exercise short of its sets counts as a missed session"; the title keeps counting unlogged working sets.
- `settingsDeloadOnNote` / `settingsDeloadOffNote` rewritten per the scope: enabled copy describes the per-exercise gap for Weight/Reps/Weight + Reps with the configured threshold, percentage and cap, keeps the excluded modes' workout gap clear where it refers to them, and must not imply that training another exercise resets the gap, that declining suppresses later offers, or that later offers compound. Disabled copy says timed offers are off, without implying ordinary progression is off or that inactivity is only per workout. Keep the current controls and values; if placeholders change, change `exercise_settings_screen.dart`'s call in the same edit.
- New recap string for the neutral held row.
- Placement by the three-word rule in `lib/l10n/README.md`: short/ for labels up to three visible words, long/ for sentences. Then `dart run tool/l10n.dart` and `flutter gen-l10n`.
- Follow the screen-copy rules in `CLAUDE.md`: label the control, one line or none, no reassurance nobody asked for.

---

## Step 4 — refactor and documentation

- Remove duplication the green pass introduced. The three places that must each have exactly one implementation: the in-scope predicate (§3.2), the per-slot axis cut (§3.9), and the baseline invalidation rule (§3.10).
- `ARCHITECTURE.md` (criterion 13): the `WorkoutItems` row in the table map gains the columns listed in §3.5; the **Layoffs** section says the gap is per exercise for Weight/Reps/Weight + Reps after a slot establishes training, with the workout gap retained for Time, cycle, GZCL and RPE, and describes the retained baseline and why declining still records nothing; the **Progression** section replaces "A skipped set is a miss" with the three-valued verdict and its mode boundary.
- Regenerate the catalogue pages with `dart run tool/features.dart`. The HTML is gitignored — never commit it.

---

## Order of operations

1. Pre-existing `--check` path fix. Commit alone.
2. Catalogue entries, new concepts, section 06 and concept metadata corrections. `--check` clean. Commit.
3. Tests, run once, seen failing for the right reasons. Commit red.
4. Schema v19 + build_runner, since almost everything else compiles against the generated columns.
5. Verdict and `advanceProgression`, then `finish()` and the recap.
6. Per-exercise clock, eligibility on `saveSession`, offers, acceptance, editor state.
7. Start dialog, notice, snapshot compatibility, l10n across five locales.
8. Green. Refactor. `ARCHITECTURE.md`, regenerate pages.
9. Final gate: `dart run tool/features.dart --check`, `flutter analyze`, one `flutter test --no-pub` covering every touched file (criterion 12).

Steps 4–7 are one working set; do not run the suite between them file by file. Regenerating l10n or touching `database.dart` invalidates most of the incremental build, so batch both.

## Integration points to watch

- `advanceProgression`'s signature change touches `finish()` and `test/feature_05_progression_test.dart`'s local `advance` helper; the widened `ProgressionMove` touches every reader of `move.axis`.
- `applyLayoffDeload`'s signature and `AppliedLayoff` result touch `start_workout.dart` and the existing section-06 tests: count assertions read the returned list length, and notice assertions use only the committed per-slot results.
- `LayoffNotice`'s widening touches `active_workout.dart`, `session_snapshot.dart` (both directions), `workout_screen.dart` and the continuity tests.
- `ItemDraft`'s new fields touch `workout_edit_screen.dart`, `routine_edit_screen.dart` and `workout_screen.dart` `_editSlot`; all three already go through `fromView` / `itemCompanions` / `itemUpdate`, so the change is additive if the helper is the only place the rule lives.
- Backup carries the database file itself, so the new columns ride along and only the manifest's schema number moves; old backups climb the same rung.

## Risks

- **Snapshot compatibility is the one change that breaks a shipped phone silently.** `_readNotice`'s `as int` casts are the specific hazard; the compatibility test (criterion 11) is written before the widening.
- **`replaceWorkoutItems` replaces row ids**, so eligibility and baseline survive a builder save only because the draft carries them. A test that goes through the real builder path, not just the companion helper, is what catches a regression here.
- **The migration's workout-plus-exercise fallback is a heuristic**, and duplicate slots in one workout all become eligible together. That is the documented compatibility choice; do not let any comment or catalogue entry claim more for it.
