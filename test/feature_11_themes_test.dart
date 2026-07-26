// Integration tests for features/11-themes.md — colour themes.
//
// The behaviour under test, straight from the spec:
//   * several presets ship, including a light one and a high-contrast one;
//   * a custom theme edits each colour role;
//   * import/export carries the palette itself (as JSON), so a shared theme
//     does not depend on the recipient having the preset installed;
//   * the choice is stored as a preset slug OR a full custom palette, and
//     resolving a stored choice maps it back to a palette, falling back to the
//     default when nothing (or nothing valid) is chosen.
//
// These are exercised through the real public surface: the [AppPalette] value
// model + [resolvePalette], the [AppDatabase] theme settings, the providers,
// and the picker widget — never private internals or generated code.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/theme_settings_screen.dart';
import 'package:foss_lift/theme/app_theme.dart';

import 'support/harness.dart';
import 'support/settle.dart';

/// A distinctive palette the user might have built themselves — deliberately
/// unlike any shipped preset, so "the custom theme is what's active" is a real
/// assertion and not an accidental match.
AppPalette _mineCustom() => kDefaultPalette.copyWith(
      id: kCustomThemeId,
      name: 'Mine',
      ground: const Color(0xFF101820),
      accent: const Color(0xFF00BCD4),
      good: const Color(0xFF8BC34A),
      gold: const Color(0xFFFFEB3B),
    );

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = memoryDb();
    container = containerFor(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('shipped presets', () {
    test('several ship, including a light and a high-contrast one', () {
      expect(kThemePresets.length, greaterThanOrEqualTo(3),
          reason: 'the spec says "several" presets ship');

      // At least one dark and one light, grouped as the picker groups them.
      expect(kThemePresets.any((p) => p.brightness == Brightness.dark), isTrue);
      expect(kThemePresets.any((p) => p.brightness == Brightness.light), isTrue,
          reason: 'a light option must ship');

      final highContrast =
          kThemePresets.where((p) => p.id == 'high_contrast').toList();
      expect(highContrast, hasLength(1),
          reason: 'a high-contrast option must ship');
    });

    test('the high-contrast preset really is maximal contrast', () {
      final hc = kThemePresets.firstWhere((p) => p.id == 'high_contrast');
      // Pure black on pure white text — the defining property of the theme,
      // asserted on the palette values rather than on any label.
      expect(hc.ground.computeLuminance(), lessThan(0.01));
      expect(hc.text.computeLuminance(), greaterThan(0.99));
    });

    test('each shipped preset resolves to its own distinct palette', () {
      // Every preset round-trips through the resolver by its slug...
      for (final preset in kThemePresets) {
        expect(resolvePalette(preset.id, null), equals(preset),
            reason: 'slug ${preset.id} should resolve to itself');
      }
      // ...and no two presets are the same palette.
      expect(kThemePresets.toSet(), hasLength(kThemePresets.length),
          reason: 'presets must be pairwise distinct');
    });
  });

  group('resolving a stored choice into a palette', () {
    test('no choice at all falls back to the default palette', () {
      expect(resolvePalette(null, null), equals(kDefaultPalette));
    });

    test('an unknown preset slug falls back to the default', () {
      expect(resolvePalette('no_such_theme', null), equals(kDefaultPalette));
    });

    test('the custom slug with no stored palette falls back to the default', () {
      expect(resolvePalette(kCustomThemeId, null), equals(kDefaultPalette));
    });

    test('the custom slug with malformed JSON falls back to the default', () {
      expect(resolvePalette(kCustomThemeId, 'not json at all'),
          equals(kDefaultPalette));
      expect(resolvePalette(kCustomThemeId, '{"nope":true}'),
          equals(kDefaultPalette));
    });

    test('the custom slug with a stored palette resolves to that palette', () {
      final mine = _mineCustom();
      final resolved = resolvePalette(kCustomThemeId, mine.toJson());
      expect(resolved, equals(mine));
      expect(resolved.id, kCustomThemeId);
    });
  });

  group('persisting the choice in Settings', () {
    test('a fresh install has no choice and paints the default', () async {
      // The spec: themePresetId/customTheme both unset on a new install.
      final setting = await db.watchThemeSetting().first;
      expect(setting.presetId, isNull);
      expect(setting.customJson, isNull);

      final palette = await readWhen(
        container,
        activePaletteProvider,
        (p) => p == kDefaultPalette,
        reason: 'the first frame paints the default preset',
      );
      expect(palette, equals(kDefaultPalette));
    });

    test('setThemePreset then watchThemeSetting round-trips the slug', () async {
      final graphite = kThemePresets.firstWhere((p) => p.id == 'graphite');
      await db.setThemePreset(graphite.id);

      final setting = await db.watchThemeSetting().first;
      expect(setting.presetId, 'graphite');
      expect(setting.customJson, isNull,
          reason: 'a preset choice stores only a slug, not a palette');

      final palette = await readWhen(
        container,
        activePaletteProvider,
        (p) => p == graphite,
        reason: 'activePalette should follow the stored preset',
      );
      expect(palette, equals(graphite));
    });

    test('setThemePreset(null) returns to the default preset', () async {
      await db.setThemePreset('graphite');
      await db.setThemePreset(null);

      final setting = await db.watchThemeSetting().first;
      expect(setting.presetId, isNull);
      expect(resolvePalette(setting.presetId, setting.customJson),
          equals(kDefaultPalette));
    });

    test('setCustomTheme stores the palette JSON under the custom slug',
        () async {
      final mine = _mineCustom();
      await db.setCustomTheme(mine.toJson());

      final setting = await db.watchThemeSetting().first;
      expect(setting.presetId, kCustomThemeId,
          reason: 'saving a custom theme also makes it active');
      expect(setting.customJson, isNotNull);
      expect(AppPalette.tryParse(setting.customJson!), equals(mine));

      final palette = await readWhen(
        container,
        activePaletteProvider,
        (p) => p == mine,
        reason: 'activePalette/resolvePalette should reflect the custom theme',
      );
      expect(palette, equals(mine));
    });

    test('switching preset -> custom -> preset is lossless for the custom theme',
        () async {
      final mine = _mineCustom();
      await db.setCustomTheme(mine.toJson());
      // Switch away to a preset...
      await db.setThemePreset('forest');
      var setting = await db.watchThemeSetting().first;
      expect(setting.presetId, 'forest');
      expect(setting.customJson, isNotNull,
          reason: 'the stored custom palette survives a switch away');

      // ...and back to custom, without re-editing.
      await db.setThemePreset(kCustomThemeId);
      setting = await db.watchThemeSetting().first;
      expect(AppPalette.tryParse(setting.customJson!), equals(mine));
    });
  });

  group('import / export carries the palette', () {
    test('a custom palette export -> import round-trips to an equal palette',
        () {
      final mine = _mineCustom();
      final exported = mine.toJson();
      final imported = AppPalette.tryParse(exported);
      expect(imported, equals(mine),
          reason: 'the full palette travels in the JSON');
    });

    test('a shared preset imports without the preset being "installed"', () {
      // Export a preset's palette, then parse it back as if received. It must
      // carry every colour, so the recipient gets the same look even though we
      // resolve it as a custom palette rather than by slug.
      for (final preset in kThemePresets) {
        final imported = AppPalette.tryParse(preset.toJson());
        expect(imported, equals(preset),
            reason: '${preset.id} must survive an export/import round-trip');
      }
    });

    test('a truncated import keeps its own colours and fills gaps sanely', () {
      // A hand-edited/partial payload should still yield a usable theme: the
      // colours it does carry are honoured, the rest fall back to a default.
      final imported = AppPalette.tryParse(
          '{"id":"custom","name":"Half","colors":{"accent":"#123456"}}');
      expect(imported, isNotNull);
      expect(imported!.accent, const Color(0xFF123456),
          reason: 'a provided colour is honoured');
      expect(imported.ground, kDefaultPalette.ground,
          reason: 'a missing colour falls back to the default role');
    });

    test('nonsense text is rejected rather than crashing the import', () {
      expect(AppPalette.tryParse('total nonsense'), isNull);
      expect(AppPalette.tryParse('[1,2,3]'), isNull);
      expect(AppPalette.tryParse('{"no":"colors"}'), isNull);
    });
  });

  group('the picker widget', () {
    testWidgets('tapping a preset stores it and drives the active palette',
        (tester) async {
      await tester.pumpWidget(
          appUnder(container, const ThemeSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Pick a preset by its shown name — a real user affordance, not internals.
      await tester.tap(find.text('Graphite'));
      await pumpUntil(tester,
          () => container.read(themeSettingProvider).value?.presetId == 'graphite');

      expect(container.read(themeSettingProvider).value?.presetId, 'graphite',
          reason: 'tapping the row selects the preset');
      expect(container.read(activePaletteProvider),
          equals(kThemePresets.firstWhere((p) => p.id == 'graphite')),
          reason: 'the active palette follows the picker');

      await stop(tester);
    });
  });
}
