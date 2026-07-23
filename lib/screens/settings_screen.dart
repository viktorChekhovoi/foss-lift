import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../widgets/builder_widgets.dart';

/// App preferences: the weight unit, the bar and plates, and the layoff rules.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final plates = ref.watch(plateSettingsProvider);
    final layoff = ref.watch(layoffSettingsProvider).value ??
        (days: kDefaultLayoffDays, percent: kDefaultLayoffPercent);
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Text('WEIGHT UNIT',
                style: kMono.copyWith(
                    fontSize: 11, letterSpacing: 1.2, color: AppColors.faint)),
            const SizedBox(height: 10),
            _UnitOption(
              label: 'Kilograms',
              suffix: 'kg',
              selected: unit == 'kg',
              onTap: () => db.setWeightUnit('kg'),
            ),
            const SizedBox(height: 10),
            _UnitOption(
              label: 'Pounds',
              suffix: 'lb',
              selected: unit == 'lb',
              onTap: () => db.setWeightUnit('lb'),
            ),
            const SizedBox(height: 14),
            Text(
              'Weights are stored internally and converted on the fly, so '
              'switching units never rewrites your history.',
              style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            Text('BAR & PLATES',
                style: kMono.copyWith(
                    fontSize: 11, letterSpacing: 1.2, color: AppColors.faint)),
            const SizedBox(height: 10),
            _NavRow(
              label: 'Bar and plate rack',
              value: '${fmtPlateWeight(toDisplayWeight(plates.barKg, unit))} '
                  '${unitLabel(unit)} bar · '
                  '${plates.plates.length} plate '
                  '${plates.plates.length == 1 ? 'size' : 'sizes'}',
              onTap: () => context.push('/settings/plates'),
            ),
            const SizedBox(height: 14),
            Text(
              'Exercises marked as loaded on a bar show what goes on each side '
              'of it, worked out from these. Until you change anything, a '
              'standard $unit gym is assumed.',
              style: const TextStyle(
                  color: AppColors.muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            Text('COMING BACK FROM A LAYOFF',
                style: kMono.copyWith(
                    fontSize: 11, letterSpacing: 1.2, color: AppColors.faint)),
            const SizedBox(height: 10),
            builderCard('Deload after time off', [
              builderGrid([
                BuilderField(
                  label: 'After',
                  child: NumberStepper(
                    value: layoff.days,
                    suffix: 'd',
                    min: 7,
                    max: 120,
                    step: 7,
                    // Zero is not a threshold, it is the feature switched off,
                    // so it gets a word rather than a number.
                    isEmpty: layoff.days == 0,
                    emptyLabel: 'Off',
                    onClear: () => db.setLayoffDays(0),
                    onChanged: db.setLayoffDays,
                  ),
                ),
                BuilderField(
                  label: 'Cut',
                  note: 'per period',
                  child: NumberStepper(
                    value: layoff.percent,
                    suffix: '%',
                    min: 5,
                    max: 50,
                    step: 5,
                    onChanged: db.setLayoffPercent,
                  ),
                ),
              ]),
            ]),
            const SizedBox(height: 14),
            Text(
              layoff.days == 0
                  ? 'Returning to a workout after any gap starts it at the '
                      'weight you left it at.'
                  : 'Go ${layoff.days} days without a workout and starting it '
                      'again offers to cut its targets by ${layoff.percent}% — '
                      'twice that after ${layoff.days * 2} days, and no more '
                      'than ${_maxCut(layoff.percent)}% however long you are '
                      'away. You are always asked first, and logged history is '
                      'never changed.',
              style: const TextStyle(
                  color: AppColors.muted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// The deepest a layoff can ever cut, given the per-period rate — the periods
/// stack only [kMaxLayoffPeriods] deep and stop at [kMaxLayoffCutPercent].
int _maxCut(int percent) {
  final stacked = kMaxLayoffPeriods * percent;
  return stacked > kMaxLayoffCutPercent ? kMaxLayoffCutPercent : stacked;
}

/// A settings row that opens a screen of its own, with today's answer on it.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
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
                    const SizedBox(height: 3),
                    Text(value,
                        style: kMono.copyWith(
                            fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.faint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitOption extends StatelessWidget {
  const _UnitOption({
    required this.label,
    required this.suffix,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String suffix;
  final bool selected;
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
            color: selected ? AppColors.accent.withValues(alpha: 0.10) : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text('$label · $suffix',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? AppColors.accent : AppColors.faint,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
