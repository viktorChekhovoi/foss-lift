# Colour themes

Pick a preset theme, build your own, or import one someone shared.

## What it does

- Ships six **preset** colour themes: two dark, two light, and a
  **high-contrast** option in each brightness.
- Lets you build a **custom** theme by editing each colour role.
- **Imports and exports** a theme (the palette as JSON), so a theme can be shared.

## How to use it

- **Pick a theme:** Profile → Settings → **Theme** → tap a preset.
- **Build your own:** on the theme screen choose **custom**, then edit each colour
  role.
- **Share:** export the current theme to a file / string, or import one you were
  given.

## Behaviour & edge cases

- **The picker groups presets by brightness**, dark then light, with each
  group's high-contrast option last and badged `AAA`.
- **An accessible theme never forces a brightness.** Both high-contrast presets
  clear WCAG AAA (7:1) for body text and AA (4.5:1) for secondary text, the
  accent, the completed marker and the record marker — over both the ground and
  a card — with borders above the 3:1 non-text floor.
- **The label on a filled button is measured, not assumed.** Whichever of a
  near-black tint or white reads better on the accent wins, so a custom or
  imported accent of any lightness still gets a legible label.
- **A custom theme is never badged accessible**, even when built from a
  high-contrast preset — the colours can be edited freely afterwards.
- **The choice is stored as a preset slug or a full custom palette.** Settings
  holds `themePresetId` (a preset slug, `custom`, or none) and `customTheme` (the
  user's palette as JSON).
- **Import/export carries the palette itself**, so a shared theme doesn't depend on
  the recipient having the same preset installed.

## Where it lives

- Palette model + presets: `lib/theme/app_theme.dart` (`AppColors`).
- Screen: `lib/screens/theme_settings_screen.dart` (picker + custom editor +
  import/export).
- Stored in `Settings` (`themePresetId`, `customTheme`) in
  `lib/data/database.dart`.

## Related issues

- [#19 Colour themes](https://github.com/viktorChekhovoi/foss-lift/issues/19) — shipped, in review
