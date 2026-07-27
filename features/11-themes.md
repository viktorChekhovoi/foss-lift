# Colour themes

Pick a preset theme, build your own, or bring in one someone shared.

## What it does

- Ships eight **preset** themes as four dark/light pairs: two everyday looks,
  **Solarized**, and a **high-contrast** option — each available in both
  brightnesses.
- Lets you build a **custom** theme by editing each colour role, with a **live
  preview** of the palette you are editing.
- **Shares your own** theme as a QR code or a link, and reads both back.

## How to use it

- **Pick a theme:** Profile → **Appearance** → tap a preset.
- **Build your own:** on the theme screen choose **Build your own**, then edit
  each colour role. The preview at the top follows every change. Tapping a role
  opens the picker, which says the same colour two ways — **RGB** with a hex
  field, or **HSL** — switchable with the toggle beside the hex.
- **Share:** with your custom theme selected, **Show QR** for someone to scan or
  **Send link** for the system share sheet (which is also where "copy" lives).
- **Receive:** **Scan QR** to use the camera, or **Paste code** for a code or a
  link.

## The lineup

|  | Dark | Light |
|---|---|---|
| Everyday | Ignition (dark default) | Daylight (light default) |
| Everyday | Graphite | Paper |
| Solarized | Solarized dark | Solarized light |
| Accessible | High contrast dark | High contrast light |

Every look exists in both brightnesses. Choosing legibility, or choosing
Solarized, never also means accepting a brightness you did not want.

## Behaviour & edge cases

- **An untouched install follows the phone.** With nothing stored the app paints
  Ignition on a phone set to dark and Daylight on one set to light, and flips
  with the system until a theme is picked. Picking one stores it, and a stored
  choice outranks the system from then on.
- **Only your own theme is shareable.** The presets ship with every copy of the
  app, so the share row is hidden unless the custom theme is the one selected.
- **The picker groups presets by brightness**, dark then light, with each
  group's high-contrast option last and badged `AAA`. Long-pressing the badge
  explains it; so does *tapping* it, but only on the row already selected — on
  any other row a tap has to go on picking the theme.
- **Both accessible presets clear WCAG AAA** (7:1) for body text and AA (4.5:1)
  for secondary text, the accent, the completed marker and the record marker —
  over both the ground and a card — with borders above the 3:1 non-text floor.
  Every other preset clears 4.5:1 for body text.
- **Solarized ships as published**, with two documented departures: body text
  takes the palette's emphasized tier rather than its body tier (Solarized's own
  body tones sit near 4.1:1), and the two intermediate surfaces are blends,
  since the palette defines two background tones and the app paints four.
- **The label on a filled button is measured, not assumed.** Whichever of a
  near-black tint or white reads better on the accent wins, so a custom or
  imported accent of any lightness still gets a legible label.
- **A custom theme is never badged accessible**, however it got there — built
  from a high-contrast preset, or arrived as a shared code from someone else's
  phone. The badge means the palette was designed and checked against WCAG,
  which is a fact about the two shipped presets; the custom slot can be
  recoloured freely afterwards and nothing re-checks it. The claim is dropped
  when an import is accepted *and* the row refuses to draw the badge whatever
  is stored, so a palette that predates this rule cannot show one either.
- **The preview warns when a palette is illegible**, comparing its own text
  against its ground and cards at the same 4.5:1 the presets are held to.
- **The picker speaks RGB and HSL, because they are for different jobs.** RGB
  and the hex field *transcribe* a colour that already exists — off a brand
  guide, out of the Solarized spec. HSL *chooses* one, and the app needs it
  twice over: the roles are families rather than twelve loose colours
  (`surface`/`surface2`/`surface3` are one hue at three lightnesses), and
  contrast is a function of lightness, so **L** is the slider that answers the
  illegibility warning without discarding the colour that raised it. Every
  colour the shipped presets use can be reached by hand — that is asserted, not
  assumed.
- **Hue and saturation are remembered, not recomputed.** A grey has no hue to
  recover — `HSLColor` reports 0 for anything achromatic — so deriving them from
  the colour would snap the hue slider to red the moment saturation reached
  zero. Switching notation never changes the value, in either direction.
- **The hex field takes `#RGB`, `#RRGGBB` or bare `RRGGBB`.** Anything that does
  not read yet simply does not move the colour, so backspacing through a hex is
  not destructive and a typo cannot silently repaint a role.
- **Each slider track is painted with the colours it traverses**, so it previews
  its own effect rather than asking you to imagine it.
- **A shared theme is always previewed, never applied on arrival.** A scan, a
  tapped link and a pasted code all land on the same confirmation screen. A code
  that will not decode offers nothing to apply.
- **An arriving theme becomes *your* custom theme.** It never claims a preset
  slot, so the shipped presets are always there to switch back to.
- **The choice is stored as a preset slug or a full custom palette.** Settings
  holds `themePresetId` (a preset slug, `custom`, or none) and `customTheme` (the
  user's palette as JSON).
- **A stored slug naming a preset that no longer exists** falls back to the
  default, as any unknown slug does.

## Sharing formats

A theme code is `FLT1.` followed by base64url — the whole palette in 65–84
characters.

- `FLT1` is a **format** version, read first and dispatched on, so a future
  `FLT2` is declined rather than misread.
- Within `FLT1`, bytes between the name and the trailing checksum are ignored,
  so a later writer can add a field without breaking older readers.
- **The role order is a wire format.** Reordering it silently changes the
  meaning of every code already shared.
- A CRC-16 catches the damage codes actually suffer — a truncated paste, a
  mistyped character. It is not a security measure.
- Reading distinguishes two failures, because the user can act on the
  difference: not a theme code at all (which includes any tag that is not
  `FLT1`), or damaged in transit.

Links are `fosslift://theme/<code>` — a custom scheme rather than an https App
Link, so sharing needs no domain, no hosting and no network and cannot stop
working when nobody is paying for a server. The trade-off is that chat apps do
not linkify it. An https filter can be added alongside later without
invalidating any code already shared.

QR codes hold the full link, so one image serves both a system camera (which
routes the scheme to the app) and the in-app scanner (which decodes the string
itself). QR decoding is pure Dart via `zxing2`, not Google's ML Kit, keeping the
app free of proprietary binaries.

## Where it lives

- Palette model + presets: `lib/theme/app_theme.dart` (`AppColors`).
- Code format: `lib/theme/theme_code.dart`.
- Preview: `lib/widgets/theme_preview.dart`; QR: `lib/widgets/theme_qr.dart`.
- Screens: `lib/screens/theme_settings_screen.dart` (picker + share/receive),
  `theme_import_screen.dart` (confirmation), `theme_scan_screen.dart` (camera).
- Link handling: `lib/services/deep_links.dart`; frame decoding:
  `lib/services/qr_decoder.dart`.
- Stored in `Settings` (`themePresetId`, `customTheme`) in
  `lib/data/database.dart`.

## Related issues

- [#19 Colour themes](https://github.com/viktorChekhovoi/foss-lift/issues/19) — presets, custom editing, preview
- [#27 Portable theme code](https://github.com/viktorChekhovoi/foss-lift/issues/27) — the `FLT1.` format
- [#28 QR share and scan](https://github.com/viktorChekhovoi/foss-lift/issues/28)
- [#29 Shared theme links](https://github.com/viktorChekhovoi/foss-lift/issues/29)
