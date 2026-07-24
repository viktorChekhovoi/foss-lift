import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/theme/app_theme.dart';

/// The theme choice persists through the single settings row and resolves to a
/// palette exactly as the app root reads it.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a fresh install has no theme chosen and shows the default', () async {
    final setting = await db.watchThemeSetting().first;
    expect(setting.presetId, isNull);
    expect(setting.customJson, isNull);
    expect(resolvePalette(setting.presetId, setting.customJson),
        kDefaultPalette);
  });

  test('choosing a preset persists and resolves to it', () async {
    await db.setThemePreset('graphite');
    final setting = await db.watchThemeSetting().first;
    expect(setting.presetId, 'graphite');

    final palette = resolvePalette(setting.presetId, setting.customJson);
    expect(palette.id, 'graphite');
    expect(palette, kThemePresets.firstWhere((p) => p.id == 'graphite'));
  });

  test('saving a custom theme stores it and selects custom in one write',
      () async {
    final mine = kDefaultPalette
        .copyWith(id: 'custom', name: 'Mine', accent: const Color(0xFF123456));
    await db.setCustomTheme(mine.toJson());

    final setting = await db.watchThemeSetting().first;
    expect(setting.presetId, 'custom');
    expect(setting.customJson, isNotNull);

    final palette = resolvePalette(setting.presetId, setting.customJson);
    expect(palette.id, kCustomThemeId);
    expect(palette.accent, const Color(0xFF123456));
  });

  test('switching to a preset keeps the custom theme for later', () async {
    final mine = kDefaultPalette
        .copyWith(id: 'custom', accent: const Color(0xFF654321));
    await db.setCustomTheme(mine.toJson());

    // Move to a preset...
    await db.setThemePreset('forest');
    var setting = await db.watchThemeSetting().first;
    expect(setting.presetId, 'forest');
    expect(setting.customJson, isNotNull,
        reason: 'the custom palette is not discarded when a preset is chosen');

    // ...and back to custom brings the saved palette straight back.
    await db.setThemePreset('custom');
    setting = await db.watchThemeSetting().first;
    final palette = resolvePalette(setting.presetId, setting.customJson);
    expect(palette.accent, const Color(0xFF654321));
  });

  test('the theme choice does not disturb the weight unit', () async {
    await db.setWeightUnit('lb');
    await db.setThemePreset('violet');
    expect(await db.watchWeightUnit().first, 'lb');
    expect((await db.watchThemeSetting().first).presetId, 'violet');
  });
}
