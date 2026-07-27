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
import '../widgets/theme_qr.dart';
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
              palette: custom ?? _seedCustom(active),
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
            _sectionLabel('SHARE THIS THEME'),
            const SizedBox(height: 10),
            _actionRow([
              (Icons.qr_code_2, 'Show QR', () => _showQr(context, active)),
              (Icons.ios_share, 'Send link', () => _shareLink(context, active)),
            ]),
            const SizedBox(height: 10),
            _actionRow([
              (Icons.content_copy, 'Copy code', () => _copyCode(context, active)),
              (Icons.save_alt, 'Save file', () => _saveFile(context, active)),
            ]),
            const SizedBox(height: 22),
            _sectionLabel('ADD A THEME'),
            const SizedBox(height: 10),
            _actionRow([
              (
                Icons.qr_code_scanner,
                'Scan QR',
                () => context.push('/settings/theme/scan')
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

/// A small all-caps section heading, matching the picker's group labels.
Widget _sectionLabel(String text) => Builder(
      builder: (_) => Text(text,
          style: kMono.copyWith(
              fontSize: 11, letterSpacing: 1.2, color: AppColors.faint)),
    );

/// A row of equal-width outlined actions. Two per row keeps the labels legible
/// at large font scales, where a four-across row would truncate.
Widget _actionRow(List<(IconData, String, VoidCallback)> actions) => Row(
      children: [
        for (final (i, action) in actions.indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: action.$3,
              icon: Icon(action.$1, size: 18),
              label: Text(action.$2, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ],
    );

void _say(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

/// Shows [palette] as a QR someone else can point a phone at.
Future<void> _showQr(BuildContext context, AppPalette palette) {
  return showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(palette.name),
      content: ThemeQr(palette: palette),
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
  if (context.mounted) _say(context, 'Theme code copied');
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
  _say(context,
      path == null ? "Couldn't save the file" : 'Saved ${p.basename(path)}');
}

/// Prompts for a pasted code, link or JSON blob and hands it to the import
/// screen, which is the only thing allowed to apply a theme.
Future<void> _paste(BuildContext context) async {
  final controller = TextEditingController();
  final pasted = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Paste a theme'),
      content: TextField(
        controller: controller,
        maxLines: 4,
        autofocus: true,
        style: kMono.copyWith(fontSize: 12, color: AppColors.text),
        decoration: const InputDecoration(
          hintText: 'FLT1.… or a fosslift:// link',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  controller.dispose();
  final text = pasted?.trim() ?? '';
  if (text.isEmpty || !context.mounted) return;

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

/// A self-contained RGB colour picker: three sliders and a live swatch, no
/// third-party dependency.
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.title, required this.initial});
  final String title;
  final Color initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double _r;
  late double _g;
  late double _b;

  @override
  void initState() {
    super.initState();
    _r = (widget.initial.r * 255).roundToDouble();
    _g = (widget.initial.g * 255).roundToDouble();
    _b = (widget.initial.b * 255).roundToDouble();
  }

  Color get _color =>
      Color.fromARGB(255, _r.round(), _g.round(), _b.round());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line),
            ),
            alignment: Alignment.center,
            child: Text('#${_hexOf(_color)}',
                style: kMono.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white)),
          ),
          const SizedBox(height: 8),
          _channel('R', _r, const Color(0xFFFF5D5D),
              (v) => setState(() => _r = v)),
          _channel('G', _g, const Color(0xFF3ED598),
              (v) => setState(() => _g = v)),
          _channel('B', _b, const Color(0xFF4C9AFF),
              (v) => setState(() => _b = v)),
        ],
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

  Widget _channel(
      String label, double value, Color tint, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(label,
              style: kMono.copyWith(
                  color: tint, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 255,
            activeColor: tint,
            onChanged: onChanged,
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
