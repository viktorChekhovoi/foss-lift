import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';

/// Shared chrome for the routine and workout builders.

InputDecoration builderInput(String hint) => InputDecoration(
      hintText: hint,
      // Set explicitly, not just via the theme: a field with its own `style`
      // would otherwise lend the hint its weight and size and make the
      // placeholder look like entered text.
      hintStyle: const TextStyle(
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
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent),
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
          : fmtPlateWeight(toDisplayWeight(widget.initialKg!, widget.unit)));

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
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: kMono.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
        decoration: builderInput(unitLabel(widget.unit)),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        if (widget.defaultLabel != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            onPressed: () =>
                Navigator.pop<WeightChoice>(context, (kg: null)),
            child: Text(widget.defaultLabel!),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
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
                    Text(label,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    if (note != null) ...[
                      const SizedBox(height: 3),
                      Text(note!,
                          style: kMono.copyWith(
                              fontSize: 11.5, color: AppColors.muted)),
                    ],
                  ],
                ),
              ),
              Text(value,
                  style: kMono.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent)),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: AppColors.faint, size: 20),
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
            fontSize: 11, letterSpacing: 1.2, color: AppColors.faint),
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
        Container(
          constraints: const BoxConstraints(minWidth: 54),
          alignment: Alignment.center,
          child: Text(
            isEmpty ? emptyLabel : '$value$suffix',
            style: kMono.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isEmpty ? AppColors.faint : AppColors.text,
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
          child: Icon(icon,
              size: 18,
              color: onTap == null ? AppColors.faint : AppColors.text),
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
    rows.add(Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: fields[i]),
        const SizedBox(width: 12),
        Expanded(
          child: i + 1 < fields.length ? fields[i + 1] : const SizedBox(),
        ),
      ],
    ));
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
                fontSize: 10, letterSpacing: 1.0, color: AppColors.faint),
            children: [
              TextSpan(text: label.toUpperCase()),
              if (note != null)
                TextSpan(
                  text: ' · ${note!.toUpperCase()}',
                  style: const TextStyle(color: AppColors.accent),
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

/// Small round move-up / move-down / remove buttons used by builder rows.
Widget builderIconButton(IconData icon, VoidCallback? onTap,
    {bool danger = false}) {
  return IconButton(
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    onPressed: onTap,
    icon: Icon(icon,
        size: 20,
        color: onTap == null
            ? AppColors.faint.withValues(alpha: 0.4)
            : (danger ? const Color(0xFFFF5D5D) : AppColors.muted)),
  );
}

/// Searchable library picker shown as a bottom sheet; pops the chosen exercise.
class ExercisePicker extends ConsumerStatefulWidget {
  const ExercisePicker({super.key});
  @override
  ConsumerState<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<ExercisePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(exerciseLibraryProvider);
    final height = MediaQuery.of(context).size.height * 0.8;
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            const SheetGrabber(),
            TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              decoration: builderInput('Search exercises…').copyWith(
                prefixIcon: const Icon(Icons.search, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: library.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.accent)),
                error: (e, _) => Center(
                    child:
                        Text('$e', style: const TextStyle(color: AppColors.muted))),
                data: (all) {
                  final q = _query.trim().toLowerCase();
                  final list = q.isEmpty
                      ? all
                      : all
                          .where((e) =>
                              e.name.toLowerCase().contains(q) ||
                              e.muscleGroup.toLowerCase().contains(q))
                          .toList();
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.line),
                    itemBuilder: (_, i) {
                      final e = list[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        subtitle: Text('${e.muscleGroup} · ${e.equipment}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted)),
                        trailing: const Icon(Icons.add, color: AppColors.accent),
                        onTap: () => Navigator.pop(context, e),
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
