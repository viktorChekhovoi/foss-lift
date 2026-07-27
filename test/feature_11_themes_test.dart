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
import 'package:foss_lift/widgets/theme_preview.dart';

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

    // The organising idea of the lineup: every look exists in both
    // brightnesses, so choosing one never forces the other on you.
    const pairs = {
      'ignition': 'daylight',
      'graphite': 'paper',
      'solarized_dark': 'solarized_light',
      'high_contrast': 'high_contrast_light',
    };

    test('eight presets, as four dark/light pairs', () {
      expect(kThemePresets, hasLength(8),
          reason: 'four pairs and nothing else');
      for (final pair in pairs.entries) {
        final dark = kThemePresets.singleWhere((p) => p.id == pair.key,
            orElse: () => throw StateError('no preset ${pair.key}'));
        final light = kThemePresets.singleWhere((p) => p.id == pair.value,
            orElse: () => throw StateError('no preset ${pair.value}'));
        expect(dark.brightness, Brightness.dark, reason: pair.key);
        expect(light.brightness, Brightness.light, reason: pair.value);
        expect(dark.accessible, light.accessible,
            reason: '${pair.key}/${pair.value}: a pair agrees on whether it '
                'is an accessibility option');
      }
    });

    test('the accessible option exists in both brightnesses', () {
      expect(of(Brightness.dark, accessible: true), hasLength(1),
          reason: 'one accessible dark theme ships');
      expect(of(Brightness.light, accessible: true), hasLength(1),
          reason: 'one accessible light theme ships — wanting legibility must '
              'not mean accepting a dark screen');
      expect(of(Brightness.dark, accessible: false), hasLength(3));
      expect(of(Brightness.light, accessible: false), hasLength(3));
    });

    test('Solarized ships as the published palette, in both brightnesses', () {
      // Solarized is a named, published palette; someone choosing it wants
      // those exact hues, so the accent/good/gold triple is shared by the two
      // and is Schoonover's blue, green and yellow.
      final dark =
          kThemePresets.singleWhere((p) => p.id == 'solarized_dark');
      final light =
          kThemePresets.singleWhere((p) => p.id == 'solarized_light');
      expect(dark.accent, const Color(0xFF268BD2), reason: 'Solarized blue');
      expect(dark.good, const Color(0xFF859900), reason: 'Solarized green');
      expect(dark.gold, const Color(0xFFB58900), reason: 'Solarized yellow');
      for (final role in [
        (dark.accent, light.accent),
        (dark.good, light.good),
        (dark.gold, light.gold),
      ]) {
        expect(role.$1, role.$2,
            reason: 'both Solarized themes share the same accent hues');
      }
      // The grounds are the palette's own base3/base03, not invented paper.
      expect(dark.ground, const Color(0xFF002B36), reason: 'base03');
      expect(light.ground, const Color(0xFFFDF6E3), reason: 'base3');
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
      // The accessible themes sit last in their group, off the bottom of a
      // small test viewport.
      await tester.ensureVisible(find.text(light.name));
      await tester.pump();
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

  group('the custom theme preview', () {
    /// A palette whose twelve roles are twelve colours found nowhere else, so
    /// "this role is painted somewhere in the preview" is a real assertion.
    AppPalette sentinels() => const AppPalette(
          id: kCustomThemeId,
          name: 'Sentinels',
          ground: Color(0xFF010203),
          surface: Color(0xFF040506),
          surface2: Color(0xFF070809),
          surface3: Color(0xFF0A0B0C),
          line: Color(0xFF0D0E0F),
          text: Color(0xFFF1F2F3),
          muted: Color(0xFFE4E5E6),
          faint: Color(0xFFD7D8D9),
          accent: Color(0xFF102030),
          accentPress: Color(0xFF405060),
          good: Color(0xFF708090),
          gold: Color(0xFFA0B0C0),
        );

    /// Every colour actually painted in the rendered subtree: fills, borders
    /// and text/icon colours alike.
    Set<Color> painted(WidgetTester tester) {
      final found = <Color>{};
      void addDecoration(Decoration? d) {
        if (d is! BoxDecoration) return;
        if (d.color != null) found.add(d.color!);
        final border = d.border;
        if (border is Border) {
          for (final side in [
            border.top,
            border.bottom,
            border.left,
            border.right,
          ]) {
            if (side.style != BorderStyle.none) found.add(side.color);
          }
        }
      }

      for (final w in tester.allWidgets) {
        switch (w) {
          case DecoratedBox(:final decoration):
            addDecoration(decoration);
          case ColoredBox(:final color):
            found.add(color);
          case Text(:final style):
            if (style?.color != null) found.add(style!.color!);
          case Icon(:final color):
            if (color != null) found.add(color);
          case _:
            break;
        }
      }
      return found;
    }

    testWidgets('paints every one of the twelve roles', (tester) async {
      // A role you cannot see while editing is a role you cannot edit with any
      // confidence — surface2, surface3 and accentPress especially, which mean
      // nothing as an isolated swatch.
      final p = sentinels();
      await tester
          .pumpWidget(appUnder(container, ThemePreview(palette: p)));
      await tester.pump();

      final shown = painted(tester);
      final roles = <String, Color>{
        'ground': p.ground,
        'surface': p.surface,
        'surface2': p.surface2,
        'surface3': p.surface3,
        'line': p.line,
        'text': p.text,
        'muted': p.muted,
        'faint': p.faint,
        'accent': p.accent,
        'accentPress': p.accentPress,
        'good': p.good,
        'gold': p.gold,
      };
      for (final role in roles.entries) {
        expect(shown, contains(role.value),
            reason: '${role.key} is never painted in the preview');
      }

      await stop(tester);
    });

    testWidgets('editing a role repaints the preview immediately',
        (tester) async {
      // "Live" is the whole point: the preview must follow the draft, not the
      // saved theme.
      var p = sentinels();
      late StateSetter setState;
      await tester.pumpWidget(appUnder(
        container,
        StatefulBuilder(builder: (_, s) {
          setState = s;
          return ThemePreview(palette: p);
        }),
      ));
      await tester.pump();
      expect(painted(tester), contains(const Color(0xFF102030)));

      const changed = Color(0xFFAB12CD);
      setState(() => p = p.copyWith(accent: changed));
      await tester.pump();

      final shown = painted(tester);
      expect(shown, contains(changed),
          reason: 'the new accent shows without saving');
      expect(shown, isNot(contains(const Color(0xFF102030))),
          reason: 'and the old one is gone');

      await stop(tester);
    });

    testWidgets('warns when a custom palette makes its own text unreadable',
        (tester) async {
      // Nothing stops someone picking grey text on a grey ground. Say so
      // rather than letting them save a theme they cannot read.
      final bad = sentinels().copyWith(
        ground: const Color(0xFF808080),
        surface: const Color(0xFF828282),
        text: const Color(0xFF888888),
      );
      expect(contrastRatio(bad.text, bad.ground), lessThan(4.5),
          reason: 'the fixture really is unreadable');

      await tester
          .pumpWidget(appUnder(container, ThemePreview(palette: bad)));
      await tester.pump();
      expect(find.textContaining('hard to read'), findsOneWidget);
      await stop(tester);
    });

    testWidgets('stays quiet when the palette is legible', (tester) async {
      await tester.pumpWidget(
          appUnder(container, ThemePreview(palette: kDefaultPalette)));
      await tester.pump();
      expect(find.textContaining('hard to read'), findsNothing);
      await stop(tester);
    });

    testWidgets('every shipped preset previews without a warning',
        (tester) async {
      for (final preset in kThemePresets) {
        await tester
            .pumpWidget(appUnder(container, ThemePreview(palette: preset)));
        await tester.pump();
        expect(find.textContaining('hard to read'), findsNothing,
            reason: '${preset.id} should not trip its own legibility warning');
      }
      await stop(tester);
    });
  });
}
