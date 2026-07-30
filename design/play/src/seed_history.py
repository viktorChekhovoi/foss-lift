#!/usr/bin/env python3
"""Seed a FossLift database with ten weeks of plausible PPL history.

Writes into a copy of the app's own sqlite file, so the schema is whatever the
app created. Weights ramp up to each workout item's current suggested_weight,
so the history and the app's next-load suggestion agree.
"""
import sqlite3
import sys
from datetime import datetime, timedelta

DB = sys.argv[1]
# Last logged session: Monday 27 Jul 2026. Today (Wed 29th) is a training day
# with nothing logged yet, so Today shows the next workout ready to start.
LAST = datetime(2026, 7, 27, 18, 10)
WEEKS = 10
ROUTINE = 1                      # Push / Pull / Legs
WORKOUTS = [(1, 'Push'), (2, 'Pull'), (3, 'Legs')]

db = sqlite3.connect(DB)
db.execute('delete from sessions')
db.execute('delete from session_sets')
db.execute('delete from live_sessions')

items = {}
for wid, _ in WORKOUTS:
    items[wid] = db.execute(
        'select wi.id, e.id, e.name, wi.target_sets, wi.reps_min, wi.reps_max,'
        '       wi.suggested_weight, wi.increment, wi.progression'
        '  from workout_items wi join exercises e on e.id = wi.exercise_id'
        ' where wi.workout_id = ? order by wi.position', (wid,)).fetchall()

# Session dates, oldest first: Mon/Wed/Fri, rotating Push → Pull → Legs.
dates = []
d = LAST
for i in range(WEEKS * 3):
    dates.append(d)
    d -= timedelta(days=3 if d.weekday() == 0 else 2)
dates.reverse()

# A couple of stalled weeks so progression does not read as a straight line:
# these session indexes repeat the previous load instead of adding to it.
STALLS = {12, 13, 22}

for n, when in enumerate(dates):
    wid, wname = WORKOUTS[n % 3]
    cycle = n // 3                      # 0..WEEKS-1, this workout's nth time
    stalled = sum(1 for s in STALLS if s // 3 < cycle and s % 3 == n % 3)
    step = max(0, cycle - stalled)
    total_cycles = WEEKS - sum(1 for s in STALLS if s % 3 == n % 3)

    # Vary the hour a little so the history list reads like a real log.
    when = when.replace(hour=17 + (n * 5) % 3, minute=(n * 23) % 60)
    started = int(when.timestamp())
    dur = 2640 + (n * 137) % 900
    cur = db.execute(
        'insert into sessions (routine_id, workout_id, name, started_at,'
        ' ended_at, duration_seconds, total_volume, sets_completed)'
        ' values (?,?,?,?,?,?,0,0)',
        (ROUTINE, wid, wname, started, started + dur, dur))
    sid = cur.lastrowid

    volume, done_sets = 0.0, 0
    for (_iid, eid, ename, sets, rmin, rmax, sw, inc, prog) in items[wid]:
        top = rmax or rmin
        if prog == 'weight' and sw is not None:
            # Final cycle lands one increment below the current suggestion, so
            # the app's next-load maths continues from where history stops.
            weight = sw - (total_cycles - step) * inc
            weight = max(inc * 2, round(weight / inc) * inc)
            goal_reps = top
        else:
            weight = 0.0
            goal_reps = min(top, rmin + step // 2)
        # Now and then the last set of an accessory lift gets left undone.
        logged = sets - 1 if (n * 3 + eid) % 17 == 0 else sets
        for s in range(1, logged + 1):
            # The last set of the heaviest lift falls a rep short now and then.
            reps = goal_reps
            if s == sets and (n + s) % 7 == 0:
                reps = max(rmin, goal_reps - 1)
            db.execute(
                'insert into session_sets (session_id, exercise_id,'
                ' exercise_name, set_number, weight, reps, done, goal_reps,'
                ' goal_weight) values (?,?,?,?,?,?,1,?,?)',
                (sid, eid, ename, s, weight, reps, goal_reps,
                 weight if weight else None))
            volume += weight * reps
            done_sets += 1

    db.execute('update sessions set total_volume = ?, sets_completed = ?'
               ' where id = ?', (volume, done_sets, sid))

# Progression state: every item has just banked a successful session.
db.execute('update workout_items set success_streak = 1, fail_streak = 0'
           ' where workout_id in (1,2,3)')
db.execute("update settings set active_routine_id = 1, tutorial_seen = 1")
db.commit()

s = db.execute('select count(*), sum(sets_completed), round(sum(total_volume))'
               ' from sessions').fetchone()
print(f'sessions={s[0]} sets={s[1]} volume={s[2]:.0f} kg')
print(db.execute('select name, datetime(started_at, "unixepoch"),'
                 ' round(total_volume) from sessions order by id desc limit 4'
                 ).fetchall())
