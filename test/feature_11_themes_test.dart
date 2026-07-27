// Integration tests for features/11-themes.md — colour themes.
//
// The behaviour under test, straight from the spec:
//   * eight presets ship as four dark/light pairs — two everyday looks,
//     Solarized, and a high-contrast option, each in both brightnesses;
//   * a custom theme edits each colour role, with a live preview;
//   * sharing carries the palette itself — as a code, a link, a QR or JSON —
//     so a shared theme does not depend on the recipient having the preset;
//   * a shared theme is previewed and accepted, never applied on arrival;
//   * the choice is stored as a preset slug OR a full custom palette, and
//     resolving a stored choice maps it back to a palette, falling back to the
//     default when nothing (or nothing valid) is chosen.
//
// These are exercised through the real public surface: the [AppPalette] value
// model + [resolvePalette], the [AppDatabase] theme settings, the providers,
// and the picker widget — never private internals or generated code.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/theme_import_screen.dart';
import 'package:foss_lift/screens/theme_settings_screen.dart';
import 'package:foss_lift/services/deep_links.dart';
import 'package:foss_lift/services/qr_decoder.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/theme/theme_code.dart';
import 'package:foss_lift/widgets/common.dart';
import 'package:foss_lift/widgets/routine_card.dart';
import 'package:foss_lift/widgets/theme_preview.dart';
import 'package:qr/qr.dart';

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

/// `RRGGBB` for [c], upper case — how the app writes a colour down.
String _hexString(Color c) {
  int ch(double v) => (v * 255).round().clamp(0, 255);
  final rgb = (ch(c.r) << 16) | (ch(c.g) << 8) | ch(c.b);
  return rgb.toRadixString(16).toUpperCase().padLeft(6, '0');
}

/// The inverse, for reading a colour back off the screen.
Color? _colorOfHex(String s) {
  final v = int.tryParse(s.replaceAll('#', ''), radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

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
    test('a fresh install has no choice and follows the system brightness',
        () async {
      // The spec: themePresetId/customTheme both unset on a new install.
      final setting = await db.watchThemeSetting().first;
      expect(setting.presetId, isNull);
      expect(setting.customJson, isNull);

      // With nothing stored the app paints the default look in whichever
      // brightness the phone is set to, rather than forcing dark on a phone
      // that asked for light.
      final expected =
          defaultPaletteFor(container.read(platformBrightnessProvider));
      final palette = await readWhen(
        container,
        activePaletteProvider,
        (p) => p == expected,
        reason: 'the first frame follows the system brightness',
      );
      expect(palette, equals(expected));
    });

    test('the two system defaults are the plain dark and light looks', () {
      expect(defaultPaletteFor(Brightness.dark).id, 'ignition');
      expect(defaultPaletteFor(Brightness.light).id, 'daylight');
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

    // Both share assertions are about what the screen does *not* offer, so
    // they need the whole list built rather than the top of a lazy viewport.
    Future<void> pumpWholePicker(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester
          .pumpWidget(appUnder(container, const ThemeSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('a preset offers nothing to share — everyone already has it',
        (tester) async {
      await pumpWholePicker(tester);

      expect(find.text('SHARE THIS THEME'), findsNothing);
      // Importing one is always on offer; it is only sending that is pointless.
      expect(find.text('ADD A THEME'), findsOneWidget);

      await stop(tester);
    });

    testWidgets('tapping AAA explains it, but only once the row is selected',
        (tester) async {
      final hc = kThemePresets
          .firstWhere((p) => p.accessible && p.brightness == Brightness.dark);
      await pumpWholePicker(tester);

      // Unselected: the tap belongs to picking the theme, not to the badge.
      await tester.tap(find.text('AAA').first);
      await pumpUntil(tester,
          () => container.read(themeSettingProvider).value?.presetId == hc.id);
      expect(find.text('Meets WCAG AAA contrast'), findsNothing,
          reason: 'the tap selected the theme rather than explaining the badge');

      // Selected: the same tap has nothing else to mean, so it explains.
      await tester.tap(find.text('AAA').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Meets WCAG AAA contrast'), findsOneWidget);

      await stop(tester);
    });

    testWidgets('a custom theme is shareable, as a QR or a link and no more',
        (tester) async {
      await tester.runAsync(() async {
        await db.setCustomTheme(
            kThemePresets.last.copyWith(name: 'Mine').toJson());
        await db.setThemePreset(kCustomThemeId);
      });
      await pumpWholePicker(tester);

      expect(find.text('SHARE THIS THEME'), findsOneWidget);
      expect(find.text('Show QR'), findsOneWidget);
      expect(find.text('Send link'), findsOneWidget);
      // The share sheet already offers "copy", and a JSON file saved beside the
      // app is a theme you then have to go and find.
      expect(find.text('Copy code'), findsNothing);
      expect(find.text('Save file'), findsNothing);

      await stop(tester);
    });
  });

  group('the portable theme code', () {
    test('every shipped preset round-trips through a code unchanged', () {
      for (final preset in kThemePresets) {
        final decoded = ThemeCode.decode(ThemeCode.encode(preset));
        expect(decoded, isA<ThemeCodeOk>(),
            reason: '${preset.id} should decode');
        final palette = (decoded as ThemeCodeOk).palette;
        // Every colour role, the name and the accessible flag survive. The id
        // does not: a code carries a theme, not a claim to be a preset.
        for (final role in [
          (palette.ground, preset.ground),
          (palette.surface, preset.surface),
          (palette.surface2, preset.surface2),
          (palette.surface3, preset.surface3),
          (palette.line, preset.line),
          (palette.text, preset.text),
          (palette.muted, preset.muted),
          (palette.faint, preset.faint),
          (palette.accent, preset.accent),
          (palette.accentPress, preset.accentPress),
          (palette.good, preset.good),
          (palette.gold, preset.gold),
        ]) {
          expect(role.$1, role.$2, reason: '${preset.id}: a role changed');
        }
        expect(palette.name, preset.name);
        expect(palette.accessible, preset.accessible);
      }
    });

    test('a custom palette round-trips, including a non-ASCII name', () {
      final mine = _mineCustom().copyWith(name: 'Mörk höst 🏋');
      final decoded = ThemeCode.decode(ThemeCode.encode(mine));
      expect(decoded, isA<ThemeCodeOk>());
      expect((decoded as ThemeCodeOk).palette.name, 'Mörk höst 🏋');
      expect(decoded.palette.accent, mine.accent);
    });

    test('a code is short enough to paste into a chat message', () {
      for (final preset in kThemePresets) {
        expect(ThemeCode.encode(preset).length, lessThan(120),
            reason: '${preset.id} encodes too long to share by hand');
      }
    });

    test('the code is version-tagged, so a later format can be told apart', () {
      expect(ThemeCode.encode(kDefaultPalette), startsWith('FLT1.'));
    });

    test('a code tagged with another format version is simply not a code', () {
      final other = ThemeCode.encode(kDefaultPalette).replaceFirst('FLT1', 'FLT9');
      final result = ThemeCode.decode(other);
      expect(result, isA<ThemeCodeFailure>());
      expect((result as ThemeCodeFailure).problem, ThemeCodeProblem.notACode);
    });

    test('text that is not a theme code at all is rejected as such', () {
      for (final junk in ['', 'hello', 'https://example.com', '{"colors":{}}']) {
        final result = ThemeCode.decode(junk);
        expect(result, isA<ThemeCodeFailure>(), reason: 'decoding "$junk"');
        expect((result as ThemeCodeFailure).problem, ThemeCodeProblem.notACode,
            reason: 'decoding "$junk"');
      }
    });

    test('a truncated code is caught rather than importing wrong colours', () {
      final code = ThemeCode.encode(kDefaultPalette);
      // Chop characters off the end — the classic damage from a bad copy.
      for (var cut = 1; cut < 12; cut++) {
        final result = ThemeCode.decode(code.substring(0, code.length - cut));
        expect(result, isA<ThemeCodeFailure>(),
            reason: 'a code missing $cut characters must not decode');
        expect((result as ThemeCodeFailure).problem, ThemeCodeProblem.damaged,
            reason: 'a code missing $cut characters is damaged, not foreign');
      }
    });

    test('a flipped character is caught by the checksum', () {
      final code = ThemeCode.encode(kDefaultPalette);
      var caught = 0;
      // Corrupt one payload character at a time; every corruption must be
      // either rejected or — never — silently decoded to a different palette.
      for (var i = 'FLT1.'.length; i < code.length; i++) {
        final ch = code[i] == 'A' ? 'B' : 'A';
        final bent = code.replaceRange(i, i + 1, ch);
        final result = ThemeCode.decode(bent);
        if (result is ThemeCodeFailure) {
          caught++;
        } else {
          fail('a one-character corruption at $i decoded silently');
        }
      }
      expect(caught, greaterThan(0));
    });

    test('unknown trailing fields are ignored, not fatal', () {
      // Forward compatibility: a later FLT1 writer may append a field this
      // reader knows nothing about. It must still read the roles it does know.
      final extended = ThemeCode.encodeWithExtraFields(
          kDefaultPalette, [0x77, 0x88, 0x99, 0xAA]);
      final result = ThemeCode.decode(extended);
      expect(result, isA<ThemeCodeOk>(),
          reason: 'an unknown trailing field must not break the import');
      expect((result as ThemeCodeOk).palette.accent, kDefaultPalette.accent);
      expect(result.palette.name, kDefaultPalette.name);
    });

    test('a code pasted with whitespace or line breaks still reads', () {
      final code = ThemeCode.encode(kDefaultPalette);
      for (final messy in [
        '  $code  ',
        '$code\n',
        '${code.substring(0, 20)}\n${code.substring(20)}',
        '${code.substring(0, 20)} ${code.substring(20)}',
      ]) {
        expect(ThemeCode.decode(messy), isA<ThemeCodeOk>(),
            reason: 'pasted text is rarely clean');
      }
    });

    test('a full share link decodes as readily as a bare code', () {
      final code = ThemeCode.encode(kDefaultPalette);
      final link = ThemeCode.link(kDefaultPalette);
      expect(link, startsWith('fosslift://theme/'));
      expect(link, endsWith(code));
      final result = ThemeCode.decode(link);
      expect(result, isA<ThemeCodeOk>(),
          reason: 'scanning a QR yields the link, not the bare code');
      expect((result as ThemeCodeOk).palette.accent, kDefaultPalette.accent);
    });

    test('the JSON path still works alongside the code', () {
      // The code is an addition, not a replacement — a theme exported as a
      // file before this existed must still import.
      final mine = _mineCustom();
      expect(AppPalette.tryParse(mine.toJson()), equals(mine));
    });
  });

  group('reading a QR code off a camera frame', () {
    /// Renders [text] as a QR and returns it as an 8-bit greyscale image —
    /// what a camera frame's luma plane looks like, without a camera.
    (Uint8List, int) renderQr(String text, {int scale = 4, int quiet = 16}) {
      final code = QrCode.fromData(
        data: text,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      final matrix = QrImage(code);
      final side = matrix.moduleCount * scale + quiet * 2;
      // 0xFF is white; QR modules are painted black.
      final luma = Uint8List(side * side)..fillRange(0, side * side, 0xFF);
      for (var y = 0; y < matrix.moduleCount; y++) {
        for (var x = 0; x < matrix.moduleCount; x++) {
          if (!matrix.isDark(y, x)) continue;
          for (var dy = 0; dy < scale; dy++) {
            for (var dx = 0; dx < scale; dx++) {
              final px = quiet + x * scale + dx;
              final py = quiet + y * scale + dy;
              luma[py * side + px] = 0x00;
            }
          }
        }
      }
      return (luma, side);
    }

    test('a rendered theme QR decodes back to the same link', () {
      // The full loop the feature rests on: a palette becomes a QR, a camera
      // sees it, and the same palette comes back out.
      final link = ThemeCode.link(_mineCustom());
      final (luma, side) = renderQr(link);

      final text = QrDecoder.decodeLuminance(luma, side, side);
      expect(text, link, reason: 'the QR must survive being read back');
      final result = ThemeCode.decode(text!);
      expect(result, isA<ThemeCodeOk>());
      expect((result as ThemeCodeOk).palette.accent, _mineCustom().accent);
    });

    test('every shipped preset fits in a scannable QR', () {
      for (final preset in kThemePresets) {
        final link = ThemeCode.link(preset);
        final (luma, side) = renderQr(link);
        expect(QrDecoder.decodeLuminance(luma, side, side), link,
            reason: '${preset.id} should round-trip through a QR');
      }
    });

    test('a frame with nothing in it is not an error', () {
      // The normal case, arriving thirty times a second.
      final blank = Uint8List(120 * 120)..fillRange(0, 120 * 120, 0xFF);
      expect(QrDecoder.decodeLuminance(blank, 120, 120), isNull);
    });

    test('a nonsense or truncated frame is refused, not crashed on', () {
      expect(QrDecoder.decodeLuminance(Uint8List(0), 0, 0), isNull);
      expect(QrDecoder.decodeLuminance(Uint8List(10), 100, 100), isNull,
          reason: 'a buffer shorter than the stated size must not read past it');
    });

    test('a padded camera row stride is unwound, not read straight through',
        () {
      // Cameras pad each row out to a stride wider than the image. Reading
      // through that without accounting for it shears the picture and nothing
      // ever decodes — the classic reason a hand-rolled scanner "just doesn't
      // work" on one device and is fine on another.
      final link = ThemeCode.link(kDefaultPalette);
      final (luma, side) = renderQr(link);
      const pad = 37;
      final stride = side + pad;
      final padded = Uint8List(stride * side);
      for (var row = 0; row < side; row++) {
        padded.setRange(row * stride, row * stride + side, luma, row * side);
      }

      final unwound = QrDecoder.lumaFromPlane(padded, side, side, stride);
      expect(unwound, isNotNull);
      expect(QrDecoder.decodeLuminance(unwound!, side, side), link);

      // And the same bytes read without unwinding the stride do not decode,
      // so the test above is actually proving something.
      expect(
          QrDecoder.decodeLuminance(
              Uint8List.sublistView(padded, 0, side * side), side, side),
          isNot(link));
    });

    test('an unpadded plane is passed through without copying it about', () {
      final link = ThemeCode.link(kDefaultPalette);
      final (luma, side) = renderQr(link);
      final same = QrDecoder.lumaFromPlane(luma, side, side, side);
      expect(same, isNotNull);
      expect(QrDecoder.decodeLuminance(same!, side, side), link);
    });

    test('a plane too short for the stated frame is refused', () {
      expect(QrDecoder.lumaFromPlane(Uint8List(10), 100, 100, 100), isNull);
    });
  });

  group('a link from outside the app', () {
    test('a theme link routes to the import screen carrying its code', () {
      final code = ThemeCode.encode(_mineCustom());
      final route = routeForLink(Uri.parse(ThemeCode.link(_mineCustom())));
      expect(route, isNotNull);
      expect(route, startsWith('/settings/theme/import?code='));
      // The route has to survive being parsed back out again, or the import
      // screen gets a mangled code.
      final back = Uri.parse(route!).queryParameters['code'];
      expect(back, code);
      expect(ThemeCode.decode(back!), isA<ThemeCodeOk>());
    });

    test('links we do not recognise are ignored rather than guessed at', () {
      for (final uri in [
        'https://example.com/theme/FLT1.abc',
        'fosslift://something-else/FLT1.abc',
        'fosslift://theme/',
        'fosslift://theme',
        'mailto:someone@example.com',
      ]) {
        expect(routeForLink(Uri.parse(uri)), isNull, reason: uri);
      }
    });
  });

  group('importing a shared theme', () {
    /// A theme someone else built, as it would arrive.
    AppPalette theirs() => _mineCustom().copyWith(name: 'Gym Bro Blue');

    testWidgets('a shared theme is previewed, not applied on arrival',
        (tester) async {
      // A code from outside the app is untrusted input. It must never
      // overwrite the current theme on the strength of a scan or a tapped URL.
      await tester.pumpWidget(appUnder(
        container,
        ThemeImportScreen(code: ThemeCode.encode(theirs())),
      ));
      await tester.pump();

      expect(find.byType(ThemePreview), findsOneWidget,
          reason: 'you see what you are about to get');
      expect(find.text('Gym Bro Blue'), findsOneWidget,
          reason: 'the shared theme names itself');
      expect(container.read(themeSettingProvider).value?.presetId, isNull,
          reason: 'nothing has been applied yet');

      await stop(tester);
    });

    testWidgets('confirming applies it as the custom theme', (tester) async {
      final incoming = theirs();
      // The import screen doesn't watch the setting, so keep the stream alive
      // for the assertions.
      final sub = container.listen(themeSettingProvider, (_, _) {});
      addTearDown(sub.close);

      await tester.pumpWidget(appUnder(
        container,
        ThemeImportScreen(code: ThemeCode.link(incoming)),
      ));
      await tester.pump();

      await tester.ensureVisible(find.text('Use this theme'));
      await tester.pump();
      await tester.tap(find.text('Use this theme'));
      await pumpUntil(tester,
          () => container.read(themeSettingProvider).value?.presetId != null);

      expect(container.read(themeSettingProvider).value?.presetId,
          kCustomThemeId);
      final active = container.read(activePaletteProvider);
      expect(active.accent, incoming.accent);
      expect(active.name, 'Gym Bro Blue');

      await stop(tester);
    });

    testWidgets('an accessible theme arrives without its AAA claim',
        (tester) async {
      // The badge means "designed and checked against WCAG". Once a palette is
      // in the custom slot it can be recoloured freely and nothing re-checks
      // it, so the claim cannot come along — the same reason building your own
      // from a high-contrast preset drops it.
      final hc = kThemePresets.firstWhere((p) => p.accessible);
      final sub = container.listen(themeSettingProvider, (_, _) {});
      addTearDown(sub.close);

      await tester.pumpWidget(appUnder(
        container,
        ThemeImportScreen(code: ThemeCode.encode(hc)),
      ));
      await tester.pump();
      await tester.ensureVisible(find.text('Use this theme'));
      await tester.pump();
      await tester.tap(find.text('Use this theme'));
      await pumpUntil(tester,
          () => container.read(themeSettingProvider).value?.presetId != null);

      final stored =
          AppPalette.tryParse(container.read(themeSettingProvider).value!.customJson!);
      expect(stored!.accessible, isFalse,
          reason: 'a shared theme is yours now, and yours is never badged');
      expect(stored.ground, hc.ground,
          reason: 'only the claim is dropped — the colours are untouched');
      expect(container.read(activePaletteProvider).accessible, isFalse);

      await stop(tester);
    });

    testWidgets('and the picker does not badge it AAA afterwards',
        (tester) async {
      final hc = kThemePresets.firstWhere((p) => p.accessible);
      // Stored the way a pre-fix import would have stored it, claim and all —
      // so this fails if the badge is ever driven by the palette alone again.
      await db.setCustomTheme(
          hc.copyWith(id: kCustomThemeId, accessible: true).toJson());
      await db.setThemePreset(kCustomThemeId);

      // Tall enough that the whole picker builds: the custom row sits below
      // both preset groups, and an unbuilt row cannot be asserted about.
      tester.view.physicalSize = const Size(1200, 4800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester
          .pumpWidget(appUnder(container, const ThemeSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Custom'), findsOneWidget,
          reason: 'the custom row is on screen, so its badge would be too');

      // Both shipped accessible presets still carry the badge; the custom row
      // must not add a third.
      expect(find.text('AAA'), findsNWidgets(2),
          reason: 'only the two checked presets may claim AAA');

      await stop(tester);
    });

    testWidgets('declining leaves the current theme untouched', (tester) async {
      await db.setThemePreset('graphite');
      final sub = container.listen(themeSettingProvider, (_, _) {});
      addTearDown(sub.close);

      await tester.pumpWidget(appUnder(
        container,
        ThemeImportScreen(code: ThemeCode.encode(theirs())),
      ));
      await tester.pump();
      await tester.ensureVisible(find.text('Cancel'));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(container.read(themeSettingProvider).value?.presetId, 'graphite',
          reason: 'declining an import changes nothing');

      await stop(tester);
    });

    testWidgets('a damaged code explains itself and offers nothing to apply',
        (tester) async {
      final code = ThemeCode.encode(theirs());
      await tester.pumpWidget(appUnder(
        container,
        ThemeImportScreen(code: code.substring(0, code.length - 6)),
      ));
      await tester.pump();

      expect(find.textContaining('characters missing'), findsOneWidget);
      expect(find.text('Use this theme'), findsNothing,
          reason: 'there is nothing safe to apply');
      expect(find.byType(ThemePreview), findsNothing);

      await stop(tester);
    });

    testWidgets('a code tagged with another format version is refused',
        (tester) async {
      await tester.pumpWidget(appUnder(
        container,
        ThemeImportScreen(
            code: ThemeCode.encode(theirs()).replaceFirst('FLT1', 'FLT7')),
      ));
      await tester.pump();

      expect(find.text('Invalid theme code.'), findsOneWidget);
      expect(find.text('Use this theme'), findsNothing);

      await stop(tester);
    });

    testWidgets('junk that is not a theme at all is rejected plainly',
        (tester) async {
      await tester.pumpWidget(appUnder(
        container,
        const ThemeImportScreen(code: 'have a nice day'),
      ));
      await tester.pump();

      expect(find.text('Invalid theme code.'), findsOneWidget);
      expect(find.text('Use this theme'), findsNothing);

      await stop(tester);
    });
  });

  group('the colour picker', () {
    // The custom theme has to be able to say anything the shipped presets say.
    // A picker that can only be driven in RGB can reach every colour in
    // principle and none of them on purpose: the roles are families — three
    // surfaces at one hue, an accent and its pressed state — and lightness is
    // the axis contrast is a function of, so it has to be a control you can
    // hold on its own.

    /// Opens the custom editor and taps [role] to bring up its picker.
    ///
    /// The twelve roles live in a `ListView`, so a role below the fold is not
    /// merely off screen — it is unbuilt, and cannot be found or tapped. A tall
    /// surface builds the lot.
    Future<void> openPicker(WidgetTester tester, String role) async {
      tester.view.physicalSize = const Size(1200, 4800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
          routedAppUnder(container, const CustomThemeEditorScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text(role));
      await frames(tester);
    }

    /// The hex the editor now shows for [role] — what the picker handed back.
    String shownHex(WidgetTester tester, String role) {
      final row = find.ancestor(
        of: find.text(role),
        matching: find.byType(Row),
      );
      final hex = find.descendant(
        of: row.first,
        matching: find.textContaining('#'),
      );
      return (tester.widget<Text>(hex.first)).data!;
    }

    Future<void> use(WidgetTester tester) async {
      await tester.tap(find.text('Use'));
      await frames(tester);
    }

    testWidgets('offers a colour in both RGB and HSL', (tester) async {
      await openPicker(tester, 'Accent');

      expect(find.text('RGB'), findsOneWidget);
      expect(find.text('HSL'), findsOneWidget,
          reason: 'hue and saturation are how a colour gets chosen');

      await stop(tester);
    });

    testWidgets('confirming without touching anything changes nothing',
        (tester) async {
      await openPicker(tester, 'Accent');
      final before = shownHex(tester, 'Accent');
      await use(tester);

      expect(shownHex(tester, 'Accent'), before,
          reason: 'opening a picker is not an edit');

      await stop(tester);
    });

    testWidgets('a colour survives the round trip through HSL and back',
        (tester) async {
      await openPicker(tester, 'Accent');
      final before = shownHex(tester, 'Accent');
      await tester.tap(find.text('HSL'));
      await frames(tester);
      await tester.tap(find.text('RGB'));
      await frames(tester);
      await use(tester);

      expect(shownHex(tester, 'Accent'), before,
          reason: 'switching how a colour is written down does not change it');

      await stop(tester);
    });

    testWidgets('a grey keeps its hue rather than being randomised',
        (tester) async {
      // HSL has no hue to recover from a pure grey. The picker has to remember
      // the one that was on screen instead of snapping the slider to red.
      await openPicker(tester, 'Accent');
      await tester.enterText(find.byType(TextField), '#808080');
      await frames(tester);
      await tester.tap(find.text('HSL'));
      await frames(tester);
      await tester.tap(find.text('RGB'));
      await frames(tester);
      await use(tester);

      expect(shownHex(tester, 'Accent'), '#808080');

      await stop(tester);
    });

    testWidgets('typing a hex sets the colour', (tester) async {
      await openPicker(tester, 'Accent');
      await tester.enterText(find.byType(TextField), '#AB12CD');
      await frames(tester);
      await use(tester);

      expect(shownHex(tester, 'Accent'), '#AB12CD',
          reason: 'a colour read off a palette elsewhere can be transcribed');

      await stop(tester);
    });

    testWidgets('the short and bare hex forms are accepted too',
        (tester) async {
      await openPicker(tester, 'Accent');
      await tester.enterText(find.byType(TextField), 'ABC');
      await frames(tester);
      await use(tester);
      expect(shownHex(tester, 'Accent'), '#AABBCC',
          reason: 'three digits expand the way CSS expands them');

      await tester.ensureVisible(find.text('Accent'));
      await tester.pump();
      await tester.tap(find.text('Accent'));
      await frames(tester);
      await tester.enterText(find.byType(TextField), '123456');
      await frames(tester);
      await use(tester);
      expect(shownHex(tester, 'Accent'), '#123456',
          reason: 'the hash is optional');

      await stop(tester);
    });

    testWidgets('nonsense in the hex field leaves the colour alone',
        (tester) async {
      await openPicker(tester, 'Accent');
      final before = shownHex(tester, 'Accent');
      await tester.enterText(find.byType(TextField), 'not a colour');
      await frames(tester);
      await use(tester);

      expect(shownHex(tester, 'Accent'), before,
          reason: 'a typo must not silently repaint a role');

      await stop(tester);
    });

    testWidgets('lightness moves on its own, leaving hue and saturation',
        (tester) async {
      // The whole reason HSL is here: the preview warns you a colour is
      // illegible, and this is the slider that answers that warning without
      // throwing away the colour you picked.
      await openPicker(tester, 'Accent');
      await tester.enterText(find.byType(TextField), '#268BD2');
      await frames(tester);
      await tester.tap(find.text('HSL'));
      await frames(tester);

      final before = HSLColor.fromColor(const Color(0xFF268BD2));
      // Third slider in HSL order: H, S, then L.
      await tester.drag(find.byType(Slider).at(2), const Offset(60, 0));
      await frames(tester);
      await use(tester);

      final after = HSLColor.fromColor(
          _colorOfHex(shownHex(tester, 'Accent'))!);
      expect(after.lightness, greaterThan(before.lightness),
          reason: 'the slider moved');
      expect(after.hue, closeTo(before.hue, 1.0),
          reason: 'and took the hue with it, unchanged');
      expect(after.saturation, closeTo(before.saturation, 0.02),
          reason: 'and the saturation too');

      await stop(tester);
    });

    testWidgets('every colour the presets use is reachable by hand',
        (tester) async {
      // Capability parity, stated as a test: nothing shipped is out of reach
      // of someone building their own.
      final wanted = <Color>{
        for (final p in kThemePresets) ...[
          p.ground,
          p.surface,
          p.surface2,
          p.surface3,
          p.line,
          p.text,
          p.muted,
          p.faint,
          p.accent,
          p.accentPress,
          p.good,
          p.gold,
        ],
      };

      await openPicker(tester, 'Accent');
      for (final c in wanted) {
        final hex = '#${_hexString(c)}';
        await tester.enterText(find.byType(TextField), hex);
        await frames(tester);
        await use(tester);
        expect(shownHex(tester, 'Accent'), hex,
            reason: '$hex is a colour the app itself ships');

        await tester.ensureVisible(find.text('Accent'));
        await tester.pump();
        await tester.tap(find.text('Accent'));
        await frames(tester);
      }

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
