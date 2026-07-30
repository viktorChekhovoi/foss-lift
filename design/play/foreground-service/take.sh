#!/usr/bin/env bash
# Drives the emulator through the foreground-service demo, on a fixed clock so
# the captions can be burned in against known offsets. Timings are cumulative
# seconds from the first frame; keep them in step with CAPTIONS in caption.sh.
set -e
A="adb shell"

# t=0  Today, at rest.
sleep 3
# t=3  open the Push day
$A input tap 540 593
sleep 3
# t=6  start the workout
$A input tap 540 2230
sleep 3
# t=9  the board, running
sleep 4
# t=13 phone away
$A input keyevent KEYCODE_HOME
sleep 3
# t=16 pull the shade down
$A cmd statusbar expand-notifications
sleep 8
# t=24 log the set from the notification
$A input tap 221 1044
sleep 3
# t=27 the rest, counting down in the shade
sleep 6
# t=33 nudge it
$A input tap 372 1044
sleep 6
# t=39 tap the notification body to come back
$A input tap 540 870
sleep 4
# t=43 the board, with that set logged
sleep 5
# t=48 finish
$A input tap 948 216
sleep 4
# t=52 the recap; the service is gone
$A cmd statusbar expand-notifications
sleep 3
# t=55 an empty shade
sleep 4
# t=59 done
$A cmd statusbar collapse
