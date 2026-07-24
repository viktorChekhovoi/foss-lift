import 'dart:convert';

import 'package:flutter/material.dart';

/// The set of colour roles that make up a theme.
///
/// Everything the app paints resolves to one of these twelve roles. A theme is
/// simply a choice of colour for each — see [kThemePresets] for the ones that
/// ship, and [AppColors] for the live values the widgets read.
///
/// A palette is a value: two with the same colours are equal, and any palette
/// round-trips through [toJson]/[fromJson] so it can be exported to a file and
/// read back on another device.
@immutable
class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.ground,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.line,
    required this.text,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.accentPress,
    required this.good,
    required this.gold,
  });

  /// A stable identifier: a preset slug (e.g. `ignition`) or [kCustomThemeId]
  /// for a palette the user built themselves.
  final String id;

  /// A human label shown in the picker.
  final String name;

  final Color ground;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color line;
  final Color text;
  final Color muted;
  final Color faint;
  final Color accent;
  final Color accentPress;
  final Color good;
  final Color gold;

  /// Whether this is a light or dark theme, read straight off the ground's
  /// luminance. Inferred rather than stored so custom and imported palettes get
  /// the right Material brightness for free — a pale ground is a light theme.
  Brightness get brightness =>
      ground.computeLuminance() > 0.5 ? Brightness.light : Brightness.dark;

  /// A legible foreground for text/icons drawn *on* the accent. A bright accent
  /// (the dark themes' oranges and mints) takes a very dark tint of itself, so
  /// the button reads brown-black or navy-black; a dark accent (the light
  /// themes' saturated colours) takes white. The 0.26 cut keeps every shipped
  /// dark preset on the dark-tint side it was designed for.
  Color get onAccent => accent.computeLuminance() >= 0.26
      ? Color.lerp(accent, Colors.black, 0.82)!
      : Colors.white;

  /// The same, for the "good"/completed colour — always a bright/medium green,
  /// so a dark tint always reads on it.
  Color get onGood => Color.lerp(good, Colors.black, 0.85)!;

  AppPalette copyWith({
    String? id,
    String? name,
    Color? ground,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? line,
    Color? text,
    Color? muted,
    Color? faint,
    Color? accent,
    Color? accentPress,
    Color? good,
    Color? gold,
  }) {
    return AppPalette(
      id: id ?? this.id,
      name: name ?? this.name,
      ground: ground ?? this.ground,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      line: line ?? this.line,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      faint: faint ?? this.faint,
      accent: accent ?? this.accent,
      accentPress: accentPress ?? this.accentPress,
      good: good ?? this.good,
      gold: gold ?? this.gold,
    );
  }

  /// The colour roles as a name→"RRGGBB" map, in a fixed order.
  Map<String, String> get _roles => {
        'ground': _hex(ground),
        'surface': _hex(surface),
        'surface2': _hex(surface2),
        'surface3': _hex(surface3),
        'line': _hex(line),
        'text': _hex(text),
        'muted': _hex(muted),
        'faint': _hex(faint),
        'accent': _hex(accent),
        'accentPress': _hex(accentPress),
        'good': _hex(good),
        'gold': _hex(gold),
      };

  /// A portable representation: the id, the name, and every colour as a hex
  /// string. This is what export writes and import reads.
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'colors': _roles,
      };

  String toJson() => jsonEncode(toMap());

  /// Rebuilds a palette from [toMap]'s shape. Missing or malformed colours fall
  /// back to the default preset's role, so a hand-edited or truncated import
  /// still yields a usable theme rather than throwing.
  factory AppPalette.fromMap(Map<String, dynamic> map) {
    final colors = (map['colors'] as Map?) ?? const {};
    Color role(String key, Color fallback) {
      final v = colors[key];
      if (v is String) {
        final parsed = _tryHex(v);
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    const d = _ignition;
    return AppPalette(
      id: (map['id'] as String?)?.trim().isNotEmpty == true
          ? map['id'] as String
          : kCustomThemeId,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : 'Custom',
      ground: role('ground', d.ground),
      surface: role('surface', d.surface),
      surface2: role('surface2', d.surface2),
      surface3: role('surface3', d.surface3),
      line: role('line', d.line),
      text: role('text', d.text),
      muted: role('muted', d.muted),
      faint: role('faint', d.faint),
      accent: role('accent', d.accent),
      accentPress: role('accentPress', d.accentPress),
      good: role('good', d.good),
      gold: role('gold', d.gold),
    );
  }

  /// Parses [toJson]. Returns null on anything that is not a theme object, so a
  /// bad paste can be reported rather than crashing the import.
  static AppPalette? tryParse(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['colors'] is! Map) return null;
      return AppPalette.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  /// A fingerprint of every colour — used to key the [MaterialApp] so a theme
  /// change (preset or a single edited role) forces the whole tree to repaint.
  String get signature => '$id|${_roles.values.join(',')}';

  @override
  bool operator ==(Object other) =>
      other is AppPalette &&
      other.id == id &&
      other.name == name &&
      other.ground == ground &&
      other.surface == surface &&
      other.surface2 == surface2 &&
      other.surface3 == surface3 &&
      other.line == line &&
      other.text == text &&
      other.muted == muted &&
      other.faint == faint &&
      other.accent == accent &&
      other.accentPress == accentPress &&
      other.good == good &&
      other.gold == gold;

  @override
  int get hashCode => Object.hash(id, name, signature);
}

/// A "RRGGBB" hex string for a colour (ignoring its alpha; the app is opaque).
String _hex(Color c) {
  int ch(double v) => (v * 255).round().clamp(0, 255);
  final rgb = (ch(c.r) << 16) | (ch(c.g) << 8) | ch(c.b);
  return rgb.toRadixString(16).toUpperCase().padLeft(6, '0');
}

/// Parses a "RRGGBB" (or "#RRGGBB") hex string, or null if it is not one.
Color? _tryHex(String hex) {
  var s = hex.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length != 6) return null;
  final value = int.tryParse(s, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}

/// The id used for the one palette the user builds and edits themselves.
const String kCustomThemeId = 'custom';

// ---------------------------------------------------------------------------
// Shipped presets
// ---------------------------------------------------------------------------

/// The original palette lifted from the design mockup (design/mockup.html): a
/// cool, navy-biased dark ground with an "ignition" orange accent, mint for
/// completed work, and gold for personal records. This is the default.
const AppPalette _ignition = AppPalette(
  id: 'ignition',
  name: 'Ignition',
  ground: Color(0xFF0F1218),
  surface: Color(0xFF171B24),
  surface2: Color(0xFF1F2530),
  surface3: Color(0xFF272E3B),
  line: Color(0xFF2A313D),
  text: Color(0xFFEAEEF5),
  muted: Color(0xFF8B95A7),
  faint: Color(0xFF5A6474),
  accent: Color(0xFFFF6A3D),
  accentPress: Color(0xFFE0521F),
  good: Color(0xFF3ED598),
  gold: Color(0xFFFFC24B),
);

/// A neutral graphite ground with an electric-blue accent.
const AppPalette _graphite = AppPalette(
  id: 'graphite',
  name: 'Graphite',
  ground: Color(0xFF121316),
  surface: Color(0xFF1A1C20),
  surface2: Color(0xFF23262B),
  surface3: Color(0xFF2C3036),
  line: Color(0xFF33373E),
  text: Color(0xFFECEEF1),
  muted: Color(0xFF9AA0A9),
  faint: Color(0xFF646A73),
  accent: Color(0xFF4C9AFF),
  accentPress: Color(0xFF2F7BE0),
  good: Color(0xFF3ED598),
  gold: Color(0xFFFFC24B),
);

/// A green-tinted ground with a lime accent.
const AppPalette _forest = AppPalette(
  id: 'forest',
  name: 'Forest',
  ground: Color(0xFF0E1512),
  surface: Color(0xFF141D18),
  surface2: Color(0xFF1C2822),
  surface3: Color(0xFF24332B),
  line: Color(0xFF2A3A31),
  text: Color(0xFFE7F0EA),
  muted: Color(0xFF8DA093),
  faint: Color(0xFF5C6F63),
  accent: Color(0xFF5BD16A),
  accentPress: Color(0xFF3DAE4C),
  good: Color(0xFF6FE3C2),
  gold: Color(0xFFF5C766),
);

/// A warm, dark ember ground with a red accent.
const AppPalette _crimson = AppPalette(
  id: 'crimson',
  name: 'Crimson',
  ground: Color(0xFF15100F),
  surface: Color(0xFF1E1614),
  surface2: Color(0xFF2A1E1B),
  surface3: Color(0xFF342623),
  line: Color(0xFF3D2C28),
  text: Color(0xFFF3E9E7),
  muted: Color(0xFFA8938E),
  faint: Color(0xFF74615C),
  accent: Color(0xFFFF5A5F),
  accentPress: Color(0xFFE03B41),
  good: Color(0xFF3ED598),
  gold: Color(0xFFFFC24B),
);

/// A deep violet ground with a magenta accent.
const AppPalette _violet = AppPalette(
  id: 'violet',
  name: 'Violet',
  ground: Color(0xFF120F18),
  surface: Color(0xFF1A1622),
  surface2: Color(0xFF241E30),
  surface3: Color(0xFF2D2639),
  line: Color(0xFF372E45),
  text: Color(0xFFECE8F5),
  muted: Color(0xFF9B92AD),
  faint: Color(0xFF675E78),
  accent: Color(0xFFB26BFF),
  accentPress: Color(0xFF9540E8),
  good: Color(0xFF3ED598),
  gold: Color(0xFFFFC24B),
);

// --- Light presets ---------------------------------------------------------
// Pale grounds with dark text. Their accents are saturated and dark enough to
// read on white (and so take white foreground on an accent button — see
// [AppPalette.onAccent]); `good`/`gold` stay a medium tone that works both as a
// coloured label and behind the dark-on-green markers the app draws.

/// A clean, cool near-white with the signature ignition orange.
const AppPalette _daylight = AppPalette(
  id: 'daylight',
  name: 'Daylight',
  ground: Color(0xFFF5F7FA),
  surface: Color(0xFFFFFFFF),
  surface2: Color(0xFFEDF1F6),
  surface3: Color(0xFFE2E8F0),
  line: Color(0xFFD5DCE6),
  text: Color(0xFF1B2430),
  muted: Color(0xFF5B6472),
  faint: Color(0xFF949CAC),
  accent: Color(0xFFD9531A),
  accentPress: Color(0xFFB5410F),
  good: Color(0xFF12A866),
  gold: Color(0xFFC8890B),
);

/// A warm paper-white with a deep blue accent.
const AppPalette _paper = AppPalette(
  id: 'paper',
  name: 'Paper',
  ground: Color(0xFFF7F4EF),
  surface: Color(0xFFFFFFFF),
  surface2: Color(0xFFF1ECE3),
  surface3: Color(0xFFE8E1D5),
  line: Color(0xFFDBD3C6),
  text: Color(0xFF25201A),
  muted: Color(0xFF6E655A),
  faint: Color(0xFF9E9384),
  accent: Color(0xFF2A5CD6),
  accentPress: Color(0xFF1E46AB),
  good: Color(0xFF12A866),
  gold: Color(0xFFB87E0A),
);

/// A cool, pale green with a teal accent.
const AppPalette _fern = AppPalette(
  id: 'fern',
  name: 'Fern',
  ground: Color(0xFFF1F6F3),
  surface: Color(0xFFFFFFFF),
  surface2: Color(0xFFE7F0EB),
  surface3: Color(0xFFDAE7E0),
  line: Color(0xFFCCDCD3),
  text: Color(0xFF15201B),
  muted: Color(0xFF566A60),
  faint: Color(0xFF869A8E),
  accent: Color(0xFF0D8F6B),
  accentPress: Color(0xFF0A6E52),
  good: Color(0xFF16A34A),
  gold: Color(0xFFBE871A),
);

// --- Accessibility ---------------------------------------------------------

/// Maximum contrast: pure black ground, pure white text, a high-visibility
/// yellow accent and vivid green/amber markers. Borders are lightened well past
/// the other dark themes so structure is never lost.
const AppPalette _highContrast = AppPalette(
  id: 'high_contrast',
  name: 'High contrast',
  ground: Color(0xFF000000),
  surface: Color(0xFF0A0A0A),
  surface2: Color(0xFF161616),
  surface3: Color(0xFF222222),
  line: Color(0xFF5A5A5A),
  text: Color(0xFFFFFFFF),
  muted: Color(0xFFD5D5D5),
  faint: Color(0xFFAEAEAE),
  accent: Color(0xFFFFD400),
  accentPress: Color(0xFFE6BE00),
  good: Color(0xFF00E676),
  gold: Color(0xFFFFAB00),
);

/// Every preset that ships with the app. The first is the default. Ordered
/// dark, then light, then the accessibility theme — the picker groups them by
/// [AppPalette.brightness].
const List<AppPalette> kThemePresets = [
  _ignition,
  _graphite,
  _forest,
  _crimson,
  _violet,
  _daylight,
  _paper,
  _fern,
  _highContrast,
];

/// The default palette, used when nothing has been chosen or a stored/imported
/// theme cannot be resolved.
const AppPalette kDefaultPalette = _ignition;

/// Resolves the persisted theme choice into the palette to paint with.
///
/// [presetId] is a preset slug, [kCustomThemeId], or null. When it is
/// [kCustomThemeId] the user's [customJson] is parsed; anything unresolvable —
/// an unknown id, a null or malformed custom theme — falls back to
/// [kDefaultPalette] rather than leaving the app unpainted.
AppPalette resolvePalette(String? presetId, String? customJson) {
  if (presetId == kCustomThemeId) {
    if (customJson != null) {
      final parsed = AppPalette.tryParse(customJson);
      if (parsed != null) return parsed.copyWith(id: kCustomThemeId);
    }
    return kDefaultPalette;
  }
  for (final preset in kThemePresets) {
    if (preset.id == presetId) return preset;
  }
  return kDefaultPalette;
}

// ---------------------------------------------------------------------------
// Live colours the widgets read
// ---------------------------------------------------------------------------

/// The colours the app paints with, right now.
///
/// These are the same role names the whole codebase already references
/// (`AppColors.accent`, `AppColors.line`, …). They are no longer compile-time
/// constants: [apply] swaps them for the active theme's colours, and the app
/// root re-keys itself so every screen repaints against the new values. This
/// keeps the thousands of call sites untouched while making the palette
/// runtime-selectable.
///
/// Per-routine accent colours do **not** come through here — a routine's own
/// `colorHex` is parsed directly by `hexColor()` and so overrides any theme,
/// exactly as before.
class AppColors {
  static Color ground = kDefaultPalette.ground;
  static Color surface = kDefaultPalette.surface;
  static Color surface2 = kDefaultPalette.surface2;
  static Color surface3 = kDefaultPalette.surface3;
  static Color line = kDefaultPalette.line;
  static Color text = kDefaultPalette.text;
  static Color muted = kDefaultPalette.muted;
  static Color faint = kDefaultPalette.faint;
  static Color accent = kDefaultPalette.accent;
  static Color accentPress = kDefaultPalette.accentPress;
  static Color good = kDefaultPalette.good;
  static Color gold = kDefaultPalette.gold;

  /// Points the live colours at [p]. Call before building the theme/tree.
  static void apply(AppPalette p) {
    ground = p.ground;
    surface = p.surface;
    surface2 = p.surface2;
    surface3 = p.surface3;
    line = p.line;
    text = p.text;
    muted = p.muted;
    faint = p.faint;
    accent = p.accent;
    accentPress = p.accentPress;
    good = p.good;
    gold = p.gold;
  }
}

/// A monospace text style for numeric data (weights, reps, timers, volume) —
/// tabular figures so columns of digits line up like a barbell readout.
const TextStyle kMono = TextStyle(
  fontFamily: 'monospace',
  fontFeatures: [FontFeature.tabularFigures()],
);

class AppTheme {
  /// Builds the Material theme for [palette], light or dark according to its
  /// [AppPalette.brightness]. As a side effect it points [AppColors] at
  /// [palette] so the widget tree — which reads those directly — paints the
  /// same theme.
  static ThemeData build(AppPalette palette) {
    AppColors.apply(palette);
    final isLight = palette.brightness == Brightness.light;
    final base = ThemeData(brightness: palette.brightness, useMaterial3: true);
    final error = isLight ? const Color(0xFFC62828) : const Color(0xFFFF5D5D);
    final scheme = isLight
        ? ColorScheme.light(
            primary: palette.accent,
            onPrimary: palette.onAccent,
            secondary: palette.good,
            onSecondary: palette.onGood,
            surface: palette.surface,
            onSurface: palette.text,
            error: error,
            outline: palette.line,
          )
        : ColorScheme.dark(
            primary: palette.accent,
            onPrimary: palette.onAccent,
            secondary: palette.good,
            onSecondary: palette.onGood,
            surface: palette.surface,
            onSurface: palette.text,
            error: error,
            outline: palette.line,
          );

    return base.copyWith(
      scaffoldBackgroundColor: palette.ground,
      colorScheme: scheme,
      splashColor: palette.accent.withValues(alpha: 0.08),
      highlightColor: palette.accent.withValues(alpha: 0.06),
      textTheme: base.textTheme.apply(
        bodyColor: palette.text,
        displayColor: palette.text,
      ),
      dividerColor: palette.line,
      // Placeholders must never be mistakable for text you typed: dimmer than
      // body text, and never inheriting the field's weight/size.
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: palette.faint,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.italic,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.ground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: palette.text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: palette.line),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
