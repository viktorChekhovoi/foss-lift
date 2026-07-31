import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/exercise_filter.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../screens/exercise_form_screen.dart';
import '../theme/app_theme.dart';
import '../util/seed_names.dart';
import '../util/units.dart';
import 'common.dart';
import 'exercise_filters.dart';
import '../util/format.dart';

/// Shared chrome for the routine and workout builders.

InputDecoration builderInput(String hint) => InputDecoration(
  hintText: hint,
  // No "12/80" counter under the name fields that cap their length: the cap
  // stops typing on its own, and a tally of a number nobody is approaching
  // is a line of noise under every field.
  counterText: '',
  // Set explicitly, not just via the theme: a field with its own `style`
  // would otherwise lend the hint its weight and size and make the
  // placeholder look like entered text.
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

/// What came back from [askWeight]: a weight in kilograms, or a null [kg]
/// meaning "use the default". A null *result* is a cancelled dialog.
typedef WeightChoice = ({double? kg});

/// Asks for a weight in the display unit and hands back kilograms.
///
/// A dialog rather than a field on the screen: the values it edits are read
/// from the database, and a live text field over a stream has to decide on
/// every keystroke whether the user or the database is right.
///
/// [defaultLabel] adds a button that clears the setting back to whatever the
/// app would have assumed — "Standard 20 kg", "Gym default".
Future<WeightChoice?> askWeight(
  BuildContext context, {
  required String title,
  required String unit,
  double? initialKg,
  String? defaultLabel,
}) {
  return showDialog<WeightChoice>(
    context: context,
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
        : fmtPlateWeight(toDisplayWeight(widget.initialKg!, widget.unit)),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Anything unreadable or absurd closes without changing a thing — a plate
  /// size is not worth an error message.
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
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.title),
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

/// Asks *which bar* this is, and hands back what it weighs in kilograms.
///
/// A weight is what gets stored, but a weight is not what anybody knows: you
/// know you curl on the EZ bar and deadlift off the trap bar, and the number
/// follows from that. So the gym's bars are offered by name, from the `Bars`
/// table — and a bar the list does not have yet can be added from here.
///
/// [defaultLabel] adds a button that hands the setting back to whatever the app
/// would otherwise assume. Null when it is already on the default.
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

/// A bar as the editor hands it back: a name and a weight in kilograms.
typedef BarDraft = ({String name, double kg});

/// Asks for a bar's name and what it weighs, in the display unit.
///
/// Both at once, because half a bar is not worth storing. Returns null when the
/// dialog was cancelled or either field was left unusable.
Future<BarDraft?> askBarEdit(
  BuildContext context, {
  required String title,
  required String unit,
  String? name,
  double? kg,
}) {
  return showDialog<BarDraft>(
    context: context,
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
        : fmtPlateWeight(toDisplayWeight(widget.kg!, widget.unit)),
  );

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    super.dispose();
  }

  /// An empty name or an unreadable weight closes without changing anything —
  /// the same silence [askWeight] keeps, for the same reason.
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
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.title),
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
    // Within a hundred grams is the same bar: a 45 lb bar is 20.41 kg and will
    // never compare equal to anything typed in kilograms.
    bool isCurrent(double kg) =>
        currentKg != null && (currentKg! - kg).abs() < 0.1;

    /// Adds a bar the list does not have yet, and picks it in the same breath —
    /// which is the only reason to be adding one from here.
    Future<void> addOne() async {
      final draft = await askBarEdit(
        context,
        title: l10n.commonAddBar,
        unit: unit,
      );
      if (draft == null) return;
      // A refusal means the list already holds a bar of that weight — which is
      // the bar being described, so picking it is still the right answer.
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
                  fmtPlateWeight(toDisplayWeight(b.weightKg, unit)),
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

/// The longest a personal note may be. Matches the column cap in
/// `database.dart` — a couple of settings and a reminder, not an essay.
const int kNoteMaxLength = 300;

/// Asks for the personal note on a movement. Returns the text as typed, `''`
/// to clear it, or null when the dialog was cancelled.
///
/// A dialog for the same reason [askWeight] is one: the value it edits comes
/// off a stream, and a live field over a stream has to decide on every
/// keystroke whether the user or the database is right.
Future<String?> askNote(
  BuildContext context, {
  required String title,
  String? initial,
}) {
  return showDialog<String>(
    context: context,
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
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        maxLines: 4,
        minLines: 2,
        maxLength: kNoteMaxLength,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 15, height: 1.4),
        decoration: builderInput(l10n.builderNoteHint),
      ),
      actions: [
        // Only offered when there is something to clear, so the common case —
        // writing a first note — is two buttons, not three.
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

/// A settings row that states a value and opens something when tapped.
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

  /// A qualifier under the label — "the gym default", "for pounds".
  final String? note;
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
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              // Flexible, because a value can be a name rather than a number —
              // "Safety squat bar" is as long as some labels. The label above
              // gives first; this is the backstop for the row that still cannot
              // fit at a large text size.
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
        ),
      ),
    );
  }
}

/// A small uppercase field caption.
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

/// A compact "− value + " stepper.
///
/// Pass [onClear] to make the value optional: pressing − at [min] empties it
/// rather than sticking, and + brings it back. That keeps an optional setting
/// the same width and shape as a required one — a separate clear button beside
/// the stepper would push it out of line with every other row.
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
  });
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final String suffix;

  /// Shows [emptyLabel] instead of [value]; + restores [min].
  final bool isEmpty;
  final String emptyLabel;

  /// Called instead of [onChanged] when − would take the value below [min].
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final canGoDown = isEmpty ? false : (value > min || onClear != null);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(Icons.remove, canGoDown ? _down : null),
        // The number gives, the two buttons never do: a stepper you cannot
        // press is not a stepper. At a large font scale in a two-column grid
        // there is not room for all three at their natural width, and 54 is a
        // minimum rather than a promise.
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
                color: isEmpty ? AppColors.faint : AppColors.text,
              ),
            ),
          ),
        ),
        _btn(Icons.add, isEmpty || value < max ? _up : null),
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

  Widget _btn(IconData icon, VoidCallback? onTap) {
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
}

/// A titled group of settings.
///
/// A sheet with a dozen controls stacked in one column reads as a dozen
/// decisions; the same controls in three captioned blocks read as three. Every
/// setting inside a card is about the same thing.
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

/// Lays fields out two to a row, last one half-width if the count is odd.
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

/// One captioned control inside a [builderGrid] cell. [note] is a qualifier
/// that belongs to the caption rather than to the value — "REST · DEFAULT".
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

/// One captioned, ordered list inside a builder: the rows, dragged into order
/// by their own handles, and the button that appends one.
///
/// Both levels of the template hierarchy are edited through this: the training
/// days of a routine and the exercise slots of a day. They are the same list of
/// the same rows, so they are one widget — reordering has to feel identical at
/// both levels, and two copies would drift.
///
/// It shrink-wraps and does not scroll: the builders put it inside their own
/// scroll view, and a list with its own would trap the drag.
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

  /// The uppercase heading, sans count — "Workouts", "Exercises".
  final String caption;
  final List<T> items;

  /// Shown in place of the rows when there are none. One line.
  final String emptyText;
  final String addLabel;
  final VoidCallback onAdd;

  /// Moves the item at `from` to `to`, an index already corrected for the item
  /// having been lifted out of the list.
  final void Function(int from, int to) onReorder;

  /// Builds the row for [item], which must be a [BuilderReorderRow] carrying
  /// the same [index] so its handle knows what it is dragging.
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
          // onReorderItem, not onReorder: it hands back a destination index
          // already corrected for the item having been lifted out.
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

/// One row of a [BuilderReorderList]: a grab handle, a name over a summary
/// line, and a remove button. Tapping it opens whatever it stands for.
class BuilderReorderRow extends StatelessWidget {
  const BuilderReorderRow({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onRemove,
  });

  /// Position in the list, which is what the drag handle moves.
  final int index;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onRemove;

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
          ),
          padding: const EdgeInsets.fromLTRB(4, 10, 6, 10),
          child: Row(
            children: [
              // Grab here to drag the row up or down the list.
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

/// Small round remove buttons used by builder rows.
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

/// Searchable library picker shown as a bottom sheet; pops the chosen exercise.
class ExercisePicker extends ConsumerStatefulWidget {
  const ExercisePicker({super.key});
  @override
  ConsumerState<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<ExercisePicker> {
  ExerciseFilter _filter = const ExerciseFilter();

  /// Builds a movement the library does not have, without losing your place.
  ///
  /// Leaving the builder to make one and coming back to start again is a dead
  /// end people work around by picking something close enough. The form goes on
  /// the root navigator so it covers this sheet rather than fighting it, and
  /// what it makes is what the picker returns — you asked for that exercise.
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
                onChanged: (v) =>
                    setState(() => _filter = _filter.withQuery(v)),
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
                  final list = _filter.apply(all, shown: (e) => shownWords(l10n, e));
                  return ListView.separated(
                    // The chips ride at the head of the list rather than in a
                    // band above it: wrapped, they are as tall as the
                    // vocabulary and the font demand, which no fixed band at
                    // the top of a sheet can promise.
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
                          filter: _filter,
                          onChanged: (f) => setState(() => _filter = f),
                        );
                      }
                      // The new-exercise row rides above the movements, where
                      // it is found by someone who has already looked and not
                      // found what they wanted.
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

/// The little drag handle at the top of a bottom sheet.
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

/// Opens the exercise picker sheet and returns the chosen exercise.
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
