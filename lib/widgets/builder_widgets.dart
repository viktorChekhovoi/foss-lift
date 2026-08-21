import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../screens/exercise_form_screen.dart';
import '../state/exercise_filter_state.dart';
import '../theme/app_theme.dart';
import '../util/seed_names.dart';
import '../util/units.dart';
import 'common.dart';
import 'exercise_filters.dart';
import '../util/format.dart';


InputDecoration builderInput(String hint) => InputDecoration(
  hintText: hint,
  counterText: '',
  hintStyle: TextStyle(
    color: AppColors.faint,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
  ),
  filled: true,
  fillColor: AppColors.surface,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: AppColors.line),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: AppColors.accent),
  ),
);

typedef WeightChoice = ({double? kg});

Future<WeightChoice?> askWeight(
  BuildContext context, {
  required String title,
  required String unit,
  double? initialKg,
  String? defaultLabel,
}) {
  return showAppDialog<WeightChoice>(
    context,
    keyboard: const TextInputType.numberWithOptions(decimal: true),
    builder: (_) => _WeightDialog(
      title: title,
      unit: unit,
      initialKg: initialKg,
      defaultLabel: defaultLabel,
    ),
  );
}

class _WeightDialog extends StatefulWidget {
  const _WeightDialog({
    required this.title,
    required this.unit,
    this.initialKg,
    this.defaultLabel,
  });
  final String title;
  final String unit;
  final double? initialKg;
  final String? defaultLabel;

  @override
  State<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initialKg == null
        ? ''
        : fmtWeight(toDisplayWeight(widget.initialKg!, widget.unit)),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final v = double.tryParse(_c.text.trim().replaceAll(',', '.'));
    Navigator.pop<WeightChoice>(
      context,
      v == null || v < 0 || v > 1000 ? null : (kg: toKg(v, widget.unit)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: widget.title,
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: kMono.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
        decoration: builderInput(unitSuffix(l10n, widget.unit)),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        if (widget.defaultLabel != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            onPressed: () => Navigator.pop<WeightChoice>(context, (kg: null)),
            child: Text(widget.defaultLabel!),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        TextButton(onPressed: _save, child: Text(l10n.commonSave)),
      ],
    );
  }
}

Future<WeightChoice?> askBar(
  BuildContext context, {
  required String title,
  required String unit,
  double? currentKg,
  String? defaultLabel,
}) {
  return showDialog<WeightChoice>(
    context: context,
    builder: (_) => _BarDialog(
      title: title,
      unit: unit,
      currentKg: currentKg,
      defaultLabel: defaultLabel,
    ),
  );
}

typedef BarDraft = ({String name, double kg});

Future<BarDraft?> askBarEdit(
  BuildContext context, {
  required String title,
  required String unit,
  String? name,
  double? kg,
}) {
  return showAppDialog<BarDraft>(
    context,
    keyboard: name == null ? TextInputType.text : null,
    builder: (_) =>
        _BarEditDialog(title: title, unit: unit, name: name, kg: kg),
  );
}

class _BarEditDialog extends StatefulWidget {
  const _BarEditDialog({
    required this.title,
    required this.unit,
    this.name,
    this.kg,
  });
  final String title;
  final String unit;
  final String? name;
  final double? kg;

  @override
  State<_BarEditDialog> createState() => _BarEditDialogState();
}

class _BarEditDialogState extends State<_BarEditDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.name ?? '',
  );
  late final TextEditingController _weight = TextEditingController(
    text: widget.kg == null
        ? ''
        : fmtWeight(toDisplayWeight(widget.kg!, widget.unit)),
  );

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final v = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    Navigator.pop<BarDraft>(
      context,
      name.isEmpty || v == null || v <= 0 || v > 1000
          ? null
          : (name: name, kg: toKg(v, widget.unit)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: widget.title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: widget.name == null,
            maxLength: kMaxNameLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: builderInput(l10n.commonName),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: kMono.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: builderInput(unitSuffix(l10n, widget.unit)),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        TextButton(onPressed: _save, child: Text(l10n.commonSave)),
      ],
    );
  }
}

class _BarDialog extends ConsumerWidget {
  const _BarDialog({
    required this.title,
    required this.unit,
    this.currentKg,
    this.defaultLabel,
  });
  final String title;
  final String unit;
  final double? currentKg;
  final String? defaultLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bars = ref.watch(barsProvider).value ?? const [];
    bool isCurrent(double kg) =>
        currentKg != null && (currentKg! - kg).abs() < 0.1;

    Future<void> addOne() async {
      final draft = await askBarEdit(
        context,
        title: l10n.commonAddBar,
        unit: unit,
      );
      if (draft == null) return;
      await ref
          .read(databaseProvider)
          .addBar(unit: unit, name: draft.name, kg: draft.kg);
      if (!context.mounted) return;
      Navigator.pop<WeightChoice>(context, (kg: draft.kg));
    }

    Widget row({
      required String label,
      String? trailing,
      required bool selected,
      required VoidCallback onTap,
    }) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.accent : AppColors.text,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: kMono.copyWith(
                  fontSize: 13,
                  color: selected ? AppColors.accent : AppColors.muted,
                ),
              ),
          ],
        ),
      ),
    );

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final b in bars)
              row(
                label: seededName(l10n, b.seedKey, b.name),
                trailing: l10n.unitWeightShort(
                  fmtWeight(toDisplayWeight(b.weightKg, unit)),
                  unitSuffix(l10n, unit),
                ),
                selected: isCurrent(b.weightKg),
                onTap: () =>
                    Navigator.pop<WeightChoice>(context, (kg: b.weightKg)),
              ),
            Divider(height: 1, color: AppColors.line),
            row(label: l10n.commonAddBar, selected: false, onTap: addOne),
          ],
        ),
      ),
      actions: [
        if (defaultLabel != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            onPressed: () => Navigator.pop<WeightChoice>(context, (kg: null)),
            child: Text(defaultLabel!),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}

const int kNoteMaxLength = 300;

Future<String?> askNote(
  BuildContext context, {
  required String title,
  String? initial,
}) {
  return showAppDialog<String>(
    context,
    keyboard: TextInputType.multiline,
    builder: (_) => _NoteDialog(title: title, initial: initial),
  );
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.title, this.initial});
  final String title;
  final String? initial;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial ?? '',
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: widget.title,
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: _c,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          maxLength: kNoteMaxLength,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 15, height: 1.4),
          decoration: builderInput(l10n.builderNoteHint),
        ),
      ),
      actions: [
        if ((widget.initial ?? '').isNotEmpty)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            onPressed: () => Navigator.pop<String>(context, ''),
            child: Text(l10n.builderClear),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop<String>(context, _c.text),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

Widget settingRowShell({
  required VoidCallback onTap,
  required Widget child,
  Color? border,
}) =>
    Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border ?? AppColors.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: child,
        ),
      ),
    );

class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.note,
  });
  final String label;
  final String value;

  final String? note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return settingRowShell(
      onTap: onTap,
      child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        note!,
                        style: kMono.copyWith(
                          fontSize: 11.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: kMono.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: AppColors.faint, size: 20),
            ],
          ),
    );
  }
}

Widget builderLabel(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 8, left: 2),
  child: Text(
    t.toUpperCase(),
    style: kMono.copyWith(
      fontSize: 11,
      letterSpacing: 1.2,
      color: AppColors.faint,
    ),
  ),
);

class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.step = 1,
    this.suffix = '',
    this.isEmpty = false,
    this.emptyLabel = '—',
    this.onClear,
    this.enabled = true,
  });
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final String suffix;

  final bool isEmpty;
  final String emptyLabel;

  final VoidCallback? onClear;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final canGoDown =
        enabled && !isEmpty && (value > min || onClear != null);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        stepperButton(Icons.remove, canGoDown ? _down : null),
        Flexible(
          child: Container(
            constraints: const BoxConstraints(minWidth: 54),
            alignment: Alignment.center,
            child: Text(
              isEmpty ? emptyLabel : '$value$suffix',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kMono.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isEmpty || !enabled ? AppColors.faint : AppColors.text,
              ),
            ),
          ),
        ),
        stepperButton(
          Icons.add,
          enabled && (isEmpty || value < max) ? _up : null,
        ),
      ],
    );
  }

  void _down() {
    if (value - step < min) {
      onClear!();
    } else {
      onChanged(_clamp(value - step));
    }
  }

  void _up() => onChanged(isEmpty ? min : _clamp(value + step));

  int _clamp(int v) => v < min ? min : (v > max ? max : v);
}

Widget stepperButton(IconData icon, VoidCallback? onTap) {
  return Material(
    color: onTap == null ? AppColors.surface : AppColors.surface2,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? AppColors.faint : AppColors.text,
        ),
      ),
    ),
  );
}

Widget builderCard(String caption, List<Widget> children) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    builderLabel(caption),
    Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    ),
  ],
);

Widget builderGrid(List<Widget> fields) {
  final rows = <Widget>[];
  for (var i = 0; i < fields.length; i += 2) {
    rows.add(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: fields[i]),
          const SizedBox(width: 12),
          Expanded(
            child: i + 1 < fields.length ? fields[i + 1] : const SizedBox(),
          ),
        ],
      ),
    );
  }
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const SizedBox(height: 16),
        rows[i],
      ],
    ],
  );
}

class BuilderField extends StatelessWidget {
  const BuilderField({
    super.key,
    required this.label,
    required this.child,
    this.note,
  });
  final String label;
  final Widget child;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            style: kMono.copyWith(
              fontSize: 10,
              letterSpacing: 1.0,
              color: AppColors.faint,
            ),
            children: [
              TextSpan(text: label.toUpperCase()),
              if (note != null)
                TextSpan(
                  text: ' · ${note!.toUpperCase()}',
                  style: TextStyle(color: AppColors.accent),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class BuilderReorderList<T> extends StatelessWidget {
  const BuilderReorderList({
    super.key,
    required this.caption,
    required this.items,
    required this.emptyText,
    required this.addLabel,
    required this.onAdd,
    required this.onReorder,
    required this.rowBuilder,
  });

  final String caption;
  final List<T> items;

  final String emptyText;
  final String addLabel;
  final VoidCallback onAdd;

  final void Function(int from, int to) onReorder;

  final Widget Function(int index, T item) rowBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('$caption · ${items.length}'),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(emptyText, style: TextStyle(color: AppColors.muted)),
          ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          padding: EdgeInsets.zero,
          itemCount: items.length,
          onReorderItem: onReorder,
          proxyDecorator: (child, _, _) => Material(
            color: Colors.transparent,
            child: Opacity(opacity: 0.9, child: child),
          ),
          itemBuilder: (context, i) => Padding(
            key: ObjectKey(items[i]),
            padding: const EdgeInsets.only(bottom: 10),
            child: rowBuilder(i, items[i]),
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: BorderSide(color: AppColors.line),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text(addLabel),
        ),
      ],
    );
  }
}

class BuilderReorderRow extends StatelessWidget {
  const BuilderReorderRow({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onRemove,
    this.badge,
    this.grouped = false,
  });

  final int index;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  final String? badge;

  final bool grouped;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
            gradient: grouped
                ? LinearGradient(
                    colors: [AppColors.accent, AppColors.surface],
                    stops: const [0.008, 0.008],
                  )
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(4, 10, 6, 10),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 22,
                    color: AppColors.faint,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (badge case final badge?) ...[
                      Text(
                        badge,
                        style: kMono.copyWith(
                          fontSize: 10,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: kMono.copyWith(
                        fontSize: 12.5,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              builderIconButton(Icons.close, onRemove, danger: true),
            ],
          ),
        ),
      ),
    );
  }
}

Widget builderIconButton(
  IconData icon,
  VoidCallback? onTap, {
  bool danger = false,
  Key? key,
}) {
  return IconButton(
    key: key,
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    onPressed: onTap,
    icon: Icon(
      icon,
      size: 20,
      color: onTap == null
          ? AppColors.faint.withValues(alpha: 0.4)
          : (danger ? const Color(0xFFFF5D5D) : AppColors.muted),
    ),
  );
}

class ExercisePicker extends ConsumerStatefulWidget {
  const ExercisePicker({super.key});
  @override
  ConsumerState<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<ExercisePicker> {
  String _query = '';

  Future<void> _createOne() async {
    final made = await Navigator.of(context, rootNavigator: true)
        .push<Exercise>(
          MaterialPageRoute(builder: (_) => const ExerciseFormScreen()),
        );
    if (made == null || !mounted) return;
    Navigator.pop(context, made);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(exerciseLibraryProvider);
    final filter = ref.watch(pickerFilterProvider).withQuery(_query);
    final height = MediaQuery.of(context).size.height * 0.8;
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            const SheetGrabber(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: builderInput(l10n.commonSearchExercises).copyWith(
                  prefixIcon: Icon(Icons.search, color: AppColors.muted),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: library.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (e, _) => Center(
                  child: Text('$e', style: TextStyle(color: AppColors.muted)),
                ),
                data: (all) {
                  final list = filter.apply(all, shown: (e) => shownWords(l10n, e));
                  return ListView.separated(
                    itemCount: list.length + 2,
                    separatorBuilder: (_, i) => i == 0
                        ? const SizedBox(height: 4)
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Divider(height: 1, color: AppColors.line),
                          ),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return ExerciseFilterChips(
                          filter: filter,
                          onChanged:
                              ref.read(pickerFilterProvider.notifier).keep,
                        );
                      }
                      if (i == 1) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ListTile(
                            key: const ValueKey('picker-new-exercise'),
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.add, color: AppColors.accent),
                            title: Text(
                              l10n.commonNewExercise,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                            onTap: _createOne,
                          ),
                        );
                      }
                      final e = list[i - 2];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            e.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${e.muscleGroup} · ${e.equipment}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          trailing: Icon(Icons.add, color: AppColors.accent),
                          onTap: () => Navigator.pop(context, e),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.line,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

Future<Exercise?> pickExercise(BuildContext context) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.ground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const ExercisePicker(),
  );
}
