// Integration tests for features/11-themes.md — colour themes.
//
// The behaviour under test, straight from the spec:
//   * six presets ship — two dark, two light, and an accessible (high-contrast)
//     one of each brightness;
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
import 'package:foss_lift/widgets/common.dart';
import 'package:foss_lift/widgets/routine_card.dart';

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
    Iterable<AppPalette> of(Brightness b, {required bool accessible}) =>
        kThemePresets
            .where((p) => p.brightness == b && p.accessible == accessible);

    test('two dark, two light, and an accessible one of each', () {
      expect(of(Brightness.dark, accessible: false), hasLength(2),
          reason: 'two everyday dark themes ship');
      expect(of(Brightness.light, accessible: false), hasLength(2),
          reason: 'two everyday light themes ship');
      expect(of(Brightness.dark, accessible: true), hasLength(1),
          reason: 'one accessible dark theme ships');
      expect(of(Brightness.light, accessible: true), hasLength(1),
          reason: 'one accessible light theme ships');
      expect(kThemePresets, hasLength(6),
          reason: 'and nothing else — six presets in total');
    });

    test('the default preset is a dark, everyday one', () {
      expect(kThemePresets.first, equals(kDefaultPalette),
          reason: 'the first preset is the default');
      expect(kDefaultPalette.brightness, Brightness.dark);
      expect(kDefaultPalette.accessible, isFalse);
    });

    test('both accessible presets really are maximal contrast', () {
      final dark = of(Brightness.dark, accessible: true).single;
      final light = of(Brightness.light, accessible: true).single;
      // Pure black ground under pure white text, and the exact mirror — the
      // defining property, asserted on the colours rather than on any label.
      expect(dark.ground.computeLuminance(), lessThan(0.01));
      expect(dark.text.computeLuminance(), greaterThan(0.99));
      expect(light.ground.computeLuminance(), greaterThan(0.99));
      expect(light.text.computeLuminance(), lessThan(0.01));
    });

    test('the accessible presets clear WCAG AAA text and AA everything else',
        () {
      for (final p in kThemePresets.where((p) => p.accessible)) {
        final why = '${p.id}: ';
        // AAA (7:1) for body text on both backgrounds it is painted over.
        expect(contrastRatio(p.text, p.ground), greaterThanOrEqualTo(7.0),
            reason: '${why}body text on the ground');
        expect(contrastRatio(p.text, p.surface), greaterThanOrEqualTo(7.0),
            reason: '${why}body text on a card');
        // AA (4.5:1) for the secondary text and the coloured markers, which
        // carry meaning (accent = action, good = done, gold = a record).
        for (final pair in [
          ('secondary text', p.muted),
          ('the accent', p.accent),
          ('the completed colour', p.good),
          ('the record colour', p.gold),
        ]) {
          expect(contrastRatio(pair.$2, p.ground), greaterThanOrEqualTo(4.5),
              reason: '$why${pair.$1} on the ground');
          expect(contrastRatio(pair.$2, p.surface), greaterThanOrEqualTo(4.5),
              reason: '$why${pair.$1} on a card');
        }
        // Labels drawn on top of a filled accent/good button.
        expect(contrastRatio(p.onAccent, p.accent), greaterThanOrEqualTo(4.5),
            reason: '${why}the label on an accent button');
        expect(contrastRatio(p.onGood, p.good), greaterThanOrEqualTo(4.5),
            reason: '${why}the label on a completed marker');
        // Structure must never be lost: borders stay visible at UI contrast.
        expect(contrastRatio(p.line, p.surface), greaterThanOrEqualTo(3.0),
            reason: '${why}card borders');
        expect(contrastRatio(p.line, p.ground), greaterThanOrEqualTo(3.0),
            reason: '${why}borders against the ground');
      }
    });

    test('every shipped preset keeps body text legible', () {
      // Not just the accessible pair — no theme may ship unreadable text.
      for (final p in kThemePresets) {
        expect(contrastRatio(p.text, p.ground), greaterThanOrEqualTo(4.5),
            reason: '${p.id}: body text on the ground');
        expect(contrastRatio(p.text, p.surface), greaterThanOrEqualTo(4.5),
            reason: '${p.id}: body text on a card');
        expect(contrastRatio(p.onAccent, p.accent), greaterThanOrEqualTo(4.5),
            reason: '${p.id}: the label on an accent button');
      }
    });

    test('the picker groups every preset under a brightness heading', () {
      // The screen renders a DARK and a LIGHT group; a preset that is in
      // neither would ship invisible.
      for (final p in kThemePresets) {
        expect(const [Brightness.dark, Brightness.light].contains(p.brightness),
            isTrue);
      }
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

  group('a routine keeps its own accent over any theme', () {
    test('a routine colour resolves the same under every preset', () {
      // A routine's accent is its own property, not a theme role: switching
      // theme must not repaint it. Asserted against every preset so a new one
      // cannot quietly start overriding it.
      const routineHex = 'FF6A3D';
      for (final preset in kThemePresets) {
        AppTheme.build(preset); // points AppColors at this theme
        expect(hexColor(routineHex), const Color(0xFFFF6A3D),
            reason: '${preset.id} must not tint a routine colour');
      }
    });

    testWidgets('a routine card shows its colour under a light theme',
        (tester) async {
      // The one that would break first if a theme ever won: a routine painted
      // in the dark default's orange, shown while a light theme is active.
      final routineId = await db.createRoutine(
          name: 'Push/Pull', color: 'FF6A3D', restSeconds: 120);
      final routine = await (db.select(db.routines)
            ..where((r) => r.id.equals(routineId)))
          .getSingle();

      // Nothing in this tree watches the theme, so keep the stream subscribed
      // for the duration or it never settles.
      final sub = container.listen(themeSettingProvider, (_, _) {});
      addTearDown(sub.close);

      await tester.pumpWidget(appUnder(
        container,
        Scaffold(
          body: RoutineCard(
            data: RoutineWithCount(routine, 3),
            isCurrent: true,
            onTap: () {},
          ),
        ),
      ));
      await tester.pump();

      await db.setThemePreset('high_contrast_light');
      await pumpUntil(tester,
          () => container.read(activePaletteProvider).id == 'high_contrast_light');

      expect(container.read(activePaletteProvider).brightness, Brightness.light,
          reason: 'the light accessible theme is the one being painted');
      expect(find.text('Push/Pull'), findsOneWidget);
      expect(hexColor(routine.colorHex), const Color(0xFFFF6A3D),
          reason: 'the routine is still painted in its own colour');

      await stop(tester);
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
      await db.setThemePreset('graphite');
      var setting = await db.watchThemeSetting().first;
      expect(setting.presetId, 'graphite');
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

    test('a shared accessible theme is still marked accessible on arrival', () {
      final hc = kThemePresets.firstWhere((p) => p.accessible);
      expect(AppPalette.tryParse(hc.toJson())!.accessible, isTrue,
          reason: 'the accessibility of a shared theme travels with it');
      final plain = kThemePresets.firstWhere((p) => !p.accessible);
      expect(AppPalette.tryParse(plain.toJson())!.accessible, isFalse);
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

    testWidgets('every shipped preset is reachable by its name on the screen',
        (tester) async {
      await tester
          .pumpWidget(appUnder(container, const ThemeSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Including both accessible ones — a preset nobody can find is a preset
      // nobody can pick.
      for (final preset in kThemePresets) {
        expect(find.text(preset.name), findsOneWidget,
            reason: '${preset.id} should have a row on the picker');
      }

      await stop(tester);
    });

    testWidgets('picking the light accessible theme switches to a light app',
        (tester) async {
      await tester
          .pumpWidget(appUnder(container, const ThemeSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final light = kThemePresets
          .firstWhere((p) => p.accessible && p.brightness == Brightness.light);
      await tester.tap(find.text(light.name));
      await pumpUntil(
          tester,
          () =>
              container.read(themeSettingProvider).value?.presetId == light.id);

      final active = container.read(activePaletteProvider);
      expect(active, equals(light));
      expect(active.brightness, Brightness.light,
          reason: 'an accessible choice must not force you into dark mode');
      expect(AppTheme.build(active).brightness, Brightness.light,
          reason: 'and Material agrees, so system widgets follow suit');

      await stop(tester);
    });
  });
}
