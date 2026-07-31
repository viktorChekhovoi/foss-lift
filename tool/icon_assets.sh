#!/usr/bin/env bash
# Re-export the launcher-icon and splash PNGs from design/icon/foss-lift.svg.
#
# The outputs are build inputs for flutter_launcher_icons and
# flutter_native_splash — they are not bundled into the app. Run this after
# editing the SVG, then run the two generators (see RUNNING.md).
#
# Needs inkscape and ImageMagick 7.

set -euo pipefail
cd "$(dirname "$0")/.."

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The logo without its rounded-square plate. The plate is a flat colour that the
# generators paint themselves — as the adaptive icon's background layer and as
# the splash window colour — so it has to come off here or it would be drawn
# twice, the second time without the rounding.
sed 's|<rect width="512" height="512" rx="115" fill="#0E1117"/>||' \
  design/icon/foss-lift.svg > "$work/logo.svg"

inkscape "$work/logo.svg" -w 2048 -h 2048 -o "$work/logo.png" 2>/dev/null
magick "$work/logo.png" -trim +repage "$work/logo-trim.png"

mkdir -p assets/icon assets/splash

# The whole plate, for launchers older than adaptive icons.
inkscape design/icon/foss-lift.svg -w 1024 -h 1024 -o assets/icon/icon.png 2>/dev/null

# The adaptive foreground. The canvas is the full 108dp; the logo is sized to
# the 72dp viewport a launcher actually shows, at the proportion it has on the
# plate. That leaves its corners just inside the 66dp circle, so the strictest
# mask still clips nothing.
magick "$work/logo-trim.png" -resize x480 \
  -background none -gravity center -extent 1024x1024 assets/icon/icon_foreground.png

# The pre-Android-12 splash: the logo alone, centred on the window colour.
magick "$work/logo-trim.png" -resize x768 \
  -background none -gravity center -extent 1024x1024 assets/splash/logo.png

# The Android 12 splash icon. The system masks it to a 160dp circle inside a
# 240dp canvas, which at this scale is a radius of 384 — so the logo is sized
# for its half-diagonal to be exactly that, and nothing is lost to the mask.
magick "$work/logo-trim.png" -resize 514x570! \
  -background none -gravity center -extent 1152x1152 assets/splash/logo_android12.png

echo "Wrote assets/icon/ and assets/splash/. Now:"
echo "  dart run flutter_launcher_icons"
echo "  dart run flutter_native_splash:create"
