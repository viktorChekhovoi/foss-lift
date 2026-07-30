import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    final active = ref.watch(activePaletteProvider);
    final db = ref.read(databaseProvider);
    final mine = ref.watch(customThemesProvider).value ?? const <AppPalette>[];
    // The *resolved* palette's id, not the stored one: with nothing chosen the
    // picker marks whichever default the system brightness put on screen, and
    // a choice that no longer resolves marks what is actually being painted.
    // Either way the radio agrees with what you can see.
    final selectedId = active.id;

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
            Text('YOUR THEMES',
                style: kMono.copyWith(
                    fontSize: 11, letterSpacing: 1.2, color: AppColors.faint)),
            const SizedBox(height: 10),
            // Each of the user's own: a tap selects it, the pencil opens it —
            // which is where its name, its colours and its bin all live.
            for (final palette in mine) ...[
              _ThemeOption(
                palette: palette,
                selected: selectedId == palette.id,
                onTap: () => db.setThemePreset(palette.id),
                onEdit: () => context.push(
                    '/settings/theme/custom/${customThemeRowId(palette.id)}'),
              ),
              const SizedBox(height: 10),
            ],
            _NewThemeRow(onTap: () => context.push('/settings/theme/custom')),
            // Only your own themes are shareable. The presets ship with every
            // copy of the app, so sending someone a code for one is sending
            // them something they already have.
            if (customThemeRowId(selectedId) != null) ...[
              const SizedBox(height: 26),
              shareSectionLabel('SHARE THIS THEME'),
              const SizedBox(height: 10),
              shareActionRow([
                (Icons.qr_code_2, 'Show QR', () => _showQr(context, active)),
                (Icons.ios_share, 'Send code', () => _shareCode(active)),
              ]),
            ],
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
          ],
        ),
      ),
    );
  }
}

/// Starts a new theme from [from], which is whatever is on screen — you tweak
/// from something that already looks right rather than from black.
///
/// It carries the bare `custom` id until it is saved and gets a row of its own,
/// and no accessibility claim: the shipped high-contrast palettes are checked
/// against WCAG, and a copy the user is free to recolour has not been.
AppPalette _seedCustom(AppPalette from, String name) =>
    from.copyWith(id: kCustomThemeId, name: name, accessible: false);

/// The name a new theme opens with. Numbered from the second one on, so a
/// picker full of "My theme" is something you have to have chosen.
String _nextThemeName(List<AppPalette> existing) =>
    existing.isEmpty ? 'My theme' : 'My theme ${existing.length + 1}';

/// The row that starts a new theme. Shaped like a theme option so the list
/// reads as one column, but with nothing to select — a plus, and the words.
class _NewThemeRow extends StatelessWidget {
  const _NewThemeRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 20, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text('New theme',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

/// Hands the theme code to the system share sheet — Quick Share, a chat app,
/// the clipboard. Nothing is uploaded: the code *is* the theme.
///
/// The bare `FLT1.…` code, not a `fosslift://` link: a chat app does not linkify
/// a custom scheme, so a link arrived as unclickable text that had to be pasted
/// anyway, carrying a prefix the reader then strips. The QR still holds the
/// link, where a camera can act on it.
Future<void> _shareCode(AppPalette palette) async {
  await SharePlus.instance.share(
    ShareParams(
      text: ThemeCode.encode(palette),
      subject: 'Foss Lift theme: ${palette.name}',
    ),
  );
}

/// Prompts for a pasted code or link and hands it to the import screen, which
/// is the only thing allowed to apply a theme.
Future<void> _paste(BuildContext context) async {
  final text = await promptForCode(context,
      title: 'Paste a theme', hint: 'FLT1.… or a fosslift:// link');
  if (text == null || !context.mounted) return;
  context.push('/settings/theme/import?code=${Uri.encodeQueryComponent(text)}');
}

/// A selectable theme row: a strip of its key colours, its name, and a radio.
/// An optional pencil edits it (used by the custom row).
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.palette,
    required this.selected,
    required this.onTap,
    this.onEdit,
  });
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;
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
                child: Text(palette.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              if (palette.accessible)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _AaaBadge(explainOnTap: selected),
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

/// The `AAA` mark on a row whose palette was designed and checked against WCAG.
///
/// A long press always explains it, as any tooltip does. A *tap* explains it too
/// — but only on the row already selected, where a tap has nothing else to mean.
/// On an unselected row the tap has to go on selecting the theme, so this stands
/// aside and lets it through: three characters of jargon are worth a tooltip,
/// not worth costing someone the tap they were actually making.
class _AaaBadge extends StatefulWidget {
  const _AaaBadge({required this.explainOnTap});
  final bool explainOnTap;

  @override
  State<_AaaBadge> createState() => _AaaBadgeState();
}

class _AaaBadgeState extends State<_AaaBadge> {
  final _tooltip = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.explainOnTap
          ? () => _tooltip.currentState?.ensureTooltipVisible()
          : null,
      child: Tooltip(
        key: _tooltip,
        message: 'Meets WCAG AAA contrast',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
  // `gold` is the came-up-short marker everywhere it is painted — a missed
  // goal, a backed-off weight, a downward delta. It used to be labelled
  // "Personal record" here, which named the opposite of what it does.
  (label: 'Completed', get: _gGood, set: _sGood),
  (label: 'Missed goal', get: _gGold, set: _sGold),
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

/// Name a theme, edit each colour role, and save it as the active one.
///
/// With no [themeId] this builds a new theme, starting from whatever is active
/// so you tweak from something that already looks right rather than from black.
/// With one it edits that theme in place — and is the only place it can be
/// renamed or deleted, because those belong with the thing itself rather than
/// scattered across the row that lists it.
class CustomThemeEditorScreen extends ConsumerStatefulWidget {
  const CustomThemeEditorScreen({super.key, this.themeId});

  /// The `CustomThemes` row being edited, or null to build a new one.
  final int? themeId;

  @override
  ConsumerState<CustomThemeEditorScreen> createState() =>
      _CustomThemeEditorScreenState();
}

class _CustomThemeEditorScreenState
    extends ConsumerState<CustomThemeEditorScreen> {
  AppPalette? _draft;
  TextEditingController? _name;

  @override
  void dispose() {
    _name?.dispose();
    super.dispose();
  }

  /// The theme being edited, if it still exists. Read from the live list rather
  /// than fetched once, so deleting it from under this screen is not a crash.
  AppPalette? _stored(List<AppPalette> mine) {
    final id = widget.themeId;
    if (id == null) return null;
    final wanted = customThemeId(id);
    for (final p in mine) {
      if (p.id == wanted) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(customThemesProvider).value ?? const <AppPalette>[];
    final active = ref.watch(activePaletteProvider);
    // Seeded once: after that the draft is the truth, so a rebuild cannot
    // undo an edit.
    final draft = _draft ??=
        _stored(mine) ?? _seedCustom(active, _nextThemeName(mine));
    final nameField = _name ??= TextEditingController(text: draft.name);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.themeId == null ? 'New theme' : 'Edit theme'),
        actions: [
          if (widget.themeId != null)
            IconButton(
              onPressed: () => _confirmDelete(widget.themeId!, draft.name),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
            ),
          TextButton(
            onPressed: () => _save(draft),
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _NameField(
              controller: nameField,
              onChanged: (text) => setState(() => _draft = draft.copyWith(
                  name: text.trim().isEmpty ? draft.name : text.trim())),
            ),
            const SizedBox(height: 16),
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

  /// Writes the draft: a new row the first time, the same row afterwards.
  /// Either way the theme ends up selected — you have been looking at the
  /// preview, and saving is a request to see it for real.
  Future<void> _save(AppPalette draft) async {
    final db = ref.read(databaseProvider);
    final id = widget.themeId;
    if (id == null) {
      await db.addCustomTheme(draft.toJson());
    } else {
      await db.updateCustomTheme(id, draft.toJson());
    }
    if (mounted) context.pop();
  }

  /// Deletes after asking. Losing a palette somebody spent an evening on to a
  /// mis-tap is exactly the sort of thing a confirmation is for.
  Future<void> _confirmDelete(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(databaseProvider).deleteCustomTheme(id);
    if (mounted) context.pop();
  }
}

/// The theme's name. Blank does not take, so backspacing through one cannot
/// leave a nameless theme in the picker.
class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: 'Name',
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.line),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

/// A role row in the editor: swatch, label, current hex, tap to change.
///
/// A long press copies the hex. The row's tap already belongs to the picker, so
/// the hex cannot have a tap of its own — and long-press-to-copy is the gesture
/// this app already uses for the one other string worth lifting off a screen,
/// the demo link on an exercise.
class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.label,
    required this.color,
    required this.onPick,
  });
  final String label;
  final Color color;
  final VoidCallback onPick;

  Future<void> _copy(BuildContext context) async {
    final hex = '#${_hexOf(color)}';
    await Clipboard.setData(ClipboardData(text: hex));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Copied $hex')));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPick,
        onLongPress: () => _copy(context),
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
/// One notation: **RGB, with a hex field**. Three channels and six hex digits
/// are how every colour a palette is built from is written down — off a brand
/// guide, out of the Solarized spec, from a screenshot — and the hex field is
/// what a colour can be copied and pasted as, which is how a family of related
/// surfaces gets built without retyping.
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.title, required this.initial});
  final String title;
  final Color initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  /// The colour itself. The sliders and the hex field are both views onto this.
  late Color _color;

  late final TextEditingController _hex;

  @override
  void initState() {
    super.initState();
    _color = widget.initial;
    _hex = TextEditingController(text: '#${_hexOf(_color)}');
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  /// Adopts [c] as the colour. [syncField] is false while the user is typing in
  /// the hex field, which must not have its own text rewritten under the caret.
  void _adopt(Color c, {bool syncField = true}) {
    setState(() {
      _color = c;
      if (syncField) _hex.text = '#${_hexOf(c)}';
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
                _hexAction(
                  icon: Icons.copy_rounded,
                  tooltip: 'Copy hex',
                  onTap: _copyHex,
                ),
                _hexAction(
                  icon: Icons.content_paste_rounded,
                  tooltip: 'Paste hex',
                  onTap: _pasteHex,
                ),
              ],
            ),
            const SizedBox(height: 4),
            ..._rgbChannels(),
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

  /// Puts this colour on the clipboard as `#RRGGBB`.
  ///
  /// The roles are families — `surface`/`surface2`/`surface3` are one hue at
  /// three lightnesses — so building one by hand starts from the value of the
  /// last. Retyping six hex digits to do that is the sort of thing people stop
  /// bothering with, and then the family drifts.
  Future<void> _copyHex() async {
    final hex = '#${_hexOf(_color)}';
    await Clipboard.setData(ClipboardData(text: hex));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Copied $hex')));
  }

  /// Takes a colour off the clipboard, in any form the field itself accepts.
  ///
  /// Junk leaves the colour alone, exactly as typing junk does — [parseHex]
  /// returning null is the whole of that rule, and it is the same rule either
  /// way in.
  Future<void> _pasteHex() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final parsed = parseHex(data?.text ?? '');
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No colour on the clipboard.')),
      );
      return;
    }
    _adopt(parsed);
  }

  Widget _hexAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: AppColors.muted),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
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
