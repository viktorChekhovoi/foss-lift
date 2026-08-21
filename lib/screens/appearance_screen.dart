import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../theme/theme_code.dart';
import '../util/locales.dart';
import '../util/seed_names.dart';
import '../util/text_scale.dart';
import '../widgets/builder_widgets.dart';
import '../widgets/share_widgets.dart';
import '../widgets/theme_preview.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final active = ref.watch(activePaletteProvider);
    final db = ref.read(databaseProvider);
    final mine = ref.watch(customThemesProvider).value ?? const <AppPalette>[];
    final selectedId = active.id;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileAppearance)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(l10n.settingsTextSize, style: sectionLabelStyle()),
            const SizedBox(height: 10),
            _ScaleChoices(
              chosen: ref.watch(textScaleProvider).value ?? 1.0,
              onSelect: db.setTextScale,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.settingsTextSizeNote,
              style:
                  TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            SettingRow(
              label: l10n.settingsLanguage,
              value: kLanguageNames[localeTag(ref.watch(activeLocaleProvider))]!,
              onTap: () => context.push(linkPath(context, '/settings/language')),
            ),
            const SizedBox(height: 28),
            for (final group in [
              (l10n.themeDarkGroup, Brightness.dark),
              (l10n.themeLightGroup, Brightness.light),
            ]) ...[
              Text(group.$1,
                  style: sectionLabelStyle()),
              const SizedBox(height: 10),
              for (final preset
                  in kThemePresets.where((p) => p.brightness == group.$2)) ...[
                _ThemeOption(
                  palette: preset,
                  label: themeDisplayName(l10n, preset),
                  selected: selectedId == preset.id,
                  onTap: () => db.setThemePreset(preset.id),
                  onEdit: () =>
                      context.push(
                          linkPath(context, '/settings/appearance/custom?from=${preset.id}')),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 10),
            ],
            Text(l10n.themeYourThemes,
                style: sectionLabelStyle()),
            const SizedBox(height: 10),
            for (final palette in mine) ...[
              _ThemeOption(
                palette: palette,
                label: palette.name,
                selected: selectedId == palette.id,
                onTap: () => db.setThemePreset(palette.id),
                onEdit: () => context.push(
                    linkPath(context, '/settings/appearance/custom/${customThemeRowId(palette.id)}')),
                onDuplicate: () => db.addCustomTheme(_seedCustom(palette,
                        _freeName(l10n.themeCopyName(palette.name), mine))
                    .toJson()),
              ),
              const SizedBox(height: 10),
            ],
            _NewThemeRow(
              onTap: () => context.push(
                  linkPath(context, '/settings/appearance/custom')),
            ),
            if (customThemeRowId(selectedId) != null) ...[
              const SizedBox(height: 26),
              shareSectionLabel(l10n.themeShareSection),
              const SizedBox(height: 10),
              shareActionRow([
                (
                  Icons.qr_code_2,
                  l10n.commonShowQr,
                  () => _showQr(context, active)
                ),
                (
                  Icons.ios_share,
                  l10n.commonSendCode,
                  () => _shareCode(l10n, active)
                ),
              ]),
            ],
            const SizedBox(height: 22),
            shareSectionLabel(l10n.themeAddSection),
            const SizedBox(height: 10),
            shareActionRow([
              if (ref.watch(capabilitiesProvider).scanning)
                (
                  Icons.qr_code_scanner,
                  l10n.themeScanQr,
                  () => context.push('/scan?for=theme')
                ),
              (
                Icons.content_paste,
                l10n.themePasteCode,
                () => _paste(context)
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

AppPalette _seedCustom(AppPalette from, String name) =>
    // Only shipped high-contrast palettes are WCAG-checked.
    from.copyWith(id: kCustomThemeId, name: name, accessible: false);

String _freeName(String base, List<AppPalette> existing) {
  final taken = {for (final p in existing) p.name};
  if (!taken.contains(base)) return base;
  for (var n = 2;; n++) {
    if (!taken.contains('$base $n')) return '$base $n';
  }
}

String _nextThemeName(AppLocalizations l10n, List<AppPalette> existing) =>
    _freeName(l10n.themeDefaultName, existing);

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
                child: Text(AppLocalizations.of(context).themeNew,
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

Future<void> _showQr(BuildContext context, AppPalette palette) {
  return showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(palette.name),
      content: ShareQr(
        data: ThemeCode.link(palette),
        caption: AppLocalizations.of(context).themeQrCaption,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).commonDone),
        ),
      ],
    ),
  );
}

Future<void> _shareCode(AppLocalizations l10n, AppPalette palette) async {
  await SharePlus.instance.share(
    ShareParams(
      text: ThemeCode.encode(palette),
      subject: l10n.themeShareSubject(palette.name),
    ),
  );
}

Future<void> _paste(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final text = await promptForCode(context,
      title: l10n.themePasteTitle, hint: l10n.themePasteHint);
  if (text == null || !context.mounted) return;
  context.push('/settings/appearance/import?code=${Uri.encodeQueryComponent(text)}');
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onEdit,
    this.onDuplicate,
  });
  final AppPalette palette;

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;

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
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              if (palette.accessible)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _AaaBadge(explainOnTap: selected),
                ),
              if (onDuplicate != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onDuplicate,
                  tooltip: AppLocalizations.of(context).themeDuplicate,
                  icon: Icon(Icons.copy_outlined,
                      size: 18, color: AppColors.muted),
                ),
              if (onEdit != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  tooltip: AppLocalizations.of(context).commonEdit,
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
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: widget.explainOnTap
          ? () => _tooltip.currentState?.ensureTooltipVisible()
          : null,
      child: Tooltip(
        key: _tooltip,
        message: l10n.themeAaaTooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.line),
          ),
          child: Text(l10n.themeAaaBadge,
              style: kMono.copyWith(
                  fontSize: 10,
                  letterSpacing: 0.8,
                  color: AppColors.muted)),
        ),
      ),
    );
  }
}

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


typedef _Role = ({
  String Function(AppLocalizations) label,
  Color Function(AppPalette) get,
  AppPalette Function(AppPalette, Color) set,
});

const List<_Role> _roles = [
  (label: _lGround, get: _gGround, set: _sGround),
  (label: _lSurface, get: _gSurface, set: _sSurface),
  (label: _lSurface2, get: _gSurface2, set: _sSurface2),
  (label: _lSurface3, get: _gSurface3, set: _sSurface3),
  (label: _lLine, get: _gLine, set: _sLine),
  (label: _lText, get: _gText, set: _sText),
  (label: _lMuted, get: _gMuted, set: _sMuted),
  (label: _lFaint, get: _gFaint, set: _sFaint),
  (label: _lAccent, get: _gAccent, set: _sAccent),
  (label: _lAccentPress, get: _gAccentPress, set: _sAccentPress),
  (label: _lGood, get: _gGood, set: _sGood),
  (label: _lGold, get: _gGold, set: _sGold),
];

String _lGround(AppLocalizations l) => l.themeRoleGround;
String _lSurface(AppLocalizations l) => l.themeRoleSurface;
String _lSurface2(AppLocalizations l) => l.themeRoleSurface2;
String _lSurface3(AppLocalizations l) => l.themeRoleSurface3;
String _lLine(AppLocalizations l) => l.themeRoleLine;
String _lText(AppLocalizations l) => l.themeRoleText;
String _lMuted(AppLocalizations l) => l.themeRoleMuted;
String _lFaint(AppLocalizations l) => l.themeRoleFaint;
String _lAccent(AppLocalizations l) => l.themeRoleAccent;
String _lAccentPress(AppLocalizations l) => l.themeRoleAccentPressed;
String _lGood(AppLocalizations l) => l.themeRoleGood;
String _lGold(AppLocalizations l) => l.themeRoleGold;

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

class CustomThemeEditorScreen extends ConsumerStatefulWidget {
  const CustomThemeEditorScreen({super.key, this.themeId, this.fromPresetId});

  final int? themeId;

  final String? fromPresetId;

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
    final l10n = AppLocalizations.of(context);
    final mine = ref.watch(customThemesProvider).value ?? const <AppPalette>[];
    final active = ref.watch(activePaletteProvider);
    final source =
        widget.themeId == null ? presetById(widget.fromPresetId) : null;
    final draft = _draft ??=
        _stored(mine) ?? _seedCustom(source ?? active, _nextThemeName(l10n, mine));
    final nameField = _name ??= TextEditingController(text: draft.name);

    return Scaffold(
      appBar: AppBar(
        title: Text(switch ((widget.themeId, source)) {
          (final int _, _) => l10n.themeEditTitle,
          (_, final AppPalette p) =>
            l10n.themeNewFrom(themeDisplayName(l10n, p)),
          _ => l10n.themeNew,
        }),
        actions: [
          if (widget.themeId != null)
            IconButton(
              onPressed: () => _confirmDelete(widget.themeId!, draft.name),
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.commonDelete,
            ),
          TextButton(
            onPressed: () => _save(draft),
            child: Text(l10n.commonSave),
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
                label: role.label(l10n),
                color: role.get(draft),
                onPick: () async {
                  final picked = await showDialog<Color>(
                    context: context,
                    builder: (_) => _ColorPickerDialog(
                      title: role.label(l10n),
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

  Future<void> _confirmDelete(int id, String name) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.themeDeleteConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(databaseProvider).deleteCustomTheme(id);
    if (mounted) context.pop();
  }
}

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
        labelText: AppLocalizations.of(context).commonName,
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
    final message = AppLocalizations.of(context).themeCopiedHex(hex);
    await Clipboard.setData(ClipboardData(text: hex));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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

Color? parseHex(String input) {
  var s = input.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 3) {
    s = s.split('').map((d) => '$d$d').join();
  }
  if (s.length != 6 || !RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(s)) return null;
  return Color(0xFF000000 | int.parse(s, radix: 16));
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.title, required this.initial});
  final String title;
  final Color initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
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

  void _adopt(Color c, {bool syncField = true}) {
    setState(() {
      _color = c;
      if (syncField) _hex.text = '#${_hexOf(c)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                  tooltip: l10n.themeCopyHex,
                  onTap: _copyHex,
                ),
                _hexAction(
                  icon: Icons.content_paste_rounded,
                  tooltip: l10n.themePasteHex,
                  onTap: _pasteHex,
                ),
              ],
            ),
            const SizedBox(height: 4),
            ..._rgbChannels(l10n),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _color),
          child: Text(l10n.themeUseColor),
        ),
      ],
    );
  }

  Future<void> _copyHex() async {
    final hex = '#${_hexOf(_color)}';
    final message = AppLocalizations.of(context).themeCopiedHex(hex);
    await Clipboard.setData(ClipboardData(text: hex));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pasteHex() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final parsed = parseHex(data?.text ?? '');
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).themeNoColorOnClipboard),
        ),
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
      onChanged: (text) {
        final parsed = parseHex(text);
        if (parsed != null) _adopt(parsed, syncField: false);
      },
    );
  }

  List<Widget> _rgbChannels(AppLocalizations l10n) {
    final r = (_color.r * 255).roundToDouble();
    final g = (_color.g * 255).roundToDouble();
    final b = (_color.b * 255).roundToDouble();
    Color at(int? nr, int? ng, int? nb) => Color.fromARGB(
        255, nr ?? r.round(), ng ?? g.round(), nb ?? b.round());
    return [
      _channel(
        label: l10n.themeChannelRed,
        value: r,
        max: 255,
        gradient: [at(0, null, null), at(255, null, null)],
        onChanged: (v) => _adopt(at(v.round(), null, null)),
      ),
      _channel(
        label: l10n.themeChannelGreen,
        value: g,
        max: 255,
        gradient: [at(null, 0, null), at(null, 255, null)],
        onChanged: (v) => _adopt(at(null, v.round(), null)),
      ),
      _channel(
        label: l10n.themeChannelBlue,
        value: b,
        max: 255,
        gradient: [at(null, null, 0), at(null, null, 255)],
        onChanged: (v) => _adopt(at(null, null, v.round())),
      ),
    ];
  }

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
class _ScaleChoices extends StatelessWidget {
  const _ScaleChoices({required this.chosen, required this.onSelect});
  final double chosen;
  final ValueChanged<double> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final choice in kTextScaleChoices)
          TextScaleChip(
            choice: choice,
            selected: (choice.scale - chosen).abs() < 0.001,
            onTap: () => onSelect(choice.scale),
          ),
      ],
    );
  }
}

class TextScaleChip extends StatelessWidget {
  const TextScaleChip({
    super.key,
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final TextScaleChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.14)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.line,
          ),
        ),
        child: Text(
          choice.label(l10n),
          textScaler: TextScaler.linear(choice.scale),
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.accent : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
