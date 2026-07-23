import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../widgets/builder_widgets.dart';

/// The bar and the plates in the gym: everything the per-side breakdown on a
/// barbell exercise is computed from.
///
/// Edited in the unit the user has chosen — a pounds gym should be typing 45,
/// not 20.4. What is stored is kilograms like every other weight, so switching
/// units re-labels this screen without moving a plate.
class PlateInventoryScreen extends ConsumerWidget {
  const PlateInventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final setup = ref.watch(plateSettingsProvider);
    final db = ref.read(databaseProvider);
    final u = unitLabel(unit);

    String show(double kg) => fmtPlateWeight(toDisplayWeight(kg, unit));

    // Every edit writes the whole rack, which is also what turns the standard
    // set into the user's own the first time they touch it.
    void write(List<PlateStack> plates) => db.setPlateInventory(plates);

    Future<void> editBar() async {
      final kg = await _askWeight(
        context,
        title: 'Bar weight',
        unit: unit,
        initialKg: setup.barKg,
      );
      if (kg != null) await db.setBarWeight(kg);
    }

    Future<void> addPlate() async {
      final kg = await _askWeight(context, title: 'Plate size', unit: unit);
      if (kg == null || kg <= 0) return;
      final exists = setup.plates
          .any((p) => (p.kg - kg).abs() <= kPlateToleranceKg);
      if (exists) return;
      write(sortedPlates([
        ...setup.plates,
        (kg: kg, count: kDefaultPlateCount),
      ]));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Bar & plates')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            builderLabel('The bar'),
            _Row(
              label: 'Bar weight',
              value: '${show(setup.barKg)} $u',
              onTap: editBar,
            ),
            const SizedBox(height: 12),
            Text(
              'The bar is counted in every barbell weight you log, so the '
              'breakdown only ever asks you to load the difference. A standard '
              'Olympic bar is 20 kg (45 lb); a womens bar is 15, and most EZ '
              'and fixed bars are lighter still.',
              style: const TextStyle(
                  color: AppColors.muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 26),
            builderLabel('Plates you own'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  if (setup.plates.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        'No plates. Every barbell weight will read as just the '
                        'bar until you add some.',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ),
                  for (var i = 0; i < setup.plates.length; i++)
                    _PlateRow(
                      plate: setup.plates[i],
                      unit: unit,
                      onCount: (n) {
                        final next = [...setup.plates];
                        next[i] = (kg: setup.plates[i].kg, count: n);
                        write(next);
                      },
                      onRemove: () => write(
                          [...setup.plates]..removeAt(i)),
                    ),
                  const Divider(height: 1, color: AppColors.line),
                  InkWell(
                    onTap: addPlate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          const Icon(Icons.add,
                              size: 18, color: AppColors.accent),
                          const SizedBox(width: 10),
                          Text('Add a plate size',
                              style: kMono.copyWith(
                                  fontSize: 13,
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Counts go up two at a time because plates go on the bar in '
              'pairs. When a weight cannot be made from what is here, the app '
              'says so and shows the closest load you can actually build '
              'instead of a number nobody can put on a bar.',
              style: const TextStyle(
                  color: AppColors.muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                onPressed: db.resetPlateSetup,
                icon: const Icon(Icons.restart_alt, size: 18),
                label: Text('Reset to a standard $u gym'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A label-and-value row that opens something when tapped.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Text(value,
                  style: kMono.copyWith(
                      fontSize: 16,
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

/// One plate size and how many of them the gym has.
class _PlateRow extends StatelessWidget {
  const _PlateRow({
    required this.plate,
    required this.unit,
    required this.onCount,
    required this.onRemove,
  });
  final PlateStack plate;
  final String unit;
  final ValueChanged<int> onCount;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:
          const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${fmtPlateWeight(toDisplayWeight(plate.kg, unit))} '
              '${unitLabel(unit)}',
              style: kMono.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          // Two at a time, because that is how they go on the bar. Taking the
          // last pair off is the same statement as not owning the size at all,
          // so − at the bottom removes the row rather than sticking at two.
          NumberStepper(
            value: plate.count,
            min: 2,
            max: 20,
            step: 2,
            onChanged: onCount,
            onClear: onRemove,
          ),
          builderIconButton(Icons.close, onRemove, danger: true),
        ],
      ),
    );
  }
}

/// Asks for a weight in the display unit and hands back kilograms.
///
/// A dialog rather than a field on the screen: the value it edits is read from
/// the database, and a live text field over a stream has to decide on every
/// keystroke whether the user or the database is right.
Future<double?> _askWeight(
  BuildContext context, {
  required String title,
  required String unit,
  double? initialKg,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) =>
        _WeightDialog(title: title, unit: unit, initialKg: initialKg),
  );
}

class _WeightDialog extends StatefulWidget {
  const _WeightDialog({
    required this.title,
    required this.unit,
    this.initialKg,
  });
  final String title;
  final String unit;
  final double? initialKg;

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
  /// rack is not worth an error message.
  void _save() {
    final v = double.tryParse(_c.text.trim().replaceAll(',', '.'));
    Navigator.pop(
        context, v == null || v < 0 || v > 1000 ? null : toKg(v, widget.unit));
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
