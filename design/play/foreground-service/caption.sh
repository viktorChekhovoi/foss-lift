#!/usr/bin/env bash
# Burns the narration into the raw screen recording. The windows below are read
# off the take rather than assumed from take.sh: screenrecord takes a moment to
# start, so everything lands a couple of seconds later than the driver script's
# own clock.
#
# Each caption goes in its own file and is passed with textfile=, because
# drawtext's own parser treats colons and commas as syntax and the narration is
# full of both.
set -e
cd "$(dirname "$0")"

RAW=demo_raw.mp4
OUT=foss-lift-foreground-service.mp4
FONT=/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf
FONTB=/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf
BAND=300          # the strip added under the phone screen, for the text to sit in

rm -rf cap && mkdir -p cap

write() { printf '%s\n' "$2" > "cap/$1.txt"; }
write 1 "Foss Lift is an offline workout tracker.
Starting a training session."
write 2 "A live session: the sets to do, the weight
for each, and a rest timer between them."
write 3 "Between sets the phone goes in a pocket,
and the app leaves the screen."
write 4 "The foreground service keeps that session
running, and shows it in the shade."
write 5 "Done logs the set from the notification
and starts the rest — with the app
still in the background."
write 6 "−15s, +15s and Skip adjust the running rest,
without opening the app."
write 7 "Reopening shows the same session, with
the set logged from the shade."
write 8 "Finishing the workout ends the service."
write 9 "No session, no notification, no service.
It runs only while a workout is on."
write 0 "Foss Lift — live workout foreground service"

WINDOWS=("0.0 7.0" "7.6 16.8" "17.2 20.0" "20.3 26.0" "26.4 34.0" "34.3 42.8" "43.2 48.8" "49.2 55.0" "55.3 62.5")

filter="pad=1080:$((2400 + BAND)):0:0:color=0x0E1116"
i=1
for w in "${WINDOWS[@]}"; do
  set -- $w
  filter="${filter},drawtext=fontfile=${FONT}:textfile=cap/${i}.txt:fontcolor=white:fontsize=38:line_spacing=14:x=(w-text_w)/2:y=2400+((${BAND}-text_h)/2):enable='between(t\,$1\,$2)'"
  i=$((i + 1))
done

# A standing label, so a frame pulled out of context still says what it is.
filter="${filter},drawtext=fontfile=${FONTB}:textfile=cap/0.txt:fontcolor=0x9AA3B0:fontsize=30:x=28:y=26:box=1:boxcolor=0x0E1116@0.6:boxborderw=12"

ffmpeg -v error -i "$RAW" -vf "$filter" -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -movflags +faststart "$OUT" -y
ffprobe -v error -show_entries format=duration,size -show_entries stream=width,height -of default=nw=1 "$OUT"
echo "wrote $OUT"
