# Colour themes

Pick a preset theme, build your own, or import one someone shared.

## What it does

- Ships several **preset** colour themes, including **light** and
  **high-contrast** options.
- Lets you build a **custom** theme by editing each colour role.
- **Imports and exports** a theme (the palette as JSON), so a theme can be shared.

## How to use it

- **Pick a theme:** Profile → Settings → **Theme** → tap a preset.
- **Build your own:** on the theme screen choose **custom**, then edit each colour
  role.
- **Share:** export the current theme to a file / string, or import one you were
  given.

## Behaviour & edge cases

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
