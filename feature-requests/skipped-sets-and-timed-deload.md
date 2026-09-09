# Skipped sets and timed deloads

Status: Feature request; not implemented.

For the normal progression options—Weight, Reps, and Weight + Reps—skipping a set should not count as a performance failure. An exercise that is skipped entirely should instead remain eligible for the existing timed deload (called a layoff deload in the feature catalogue). Performing even some of its sets counts as training that exercise for inactivity tracking.

## Requested behavior

- Treat an unperformed set as skipped. Skipping it must not itself trigger normal progression, a performance-based deload, or an increase in the failure streak.
- If no sets of an exercise are performed, leave its normal weight and rep targets and progression streaks unchanged. Do not record the exercise as successfully completed or failed.
- A fully skipped exercise does not reset its inactivity timer. Time continues to accumulate since that exercise was last trained, even when other exercises in the workout are performed.
- Once that inactivity reaches the configured timed-deload threshold, offer the existing weight reduction for the skipped exercise. Skipping does not cause an immediate reduction; the existing timing, reduction settings, and accept-or-decline behavior still apply.
- If at least one set of an exercise is performed, treat the exercise as trained for inactivity purposes. Reset its inactivity timer even if the remaining sets are skipped. This partial session must not count as continued inactivity.
- Distinguish skipped sets from performed sets that miss their targets. A recorded performance shortfall remains subject to the normal performance rules.

The requested change covers Weight, Reps, and Weight + Reps progression. Other progression types are outside this request.

## Examples and acceptance criteria

| Session outcome for an exercise | Normal progression | Timed deload tracking |
| --- | --- | --- |
| All three planned sets are skipped | Preserve targets and progression streaks; no success or failure | Keep the previous last-trained time; inactivity continues |
| One or two of three planned sets are performed | Skipped sets do not count as failures or independently cause progression or deload | Count the exercise as trained; reset its inactivity timer |
| All planned sets are performed | Apply the existing performance rules | Count the exercise as trained; reset its inactivity timer |
| Other exercises are performed, but this exercise is entirely skipped | Preserve this exercise's targets and progression streaks | Other exercises must not reset this exercise's inactivity timer |
| The exercise is skipped across enough sessions to reach the configured inactivity threshold | No normal progression or performance deload caused by those skips | Offer the configured timed deload when the exercise is next due to be trained |

For example, finishing a workout with squats completed and bench press entirely skipped should update squats normally while preserving bench press's targets and allowing its inactivity timer to continue. Performing one bench press set would instead count bench press as trained for that timer.

## Existing behavior affected

The [automatic progression catalogue](../features/catalogue/05-progression.yaml) currently describes a skipped set as a miss (`verdict-every-planned-set-logged`). The [layoff deload catalogue](../features/catalogue/06-layoff-deloads.yaml) currently tracks inactivity per workout (`watches-gap-since-workout-was`). Implementing this request will require distinguishing training activity for each exercise so that completing the rest of a workout cannot hide a fully skipped exercise.

## Detail to confirm before implementation

For a partially completed exercise, should normal progression evaluate only the performed sets, or hold the exercise's targets and progression streaks until all planned sets are performed? The requirements above establish that skipped sets must not be treated as failures and that any performed set resets inactivity; they leave this progression decision open.
