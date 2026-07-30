import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme_id.dart';

export 'theme_id.dart';

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
    this.accessible = false,
  });

  /// A stable identifier: a preset slug (e.g. `ignition`) or [kCustomThemeId]
  /// for a palette the user built themselves.
  final String id;

  /// A human label shown in the picker.
  final String name;

  /// Whether this palette is one of the deliberately high-contrast ones. It is
  /// declared rather than measured so a theme is only ever presented as
  /// accessible if it was designed and checked to be — see the contrast
  /// assertions in the feature tests. It travels through [toMap]/[fromMap] so a
  /// shared theme arrives still labelled.
  final bool accessible;

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
  /// (the dark themes' oranges and blues) takes a very dark tint of itself, so
  /// the button reads brown-black or navy-black; a dark accent (the light
  /// themes' saturated colours) takes white.
  Color get onAccent => _foregroundOn(accent);

  /// The same, for the "good"/completed colour.
  Color get onGood => _foregroundOn(good);

  /// Whichever of the two candidate foregrounds actually reads better on [bg]:
  /// a near-black tint of the colour itself, or white. Picking by measured
  /// contrast rather than a luminance cut-off matters for mid-tone colours,
  /// where a fixed threshold lands on the wrong side and leaves a button label
  /// below the 4.5:1 floor — and it means a custom or imported accent gets a
  /// readable label wherever on the scale it sits.
  static Color _foregroundOn(Color bg) {
    final tint = Color.lerp(bg, Colors.black, 0.86)!;
    return contrastRatio(tint, bg) >= contrastRatio(Colors.white, bg)
        ? tint
        : Colors.white;
  }

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
    bool? accessible,
  }) {
    return AppPalette(
      id: id ?? this.id,
      name: name ?? this.name,
      accessible: accessible ?? this.accessible,
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
        'accessible': accessible,
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
      accessible: map['accessible'] == true,
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
      other.accessible == accessible &&
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

/// The WCAG contrast ratio between two opaque colours: 1.0 when they are
/// identical, 21.0 for black against white. 4.5 is the AA floor for body text,
/// 7.0 the AAA floor, and 3.0 the floor for borders and other non-text UI.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// How far apart two colours look, as CIE76 ΔE over CIELAB.
///
/// [contrastRatio] answers "can this be read against that", which is a question
/// about lightness alone. This answers the different question the done/short
/// markers ask: **can these two be told apart from each other.** Solarized's
/// green and yellow are the case that needs it — they sit at the same
/// luminance, so their contrast ratio against each other is 1.00 and says
/// nothing at all, while their ΔE says plainly that they are close.
///
/// Rough reading: under 10 is a shade of the same colour, around 25 is
/// noticeably different, and [kMarkerDistance] is where two states of a signal
/// are unmistakable at a glance.
double colourDistance(Color a, Color b) {
  final (l1, a1, b1) = _lab(a);
  final (l2, a2, b2) = _lab(b);
  final dl = l1 - l2, da = a1 - a2, db = b1 - b2;
  return math.sqrt(dl * dl + da * da + db * db);
}

/// The ΔE the done and short markers must keep between them.
///
/// They are the fastest read on the workout board — a column of set rows tells
/// you how the session went before you read a number — so "noticeably
/// different" is not enough. Every shipped preset clears this, and the feature
/// tests hold it there.
const double kMarkerDistance = 45;

/// One colour in CIELAB (D65), the space ΔE is measured in.
(double, double, double) _lab(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final r = lin(c.r), g = lin(c.g), b = lin(c.b);
  // sRGB → XYZ, then normalised against the D65 white point.
  final x = (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047;
  final y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750;
  final z = (r * 0.0193339 + g * 0.1191920 + b * 0.9503041) / 1.08883;
  double f(double t) => t > 216 / 24389
      ? math.pow(t, 1 / 3).toDouble()
      : (841 / 108) * t + 4 / 29;
  final fx = f(x), fy = f(y), fz = f(z);
  return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
}

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

// --- Solarized -------------------------------------------------------------
// Ethan Schoonover's published palette (ethanschoonover.com/solarized), whose
// whole point is that the sixteen tones are fixed: someone choosing Solarized
// wants *that* Solarized, so the hues are used as specified rather than
// re-tuned to taste.
//
// Two deliberate departures, both about legibility. The body text uses the
// palette's *emphasized* tier (base1 on dark, base02 on light) rather than its
// designated body tier — Solarized's own body tones land at roughly 4.1:1 on
// their backgrounds, under the 4.5:1 floor every preset here has to clear, and
// a workout log read at arm's length mid-set is not prose on a laptop. The
// intermediate surfaces are blends between base03 and base02, since the
// palette defines only two background tones and the app paints four.

const Color _solBase03 = Color(0xFF002B36);
const Color _solBase02 = Color(0xFF073642);
const Color _solBase01 = Color(0xFF586E75);
const Color _solBase00 = Color(0xFF657B83);
const Color _solBase0 = Color(0xFF839496);
const Color _solBase1 = Color(0xFF93A1A1);
const Color _solBase2 = Color(0xFFEEE8D5);
const Color _solBase3 = Color(0xFFFDF6E3);
const Color _solBlue = Color(0xFF268BD2);

// The done/short markers are the third departure, and the largest. Solarized's
// green (#859900) and yellow (#B58900) sit at the *same* luminance — their
// contrast ratio against each other is 1.00 — and only 30 ΔE apart, which is
// fine for syntax highlighting where a token's meaning comes from its position
// as much as its colour, and useless for a binary did-you-hit-it signal read at
// a glance down a column. So the short marker takes Solarized's **orange**
// (#CB4B16) rather than its yellow, and both are moved along their own
// lightness ramp until they clear 4.5:1 on this palette's ground and card.
// Still Solarized's hues; not Solarized's exact tones.
const Color _solGreenDark = Color(0xFF9BB000);
const Color _solOrangeDark = Color(0xFFE58A3C);
const Color _solGreenLight = Color(0xFF4F6600);
const Color _solOrangeLight = Color(0xFF9C3B0D);

/// Solarized dark: base03 ground, base02 cards, blue accent.
const AppPalette _solarizedDark = AppPalette(
  id: 'solarized_dark',
  name: 'Solarized dark',
  ground: _solBase03,
  surface: _solBase02,
  surface2: Color(0xFF0D4250),
  surface3: Color(0xFF124E5E),
  line: Color(0xFF14505F),
  text: _solBase1,
  muted: _solBase0,
  faint: _solBase01,
  accent: _solBlue,
  accentPress: Color(0xFF1B6FA8),
  good: _solGreenDark,
  gold: _solOrangeDark,
);

/// Solarized light: base3 ground, base2 cards, the same blue accent.
const AppPalette _solarizedLight = AppPalette(
  id: 'solarized_light',
  name: 'Solarized light',
  ground: _solBase3,
  surface: _solBase2,
  surface2: Color(0xFFE6DFC8),
  surface3: Color(0xFFDCD4BA),
  line: _solBase1,
  text: _solBase02,
  muted: _solBase01,
  faint: _solBase00,
  accent: _solBlue,
  accentPress: Color(0xFF1F6FA8),
  good: _solGreenLight,
  gold: _solOrangeLight,
);

// --- Light presets ---------------------------------------------------------
// Pale grounds with dark text. Their accents are saturated and dark enough to
// read on white; `good`/`gold` stay a medium tone that works both as a coloured
// label and behind the markers the app draws on them. What a filled button's
// label ends up being is measured, not assumed — see [AppPalette.onAccent].

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
  good: Color(0xFF0E7A47),
  gold: Color(0xFF8A5A00),
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
  good: Color(0xFF0E7A47),
  gold: Color(0xFF7E5600),
);

// --- Accessibility ---------------------------------------------------------
// One high-contrast theme per brightness, so choosing legibility never also
// means choosing dark-on-light or light-on-dark. Both clear WCAG AAA (7:1) for
// body text and AA (4.5:1) for the muted text and every coloured marker, on
// both the ground and a card; borders clear the 3:1 non-text floor so structure
// is never lost. The feature tests assert all of that.

/// Maximum contrast, dark: pure black ground, pure white text, a
/// high-visibility yellow accent and vivid green/amber markers.
const AppPalette _highContrastDark = AppPalette(
  id: 'high_contrast',
  name: 'High contrast dark',
  accessible: true,
  ground: Color(0xFF000000),
  surface: Color(0xFF0A0A0A),
  surface2: Color(0xFF161616),
  surface3: Color(0xFF222222),
  line: Color(0xFF727272),
  text: Color(0xFFFFFFFF),
  muted: Color(0xFFD5D5D5),
  faint: Color(0xFFAEAEAE),
  accent: Color(0xFFFFD400),
  accentPress: Color(0xFFE6BE00),
  good: Color(0xFF00E676),
  gold: Color(0xFFFFAB00),
);

/// The mirror image: pure white ground, pure black text, and deep saturated
/// markers dark enough to hold 4.5:1 against the paper.
const AppPalette _highContrastLight = AppPalette(
  id: 'high_contrast_light',
  name: 'High contrast light',
  accessible: true,
  ground: Color(0xFFFFFFFF),
  surface: Color(0xFFFAFAFA),
  surface2: Color(0xFFF0F0F0),
  surface3: Color(0xFFE4E4E4),
  line: Color(0xFF6B6B6B),
  text: Color(0xFF000000),
  muted: Color(0xFF2E2E2E),
  faint: Color(0xFF4A4A4A),
  accent: Color(0xFF0038A8),
  accentPress: Color(0xFF002A80),
  good: Color(0xFF0F7A3D),
  gold: Color(0xFF8A5A00),
);

/// Every preset that ships with the app, as four dark/light pairs: two everyday
/// looks, Solarized, and the accessible option. Every look exists in both
/// brightnesses, so choosing one never forces the other on you.
///
/// The first is the default. Ordered dark then light, each brightness's
/// accessible option last in its group — the picker groups them by
/// [AppPalette.brightness] and renders them in this order.
const List<AppPalette> kThemePresets = [
  _ignition,
  _graphite,
  _solarizedDark,
  _highContrastDark,
  _daylight,
  _paper,
  _solarizedLight,
  _highContrastLight,
];

/// The shipped preset [id] names, or null if it names none — a `custom:<n>`
/// id, an unknown slug, or nothing at all.
AppPalette? presetById(String? id) {
  for (final preset in kThemePresets) {
    if (preset.id == id) return preset;
  }
  return null;
}

/// The fallback palette, used when a stored or imported theme cannot be
/// resolved at all. Not what an untouched install gets — see [defaultPaletteFor].
const AppPalette kDefaultPalette = _ignition;

/// What to paint with before anything has been chosen: the default look in the
/// brightness the phone itself asked for.
///
/// Following the system is the only defensible guess. A phone set to light and
/// an app that opens dark is not a preference being honoured, it is one being
/// overridden, and the person has to go and find the picker to undo it.
AppPalette defaultPaletteFor(Brightness system) =>
    system == Brightness.light ? _daylight : _ignition;

/// Resolves the persisted theme choice into the palette to paint with.
///
/// [presetId] is a preset slug, a `custom:<n>` id naming one of [customs], or
/// null. Null means nothing has been chosen, which follows [system]. Anything
/// unresolvable — an unknown slug, a `custom:<n>` whose theme has been deleted
/// — falls back rather than leaving the app unpainted.
///
/// [customs] are the user's own themes, already parsed and carrying their
/// stored ids (see [customThemeFromRow]).
AppPalette resolvePalette(
  String? presetId,
  List<AppPalette> customs, {
  Brightness system = Brightness.dark,
}) {
  for (final custom in customs) {
    if (custom.id == presetId) return custom;
  }
  return presetById(presetId) ?? defaultPaletteFor(system);
}

/// The palette held in a `CustomThemes` row, stamped with the id that names it.
///
/// Never accessible, whatever the JSON claims: the badge means a palette was
/// designed and checked against WCAG, and one the user can recolour has not
/// been. A row whose JSON will not parse yields null rather than a half-palette
/// of default colours wearing the user's name.
AppPalette? customThemeFromRow(int rowId, String json) =>
    AppPalette.tryParse(json)
        ?.copyWith(id: customThemeId(rowId), accessible: false);

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

  /// The measured label colour for anything painted on [accent] — mirrors
  /// [AppPalette.onAccent] so a widget filling a shape with the accent does not
  /// have to guess at, or re-derive, what reads on top of it.
  static Color onAccent = kDefaultPalette.onAccent;

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
    onAccent = p.onAccent;
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
