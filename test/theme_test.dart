import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/widgets/common.dart';

void main() {
  group('preset library', () {
    test('several presets ship, and the default is the first', () {
      expect(kThemePresets.length, greaterThanOrEqualTo(3));
      expect(kDefaultPalette, kThemePresets.first);
      expect(kDefaultPalette.id, 'ignition');
    });

    test('every preset has a unique id', () {
      final ids = kThemePresets.map((p) => p.id).toSet();
      expect(ids.length, kThemePresets.length);
    });

    test('both light and dark presets ship', () {
      final dark =
          kThemePresets.where((p) => p.brightness == Brightness.dark);
      final light =
          kThemePresets.where((p) => p.brightness == Brightness.light);
      expect(dark.length, greaterThanOrEqualTo(3));
      expect(light.length, greaterThanOrEqualTo(3));
    });

    test('a high-contrast accessibility preset ships', () {
      final hc = kThemePresets.firstWhere((p) => p.id == 'high_contrast');
      // Pure black ground, pure white text — maximum luminance contrast.
      expect(hc.ground.computeLuminance(), lessThan(0.02));
      expect(hc.text.computeLuminance(), greaterThan(0.95));
    });
  });

  group('brightness and on-accent contrast', () {
    test('a pale ground reads as a light theme, a dark one as dark', () {
      for (final p in kThemePresets) {
        final expected = p.ground.computeLuminance() > 0.5
            ? Brightness.light
            : Brightness.dark;
        expect(p.brightness, expected, reason: p.id);
      }
    });

    test('the accent foreground stays legible on every preset', () {
      // A dark accent (the light themes) takes white; a bright one (the dark
      // themes) takes a dark tint. Either way the two must be far apart.
      for (final p in kThemePresets) {
        final contrast =
            (p.accent.computeLuminance() - p.onAccent.computeLuminance()).abs();
        expect(contrast, greaterThan(0.2), reason: '${p.id} accent vs onAccent');
      }
    });

    test('the light themes put white on their dark accents', () {
      for (final p in kThemePresets.where((p) => p.brightness == Brightness.light)) {
        expect(p.onAccent, Colors.white, reason: p.id);
      }
    });
  });

  group('serialisation (export/import)', () {
    test('a palette round-trips through JSON unchanged', () {
      for (final preset in kThemePresets) {
        final restored = AppPalette.tryParse(preset.toJson());
        expect(restored, isNotNull);
        expect(restored, equals(preset));
      }
    });

    test('the JSON carries every colour role as a hex string', () {
      final map = kDefaultPalette.toMap();
      final colors = map['colors'] as Map<String, dynamic>;
      expect(colors.keys, containsAll(<String>[
        'ground', 'surface', 'surface2', 'surface3', 'line', 'text',
        'muted', 'faint', 'accent', 'accentPress', 'good', 'gold',
      ]));
      expect(colors['accent'], 'FF6A3D');
    });

    test('a missing colour falls back to the default rather than throwing', () {
      final palette = AppPalette.fromMap({
        'id': 'custom',
        'name': 'Partial',
        'colors': {'accent': '112233'},
      });
      expect(palette.accent, const Color(0xFF112233));
      // Untouched role keeps the default preset's value.
      expect(palette.ground, kDefaultPalette.ground);
    });

    test('a "#RRGGBB" form is accepted', () {
      final palette = AppPalette.fromMap({
        'colors': {'accent': '#00FF00'},
      });
      expect(palette.accent, const Color(0xFF00FF00));
    });

    test('garbage input parses to null instead of crashing an import', () {
      expect(AppPalette.tryParse('not json'), isNull);
      expect(AppPalette.tryParse('[1,2,3]'), isNull);
      expect(AppPalette.tryParse('{"id":"x"}'), isNull);
    });
  });

  group('resolvePalette', () {
    test('a null choice is the default preset', () {
      expect(resolvePalette(null, null), kDefaultPalette);
    });

    test('a known preset id resolves to that preset', () {
      final graphite = kThemePresets.firstWhere((p) => p.id == 'graphite');
      expect(resolvePalette('graphite', null), graphite);
    });

    test('an unknown id degrades to the default', () {
      expect(resolvePalette('does-not-exist', null), kDefaultPalette);
    });

    test('custom resolves from the stored JSON, keeping the custom id', () {
      final custom = kDefaultPalette
          .copyWith(id: 'custom', name: 'Mine', accent: const Color(0xFFABCDEF));
      final resolved = resolvePalette('custom', custom.toJson());
      expect(resolved.id, kCustomThemeId);
      expect(resolved.accent, const Color(0xFFABCDEF));
    });

    test('custom with no stored JSON degrades to the default', () {
      expect(resolvePalette('custom', null), kDefaultPalette);
    });

    test('custom with malformed JSON degrades to the default', () {
      expect(resolvePalette('custom', 'broken'), kDefaultPalette);
    });
  });

  group('signature', () {
    test('changes when any single role is edited', () {
      final a = kDefaultPalette;
      final b = a.copyWith(accent: const Color(0xFF000001));
      expect(a.signature, isNot(b.signature));
    });
  });

  group('AppColors.apply', () {
    test('points the live colours at the given palette', () {
      final graphite = kThemePresets.firstWhere((p) => p.id == 'graphite');
      AppColors.apply(graphite);
      expect(AppColors.accent, graphite.accent);
      expect(AppColors.ground, graphite.ground);
      // Put it back so later tests see the default.
      AppColors.apply(kDefaultPalette);
      expect(AppColors.accent, kDefaultPalette.accent);
    });
  });

  group('per-routine accent survives any theme', () {
    test('hexColor is independent of the active palette', () {
      const routineHex = '3ED598';
      final asDefault = hexColor(routineHex);

      // Switch the whole app to a totally different theme.
      AppColors.apply(kThemePresets.firstWhere((p) => p.id == 'crimson'));
      final asCrimson = hexColor(routineHex);

      // The routine's own colour is parsed from its stored hex, not from any
      // theme role, so it is byte-for-byte the same whatever the theme.
      expect(asCrimson, asDefault);
      expect(asCrimson, const Color(0xFF3ED598));

      AppColors.apply(kDefaultPalette);
    });
  });
}
