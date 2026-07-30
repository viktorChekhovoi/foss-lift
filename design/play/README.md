# Play Store listing assets

Everything Google Play asks for as an image, plus the scripts that made it.
Nothing here ships in the app.

| File | Slot | Size |
|---|---|---|
| `feature-graphic.png` | Feature graphic | 1024×500 |
| `screenshots/phone/*.png` | Phone screenshots | 1080×1920 |
| `screenshots/tablet-7/*.png` | 7-inch tablet | 1440×2560 |
| `screenshots/tablet-10/*.png` | 10-inch tablet | 1620×2880 |

Eight screenshots per slot — Play's maximum — numbered in upload order. All are
9:16 PNGs well under Play's 8 MB per-image limit. Dropping one means dropping
its file from all three directories so the numbering stays parallel.

The accessibility shot is deliberately in **High contrast dark** with the text
nudge on Larger; every other shot is Ignition at the default size.

## Regenerating

`feature-graphic.html` is the source of the feature graphic:

```bash
google-chrome --headless --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=2 --window-size=1024,500 \
  --screenshot=/tmp/fg.png design/play/feature-graphic.html
magick /tmp/fg.png -resize 1024x500 -strip PNG24:design/play/feature-graphic.png
```

The screenshots come from a real build on an emulator, composed with a caption
afterwards:

1. **Seed the data.** `src/seed_history.py <db>` writes ten weeks of Push /
   Pull / Legs history into a copy of the app's sqlite file, ramping each lift
   up to the `suggested_weight` already in `workout_items` so the history and
   the app's next-load suggestion agree. It also sets `tutorial_seen` so the
   first-run tour stays out of the frame. Push the result to
   `/data/data/com.fosslift.foss_lift/app_flutter/foss_lift.sqlite` with the app
   stopped, then `chown` it back to the app uid and `restorecon` it.
2. **Capture.** Emulator at `wm size 1620x2880`, `wm density 630` — the same
   411 dp width as a phone, at 1.5× the pixels, so the tablet composites are
   downscales rather than upscales. SystemUI demo mode pins the clock to 9:30
   and hides the notification icons:

   ```bash
   adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0930
   adb shell am broadcast -a com.android.systemui.demo -e command network \
     -e wifi show -e level 4 -e fully true -e mobile hide
   adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
   ```

   `adb exec-out screencap -p`, then shave 9 px off each edge — the emulator
   draws a border into the framebuffer.
3. **Compose.** `src/make_shots.py [outdir]` renders one 1080×1920 CSS layout
   per shot through headless Chrome at three device scale factors. Captions and
   the source-to-caption pairing live in its `SHOTS` list. The raw device
   captures it reads sit beside it in `src/`.

The palette in both HTML files is the shipped **Ignition** theme from
`lib/theme/app_theme.dart`. If those colours change, change these too.
