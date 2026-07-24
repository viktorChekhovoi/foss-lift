import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

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
            Text('PRESETS',
                style: kMono.copyWith(
                    fontSize: 11, letterSpacing: 1.2, color: AppColors.faint)),
            const SizedBox(height: 10),
            for (final preset in kThemePresets) ...[
              _ThemeOption(
                palette: preset,
                selected: selectedId == preset.id,
                onTap: () => db.setThemePreset(preset.id),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 18),
            Text('YOUR THEME',
                style: kMono.copyWith(
                    fontSize: 11, letterSpacing: 1.2, color: AppColors.faint)),
            const SizedBox(height: 10),
            _ThemeOption(
              palette: custom ??
                  active.copyWith(id: kCustomThemeId, name: 'Custom'),
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
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _export(context, active),
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text('Export'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _import(context, db),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Import'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Export copies the current theme to your clipboard and saves it as '
              'a .json file you can back up or share. Import reads one back — '
              'paste the JSON to load it as your custom theme. Everything stays '
              'on your device.',
              style: TextStyle(
                  color: AppColors.muted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Writes [palette] to a file, copies its JSON to the clipboard, and says so.
Future<void> _export(BuildContext context, AppPalette palette) async {
  final pretty = const JsonEncoder.withIndent('  ').convert(palette.toMap());
  await Clipboard.setData(ClipboardData(text: pretty));
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
    // A file is a nicety; the clipboard copy is the thing that matters and has
    // already happened, so a filesystem hiccup should not fail the export.
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(path == null
        ? 'Theme copied to clipboard'
        : 'Theme copied to clipboard · saved to ${p.basename(path)}'),
  ));
}

/// Prompts for pasted theme JSON and, if it parses, stores it as the custom
/// theme and makes it active.
Future<void> _import(BuildContext context, AppDatabase db) async {
  final controller = TextEditingController();
  final json = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Import theme'),
      content: TextField(
        controller: controller,
        maxLines: 6,
        autofocus: true,
        style: kMono.copyWith(fontSize: 12, color: AppColors.text),
        decoration: const InputDecoration(
          hintText: 'Paste theme JSON here',
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
          child: const Text('Import'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (json == null || json.trim().isEmpty) return;
  final parsed = AppPalette.tryParse(json);
  if (!context.mounted) return;
  if (parsed == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('That does not look like a theme'),
    ));
    return;
  }
  await db.setCustomTheme(parsed.toJson());
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content: Text('Theme imported'),
  ));
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
    final draft = _draft ??=
        (existing ?? active).copyWith(id: kCustomThemeId, name: 'Custom');

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
            _Preview(palette: draft),
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

/// A miniature of the app painted in the draft palette, so edits are seen in
/// context rather than as isolated chips.
class _Preview extends StatelessWidget {
  const _Preview({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.ground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bench Press',
                    style: TextStyle(
                        color: palette.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('4 × 6–8 · working set',
                    style: kMono.copyWith(
                        color: palette.muted, fontSize: 12)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('80 kg',
                        style: kMono.copyWith(
                            color: palette.good,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 12),
                    Text('PR 92.5',
                        style: kMono.copyWith(
                            color: palette.gold, fontSize: 13)),
                    const Spacer(),
                    Text('rest 90s',
                        style: kMono.copyWith(
                            color: palette.faint, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text('Start workout',
                  style: TextStyle(
                      color: palette.onAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
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
