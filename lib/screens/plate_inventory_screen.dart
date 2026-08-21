import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../widgets/builder_widgets.dart';
import '../util/format.dart';

class PlateInventoryScreen extends ConsumerWidget {
  const PlateInventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final setup = ref.watch(plateSettingsProvider);
    final db = ref.read(databaseProvider);
    final l10n = AppLocalizations.of(context);
    final u = unitSuffix(l10n, unit);

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
