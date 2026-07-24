import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../widgets/builder_widgets.dart';

/// The bar every barbell exercise is assumed to use.
///
/// A default, not a rule: a gym is not one bar, so an exercise can carry its
/// own (Exercise → Bar weight) and this is only what the rest of them fall back
/// to.
class BarSettingsScreen extends ConsumerWidget {
  const BarSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final stored = ref.watch(storedPlateSetupProvider).value;
    final setup = ref.watch(plateSettingsProvider);
    final db = ref.read(databaseProvider);
    final u = unitLabel(unit);
    final isDefault = stored?.barKg == null;

    Future<void> edit() async {
      final choice = await askWeight(
        context,
        title: 'Default bar weight',
        unit: unit,
        initialKg: setup.barKg,
        defaultLabel: isDefault
            ? null
            : 'Standard ${fmtPlateWeight(toDisplayWeight(defaultBarKg(unit), unit))} $u',
      );
      if (choice == null) return;
      final kg = choice.kg;
      if (kg == null) {
        await db.resetBarWeight();
      } else {
        await db.setBarWeight(kg);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Default bar weight')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            SettingRow(
              label: 'Bar weight',
              note: isDefault ? 'the standard bar' : 'set by you',
              value: '${fmtPlateWeight(toDisplayWeight(setup.barKg, unit))} $u',
              onTap: edit,
            ),
            const SizedBox(height: 14),
            Text(
              'The bar counts towards every barbell weight you log, so the '
              'breakdown only asks you to load the difference. A standard '
              'Olympic bar is 20 kg (45 lb); a womens bar is 15.',
              style: TextStyle(
                  color: AppColors.muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 14),
            Text(
              'One bar does not fit a whole gym — an EZ curl bar is nearer 10, '
              'a trap bar 25. Any exercise can be given its own: open it in the '
              'exercise library and set the bar weight there. This is what the '
              'rest of them use.',
              style: TextStyle(
                  color: AppColors.muted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
