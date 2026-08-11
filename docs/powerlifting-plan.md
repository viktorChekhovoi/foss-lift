# Making FossLift usable for powerlifters

A design plan, not a specification. Nothing here has been written into `features/catalogue/` yet — that happens per feature, before its code, as rule 5 requires.

The premise: a powerlifter's program differs from the app's current model in four ways, and only one of them changes the shape of a routine. Everything else is a per-slot option that a regular gym-goer never sees. There is no "powerlifting mode" anywhere in this plan; a global mode switch is the thing that would actually compromise the UI.

Schema version is currently 2. The rungs below are numbered in the order they'd land; renumber them if the order changes before anything ships.

---

## What already carries over

Worth stating, because it makes the remaining work smaller than it looks.

- The competition lifts and their common variants are seeded: Back Squat, Front Squat, Bench Press, Close-Grip Bench Press, Deadlift, Sumo Deadlift, Romanian Deadlift, Overhead Press.
- The trap bar and safety squat bar are already standard bars in both units (`kStandardBarsKg` / `kStandardBarsLb`), and the bar list takes additions.
- `SetScheme` already gives back-off, ramp and fully written-out custom sets, each as a percentage of the slot's weight, and the live board hydrates each set at its own weight and its own rep goal — so a back-off set is already judged against the back-off weight rather than the top one.
- `toFailure` already logs an AMRAP set, and the slot's rest override already handles a four-minute rest.
- Weights are stored in kilograms and converted at the view boundary, so nothing below has a unit problem it has to solve for itself.

The gaps are RPE, a reference weight that percentages mean something against, week-to-week variation, and tempo.

---

## 1. RPE and autoregulated progression

### The problem

Nothing records how hard a set was. `progression.verdict` is "every planned set logged and none short", so five reps at RPE 7 and five reps at a grinding RPE 10 are the same clean session, and both step the slot up by its increment. That is correct for a novice linear progression and wrong for everything a powerlifter runs. It is the single change that decides whether the app is usable past the first few months.

### Behaviour

A slot can advance on a fourth axis: **RPE**. On such a slot you record an RPE against each working set as you log it, and the target moves according to how the prescribed reps felt rather than according to whether you completed them.

The verdict becomes three-way rather than boolean:

- Reps completed at or below the target RPE → **step up** (the existing increment, the existing success threshold).
- Reps completed within a tolerance above target → **hold**, and the streak counters reset the way a hold does today.
- Reps completed well above target, or the reps missed at any RPE → **back off** (the existing deload amount, the existing failure threshold).

The tolerance is one configurable number — call it the over-RPE allowance, default 1.0. Two thresholds (hold vs. back off) would be more expressive and is more knobs than the payoff justifies; one threshold with the existing miss rule underneath it covers the cases people actually run into.

Only the top set's RPE decides the verdict on a slot with a back-off or ramp scheme, for the same reason the weight axis steps from the lightest logged set: the load that carried the exercise is the one being judged. On a flat slot every set is the top set, so this collapses to "the hardest set logged".

### UI

The axis picker is already the first control in the config sheet and already constrains everything below it, so RPE fits the pattern exactly rather than needing a new place to live.

- Config sheet: RPE joins weight/reps/time in the axis picker for a counted exercise. Choosing it reveals two fields — target RPE and the over-RPE allowance — in the same card as the other progression rates. The allowance sits behind the existing Advanced toggle; the target does not.
- Live board: a slot on the RPE axis grows one more cell per set row, tapped after the reps land. It opens a short scale — 6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10 — as tap targets, not a free text field and not a slider. A set logged without an RPE is not a miss; it just contributes nothing to the verdict, and if no set in the exercise carried one, the slot holds.
- Recap: the progression section already says what each target did. On an RPE slot it says why, in the same one line — "Bench Press: 100 → 102.5 kg (RPE 7.5, under 8)".
- Nowhere else. A slot not on the RPE axis shows no RPE field on the board, in the recap, or in history.

### Data

- `SessionSets.rpe`, nullable real. Nullable is the entire upgrade story: existing rows read as "not recorded", which is exactly what they are.
- `WorkoutItems.targetRpe`, nullable real, and `WorkoutItems.rpeAllowance`, real defaulting to 1.0.
- `ProgressionMode.rpe` added to the enum. **Append only** — the enum is stored as text (`textEnum<ProgressionMode>()`), so the risk is not a renumbering but a stored value the old build cannot parse. That matters only for downgrade, which is not supported, and for the routine code, which is handled below.
- `ExerciseMeasure.reps.modes` gains `ProgressionMode.rpe`; `coerce` keeps doing its job unchanged, so a slot on the RPE axis whose exercise turns into a held movement falls back to time rather than logging an RPE against a plank.
- Migration rung 3: add the three columns. All nullable or defaulted, so the rung is the cheap case.

`stepProgression` in `lib/data/progression.dart` does not change shape. It takes a boolean today; it needs to take a three-way outcome instead, with the existing thresholds applying to whichever counter moves. Keep the arithmetic in that file, free of drift and Flutter, and keep the RPE-to-verdict decision there too — it is exactly the kind of rule that silently rewrites months of training if it is wrong.

### Routine sharing

`FLR1` carries the prescription, so it has to carry the axis. The flag bits and enum slots are append-only: RPE gets the next free progression slot, and target RPE and the allowance ride as new optional fields. A phone on the old build receiving a code with an RPE slot in it is the case to decide deliberately — either the old reader rejects the code, or the field is written so an old reader skips it and lands the slot on the weight axis. The second is better and is what the format's optionality is for, but it needs checking against how `share_code.dart` actually skips unknown tags before it is promised.

### Open questions

- RPE or RIR? RPE is what powerlifting programs are written in and what the audience asks for. RIR is the same scale inverted and is what a general gym audience finds legible. Offering both is a display preference over one stored number (`rir = 10 - rpe`), which is cheap, but it is another setting. Recommendation: store RPE, ship RPE only, revisit if anyone asks.
- Does an RPE slot still honour a rep range? Yes, and it should — "3 × 5 @ RPE 8" and "3 × 5–7 @ RPE 8" are both real prescriptions. The reps part of the verdict stays exactly as it is; RPE decides only which direction the target moves once the reps are satisfied.

---

## 2. A training max, and percentages that reference it

### The problem

A scheme's percentages are of `WorkoutItems.suggestedWeight`, an absolute number that progression walks up session by session. A powerlifting program is written against a 1RM or a training max that moves once a *block*: 5/3/1, Sheiko, most of the Russian templates. Expressing "82.5% of your training max" today means computing it by hand and retyping it into every slot whenever the training max moves.

### Behaviour

An exercise gains an optional **training max** — one number, edited in one place, in the exercise's own settings beside the bar and the weight type. It is a property of the movement, not of any program built on it, exactly like the measure and the weight type.

A slot's weight becomes either an absolute number (today, and the default) or a percentage of its exercise's training max. When it is a percentage, the whole existing scheme ladder computes off the resolved weight and needs no change at all — the slot's weight is still the top of the ladder, and progression still moves one number.

Progression on a percentage slot moves the **training max**, not the slot. That is the point: one clean block bumps the training max and every slot referencing it moves together, which is what a percentage-based program means by progressing.

### UI

- Exercise settings (already reachable from the config sheet's Exercise card): one more field, "Training max", empty by default. Empty is a real state and means the exercise has no training max, which is true of almost every accessory.
- Config sheet, weight field: a small unit-style toggle between `kg` and `%`. In `%` the field takes 82.5 and the line under it reads the resolved weight — "82.5% of 180 kg = 147.5 kg" — so nobody has to do the arithmetic to know what they're loading. If the exercise has no training max, the `%` option is disabled with the reason, the same way the weight axis is withheld from an unloaded movement.
- Nothing new on the live board. The board shows a weight; where it came from is the builder's business.

### Data

- `Exercises.trainingMaxKg`, nullable real. Canonical kilograms like every other stored weight.
- `WorkoutItems.weightIsPercent`, boolean defaulting false, with `suggestedWeight` reinterpreted as a percentage when it is true. Reusing the column rather than adding a second one keeps there from being two places a slot's weight can hide.
- Migration rung 4: two columns, both cheap.

### Rounding

`resolveSetTargets` snaps every computed weight to the display unit's step — 2.5 kg or 5 lb — and holds it at or above the bar. 82.5% of 180 is 148.5, which becomes 147.5. That is defensible but coarse for a program whose whole method is small percentage steps, and it compounds when the training max moves by 2.5 kg and half the slots don't move at all.

Two things follow, and they are worth doing with this feature rather than after complaints:

- The rounding step becomes a setting (Profile → Exercise settings), defaulting to today's behaviour so nothing changes for anyone who doesn't touch it. 1.25 kg and 0.5 kg are the values that matter.
- The plate inventory has to accept sub-1.25 kg plates. `kDefaultPlateInventory` starts at 1.25 kg; check that the inventory screen takes an arbitrary size rather than a fixed list, and that the solver's cost model doesn't misbehave with four microplates a side. If it does not, this is its own small piece of work and belongs before the rounding setting, not after — a rounding step the rack cannot load is worse than no setting.

### Open question

Training max or 1RM? They differ by a convention (a training max is usually 90% of a tested 1RM) and by what people type in. Storing a training max and letting people type whatever number they want their percentages to be against is simpler, honest about what it is, and does not require the app to have an opinion about the 90% convention. Recommendation: training max, labelled as such, no derived 1RM anywhere.

---

## 3. Week-to-week waves

### The problem

A routine is a set of workouts on a weekly day mask. There is no notion of "week 2 of the block", so 5/3/1's 5s/3s/1s+ weeks, or any wave at all, can only be built as three near-identical workouts that you remember to run in order. That works today and is genuinely unpleasant.

This is the only piece in this plan that changes the shape of a routine, and the only one that can make the builder confusing. It should land alone, after the first two have been used for a while.

### Behaviour, kept narrow

- A routine gains an optional **cycle length in weeks** and a **current week**. Default is 1, which is exactly today's behaviour and means the concept is invisible on every routine nobody opts in.
- A slot can carry per-week overrides of its weight (absolute or percentage), its rep target, and its target RPE. A week with no override runs the slot as configured, so a wave that changes only the top set does not require writing out every week of every slot.
- The current week advances when the routine comes round — when every workout in it has been trained once, or on a fixed weekly boundary. **This needs deciding before anything is written.** "Every workout trained once" survives a missed session by not advancing, which is usually what somebody wants and occasionally is not. A manual "advance week" control is the escape hatch either way and is not optional.
- The Today tab reads "Week 2 of 4" where it currently reads nothing.

### Explicitly not in scope

A block or mesocycle builder — accumulation/intensification/peaking phases, planned deload weeks as a first-class thing, a calendar of the next twelve weeks. That is a different application and it is where this feature turns into one.

### Data

- `Routines.cycleWeeks` (int, default 1) and `Routines.currentWeek` (int, default 1).
- A `WorkoutItemWeeks` table: item id, week number, and the nullable overrides. A row per (slot, week) that actually overrides something, rather than a dense grid.
- Migration rung 5: two columns and one new table.
- Routine sharing carries the cycle. A shared 5/3/1 that arrives without its weeks is not the program.

### The interaction to get right

Progression and waves both want to move the slot's weight, and they must not both do it. On a routine with a cycle, progression should move the training max (or the slot's base weight) at the end of the cycle, not at the end of each session, and the per-week overrides should be percentages off that base rather than absolute numbers. Writing that rule down before the schema is the difference between this feature working and it fighting itself.

---

## 4. Tempo, and the small things

### Tempo

Paused bench, tempo squats and pin work are currently expressible only by naming an exercise "Paused Bench Press", which multiplies the library and loses the history of the movement underneath.

A slot gains an optional tempo — `TextColumn get tempo`, nullable, holding a string like `3-1-1-0`. It is shown on the live board beside the rep goal and nowhere else, and it is not validated beyond a length cap: the notation has three-, four- and five-figure variants and the app has no business having an opinion on which one somebody's coach writes in. It affects nothing computationally. Migration rung: one nullable column.

### Best single, triple and five

The progress chart plots the top set by weight, which is the right default and was chosen deliberately over an estimated 1RM. What it does not offer is what a powerlifter actually tracks: the best set at each rep count. A "best lifts" section on the exercise progress screen — heaviest single, heaviest double, heaviest triple, heaviest five — is pure aggregation over sets already stored, needs no schema change, and is honest in exactly the way the rejected e1RM was not, because every number in it is a lift that happened.

### Bodyweight

There is no bodyweight log anywhere in the app. It is what a weight class, a Wilks/DOTS score and any bodyweight-relative stat would all have to be built on, and none of those are in this plan. Noting it here so the absence is a known one rather than a discovery.

---

## The tension worth naming

`10-history-and-stats.yaml` rejects the estimated 1RM as a chart line, and the reason given is good: it is a formula's opinion about a lift you did not do, and two numbers disagreeing about whether you are progressing is one number too many.

RPE-driven progression computes something very close to an e1RM internally — "5 reps at RPE 8" is a point on the same table. Using it as a hidden input while refusing to draw it beside the top set is a defensible position, and I think the right one, because the objection was to the number as a *display* competing with a real one. But it is a decision to make on purpose rather than to discover halfway through implementing the RPE axis, and if the answer is "no e1RM anywhere, including internally", then the RPE verdict has to be written as a direct comparison against the target rather than as a load calculation, which is a different implementation.

---

## Order

1. **RPE axis.** No new screens, one new axis, three columns. The change that decides whether the app is usable for this audience at all.
2. **Training max and percentage weights**, with the rounding step and the microplate check. Percentage schemes already exist; only their reference point is missing.
3. **Tempo** and **best single/triple/five**. Cheap, independent of everything above, good filler between the larger two.
4. **Week waves.** Alone, once 1 and 2 have been lived with, and only after the progression-versus-wave interaction is written down.

Nothing in 1–3 changes an existing behaviour, so each is an added option on a slot rather than an edit to what a slot already does. Item 4 is the one that will need existing catalogue entries edited in place rather than new ones added beside them.
