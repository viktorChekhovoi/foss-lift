/// How a theme is named in storage.
///
/// Deliberately free of Flutter and of `AppPalette`: the data layer has to
/// write and read these ids (`Settings.themePresetId` points at a row of
/// `CustomThemes` with one), and the theme layer has to resolve them, so the
/// format itself belongs to neither. `app_theme.dart` re-exports this, so
/// nothing that already imports the palette needs a second import.
library;

/// The prefix on a theme the user owns, and the id a palette carries before it
/// has a row of its own — a decoded share code, an unsaved draft.
const String kCustomThemeId = 'custom';

/// The stored id of the user's theme in row [rowId]: `custom:12`.
String customThemeId(int rowId) => '$kCustomThemeId:$rowId';

/// The row id inside a `custom:<n>` theme id, or null if [id] does not name one
/// — a preset slug, a bare `custom` with no row behind it, null, or junk.
int? customThemeRowId(String? id) {
  if (id == null || !id.startsWith('$kCustomThemeId:')) return null;
  return int.tryParse(id.substring(kCustomThemeId.length + 1));
}
