// Integration tests for features/index.html#sec11 — colour themes.
//
// The behaviour under test, straight from the spec:
//   * eight presets ship as four dark/light pairs — two everyday looks,
//     Solarized, and a high-contrast option, each in both brightnesses;
//   * a custom theme edits each colour role, with a live preview;
//   * sharing carries the palette itself — as a code, a QR or JSON — so a
//     shared theme does not depend on the recipient having the preset. The share
//     sheet sends the bare code; the QR holds the `fosslift://` link, so a
//     system camera can act on it;
//   * a shared theme is previewed and accepted, never applied on arrival;
//   * the choice is stored as a preset slug OR a full custom palette, and
//     resolving a stored choice maps it back to a palette, falling back to the
//     default when nothing (or nothing valid) is chosen.
//
// These are exercised through the real public surface: the [AppPalette] value
// model + [resolvePalette], the [AppDatabase] theme settings, the providers,
// and the picker widget — never private internals or generated code.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/data/share_code.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/home_shell.dart';
import 'package:foss_lift/screens/theme_import_screen.dart';
import 'package:foss_lift/screens/appearance_screen.dart';
import 'package:foss_lift/services/deep_links.dart';
import 'package:foss_lift/services/qr_decoder.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/theme/theme_code.dart';
import 'package:foss_lift/widgets/common.dart';
import 'package:foss_lift/widgets/routine_card.dart';
import 'package:foss_lift/widgets/share_widgets.dart';
import 'package:foss_lift/widgets/theme_preview.dart';
import 'package:go_router/go_router.dart';
import 'package:qr/qr.dart';

import 'package:foss_lift/util/locales.dart';

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

/// Adds [palette] as one of the user's own themes and returns it as stored:
/// the same colours, wearing the `custom:<n>` id its row gave it.
Future<AppPalette> _addTheme(AppDatabase db, AppPalette palette) async {
  final id = await db.addCustomTheme(palette.toJson());
  return palette.copyWith(id: customThemeId(id));
}

/// A viewport tall enough that the whole picker builds in one go.
///
/// Eight preset rows, each carrying a pencil, plus your own and the share rows
/// run well past the default test window — and a row a ListView has not built
/// yet can be neither found nor tapped.
void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

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
      // those hues, so the accent is Schoonover's blue in both brightnesses and
      // the grounds are the palette's own base3/base03, not invented paper.
      final dark = kThemePresets.singleWhere((p) => p.id == 'solarized_dark');
      final light = kThemePresets.singleWhere((p) => p.id == 'solarized_light');

      expect(dark.accent, const Color(0xFF268BD2), reason: 'Solarized blue');
      expect(light.accent, dark.accent,
          reason: 'both Solarized themes share the accent');
      expect(dark.ground, const Color(0xFF002B36), reason: 'base03');
      expect(light.ground, const Color(0xFFFDF6E3), reason: 'base3');
    });

    test('but its markers are moved, because its own two cannot be told apart',
        () {
      // The documented third departure. Solarized's green (#859900) and yellow
      // (#B58900) sit at the same luminance — 1.00:1 against each other — which
      // is fine for syntax highlighting and useless for a binary
      // did-you-hit-it signal. So the short marker takes Solarized's *orange*
      // instead, and both are moved along their lightness ramp until they read
      // on this palette's ground.
      for (final id in ['solarized_dark', 'solarized_light']) {
        final p = kThemePresets.singleWhere((x) => x.id == id);
        expect(p.good, isNot(const Color(0xFF859900)), reason: '$id green');
        expect(p.gold, isNot(const Color(0xFFB58900)), reason: '$id yellow');
        // Still recognisably a green and an orange: green dominant in one, and
        // red-through-green descending in the other.
        expect(p.good.g, greaterThan(p.good.b), reason: '$id good is green');
        expect(p.gold.r, greaterThan(p.gold.g), reason: '$id gold is warm');
        expect(p.gold.g, greaterThan(p.gold.b), reason: '$id gold is warm');
      }
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

    test('done and short are unmistakable from each other, in every preset',
        () {
      // The most-read signal in the app: you glance down a column of set rows
      // and see how the session went. Contrast against the *background* is not
      // what makes that work — telling green from gold is, and two colours at
      // the same luminance have a contrast ratio of 1.00 against each other
      // while looking every bit as different as they are, which is not at all.
      for (final p in kThemePresets) {
        expect(
          colourDistance(p.good, p.gold),
          greaterThanOrEqualTo(kMarkerDistance),
          reason: '${p.id}: done and short are the same colour at a glance',
        );
      }
    });

    test('and both markers read against the ground and a card, in every preset',
        () {
      // Not just the accessible pair. A marker is a number you have to read, so
      // it answers to the same 4.5:1 body-text floor wherever it is painted.
      for (final p in kThemePresets) {
        for (final (what, colour) in [
          ('the completed colour', p.good),
          ('the short colour', p.gold),
        ]) {
          expect(contrastRatio(colour, p.ground), greaterThanOrEqualTo(4.5),
              reason: '${p.id}: $what on the ground');
          expect(contrastRatio(colour, p.surface), greaterThanOrEqualTo(4.5),
              reason: '${p.id}: $what on a card');
        }
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
        expect(resolvePalette(preset.id, const []), equals(preset),
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
      final sub = container.listen(themePresetIdProvider, (_, _) {});
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
      expect(resolvePalette(null, const []), equals(kDefaultPalette));
    });

    test('an unknown preset slug falls back to the default', () {
      expect(resolvePalette('no_such_theme', const []),
          equals(kDefaultPalette));
    });

    test('a custom id with no theme behind it falls back to the default', () {
      // The shape a deleted theme leaves behind if a selection somehow
      // outlives it: the app paints the default rather than nothing at all.
      expect(resolvePalette(customThemeId(7), const []),
          equals(kDefaultPalette));
      expect(resolvePalette(kCustomThemeId, const []),
          equals(kDefaultPalette));
    });

    test('a custom id resolves to the theme it names, and not another', () {
      final first = _mineCustom().copyWith(id: customThemeId(1), name: 'One');
      final second = _mineCustom().copyWith(
          id: customThemeId(2), name: 'Two', accent: const Color(0xFFAA0000));

      expect(resolvePalette(customThemeId(2), [first, second]),
          equals(second));
      expect(resolvePalette(customThemeId(1), [first, second]), equals(first));
    });

    test('a row that will not parse is not offered as a theme', () {
      expect(customThemeFromRow(3, 'not json at all'), isNull);
      expect(customThemeFromRow(3, '{"nope":true}'), isNull);
    });

    test('a stored row resolves to its palette under its own id', () {
      final stored = customThemeFromRow(4, _mineCustom().toJson());
      expect(stored, isNotNull);
      expect(stored!.id, customThemeId(4));
      expect(stored, equals(_mineCustom().copyWith(id: customThemeId(4))));
    });
  });

  group('persisting the choice in Settings', () {
    test('a fresh install has no choice and follows the system brightness',
        () async {
      // The spec: nothing chosen, and no themes of your own, on a new install.
      expect(await db.watchThemePresetId().first, isNull);
      expect(await db.watchCustomThemes().first, isEmpty);

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

    test('setThemePreset then watchThemePresetId round-trips the slug',
        () async {
      final graphite = kThemePresets.firstWhere((p) => p.id == 'graphite');
      await db.setThemePreset(graphite.id);

      expect(await db.watchThemePresetId().first, 'graphite');
      expect(await db.watchCustomThemes().first, isEmpty,
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

      expect(await db.watchThemePresetId().first, isNull);
      expect(resolvePalette(null, const []), equals(kDefaultPalette));
    });

    test('addCustomTheme stores the palette and makes it active', () async {
      final mine = await _addTheme(db, _mineCustom());

      expect(await db.watchThemePresetId().first, mine.id,
          reason: 'saving a theme also makes it active');
      expect(customThemeRowId(mine.id), isNotNull,
          reason: 'a theme of your own is named by its row');

      final palette = await readWhen(
        container,
        activePaletteProvider,
        (p) => p == mine,
        reason: 'activePalette should reflect the theme just added',
      );
      expect(palette, equals(mine));
    });

    test('switching preset -> your theme -> preset is lossless', () async {
      final mine = await _addTheme(db, _mineCustom());
      // Switch away to a preset...
      await db.setThemePreset('graphite');
      expect(await db.watchThemePresetId().first, 'graphite');
      expect(await db.watchCustomThemes().first, hasLength(1),
          reason: 'the stored palette survives a switch away');

      // ...and back, without re-editing.
      await db.setThemePreset(mine.id);
      final rows = await db.watchCustomThemes().first;
      expect(customThemeFromRow(rows.single.id, rows.single.palette),
          equals(mine));
    });
  });

  group('several themes of your own', () {
    test('they accumulate rather than overwrite each other', () async {
      final first = await _addTheme(db, _mineCustom().copyWith(name: 'One'));
      final second = await _addTheme(db, _mineCustom().copyWith(name: 'Two'));

      final rows = await db.watchCustomThemes().first;
      expect(rows, hasLength(2), reason: 'the second did not replace the first');
      expect(first.id, isNot(second.id));
      expect(
        [for (final r in rows) customThemeFromRow(r.id, r.palette)!.name],
        ['One', 'Two'],
        reason: 'listed oldest first, the order they were built in',
      );
    });

    test('the last one added is the active one', () async {
      await _addTheme(db, _mineCustom().copyWith(name: 'One'));
      final second = await _addTheme(db, _mineCustom().copyWith(name: 'Two'));
      expect(await db.watchThemePresetId().first, second.id);
    });

    test('renaming one leaves the others alone', () async {
      final first = await _addTheme(db, _mineCustom().copyWith(name: 'One'));
      final second = await _addTheme(db, _mineCustom().copyWith(name: 'Two'));

      await db.updateCustomTheme(customThemeRowId(first.id)!,
          _mineCustom().copyWith(name: 'Renamed').toJson());

      final rows = await db.watchCustomThemes().first;
      expect(
        [for (final r in rows) customThemeFromRow(r.id, r.palette)!.name],
        ['Renamed', 'Two'],
      );
      expect(await db.watchThemePresetId().first, first.id,
          reason: 'saving a theme selects it');
      expect(second.id, isNot(first.id));
    });

    test('editing one theme does not touch another', () async {
      final first = await _addTheme(db, _mineCustom().copyWith(name: 'One'));
      final second = await _addTheme(
          db, _mineCustom().copyWith(name: 'Two', accent: const Color(0xFF112233)));

      await db.updateCustomTheme(
        customThemeRowId(first.id)!,
        _mineCustom().copyWith(name: 'One', accent: const Color(0xFFAABBCC))
            .toJson(),
      );

      final rows = await db.watchCustomThemes().first;
      final palettes = [
        for (final r in rows) customThemeFromRow(r.id, r.palette)!,
      ];
      expect(palettes[0].accent, const Color(0xFFAABBCC));
      expect(palettes[1].accent, const Color(0xFF112233),
          reason: '${second.name} kept its own accent');
    });

    test('deleting one removes only it', () async {
      final first = await _addTheme(db, _mineCustom().copyWith(name: 'One'));
      await _addTheme(db, _mineCustom().copyWith(name: 'Two'));

      await db.deleteCustomTheme(customThemeRowId(first.id)!);

      final rows = await db.watchCustomThemes().first;
      expect(rows, hasLength(1));
      expect(customThemeFromRow(rows.single.id, rows.single.palette)!.name,
          'Two');
    });

    test('deleting the active theme falls back rather than unpainting the app',
        () async {
      final only = await _addTheme(db, _mineCustom());
      expect(await db.watchThemePresetId().first, only.id);

      await db.deleteCustomTheme(customThemeRowId(only.id)!);

      expect(await db.watchThemePresetId().first, isNull,
          reason: 'the selection goes with the row it named');
      final expected =
          defaultPaletteFor(container.read(platformBrightnessProvider));
      final palette = await readWhen(
        container,
        activePaletteProvider,
        (p) => p == expected,
        reason: 'the app falls back to the system default, not to nothing',
      );
      expect(palette, equals(expected));
    });

    test('deleting a theme you are not using leaves the selection alone',
        () async {
      final keep = await _addTheme(db, _mineCustom().copyWith(name: 'Keep'));
      final drop = await _addTheme(db, _mineCustom().copyWith(name: 'Drop'));
      await db.setThemePreset(keep.id);

      await db.deleteCustomTheme(customThemeRowId(drop.id)!);

      expect(await db.watchThemePresetId().first, keep.id);
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

  group("the app's own headings read in every palette", () {
    // `faint` is the one role no palette is asked to keep legible — it exists
    // for a column heading nobody reads twice. Headings and eyebrows are read,
    // so they take the two roles that are held to 4.5:1.
    test('the dimmest role is the one no palette keeps readable', () {
      // Not a requirement on the palettes — a statement of why the widgets may
      // not use it. If this ever stops being true the rule can be revisited.
      expect(
        kThemePresets.where((p) => contrastRatio(p.faint, p.ground) < 4.5),
        isNotEmpty,
        reason: 'faint is legible everywhere; the heading rule has no basis',
      );
    });

    test('the heading roles clear 4.5:1 against the ground, in every preset',
        () {
      for (final p in kThemePresets) {
        expect(contrastRatio(p.muted, p.ground), greaterThanOrEqualTo(4.5),
            reason: '${p.id}: a section heading on the ground');
        expect(contrastRatio(p.text, p.ground), greaterThanOrEqualTo(4.5),
            reason: '${p.id}: an eyebrow on the ground');
      }
    });

    testWidgets('a section heading is not painted in the dimmest role',
        (tester) async {
      await tester.pumpWidget(
          appUnder(container, const SectionLabel('your routines')));
      await tester.pump();
      final style = tester.widget<Text>(find.text('YOUR ROUTINES')).style!;
      expect(style.color, isNot(AppColors.faint),
          reason: 'a heading you are meant to read cannot take the dim role');
      expect(style.color, AppColors.muted);
      await stop(tester);
    });

    testWidgets('a screen eyebrow is painted in the body role', (tester) async {
      await tester.pumpWidget(appUnder(
          container, const ScreenHeader(eyebrow: 'today', title: 'Push')));
      await tester.pump();
      final style = tester.widget<Text>(find.text('TODAY')).style!;
      expect(style.color, isNot(AppColors.faint));
      expect(style.color, AppColors.text);
      await stop(tester);
    });
  });

  group('the picker widget', () {
    testWidgets('tapping a preset stores it and drives the active palette',
        (tester) async {
      await tester.pumpWidget(
          appUnder(container, const AppearanceScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Pick a preset by its shown name — a real user affordance, not internals.
      await tester.tap(find.text('Graphite'));
      await pumpUntil(tester,
          () => container.read(themePresetIdProvider).value == 'graphite');

      expect(container.read(themePresetIdProvider).value, 'graphite',
          reason: 'tapping the row selects the preset');
      expect(container.read(activePaletteProvider),
          equals(kThemePresets.firstWhere((p) => p.id == 'graphite')),
          reason: 'the active palette follows the picker');

      await stop(tester);
    });

    testWidgets('every shipped preset is reachable by its name on the screen',
        (tester) async {
      tallScreen(tester);
      await tester
          .pumpWidget(appUnder(container, const AppearanceScreen()));
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
      tallScreen(tester);
      await tester
          .pumpWidget(appUnder(container, const AppearanceScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final light = kThemePresets
          .firstWhere((p) => p.accessible && p.brightness == Brightness.light);
      // The accessible themes sit last in their group, well down the list.
      await tester.ensureVisible(find.text(light.name));
      await tester.pump();
      await tester.tap(find.text(light.name));
      await pumpUntil(
          tester,
          () =>
              container.read(themePresetIdProvider).value == light.id);

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
          .pumpWidget(appUnder(container, const AppearanceScreen()));
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
          () => container.read(themePresetIdProvider).value == hc.id);
      expect(find.text('Meets WCAG AAA contrast'), findsNothing,
          reason: 'the tap selected the theme rather than explaining the badge');

      // Selected: the same tap has nothing else to mean, so it explains.
      await tester.tap(find.text('AAA').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Meets WCAG AAA contrast'), findsOneWidget);

      await stop(tester);
    });

    testWidgets('a theme of your own is shareable, as a QR or a code and no more',
        (tester) async {
      await tester.runAsync(() async {
        await _addTheme(db, kThemePresets.last.copyWith(name: 'Mine'));
      });
      await pumpWholePicker(tester);

      expect(find.text('SHARE THIS THEME'), findsOneWidget);
      expect(find.text('Show QR'), findsOneWidget);
      expect(find.text('Send code'), findsOneWidget);
      // A link is not on offer at all: chat apps do not linkify fosslift://, so
      // it arrived as unclickable text that had to be pasted anyway.
      expect(find.text('Send link'), findsNothing);
      // The share sheet already offers "copy", and a JSON file saved beside the
      // app is a theme you then have to go and find.
      expect(find.text('Copy code'), findsNothing);
      expect(find.text('Save file'), findsNothing);

      await stop(tester);
    });

    testWidgets('and the QR it shows holds the link, not the bare code',
        (tester) async {
      await tester.runAsync(() async {
        await _addTheme(db, kThemePresets.last.copyWith(name: 'Mine'));
      });
      await pumpWholePicker(tester);

      await tester.tap(find.text('Show QR'));
      await frames(tester);

      final qr = tester.widget<ShareQr>(find.byType(ShareQr));
      expect(qr.data, startsWith(ShareCodec.linkPrefix(ThemeCode.host)),
          reason: 'a phone camera can only act on a symbol holding a link');
      expect(ThemeCode.decode(qr.data), isA<ThemeCodeOk>(),
          reason: 'and what it holds is the theme');

      await stop(tester);
    });
  });

  group('naming, keeping and deleting several themes', () {
    Future<void> pumpPicker(WidgetTester tester) async {
      tallScreen(tester);
      await tester
          .pumpWidget(routedAppUnder(container, const AppearanceScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    Future<void> pumpEditor(WidgetTester tester, {int? themeId}) async {
      tallScreen(tester);
      await tester.pumpWidget(routedAppUnder(
          container, CustomThemeEditorScreen(themeId: themeId)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('the picker lists every theme of your own, by name',
        (tester) async {
      await tester.runAsync(() async {
        await _addTheme(db, _mineCustom().copyWith(name: 'Dawn'));
        await _addTheme(db, _mineCustom().copyWith(name: 'Dusk'));
      });
      await pumpPicker(tester);

      expect(find.text('Dawn'), findsOneWidget);
      expect(find.text('Dusk'), findsOneWidget);
      expect(find.text('New theme'), findsOneWidget,
          reason: 'there is always a way to build another');

      await stop(tester);
    });

    testWidgets('with none built yet, the only offer is to build one',
        (tester) async {
      await pumpPicker(tester);

      expect(find.text('New theme'), findsOneWidget);
      // No empty-state paragraph explaining what a theme is. The heading and
      // the row say it.
      expect(find.textContaining('No themes'), findsNothing);

      await stop(tester);
    });

    testWidgets('saving a new theme adds one rather than replacing the last',
        (tester) async {
      await tester.runAsync(
          () => _addTheme(db, _mineCustom().copyWith(name: 'First')));
      final themes = container.listen(customThemesProvider, (_, _) {});
      addTearDown(themes.close);

      await pumpEditor(tester);
      await tester.enterText(find.byType(TextField), 'Second');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await pumpUntil(tester,
          () => container.read(customThemesProvider).value?.length == 2);

      final names = [
        for (final p in container.read(customThemesProvider).value!) p.name,
      ];
      expect(names, ['First', 'Second'],
          reason: 'the first survived; the new one joined it');

      await stop(tester);
    });

    testWidgets('the name field renames the theme it opened on',
        (tester) async {
      final mine = (await tester.runAsync(
          () => _addTheme(db, _mineCustom().copyWith(name: 'Old name'))))!;
      final themes = container.listen(customThemesProvider, (_, _) {});
      addTearDown(themes.close);

      await pumpEditor(tester, themeId: customThemeRowId(mine.id));
      expect(find.text('Old name'), findsOneWidget,
          reason: 'the field opens on the name it has');

      await tester.enterText(find.byType(TextField), 'New name');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await pumpUntil(
          tester,
          () =>
              container.read(customThemesProvider).value?.single.name ==
              'New name');

      expect(container.read(customThemesProvider).value, hasLength(1),
          reason: 'renaming edits the theme rather than adding another');

      await stop(tester);
    });

    testWidgets('a blank name does not take', (tester) async {
      final mine = (await tester.runAsync(
          () => _addTheme(db, _mineCustom().copyWith(name: 'Keep me'))))!;
      final themes = container.listen(customThemesProvider, (_, _) {});
      addTearDown(themes.close);

      await pumpEditor(tester, themeId: customThemeRowId(mine.id));
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await pumpUntil(
          tester, () => container.read(customThemesProvider).hasValue);
      await tester.pump(const Duration(milliseconds: 50));

      expect(container.read(customThemesProvider).value!.single.name, 'Keep me',
          reason: 'backspacing through a name cannot leave one nameless');

      await stop(tester);
    });

    testWidgets('deleting asks first, and cancelling keeps the theme',
        (tester) async {
      final mine = (await tester.runAsync(
          () => _addTheme(db, _mineCustom().copyWith(name: 'Precious'))))!;
      final themes = container.listen(customThemesProvider, (_, _) {});
      addTearDown(themes.close);

      await pumpEditor(tester, themeId: customThemeRowId(mine.id));
      await tester.tap(find.byIcon(Icons.delete_outline));
      await frames(tester);

      expect(find.text('Delete Precious?'), findsOneWidget,
          reason: 'the confirmation names what is about to go');

      await tester.tap(find.text('Cancel'));
      await frames(tester);

      expect(container.read(customThemesProvider).value, hasLength(1),
          reason: 'a mis-tap does not cost you an evening of colour picking');

      await stop(tester);
    });

    testWidgets('confirming the delete removes it and leaves the others',
        (tester) async {
      final drop = (await tester.runAsync(() async {
        await _addTheme(db, _mineCustom().copyWith(name: 'Keep'));
        return _addTheme(db, _mineCustom().copyWith(name: 'Drop'));
      }))!;
      final themes = container.listen(customThemesProvider, (_, _) {});
      addTearDown(themes.close);

      await pumpEditor(tester, themeId: customThemeRowId(drop.id));
      await tester.tap(find.byIcon(Icons.delete_outline));
      await frames(tester);
      await tester.tap(find.text('Delete'));
      await pumpUntil(tester,
          () => container.read(customThemesProvider).value?.length == 1);

      expect(container.read(customThemesProvider).value!.single.name, 'Keep');

      await stop(tester);
    });

    testWidgets('a new theme offers no bin — there is nothing to delete yet',
        (tester) async {
      await pumpEditor(tester);

      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.text('New theme'), findsOneWidget,
          reason: 'the app bar says which of the two jobs this is');

      await stop(tester);
    });
  });

  group('editing a preset saves a copy', () {
    /// The high-contrast dark preset: the interesting one to copy, because it
    /// is the pair that carries the AAA badge a copy must not inherit.
    final hc = kThemePresets.firstWhere((p) => p.id == 'high_contrast');

    Future<void> pumpPicker(WidgetTester tester,
        {List<String> alsoRoutes = const []}) async {
      tallScreen(tester);
      await tester.pumpWidget(routedAppUnder(
          container, const AppearanceScreen(),
          alsoRoutes: alsoRoutes));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    Future<void> pumpEditor(WidgetTester tester, String presetId) async {
      tallScreen(tester);
      await tester.pumpWidget(routedAppUnder(
          container, CustomThemeEditorScreen(fromPresetId: presetId)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('every preset row carries a pencil, like your own themes do',
        (tester) async {
      await tester.runAsync(() => _addTheme(db, _mineCustom()));
      await pumpPicker(tester);

      expect(find.byIcon(Icons.edit_outlined),
          findsNWidgets(kThemePresets.length + 1),
          reason: 'one per preset, plus the one theme of your own');

      await stop(tester);
    });

    testWidgets('the pencil on a preset opens the theme editor',
        (tester) async {
      await pumpPicker(tester, alsoRoutes: ['settings/appearance/custom']);
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await frames(tester);

      expect(find.text('at /settings/appearance/custom'), findsOneWidget);

      await stop(tester);
    });

    testWidgets("the editor opens on the preset's colours, named for it",
        (tester) async {
      await pumpEditor(tester, hc.id);

      expect(find.text('New from ${hc.name}'), findsOneWidget,
          reason: 'the app bar says what this is a copy of');
      expect(find.text('My theme'), findsOneWidget,
          reason: 'it is a new theme of your own, not the preset renamed');
      expect(find.text('#${_hexString(hc.accent)}'), findsOneWidget,
          reason: "you tweak from the preset's colours, not from black");
      expect(find.byIcon(Icons.delete_outline), findsNothing,
          reason: 'there is no row to delete, and a preset is not deletable');

      await stop(tester);
    });

    testWidgets('saving writes a copy and leaves the preset untouched',
        (tester) async {
      final themes = container.listen(customThemesProvider, (_, _) {});
      addTearDown(themes.close);

      await pumpEditor(tester, hc.id);
      await tester.tap(find.text('Save'));
      await pumpUntil(tester,
          () => container.read(customThemesProvider).value?.length == 1);

      final copy = container.read(customThemesProvider).value!.single;
      expect(copy.ground, hc.ground);
      expect(copy.accent, hc.accent);
      expect(customThemeRowId(copy.id), isNotNull,
          reason: 'it is a theme of your own, with a row of its own');
      expect(copy.accessible, isFalse,
          reason: 'a palette you can recolour carries no WCAG claim');
      expect(resolvePalette(hc.id, [copy]), hc,
          reason: 'the preset itself is still there, unchanged');

      await stop(tester);
    });

    testWidgets('the copy shows up in the picker without the AAA badge',
        (tester) async {
      await tester.runAsync(
          () => _addTheme(db, hc.copyWith(name: 'My theme', accessible: true)));
      await pumpPicker(tester);

      expect(find.text('My theme'), findsOneWidget);
      expect(find.text('AAA'), findsNWidgets(2),
          reason: 'the two shipped high-contrast presets, and nothing else');

      await stop(tester);
    });
  });

  group('duplicating one of your own', () {
    Future<void> pumpPicker(WidgetTester tester) async {
      tallScreen(tester);
      await tester
          .pumpWidget(routedAppUnder(container, const AppearanceScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('only your own themes offer the copy icon', (tester) async {
      await tester.runAsync(() => _addTheme(db, _mineCustom()));
      await pumpPicker(tester);

      expect(find.byIcon(Icons.copy_outlined), findsOneWidget,
          reason: 'a preset is copied by its pencil; only yours needs this');

      await stop(tester);
    });

    testWidgets('the copy icon clones the theme and selects the clone',
        (tester) async {
      final mine = (await tester.runAsync(() => _addTheme(db, _mineCustom())))!;
      final themes = container.listen(customThemesProvider, (_, _) {});
      addTearDown(themes.close);

      await pumpPicker(tester);
      await tester.tap(find.byIcon(Icons.copy_outlined));
      await pumpUntil(tester,
          () => container.read(customThemesProvider).value?.length == 2);

      final all = container.read(customThemesProvider).value!;
      expect([for (final p in all) p.name], ['Mine', 'Mine copy'],
          reason: 'the original keeps its name and its colours');
      expect(all.last.accent, mine.accent,
          reason: 'a copy is the same palette, not a fresh one');
      expect(all.last.accessible, isFalse);
      expect(container.read(themePresetIdProvider).value, all.last.id,
          reason: 'the clone is what you are now on, ready to be recoloured');

      await stop(tester);
    });

    testWidgets('copying twice does not leave two rows wearing one name',
        (tester) async {
      await tester.runAsync(() => _addTheme(db, _mineCustom()));
      final themes = container.listen(customThemesProvider, (_, _) {});
      addTearDown(themes.close);

      await pumpPicker(tester);
      await tester.tap(find.byIcon(Icons.copy_outlined).first);
      await pumpUntil(tester,
          () => container.read(customThemesProvider).value?.length == 2);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byIcon(Icons.copy_outlined).first);
      await pumpUntil(tester,
          () => container.read(customThemesProvider).value?.length == 3);

      expect([for (final p in container.read(customThemesProvider).value!) p.name],
          ['Mine', 'Mine copy', 'Mine copy 2']);

      await stop(tester);
    });

    testWidgets('a duplicate of an imported theme drops its AAA claim',
        (tester) async {
      final hc = kThemePresets.firstWhere((p) => p.accessible);
      await tester.runAsync(
          () => _addTheme(db, hc.copyWith(name: 'Sent to me', accessible: true)));
      final themes = container.listen(customThemesProvider, (_, _) {});
      addTearDown(themes.close);

      await pumpPicker(tester);
      await tester.tap(find.byIcon(Icons.copy_outlined).first);
      await pumpUntil(tester,
          () => container.read(customThemesProvider).value?.length == 2);
      await tester.pump(const Duration(milliseconds: 50));

      expect(container.read(customThemesProvider).value!.last.accessible, isFalse);
      expect(find.text('AAA'), findsNWidgets(2),
          reason: 'still only the two shipped presets carry the badge');

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
          reason: 'a link that arrives from outside still has to read');
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
      expect(route, startsWith('/settings/appearance/import?code='));
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
      expect(container.read(themePresetIdProvider).value, isNull,
          reason: 'nothing has been applied yet');

      await stop(tester);
    });

    testWidgets('confirming adds it as one of your own', (tester) async {
      final incoming = theirs();
      // The import screen doesn't watch the setting, so keep both halves of
      // the theme state subscribed for the assertions: the selected id says
      // which theme, the list says what it looks like.
      final sub = container.listen(themePresetIdProvider, (_, _) {});
      addTearDown(sub.close);
      final themes = container.listen(customThemesProvider, (_, _) {});
      addTearDown(themes.close);

      await tester.pumpWidget(appUnder(
        container,
        ThemeImportScreen(code: ThemeCode.link(incoming)),
      ));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('Use this theme'), 150,
          scrollable: find.byType(Scrollable).first);
      await tester.pump();
      await tester.tap(find.text('Use this theme'));
      await pumpUntil(
          tester,
          () =>
              container.read(activePaletteProvider).accent == incoming.accent);

      expect(customThemeRowId(container.read(themePresetIdProvider).value),
          isNotNull,
          reason: 'it arrived as a theme of your own, with a row of its own');
      final active = container.read(activePaletteProvider);
      expect(active.accent, incoming.accent);
      expect(active.name, 'Gym Bro Blue');

      await stop(tester);
    });

    testWidgets('and the import screen closes behind it', (tester) async {
      // The loop this covers: applying a theme repaints the whole app — the
      // root keys `MaterialApp` by the palette — so the screen was unmounted
      // before the write returned, the code that dismissed it never ran, and
      // the confirmation came straight back up. Back was the only way out.
      //
      // So the tree here is the app root's shape, keyed on the palette, rather
      // than a plain MaterialApp that would never rebuild and never notice.
      final incoming = theirs();
      final themes = container.listen(customThemesProvider, (_, _) {});
      addTearDown(themes.close);

      final router = GoRouter(
        initialLocation: '/settings/appearance',
        routes: [
          GoRoute(
            path: '/settings/appearance',
            builder: (_, _) => const Scaffold(body: Text('the theme picker')),
          ),
          GoRoute(
            path: '/settings/appearance/import',
            builder: (_, s) =>
                ThemeImportScreen(code: s.uri.queryParameters['code'] ?? ''),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: Consumer(builder: (context, ref, _) {
          final palette = ref.watch(activePaletteProvider);
          return MaterialApp.router(
            key: ValueKey(palette.signature),
            theme: AppTheme.build(palette),
            // The screen reads its words from the catalogue, as every screen
            // does — see `routedAppUnder`. This root is hand-built because the
            // palette has to re-key the MaterialApp itself.
            supportedLocales: kSupportedLocales,
            localizationsDelegates: kTestDelegates,
            routerConfig: router,
          );
        }),
      ));
      await tester.pump();

      router.push('/settings/appearance/import'
          '?code=${Uri.encodeQueryComponent(ThemeCode.encode(incoming))}');
      await frames(tester);
      expect(find.byType(ThemeImportScreen), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Use this theme'), 150,
          scrollable: find.byType(Scrollable).first);
      await tester.pump();
      await tester.tap(find.text('Use this theme'));
      await pumpUntil(tester,
          () => container.read(activePaletteProvider).accent == incoming.accent);
      // Long enough for the page to finish animating out; the route itself is
      // gone the moment the button is pressed.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ThemeImportScreen), findsNothing,
          reason: 'the confirmation is done with; it should be gone');
      expect(find.text('the theme picker'), findsOneWidget,
          reason: 'and you are back where a normal tap would have left you');
      expect(container.read(activePaletteProvider).accent, incoming.accent,
          reason: 'the theme was applied on the way out');

      await stop(tester);
    });

    testWidgets('an accessible theme arrives without its AAA claim',
        (tester) async {
      // The badge means "designed and checked against WCAG". Once a palette is
      // one of yours it can be recoloured freely and nothing re-checks it, so
      // the claim cannot come along — the same reason building your own from a
      // high-contrast preset drops it.
      final hc = kThemePresets.firstWhere((p) => p.accessible);
      final sub = container.listen(themePresetIdProvider, (_, _) {});
      addTearDown(sub.close);
      final themes = container.listen(customThemesProvider, (_, _) {});
      addTearDown(themes.close);

      await tester.pumpWidget(appUnder(
        container,
        ThemeImportScreen(code: ThemeCode.encode(hc)),
      ));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Use this theme'), 150,
          scrollable: find.byType(Scrollable).first);
      await tester.pump();
      await tester.tap(find.text('Use this theme'));
      await pumpUntil(tester,
          () => container.read(themePresetIdProvider).value != null);

      final stored = container.read(customThemesProvider).value!.single;
      expect(stored.accessible, isFalse,
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
      await _addTheme(db, hc.copyWith(name: 'Mine', accessible: true));

      // Tall enough that the whole picker builds: your own themes sit below
      // both preset groups, and an unbuilt row cannot be asserted about.
      tester.view.physicalSize = const Size(1200, 4800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester
          .pumpWidget(appUnder(container, const AppearanceScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Mine'), findsOneWidget,
          reason: 'your own row is on screen, so its badge would be too');

      // Both shipped accessible presets still carry the badge; your own row
      // must not add a third.
      expect(find.text('AAA'), findsNWidgets(2),
          reason: 'only the two checked presets may claim AAA');

      await stop(tester);
    });

    testWidgets('declining leaves the current theme untouched', (tester) async {
      await db.setThemePreset('graphite');
      final sub = container.listen(themePresetIdProvider, (_, _) {});
      addTearDown(sub.close);

      await tester.pumpWidget(appUnder(
        container,
        ThemeImportScreen(code: ThemeCode.encode(theirs())),
      ));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Cancel'), 150,
          scrollable: find.byType(Scrollable).first);
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(container.read(themePresetIdProvider).value, 'graphite',
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
    // The custom theme has to be able to say anything the shipped presets say,
    // and it says it in one notation: RGB, with a hex field. Six hex digits are
    // how a colour gets written down and read back — off a preset, off a brand
    // guide, off the clipboard — so that is the whole of the picker.

    /// The picker's hex field, scoped to the dialog — the editor behind it
    /// carries the theme's name field, which is also a `TextField`.
    final hexField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

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

    testWidgets('offers RGB and a hex field, and nothing else', (tester) async {
      await openPicker(tester, 'Accent');

      // Three channels, one per byte of the hex beside them.
      expect(find.byType(Slider), findsNWidgets(3));
      for (final channel in ['R', 'G', 'B']) {
        expect(find.text(channel), findsOneWidget, reason: channel);
      }
      expect(hexField, findsOneWidget);
      // HSL is gone, toggle and all — there is nothing to switch between.
      expect(find.text('HSL'), findsNothing);
      expect(find.text('RGB'), findsNothing,
          reason: 'a label for the only notation there is labels nothing');

      await stop(tester);
    });

    testWidgets('a role wears one name, in the list and in its picker',
        (tester) async {
      for (final role in ['Completed', 'Missed goal']) {
        await openPicker(tester, role);
        expect(
            find.descendant(
                of: find.byType(AlertDialog), matching: find.text(role)),
            findsOneWidget,
            reason: 'the picker for $role should be titled $role');
        await tester.tap(find.text('Cancel'));
        await frames(tester);
      }
      // And the names they replaced are nowhere on the editor. "Personal
      // record" named the opposite of what `gold` paints: a missed goal, a
      // backed-off weight, a downward delta.
      for (final stale in ['Done', 'Short', 'Personal record']) {
        expect(find.text(stale), findsNothing, reason: stale);
      }

      await stop(tester);
    });

    testWidgets('a channel slider moves its own byte and no other',
        (tester) async {
      await openPicker(tester, 'Accent');
      await tester.enterText(hexField, '#404040');
      await frames(tester);

      // Second slider: R, then G, then B.
      await tester.drag(find.byType(Slider).at(1), const Offset(60, 0));
      await frames(tester);
      await use(tester);

      final after = _colorOfHex(shownHex(tester, 'Accent'))!;
      expect(after.g, greaterThan(0x40 / 255), reason: 'green moved');
      expect((after.r * 255).round(), 0x40, reason: 'red did not');
      expect((after.b * 255).round(), 0x40, reason: 'nor blue');

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

    testWidgets('typing a hex sets the colour', (tester) async {
      await openPicker(tester, 'Accent');
      await tester.enterText(hexField, '#AB12CD');
      await frames(tester);
      await use(tester);

      expect(shownHex(tester, 'Accent'), '#AB12CD',
          reason: 'a colour read off a palette elsewhere can be transcribed');

      await stop(tester);
    });

    testWidgets('the short and bare hex forms are accepted too',
        (tester) async {
      await openPicker(tester, 'Accent');
      await tester.enterText(hexField, 'ABC');
      await frames(tester);
      await use(tester);
      expect(shownHex(tester, 'Accent'), '#AABBCC',
          reason: 'three digits expand the way CSS expands them');

      await tester.ensureVisible(find.text('Accent'));
      await tester.pump();
      await tester.tap(find.text('Accent'));
      await frames(tester);
      await tester.enterText(hexField, '123456');
      await frames(tester);
      await use(tester);
      expect(shownHex(tester, 'Accent'), '#123456',
          reason: 'the hash is optional');

      await stop(tester);
    });

    /// Stands in for the system clipboard, which is a platform channel a widget
    /// test has none of. Returns a one-entry box the test can read and write.
    List<String?> fakeClipboard(WidgetTester tester) {
      final held = <String?>[null];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              held[0] = (call.arguments as Map)['text'] as String?;
              return null;
            case 'Clipboard.getData':
              return held[0] == null ? null : {'text': held[0]};
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      return held;
    }

    testWidgets('the hex can be copied out of the picker', (tester) async {
      // The roles are families — surface, surface2 and surface3 are one hue at
      // three lightnesses — so building one starts from the last one's value.
      final clipboard = fakeClipboard(tester);
      await openPicker(tester, 'Accent');
      await tester.enterText(hexField, '#123456');
      await frames(tester);

      await tester.tap(find.byTooltip('Copy hex'));
      await frames(tester);

      expect(clipboard[0], '#123456');
      await stop(tester);
    });

    testWidgets('and pasted in, in any form the field itself takes',
        (tester) async {
      final clipboard = fakeClipboard(tester);

      for (final (pasted, expected) in [
        ('#ABCDEF', '#ABCDEF'),
        ('ABCDEF', '#ABCDEF'), // bare, no hash
        ('#ABC', '#AABBCC'), // CSS shorthand
      ]) {
        clipboard[0] = pasted;
        await openPicker(tester, 'Accent');
        await tester.tap(find.byTooltip('Paste hex'));
        await frames(tester);
        await use(tester);

        expect(shownHex(tester, 'Accent'), expected, reason: 'pasted "$pasted"');
      }

      await stop(tester);
    });

    testWidgets('pasting junk leaves the colour alone', (tester) async {
      // The same rule as typing junk: parseHex returning null is the whole of
      // it, and it has to hold whichever way the text arrives.
      final clipboard = fakeClipboard(tester);
      clipboard[0] = 'not a colour at all';

      await openPicker(tester, 'Accent');
      final before = shownHex(tester, 'Accent');
      await tester.tap(find.byTooltip('Paste hex'));
      await frames(tester);
      await use(tester);

      expect(shownHex(tester, 'Accent'), before);
      await stop(tester);
    });

    testWidgets('a role row hands over its hex on a long press', (tester) async {
      // The row's tap already belongs to the picker, so the hex it prints
      // cannot have a tap of its own.
      final clipboard = fakeClipboard(tester);
      tester.view.physicalSize = const Size(1200, 4800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
          routedAppUnder(container, const CustomThemeEditorScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final shown = shownHex(tester, 'Accent');
      await tester.longPress(find.text('Accent'));
      await frames(tester);

      expect(clipboard[0], shown);
      await stop(tester);
    });

    testWidgets('nonsense in the hex field leaves the colour alone',
        (tester) async {
      await openPicker(tester, 'Accent');
      final before = shownHex(tester, 'Accent');
      await tester.enterText(hexField, 'not a colour');
      await frames(tester);
      await use(tester);

      expect(shownHex(tester, 'Accent'), before,
          reason: 'a typo must not silently repaint a role');

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
        await tester.enterText(hexField, hex);
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
        expect(find.textContaining('look alike'), findsNothing,
            reason: '${preset.id} should not trip the marker warning either');
      }
      await stop(tester);
    });

    testWidgets('it shows a set row with both markers on it', (tester) async {
      // The markers are the palette's hardest job, and a swatch of each says
      // nothing about whether you could tell them apart at a glance down a
      // column. So the preview is the board: a hit, a short one, one to go.
      final p = sentinels();
      await tester.pumpWidget(appUnder(container, ThemePreview(palette: p)));
      await tester.pump();

      // The set rows themselves, in the shape the board draws them.
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('80×8'), findsWidgets);
      for (final n in ['1', '2', '3']) {
        expect(find.text(n), findsWidgets, reason: 'set $n');
      }

      // And the cue that does not depend on hue, on the short row only.
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);

      final shown = painted(tester);
      expect(shown, contains(p.good), reason: 'the hit row');
      expect(shown, contains(p.gold), reason: 'the short row');

      await stop(tester);
    });

    testWidgets('warns when the two set markers are too close to tell apart',
        (tester) async {
      // The other warning is about reading text against a background. This one
      // is about telling two colours apart from each other, which no contrast
      // ratio answers — Solarized's own pair sat at 1.00:1 and looked it.
      final alike = sentinels().copyWith(
        good: const Color(0xFF859900),
        gold: const Color(0xFFB58900),
      );
      expect(colourDistance(alike.good, alike.gold),
          lessThan(kMarkerDistance),
          reason: 'the fixture really is a pair nobody could separate');

      await tester.pumpWidget(appUnder(container, ThemePreview(palette: alike)));
      await tester.pump();

      expect(find.textContaining('look alike'), findsOneWidget);
      await stop(tester);
    });

    testWidgets('and names the two roles the way the editor names them',
        (tester) async {
      // One set of names per colour role, wherever the user meets one. The
      // warning used to call them "done" and "short" while the role list called
      // them "Completed" and "Personal record" — two names for each colour, and
      // one of them naming the opposite of what the colour paints.
      final alike = sentinels().copyWith(
        good: const Color(0xFF859900),
        gold: const Color(0xFFB58900),
      );
      await tester.pumpWidget(appUnder(container, ThemePreview(palette: alike)));
      await tester.pump();

      expect(find.textContaining('Completed'), findsOneWidget);
      expect(find.textContaining('Missed goal'), findsOneWidget);
      for (final stale in ['Done and short', 'done and short', 'Personal record']) {
        expect(find.textContaining(stale), findsNothing, reason: stale);
      }

      await stop(tester);
    });
  });

  group('a stored theme survives a cold launch', () {
    /// The app root's shape: watch the palette, key the app by its signature,
    /// build the theme (which points AppColors at it) on the way past.
    Widget root(GoRouter router) => Consumer(
          builder: (context, ref, _) {
            final palette = ref.watch(activePaletteProvider);
            return MaterialApp.router(
              key: ValueKey(palette.signature),
              theme: AppTheme.build(palette),
              supportedLocales: kSupportedLocales,
              localizationsDelegates: kTestDelegates,
              routerConfig: router,
            );
          },
        );

    GoRouter shellRouter() => GoRouter(
          initialLocation: '/today',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (_, _, shell) => HomeShell(shell: shell),
              branches: [
                for (final p in const [
                  '/today',
                  '/routines',
                  '/history',
                  '/profile'
                ])
                  StatefulShellBranch(
                    routes: [
                      GoRoute(path: p, builder: (_, _) => const SizedBox.shrink())
                    ],
                  ),
              ],
            ),
          ],
        );

    testWidgets('the navigation bar paints the stored theme, untapped',
        (tester) async {
      // The bar built once from the default palette — the settings row had not
      // arrived — and nothing rebuilt it when the real one did. go_router holds
      // the shell's branch navigators by GlobalKey, so re-keying MaterialApp
      // *moves* the shell's elements rather than rebuilding them, and a
      // NavigationBarTheme built from the mutable AppColors globals kept
      // whatever it read first. Any tap marked it dirty and it came right,
      // which is exactly what was reported.
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.runAsync(() => db.setThemePreset('solarized_light'));

      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: root(shellRouter())));
      await tester.pumpAndSettle();

      final stored = kThemePresets.firstWhere((p) => p.id == 'solarized_light');
      final bar = NavigationBarTheme.of(
          tester.element(find.byType(NavigationBar)));

      expect(bar.backgroundColor, stored.ground,
          reason: 'the navigation bar is painted in some other theme');

      await stop(tester);
    });

    testWidgets('and follows a change of theme without being touched',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: root(shellRouter())));
      await tester.pumpAndSettle();

      await tester.runAsync(() => db.setThemePreset('solarized_dark'));
      await tester.pumpAndSettle();

      final stored = kThemePresets.firstWhere((p) => p.id == 'solarized_dark');
      expect(
        NavigationBarTheme.of(tester.element(find.byType(NavigationBar)))
            .backgroundColor,
        stored.ground,
      );

      await stop(tester);
    });
  });
}
