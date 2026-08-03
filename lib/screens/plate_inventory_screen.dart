import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../widgets/builder_widgets.dart';
import '../util/format.dart';

/// The plates in the gym: what every per-side breakdown is built out of.
///
/// Edited in the unit the user has chosen — a pounds gym should be typing 45,
/// not 20.4 — and **kept per unit**, so adding a 30 kg plate here does not turn
/// into a 66.14 lb plate nobody owns the moment the app is switched to pounds.
/// The values themselves are stored in kilograms like every other weight.
class PlateInventoryScreen extends ConsumerWidget {
  const PlateInventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final setup = ref.watch(plateSettingsProvider);
    final db = ref.read(databaseProvider);
    final l10n = AppLocalizations.of(context);
    final u = unitSuffix(l10n, unit);

    // Every edit writes the whole rack, which is also what turns the standard
    // set into the user's own the first time they touch it.
    void write(List<PlateStack> plates) => db.setPlateInventory(plates, unit);

    Future<void> addPlate() async {
      final choice = await askWeight(context,
          title: l10n.plateRackPlateSize, unit: unit);
      final kg = choice?.kg;
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
      appBar: AppBar(title: Text(l10n.plateRackTitle(u))),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            builderLabel(l10n.plateRackOwned),
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
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        l10n.plateRackEmpty,
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
                  Divider(height: 1, color: AppColors.line),
                  InkWell(
                    onTap: addPlate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.add,
                              size: 18, color: AppColors.accent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(l10n.plateRackAdd,
                                style: kMono.copyWith(
                                    fontSize: 13,
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.plateRackNote(u),
              style: TextStyle(
                  color: AppColors.muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                onPressed: () => db.resetPlateInventory(unit),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: Text(l10n.plateRackReset(u)),
              ),
            ),
          ],
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
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.unitWeightShort(
                  fmtWeight(toDisplayWeight(plate.kg, unit)),
                  unitSuffix(l10n, unit)),
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
