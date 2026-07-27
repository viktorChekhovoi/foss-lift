import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../theme/theme_code.dart';
import '../widgets/share_widgets.dart';
import '../widgets/theme_preview.dart';

/// Pick a colour theme: a shipped preset or your own, with import/export.
///
/// Selecting a theme writes it to the settings row; the app root watches the
/// resolved palette and repaints every screen. A routine's own accent colour is
/// parsed straight from its `colorHex` and so still shows through, whatever is
/// chosen here.
class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(themeSettingProvider).value;
    final active = ref.watch(activePaletteProvider);
    final db = ref.read(databaseProvider);
    final customJson = setting?.customJson;
    final custom = customJson == null ? null : AppPalette.tryParse(customJson);
    final selectedId = setting?.presetId ?? kDefaultPalette.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Colour theme')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            // Presets grouped by brightness so light and dark are easy to
            // scan. Each group ends with its high-contrast option, which the
            // row badges — picking legibility should never also mean giving up
            // the brightness you prefer.
            for (final group in const [
              ('DARK', Brightness.dark),
              ('LIGHT', Brightness.light),
            ]) ...[
              Text(group.$1,
                  style: kMono.copyWith(
                      fontSize: 11, letterSpacing: 1.2, color: AppColors.faint)),
              const SizedBox(height: 10),
              for (final preset
                  in kThemePresets.where((p) => p.brightness == group.$2)) ...[
                _ThemeOption(
                  palette: preset,
                  selected: selectedId == preset.id,
                  onTap: () => db.setThemePreset(preset.id),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 10),
            ],
            Text('YOUR THEME',
                style: kMono.copyWith(
                    fontSize: 11, letterSpacing: 1.2, color: AppColors.faint)),
            const SizedBox(height: 10),
            _ThemeOption(
              // Through _seedCustom either way: whatever is stored, the row
              // that can be recoloured never shows an accessibility claim.
              palette: _seedCustom(custom ?? active),
              label: custom == null ? 'Build your own' : 'Custom',
              selected: selectedId == kCustomThemeId,
              // With no custom theme yet, tapping goes straight to the editor to
              // build one; once it exists a tap re-selects it and the pencil
              // edits it.
              onTap: custom == null
                  ? () => context.push('/settings/theme/custom')
                  : () => db.setThemePreset(kCustomThemeId),
              onEdit: () => context.push('/settings/theme/custom'),
            ),
            const SizedBox(height: 26),
            shareSectionLabel('SHARE THIS THEME'),
            const SizedBox(height: 10),
            shareActionRow([
              (Icons.qr_code_2, 'Show QR', () => _showQr(context, active)),
              (Icons.ios_share, 'Send link', () => _shareLink(context, active)),
            ]),
            const SizedBox(height: 10),
            shareActionRow([
              (Icons.content_copy, 'Copy code', () => _copyCode(context, active)),
              (Icons.save_alt, 'Save file', () => _saveFile(context, active)),
            ]),
            const SizedBox(height: 22),
            shareSectionLabel('ADD A THEME'),
            const SizedBox(height: 10),
            shareActionRow([
              (
                Icons.qr_code_scanner,
                'Scan QR',
                () => context.push('/scan?for=theme')
              ),
              (Icons.content_paste, 'Paste code', () => _paste(context)),
            ]),
            const SizedBox(height: 16),
            Text(
              'A theme code is a short line of text like FLT1.AA8… — the whole '
              'palette, small enough to paste into a message or hold in a QR '
              'code. Anything you scan or paste is shown to you first; nothing '
              'changes until you say so. None of this touches the network.',
              style:
                  TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Re-labels [from] as the user's own theme: the custom slug, the custom name,
/// and no accessibility claim. The claim is dropped deliberately — the shipped
/// high-contrast palettes are checked against WCAG, and a copy the user is
/// free to recolour has not been.
AppPalette _seedCustom(AppPalette from) =>
    from.copyWith(id: kCustomThemeId, name: 'Custom', accessible: false);

/// Shows [palette] as a QR someone else can point a phone at.
Future<void> _showQr(BuildContext context, AppPalette palette) {
  return showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(palette.name),
      content: ShareQr(
        data: ThemeCode.link(palette),
        caption: 'Point another phone at this. Foss Lift will ask before '
            'changing anything.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

/// Hands the theme link to the system share sheet — Quick Share, a chat app,
/// wherever. Nothing is uploaded: the link *is* the theme.
Future<void> _shareLink(BuildContext context, AppPalette palette) async {
  final link = ThemeCode.link(palette);
  await SharePlus.instance.share(
    ShareParams(text: link, subject: 'Foss Lift theme: ${palette.name}'),
  );
}

/// Copies the bare code. Kept separate from the link because chat apps do not
/// turn a `fosslift://` URL into something tappable, so the code is often the
/// more useful thing to paste.
Future<void> _copyCode(BuildContext context, AppPalette palette) async {
  await Clipboard.setData(ClipboardData(text: ThemeCode.encode(palette)));
  if (context.mounted) saySnack(context, 'Theme code copied');
}

/// Writes the palette as JSON next to the app's documents. The long-standing
/// file path, kept for backups — the code is for sharing, a file is for keeping.
Future<void> _saveFile(BuildContext context, AppPalette palette) async {
  final pretty = const JsonEncoder.withIndent('  ').convert(palette.toMap());
  String? path;
  try {
    final dir = await getApplicationDocumentsDirectory();
    final slug = palette.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final file = File(p.join(dir.path, 'foss_lift_theme_$slug.json'));
    await file.writeAsString(pretty);
    path = file.path;
  } catch (_) {
    // A filesystem hiccup should report itself, not throw into the button.
  }
  if (!context.mounted) return;
  saySnack(context,
      path == null ? "Couldn't save the file" : 'Saved ${p.basename(path)}');
}

/// Prompts for a pasted code, link or JSON blob and hands it to the import
/// screen, which is the only thing allowed to apply a theme.
Future<void> _paste(BuildContext context) async {
  final text = await promptForCode(context,
      title: 'Paste a theme', hint: 'FLT1.… or a fosslift:// link');
  if (text == null || !context.mounted) return;

  // Themes exported as a file before codes existed are still JSON. Accept
  // either without making the user say which they have.
  final asJson = AppPalette.tryParse(text);
  final code = asJson != null ? ThemeCode.encode(asJson) : text;
  context.push('/settings/theme/import?code=${Uri.encodeQueryComponent(code)}');
}

/// A selectable theme row: a strip of its key colours, its name, and a radio.
/// An optional pencil edits it (used by the custom row).
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.palette,
    required this.selected,
    required this.onTap,
    this.label,
    this.onEdit,
  });
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;
  final String? label;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.10)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _Swatches(palette: palette),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label ?? palette.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              if (palette.accessible)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: 'Meets WCAG AAA contrast',
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Text('AAA',
                          style: kMono.copyWith(
                              fontSize: 10,
                              letterSpacing: 0.8,
                              color: AppColors.muted)),
                    ),
                  ),
                ),
              if (onEdit != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.muted),
                ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 22,
                color: selected ? AppColors.accent : AppColors.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A little row of colour chips previewing a palette's ground and accents.
class _Swatches extends StatelessWidget {
  const _Swatches({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final colors = [
      palette.ground,
      palette.surface2,
      palette.accent,
      palette.good,
      palette.gold,
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.ground,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in colors)
            Container(
              width: 12,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom theme editor
// ---------------------------------------------------------------------------

/// One editable role: its label and how to read/write it on a palette.
typedef _Role = ({
  String label,
  Color Function(AppPalette) get,
  AppPalette Function(AppPalette, Color) set,
});

const List<_Role> _roles = [
  (label: 'Background', get: _gGround, set: _sGround),
  (label: 'Surface', get: _gSurface, set: _sSurface),
  (label: 'Raised surface', get: _gSurface2, set: _sSurface2),
  (label: 'Highest surface', get: _gSurface3, set: _sSurface3),
  (label: 'Lines & borders', get: _gLine, set: _sLine),
  (label: 'Text', get: _gText, set: _sText),
  (label: 'Muted text', get: _gMuted, set: _sMuted),
  (label: 'Faint text', get: _gFaint, set: _sFaint),
  (label: 'Accent', get: _gAccent, set: _sAccent),
  (label: 'Accent pressed', get: _gAccentPress, set: _sAccentPress),
  (label: 'Completed', get: _gGood, set: _sGood),
  (label: 'Personal record', get: _gGold, set: _sGold),
];

Color _gGround(AppPalette p) => p.ground;
Color _gSurface(AppPalette p) => p.surface;
Color _gSurface2(AppPalette p) => p.surface2;
Color _gSurface3(AppPalette p) => p.surface3;
Color _gLine(AppPalette p) => p.line;
Color _gText(AppPalette p) => p.text;
Color _gMuted(AppPalette p) => p.muted;
Color _gFaint(AppPalette p) => p.faint;
Color _gAccent(AppPalette p) => p.accent;
Color _gAccentPress(AppPalette p) => p.accentPress;
Color _gGood(AppPalette p) => p.good;
Color _gGold(AppPalette p) => p.gold;

AppPalette _sGround(AppPalette p, Color c) => p.copyWith(ground: c);
AppPalette _sSurface(AppPalette p, Color c) => p.copyWith(surface: c);
AppPalette _sSurface2(AppPalette p, Color c) => p.copyWith(surface2: c);
AppPalette _sSurface3(AppPalette p, Color c) => p.copyWith(surface3: c);
AppPalette _sLine(AppPalette p, Color c) => p.copyWith(line: c);
AppPalette _sText(AppPalette p, Color c) => p.copyWith(text: c);
AppPalette _sMuted(AppPalette p, Color c) => p.copyWith(muted: c);
AppPalette _sFaint(AppPalette p, Color c) => p.copyWith(faint: c);
AppPalette _sAccent(AppPalette p, Color c) => p.copyWith(accent: c);
AppPalette _sAccentPress(AppPalette p, Color c) => p.copyWith(accentPress: c);
AppPalette _sGood(AppPalette p, Color c) => p.copyWith(good: c);
AppPalette _sGold(AppPalette p, Color c) => p.copyWith(gold: c);

/// Edit each colour role and save the result as the active custom theme.
///
/// The draft starts from the existing custom palette, or from whatever is
/// active, so you always tweak from something that already looks right rather
/// than from black.
class CustomThemeEditorScreen extends ConsumerStatefulWidget {
  const CustomThemeEditorScreen({super.key});

  @override
  ConsumerState<CustomThemeEditorScreen> createState() =>
      _CustomThemeEditorScreenState();
}

class _CustomThemeEditorScreenState
    extends ConsumerState<CustomThemeEditorScreen> {
  AppPalette? _draft;

  @override
  Widget build(BuildContext context) {
    final setting = ref.watch(themeSettingProvider).value;
    final active = ref.watch(activePaletteProvider);
    // Seed the draft once, from the stored custom theme if there is one.
    final existing = setting?.customJson == null
        ? null
        : AppPalette.tryParse(setting!.customJson!);
    final draft = _draft ??= _seedCustom(existing ?? active);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom theme'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(databaseProvider).setCustomTheme(draft.toJson());
              if (context.mounted) context.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            ThemePreview(palette: draft),
            const SizedBox(height: 20),
            for (final role in _roles) ...[
              _RoleRow(
                label: role.label,
                color: role.get(draft),
                onPick: () async {
                  final picked = await showDialog<Color>(
                    context: context,
                    builder: (_) => _ColorPickerDialog(
                      title: role.label,
                      initial: role.get(draft),
                    ),
                  );
                  if (picked != null) {
                    setState(() => _draft = role.set(draft, picked));
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// A role row in the editor: swatch, label, current hex, tap to change.
class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.label,
    required this.color,
    required this.onPick,
  });
  final String label;
  final Color color;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: AppColors.line),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Text('#${_hexOf(color)}',
                  style: kMono.copyWith(fontSize: 13, color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

String _hexOf(Color c) {
  int ch(double v) => (v * 255).round().clamp(0, 255);
  final rgb = (ch(c.r) << 16) | (ch(c.g) << 8) | ch(c.b);
  return rgb.toRadixString(16).toUpperCase().padLeft(6, '0');
}

/// Reads a colour written as `#RGB`, `#RRGGBB` or bare `RRGGBB`.
///
/// Null for anything else, which is what keeps a half-typed or mistyped hex
/// from repainting a role: the caller holds its colour until this returns one.
Color? parseHex(String input) {
  var s = input.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 3) {
    // CSS shorthand: each digit doubles, so #ABC is #AABBCC.
    s = s.split('').map((d) => '$d$d').join();
  }
  if (s.length != 6 || !RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(s)) return null;
  return Color(0xFF000000 | int.parse(s, radix: 16));
}

/// A self-contained colour picker — no third-party dependency.
///
/// It speaks two ways of writing the same colour, because they are for two
/// different jobs. **RGB and hex** are for *transcribing* a colour that already
/// exists: off a brand guide, out of the Solarized spec, from a screenshot.
/// **HSL** is for *choosing* one, and the app leans on it twice over —
///
///  * the roles are families, not twelve loose colours. `surface`/`surface2`/
///    `surface3` are one hue at three lightnesses, `accent`/`accentPress` one
///    hue at two. In RGB that is arithmetic; in HSL it is one slider.
///  * the preview warns when a palette falls under 4.5:1, and contrast is a
///    function of lightness. Dragging L answers that warning without throwing
///    away the colour that raised it. In RGB it takes three sliders moved in
///    concert and the hue drifts while you do it.
///
/// Hue and saturation are held in state rather than recomputed from the colour,
/// because a grey has no hue to recover: `HSLColor.fromColor` reports 0 for
/// everything achromatic, so deriving them would snap the slider to red the
/// moment saturation reached zero and lose the colour the user was working in.
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.title, required this.initial});
  final String title;
  final Color initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  /// The colour itself. Both modes are views onto this; switching between them
  /// never recomputes it, so a round trip cannot drift.
  late Color _color;

  /// Retained hue and saturation — see the note on the class.
  late double _hue;
  late double _sat;

  bool _asHsl = false;
  late final TextEditingController _hex;

  @override
  void initState() {
    super.initState();
    _color = widget.initial;
    final hsl = HSLColor.fromColor(_color);
    _hue = hsl.hue;
    _sat = hsl.saturation;
    _hex = TextEditingController(text: '#${_hexOf(_color)}');
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  double get _light => HSLColor.fromColor(_color).lightness;

  /// Adopts [c] as the colour, refreshing the retained hue and saturation from
  /// it — except when [c] is achromatic and has none to give.
  void _adopt(Color c, {bool syncField = true}) {
    final hsl = HSLColor.fromColor(c);
    setState(() {
      _color = c;
      if (hsl.saturation > 0.001) {
        _hue = hsl.hue;
        _sat = hsl.saturation;
      } else {
        _sat = 0;
      }
      if (syncField) _hex.text = '#${_hexOf(c)}';
    });
  }

  /// Rebuilds the colour from the HSL controls, which own hue and saturation
  /// outright while this mode is showing.
  void _fromHsl({double? h, double? s, double? l}) {
    _hue = h ?? _hue;
    _sat = s ?? _sat;
    setState(() {
      _color = HSLColor.fromAHSL(1, _hue, _sat, l ?? _light).toColor();
      _hex.text = '#${_hexOf(_color)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _hexField()),
                const SizedBox(width: 10),
                _modeToggle(),
              ],
            ),
            const SizedBox(height: 4),
            if (_asHsl) ..._hslChannels() else ..._rgbChannels(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _color),
          child: const Text('Use'),
        ),
      ],
    );
  }

  Widget _hexField() {
    return TextField(
      controller: _hex,
      style: kMono.copyWith(fontSize: 14, color: AppColors.text),
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.line),
        ),
      ),
      // Typed as it goes: a hex that does not read yet simply does not move
      // the colour, so backspacing through one is not destructive.
      onChanged: (text) {
        final parsed = parseHex(text);
        if (parsed != null) _adopt(parsed, syncField: false);
      },
    );
  }

  /// RGB ⇄ HSL. Both describe the colour already on screen, so switching is a
  /// change of notation and never of value.
  Widget _modeToggle() {
    Widget half(String label, bool hsl) {
      final on = _asHsl == hsl;
      return GestureDetector(
        onTap: on ? null : () => setState(() => _asHsl = hsl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          color: on ? AppColors.accent : Colors.transparent,
          child: Text(
            label,
            style: kMono.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: on ? AppColors.onAccent : AppColors.muted,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: AppColors.line)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [half('RGB', false), half('HSL', true)],
        ),
      ),
    );
  }

  List<Widget> _rgbChannels() {
    final r = (_color.r * 255).roundToDouble();
    final g = (_color.g * 255).roundToDouble();
    final b = (_color.b * 255).roundToDouble();
    Color at(int? nr, int? ng, int? nb) => Color.fromARGB(
        255, nr ?? r.round(), ng ?? g.round(), nb ?? b.round());
    return [
      _channel(
        label: 'R',
        value: r,
        max: 255,
        gradient: [at(0, null, null), at(255, null, null)],
        onChanged: (v) => _adopt(at(v.round(), null, null)),
      ),
      _channel(
        label: 'G',
        value: g,
        max: 255,
        gradient: [at(null, 0, null), at(null, 255, null)],
        onChanged: (v) => _adopt(at(null, v.round(), null)),
      ),
      _channel(
        label: 'B',
        value: b,
        max: 255,
        gradient: [at(null, null, 0), at(null, null, 255)],
        onChanged: (v) => _adopt(at(null, null, v.round())),
      ),
    ];
  }

  List<Widget> _hslChannels() {
    Color hsl(double h, double s, double l) =>
        HSLColor.fromAHSL(1, h, s, l).toColor();
    return [
      _channel(
        label: 'H',
        value: _hue,
        max: 360,
        gradient: [
          for (var d = 0; d <= 360; d += 60) hsl(d.toDouble(), _sat, _light),
        ],
        onChanged: (v) => _fromHsl(h: v),
      ),
      _channel(
        label: 'S',
        value: _sat * 100,
        max: 100,
        gradient: [hsl(_hue, 0, _light), hsl(_hue, 1, _light)],
        onChanged: (v) => _fromHsl(s: v / 100),
      ),
      _channel(
        label: 'L',
        value: _light * 100,
        max: 100,
        gradient: [
          hsl(_hue, _sat, 0),
          hsl(_hue, _sat, 0.5),
          hsl(_hue, _sat, 1),
        ],
        onChanged: (v) => _fromHsl(l: v / 100),
      ),
    ];
  }

  /// One channel: a track painted with the colours it actually traverses, so
  /// the slider previews its own effect instead of asking you to imagine it.
  Widget _channel({
    required String label,
    required double value,
    required double max,
    required List<Color> gradient,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(label,
              style: kMono.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
        Expanded(
          child: SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradient),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppColors.line),
                    ),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 10,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.white,
                    overlayColor: AppColors.accent.withValues(alpha: 0.15),
                  ),
                  child: Slider(
                    value: value.clamp(0, max),
                    max: max,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text('${value.round()}',
              textAlign: TextAlign.right,
              style: kMono.copyWith(color: AppColors.muted, fontSize: 13)),
        ),
      ],
    );
  }
}
