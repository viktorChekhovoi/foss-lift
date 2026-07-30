# The foreground-service declaration

Play requires a declaration and a demonstration video for every
`FOREGROUND_SERVICE_*` type an app declares. Foss Lift declares `specialUse`,
for the live workout — see the manifest comment in
`android/app/src/main/AndroidManifest.xml` and `lib/services/workout_shade.dart`.

Three things have to agree with each other, and a reviewer will compare them:

| | Where |
|---|---|
| The subtype string | `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` in the manifest |
| The written declaration | `RELEASING.md`, under "Foreground service declaration" |
| The video | recorded here as `demo.mp4`, uploaded unlisted to YouTube for the form |

If you change what the service does, change all three.

## Re-recording the video

**The video is not in the repository** — it is a 1.5 MB binary no diff can
review, and it is gitignored. A fresh clone has none until you record one, which
is what the two scripts here are for and the reason *they* are checked in: the
take has to be re-shot whenever the shade's behaviour changes, and doing it by
hand means re-deciding the timings every time.

It is a screen recording of an emulator with captions burned in.

You need an emulator running (`~/Android/Sdk/emulator/emulator -list-avds`),
`adb` on the path, and `ffmpeg`. The scripts assume a **1080×2400** screen; the
tap coordinates are hard-coded and are wrong on any other size.

```bash
# 1. Install the build you are shipping.
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# 2. Put the app in a known state: seeded data, notifications already granted,
#    the first-run tour dismissed, and nothing else in the shade.
adb shell pm clear com.fosslift.foss_lift
adb shell pm grant com.fosslift.foss_lift android.permission.POST_NOTIFICATIONS
adb shell cmd statusbar expand-notifications && adb shell input tap 876 1445  # Clear all
adb shell cmd statusbar collapse
adb shell monkey -p com.fosslift.foss_lift -c android.intent.category.LAUNCHER 1
sleep 7 && adb shell input tap 540 1392                                       # "Not now"

# 3. Check you are on Today, with the app focused, before rolling.
adb exec-out screencap -p > /tmp/pre.png

# 4. Roll.
(adb shell screenrecord --bit-rate 8000000 --time-limit 75 /sdcard/demo_raw.mp4 &)
sleep 2 && ./take.sh
adb shell pkill -INT screenrecord && sleep 3
adb pull /sdcard/demo_raw.mp4 .

# 5. Caption it.
./caption.sh          # writes foss-lift-foreground-service.mp4
```

**Check the timings before captioning.** `screenrecord` takes a second or two to
start, so the caption windows in `caption.sh` are offset from the driver clock in
`take.sh` and are read off the finished take rather than calculated. Sample
frames and adjust if a caption sits over the wrong screen:

```bash
for t in 3 12 18 23 30 38 45 52 58; do
  ffmpeg -ss $t -i demo_raw.mp4 -frames:v 1 f_$t.png -y
done
```

Keep caption lines under about 46 characters. Longer ones run off both edges of
the frame, and centred text hides that until you look.
