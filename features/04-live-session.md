# Live workout session

Start a day, log each set, run the rest timer, and finish — all in memory until
you're done.

## What it does

- **Starts a training day** and hydrates set rows from the template.
- **Logs sets by tapping.** Each row shows a goal (reps or seconds) and a weight;
  tapping cycles the logged value, and holding types an exact one in.
- **Carries one weight per exercise.** The load is set once, above the working
  sets, and every set follows it — a single set can still be dropped on its own.
- **Tracks duration and set count live** — a 1-second timer ticks the elapsed
  time; the set counter updates as you log.
- **Runs a rest timer** using each slot's configured rest, with
  shorter / longer / skip controls — captioned with what to do with the rest,
  and sounding when it ends: a tone if you are looking at the app, a
  notification if you are not.
- **Marks the set you are on**, so coming back to the phone does not mean
  scanning for the last row that went green.
- **Suggests warm-up sets** for barbell/weighted lifts — an ascending ramp toward
  the working weight, landing only on loads the gym can actually be set to —
  kept separate from the working sets.
- **Survives being collapsed** — leave the session and a resume bar sits at the
  bottom of every other screen, one tap from getting back to it.
- **Lives in the notification shade** for as long as it is running: what to
  lift, with **Done** and **Missed**, or how long is left of the rest, with
  **+30s** and **Skip**.
- **Can be aborted**, for the session started by a misplaced tap: a confirmed
  abort throws it away without writing anything or moving a target.
- **On Finish**, writes only the completed sets, advances progression, and opens
  the [post-session recap](10-history-and-stats.md).

## How to use it

- **Start:** Today → tap a day → **Start workout**. (If a [layoff
  deload](06-layoff-deloads.md) is offered, accept or decline it here first.)
- **Log a set:** tap the set row's result cell to cycle its value (goal → one
  fewer → … → 0 → untouched); hold it to type an exact count.
- **Log a hold:** tap the result cell to start the clock, tap again to stop it.
  Holding it still types a duration in by hand.
- **Change the weight:** tap the weight above the working sets to move the whole
  exercise; tap a single row's weight to move only that set.
- **Your note:** tap the note icon beside an exercise to read it, the pencil
  that appears to change it. On a movement you have not noted anything about,
  the icon writes the first note.
- **Rest:** logging a set starts the rest banner; use shorter / longer / skip.
- **Warm-ups:** expand the collapsed warm-up group above the working sets; adjust
  the number of warm-up sets with its stepper.
- **Leave and come back:** the down-arrow collapses the session (it keeps
  running); tap the resume bar at the bottom of the screen to return.
- **Abort:** the bin icon beside Finish → **Abort** on the confirmation.
- **Finish:** tap Finish → the recap screen appears.

## Behaviour & edge cases

- **The live session is in memory** and only writes to the DB on Finish, so
  editing sets is instant and a mid-session crash can't leave half-saved rows.
- **The note is the one exception, and it goes both ways.** Mid-workout is when
  you learn the thing worth noting — the seat was wrong, the pin is one lower
  than you remembered — so a note can be written and edited from the board, and
  it lands in the library at once. It is read live too, so one written from the
  library while a session runs shows up on that session. A note is a fact about
  the movement, not session state; everything else on the board stays the
  snapshot it started as.
- **The resume bar has one slot: the row directly above the bottom navigation
  bar.** Where there is no navigation bar — every screen pushed over a tab — it
  is the last row of the app, which is the same slot with nothing under it. It
  is never over content, never below the navigation bar, and never in two places
  at once. That is the whole rule; everything below is why it takes work.
- **The resume bar docks, it does not float.** A control that hides what you are
  trying to read is worse than one you have to go and find, so it takes real room
  rather than lying over the screen: on a tab screen it stacks above the
  navigation bar, everywhere else it is the last row of the app. Nothing is ever
  underneath it, and the bottom of every list stays reachable while a session is
  open. One line, because it is furniture for as long as the session lasts.
- **There is only ever one resume bar on screen.** Two mount points draw it and
  exactly one may be live at a time — including *during* a navigation, which is
  the case that got this wrong. Pushing a screen over a tab flips the route the
  instant the tap lands, but the tab screen keeps painting for the length of the
  slide, so for those few hundred milliseconds both mount points thought the bar
  was theirs and it appeared twice: once above the navigation bar and once below
  it. Ownership follows what is *on screen*, not what the route says, so the
  count is one whether the app is settled or mid-transition.
- **The whole session is in the notification shade.** Phone in a pocket, and a
  straightforward set needs no screen: the notification names the exercise, the
  weight in your unit and the reps, walks an exercise's warm-up rungs before its
  working sets, and counts the rest down live.
  - **Done** logs the outstanding set at its goal and starts the rest, without
    the app coming forward. It asks the session what is outstanding rather than
    trusting the notification it came from, which may be a moment out of date.
  - **Missed** logs one short of the goal — so it lands gold and the number is
    already close — and brings the app up to correct it. No rest starts: you are
    about to be looking at the screen anyway.
  - **A rest offers +30s and Skip.** Nothing can be logged during one, but the
    rest is the one stretch of a session you are certainly not holding the phone
    for. Skipping was left off at first — cutting a rest short is a decision,
    and a decision does not belong on a control you brush past through a coat —
    and that was wrong in the gym: unlocking the phone to press Skip costs more,
    every time, than an accidental press costs once. The step is +30s rather
    than the screen's +15s, because a pocket press is not a considered one.
    Skip is silent, and neither button brings the app forward.
  - **It says which set of how many.** `Bench Press · Set 4/5`, and a warm-up
    rung counts its own ramp: `Warm-up · Bench Press · Set 2/3`. Four identical
    sets of bench read identically from a pocket without it, and the only way to
    tell the first from the last would be to open the app the shade exists to
    save you opening.
  - **While resting, the line names the exercise.** The bold line is the
    countdown, so the second line is the only place a movement can be named:
    `Next: Bench Press · Set 4/5 · 80 kg × 8`, and `Next: Warm-up · Bench Press
    · Set 1/3 · 60 kg × 5` when the ramp is what comes next. A weight and a rep count belonging to
    nothing is not an instruction.
  - **A hold gets one button, "Open".** How long you held something is the
    measurement itself, so nothing can claim it at the goal or guess it one
    short — it opens the app at the stopwatch instead.
- **It is a foreground service, and that is not about the notification.** An
  ordinary notification would draw the same thing. The service is about the
  *process*: the session is in memory and untouched until Finish, so a Done
  press has to reach the isolate holding it, and without a service Android may
  kill the app once it is backgrounded. **The service is what makes "in memory"
  survivable** rather than a reason to start persisting mid-workout.
  - Android 14 wants a `foregroundServiceType` and none of them fits a workout
    log: `health` needs an activity-recognition permission this app has no
    business asking for, `shortService` caps at three minutes, `dataSync` is
    wrong and capped at six hours a day. So `specialUse`, with the subtype
    spelled out — which needs a justification at Play Store review.
  - Off Android it is a no-op, not a crash.
- **It asks to post notifications, or it is invisible.** Declaring the
  permission in the manifest is not the same as holding it: on Android 13 and
  up it is a runtime grant, and without it the service starts, reports success
  and draws nothing — the failure the user sees is not an error but an absence,
  which is why it went unnoticed. So the first session asks. The ask happens at
  the point the shade is first needed rather than on launch, because a
  permission prompt makes sense next to the thing that wants it and reads as
  noise on a cold start.
  - **Refusal is not an error.** The workout runs exactly as before, just
    without the shade, and nothing interrupts it to say so. The app asks once
    and does not badger; Android stops showing the dialog after a refusal
    anyway, and the switch that turns it back on is the phone's, not the app's.
  - Nothing else in the app gains a permission from this. Reminders already ask
    for the same grant on their own account and either may be the one that
    happens to get it first.
- **The rest clock belongs to the session, not to the screen.** It keeps
  running while the logging screen is popped — putting the phone away mid-rest
  is the ordinary case, not an edge one — and a countdown a notification can
  show has to exist somewhere the notification can see. A timer owned by a
  widget dies with the widget.
- **A session ends by finishing it or by aborting it.** Collapsing never
  discards it, and an abort always asks first — it is the one control on the
  screen that destroys work.
- **Only one session runs at a time, and Start knows it.** Starting the workout
  already in progress opens it rather than restarting it: you tapped the thing
  you are already doing, so there is nothing to decide. Starting a *different*
  one asks first — it names the session at risk, how many of its sets are logged
  and how long it has been running, and defaults to keeping it. Every entry
  point goes through the same check, and the check comes before the layoff offer
  so nothing is cut for a session that never starts.
- **The weight belongs to the exercise, not to each set.** Deciding mid-session
  that today's squat is 100 rather than 95 is one edit, not one per set row. The
  sets follow it; the ones already logged keep the weight they were actually
  done at. Neither the exercise's weight nor a set's own is a text field sitting
  open on the board — both are values you tap to edit, because the weight
  changes now and then, not every set.
- **Moving the weight rebuilds the warm-up.** A ramp computed for a weight you
  are no longer lifting is priming the wrong lift. Rungs already logged survive
  the recompute — the plates were on the bar and you lifted it — and only the
  ones still ahead of you are redrawn. Changing the *count* follows the same
  rule.
- **A rest says what it is for.** What you should be doing during one differs
  by where in the session you are, and the app knows which case it is in, so the
  banner says rather than just counting:
  - *between warm-up rungs* — the next rung is a different load: "Set up 60 kg,
    then lift."
  - *after the last rung* — the working weight is different again, and this is
    the longest rest of the ramp: "Set up 100 kg, rest, then lift."
  - *between working sets* — nothing to change: "Rest, then lift."
  - *between exercises* — a different movement and a different setup: "Set up
    Overhead Press, rest, then lift."

  The weight named is the one about to be lifted, in the display unit. The line
  replaces the word "REST": a banner counting down is self-evidently a rest.
  "Between exercises" skips past any exercise already finished — walking to a
  machine you are done with is not advice.
- **The caption gives; the banner does not grow.** "Set up Barbell Romanian
  Deadlift, rest, then lift." is a real exercise name in a real sentence, and
  left to itself it wrapped to three lines, pushed the clock down and squeezed
  the shorter / longer / skip buttons out of shape. The banner is a fixed piece
  of furniture over the board: the caption is the part with no length to it, so
  the caption is the part that yields — it holds to two lines and ellipsises
  past that, while the countdown and the three controls keep their place and
  their size at any name length and any text scale.
- **It makes a sound when it ends.** A rest that ends silently is one you
  overrun with the phone in your pocket. **One note, not two.** The first tone was a two-note figure a fifth apart, which reads as
  "da-dong" — a little melody, and a melody is a thing you notice having heard
  rather than a thing you act on. A rest ending is one event, so it gets one
  ding: a single pitch with a fast attack and a short decay, under half a
  second, struck at the top of the scale. It was a third of a second and well
  under the ceiling, and was reported as too quiet — loudness is duration as
  much as amplitude.

  The tone is *synthesised* and shipped as an asset, so there is no licence
  attached to it and nothing to attribute. **The generator is committed beside
  it** (`tool/make_rest_tone.dart`) rather than left in a commit message: a wav
  is a binary nobody can review, and the frequency, the envelope and the length
  are the whole design. Regenerating it must produce the same file, byte for
  byte. It is not built in CI — an asset that only exists in a release is one no
  developer has ever heard and no test can play.

  A system sound was the obvious route and is a dead end: Flutter's
  `SystemSound.play` is documented as ignored on Android and iOS both. The tone
  is declared as an **alarm** on Android: that puts it on the alarm stream,
  where it follows the phone's own silent and Do-Not-Disturb behaviour rather
  than overriding it. It takes transient focus, so music pauses for the length
  of the ding and resumes — asking a player to duck if it feels like it is a
  request most players decline, which is the other half of "too quiet".
  **There is no switch on it.** A rest timer that ends silently is a rest timer
  that does not work, and the phone already has three better controls for the
  same intent — the volume keys, silent mode and Do Not Disturb — every one of
  which both routes follow by being declared alarms. No network permission, and
  the player is MIT-licensed.

- **Off screen, the ding is a notification instead.** A media player is the
  right instrument while you are watching the countdown and the wrong one with
  the phone in a pocket and the screen off — which is most of what a rest timer
  is for. So a rest that runs out while the app is not on screen arrives on its
  own high-importance channel, at alarm volume, with a buzz, naming what is
  next ("Rest done — Bench Press · 80 kg × 8"); it clears itself, and the next
  rest starting takes it down. **Never both**: two dings for one rest reads as
  two rests. It is the same sound either way — the generator writes the wav
  twice, once as a Flutter asset and once as an Android raw resource, because a
  notification can only sound from Android's own resources and a rest should not
  end with a noise you have never heard. Skipping a rest by hand sounds nothing,
  and the rest-sound switch silences both routes.
- **−15s ends a rest with less than 15 seconds left.** Below that the button's
  only honest readings are "skip" and "do nothing", and a button that does
  nothing is the worse of the two.
- **The goal is stated once per exercise**, on the line that carries the weight
  you can edit: `WORKING SETS   × 8   [80 kg ✎]`. It used to be a column,
  reprinted on every row — where the weight cell beside it already said the
  weight and the untouched result cell already said the reps, greyed out as the
  number you are about to claim. A held movement reads `× 45s`; one with no load
  to name states the target on its own rather than hanging a `×` off nothing.
- **The board marks the set you are on.** Every set of the session is drawn at
  once, which is what the board is for — but it also means the only way to find
  your place after a rest, or after picking the phone up, was to scan for the
  last row that went green. The set the shade would name is marked in the accent
  on the board too, from the same arithmetic. Warm-ups count: when the ramp is
  where you are and its group is shut, the group carries the mark, and opening
  it moves the mark onto the rung. Exactly one thing is ever marked, and nothing
  is once every set is logged.
- **The tap-to-log hint is pinned**, beside the duration and set count, rather
  than scrolled with the rows: "how do I log this?" occurs on whichever exercise
  you are looking at, not only the first.
- **Warm-ups are never persisted** — they're suggestions, not history, so logging
  them can't distort volume or lifetime totals. They ride alongside the working
  sets and are excluded from every working-set aggregate (verdict, volume, set
  count). The group carries a liability disclaimer.
- **Warm-up rest is shorter between rungs, full before the work.** 45 s between
  warm-up sets — that's changing the plates and catching your breath — but after
  the *last* rung the exercise's own rest runs instead, because the next thing
  you do is the working set and a warm-up is not meant to be fatigue you lift
  through.
- **Every warm-up rung is a load the gym can be set to.** A ramp of percentages
  is useless if nobody can build the numbers, so each step lands on the nearest
  *cheap* real load rather than the exact percentage:
  - **Barbell — starts on the empty bar**, and each later rung is a weight the
    plates can make, preferring the fewest plates per side. 225 lb over a 45 lb
    bar gives **45 → 115 → 185** at the default three, and **45 → 95 → 135 →
    185** at four: one pair a step, in the sizes a lifter reaches for. (In a
    metric gym, 80 kg over a 20 kg bar gives 20 → 40 → 60.)
  - **Dumbbell — the increments a gym stocks bells in**: multiples of 5 lb, or
    2.5 kg in a metric gym.
  - **Machine/cable — multiples of 5**, which is how a stack is labelled, in
    either unit.
  - The ramp starts on the empty bar for a barbell and at ~40% of the work for
    anything else (a dumbbell has no empty bar to stand on). **85% of the work
    is a hard ceiling** — snapping onto a loadable weight rounds down past it,
    never up, so the last warm-up can't turn into a first working set. Reps fall
    off as the load climbs (8 → 5 → 3 → 2 by fraction of the work), so an 80 kg
    bench warms up 20×8, 40×5, 60×3.
  - **A step will only stray a tenth of the working weight to find a cheaper
    load.** Cheapness breaks a tie between neighbouring loads; it is never worth
    warming up 50 kg lighter than intended for the sake of one pair of plates.
  - Where a coarse grid puts two steps on the same load the duplicate is
    dropped, so a light lift gets a shorter ramp than asked for rather than one
    that stalls or steps backward.
- **One warm-up set is a middle-of-the-road set, not the empty bar.** Dial the
  stepper to 1 and you get a single rung around halfway between the bar and the
  ceiling — heavy enough to actually warm you up, light enough to be safe: 40 kg
  for an 80 kg bench, 70 for a 140 kg squat, 115 lb for a 225 lb squat. With one
  set there is no ramp to open, so the "starts on the empty bar" rule doesn't
  apply — it resumes at two rungs and up. **A light lift still collapses to the
  bar on its own**, at any set count, because there is nothing between the bar
  and the work to put in: a 25 kg lift over a 20 kg bar warms up with the empty
  bar and nothing else.
- **The ramp's shape follows published practice, as fractions of the working
  weight** (not of 1RM): three sets by default because 2–4 is where the research
  lands for a compound lift and more starts costing fatigue; 40–50% / 60–70% /
  70–80% for the loads; 8–10 / 4–6 / 1–3 for the reps; 45–60 s between rungs. The
  stepper goes to six for a heavy lift starting from an empty bar, but six is a
  choice the user makes, not a suggestion. Sources are cited in
  `lib/data/warmup.dart`.
- **A held set times itself.** A hold is a duration you measure, not a count you
  claim, so its result cell is a stopwatch: tap to start, tap again to stop, and
  the seconds it ran are what gets logged. It shows the running count in the
  accent with a heavier border — the one thing on the board actively happening —
  and sounds the same tone as the rest timer when it stops. The rest begins then
  too, not when the hold started.

  Only one hold runs at a time. Starting a second logs the first rather than
  losing it: you cannot be in two planks at once, and the one you were in did
  happen. Tapping a hold that is already logged clears it, which is the same
  "undo by tapping" the rep cycle ends on. A long press still types an exact
  duration in — for the hold you timed on the clock on the wall.
- **A missed set** is one that fell short on reps/seconds *or* weight (deloading
  to finish counts as a miss) — this feeds progression.
- **Finish order matters:** sets are saved *before* progression advances, so a
  template never steps up without the history to justify it.

## Where it lives

- State: `lib/state/active_workout.dart` (`SetEntry` / `ExerciseEntry` /
  `ActiveWorkout` + `ActiveWorkoutController`).
- Warm-up ramp: `lib/data/warmup.dart`; the loads it may land on come from
  `loadLadder` in `lib/data/plates.dart`.
- Screens/widgets: `lib/screens/workout_screen.dart`,
  `lib/widgets/resume_workout_bar.dart`.
- The rest tone: `lib/services/rest_tone.dart` on screen and
  `lib/services/rest_alarm.dart` off it, with the asset in `assets/sound/`, its
  twin in `android/app/src/main/res/raw/`, and the generator that produced both
  in `tool/make_rest_tone.dart`.
- The shade: `lib/services/workout_shade.dart`, on the "what now?" model in
  `lib/state/workout_cue.dart`; kept current by `workoutShadeSyncProvider`.
- Starting one: `lib/widgets/start_workout.dart` — the switch confirmation, the
  layoff offer and the push to `/session`, in that order.

## Related issues

- [#8 StrongLifts-style set logging](https://github.com/viktorChekhovoi/foss-lift/issues/8) — shipped
- [#9 Suggest the next workout, but allow choosing any](https://github.com/viktorChekhovoi/foss-lift/issues/9) — shipped
- [#26 Workout should persist until manually ended](https://github.com/viktorChekhovoi/foss-lift/issues/26) — shipped
- [#25 Warmup calculator](https://github.com/viktorChekhovoi/foss-lift/issues/25) — shipped, in review
- [#35 One weight per exercise, and a warm-up ramp that follows it](https://github.com/viktorChekhovoi/foss-lift/issues/35) — shipped, in review
- [#39 Starting a workout while one is already live](https://github.com/viktorChekhovoi/foss-lift/issues/39) — shipped, in review
- [#40 Exercise notes, editable during a workout](https://github.com/viktorChekhovoi/foss-lift/issues/40) — shipped, in review
- [#41 The resume bar covered content it should not](https://github.com/viktorChekhovoi/foss-lift/issues/41) — shipped, in review
- [#36 Rest prompts, and a sound when the timer ends](https://github.com/viktorChekhovoi/foss-lift/issues/36) — shipped, in review
- [#38 Timed movements: a count-up timer](https://github.com/viktorChekhovoi/foss-lift/issues/38) — shipped, in review
- [#37 Run a workout from the notification shade](https://github.com/viktorChekhovoi/foss-lift/issues/37) — shipped, in review
- [#55 The live-workout notification never appears](https://github.com/viktorChekhovoi/foss-lift/issues/55) — open
- [#56 Two resume bars during a navigation](https://github.com/viktorChekhovoi/foss-lift/issues/56) — open
- [#57 A long exercise name wrecks the rest banner](https://github.com/viktorChekhovoi/foss-lift/issues/57) — open
- [#58 One clean ding instead of a two-note figure](https://github.com/viktorChekhovoi/foss-lift/issues/58) — open
- [#60 The board never says which set you are on](https://github.com/viktorChekhovoi/foss-lift/issues/60) — shipped, in review
- [#61 The rest ding is too quiet, and silent off screen](https://github.com/viktorChekhovoi/foss-lift/issues/61) — shipped, in review
- [#62 Rest controls in the shade, and a "Next:" that says what of](https://github.com/viktorChekhovoi/foss-lift/issues/62) — shipped, in review
- [#63 The goal was reprinted on every set row](https://github.com/viktorChekhovoi/foss-lift/issues/63) — shipped, in review
- [#65 The shade did not say which set of how many](https://github.com/viktorChekhovoi/foss-lift/issues/65) — shipped, in review
- [#66 The rest sound is no longer a setting](https://github.com/viktorChekhovoi/foss-lift/issues/66) — shipped, in review
