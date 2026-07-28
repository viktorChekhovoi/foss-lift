import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/text_scale.dart';
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
              // Tapping the unit you are already on is not a switch and gets no
              // dialog about one.
              onTap: () =>
                  unit == 'kg' ? null : _switchUnit(context, db, 'kg'),
            ),
            const SizedBox(height: 10),
            _UnitOption(
              label: 'Pounds',
              suffix: 'lb',
              selected: unit == 'lb',
              onTap: () =>
                  unit == 'lb' ? null : _switchUnit(context, db, 'lb'),
            ),
            const SizedBox(height: 28),
            Text('BAR & PLATES',
                style: kMono.copyWith(
                    fontSize: 11, letterSpacing: 1.2, color: AppColors.faint)),
            const SizedBox(height: 10),
            SettingRow(
              label: 'Default bar weight',
              value: '${fmtPlateWeight(toDisplayWeight(plates.barKg, unit))} '
                  '${unitLabel(unit)}',
              onTap: () => context.push('/settings/bar'),
            ),
            const SizedBox(height: 10),
            SettingRow(
              label: 'Available plates',
              value: '${plates.plates.length} '
                  '${plates.plates.length == 1 ? 'size' : 'sizes'}',
              onTap: () => context.push('/settings/plates'),
            ),
            const SizedBox(height: 28),
            Text('SET VIDEOS',
                style: kMono.copyWith(
                    fontSize: 11, letterSpacing: 1.2, color: AppColors.faint)),
            const SizedBox(height: 10),
            SettingRow(
              label: 'Quality & storage',
              value: fmtBytes(ref.watch(videoUsageProvider).value ?? 0),
              onTap: () => context.push('/settings/videos'),
            ),
            const SizedBox(height: 28),
            Text('TEXT SIZE',
                style: kMono.copyWith(
                    fontSize: 11, letterSpacing: 1.2, color: AppColors.faint)),
            const SizedBox(height: 10),
            _ScaleChoices(
              chosen: ref.watch(textScaleProvider).value ?? 1.0,
              onSelect: db.setTextScale,
            ),
            const SizedBox(height: 12),
            Text(
              'On top of your phone’s own text size, which the app follows '
              'either way.',
              style: TextStyle(
                  color: AppColors.muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
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
                      'away.',
              style: TextStyle(
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

/// Changes the unit, once the user has seen what it will do.
///
/// Stored weights are never rewritten — history in particular has to stay the
/// weight it was lifted at. The cost of that is arithmetic in plain sight: a
/// 100 kg squat reads as 220.5 lb, which is not a bar anybody loads, and the
/// plate rack for the new unit is whatever was set up for it (a standard gym,
/// until it is edited). Both are things to go and look at, so the dialog says
/// so rather than letting them be discovered mid-set.
Future<void> _switchUnit(
    BuildContext context, AppDatabase db, String unit) async {
  final to = unit == 'lb' ? 'pounds' : 'kilograms';
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Switch to $to?'),
      content: Text(
        'Your exercise weights and available plates are converted to $to '
        'automatically. Some conversions may need to be manually adjusted.',
        style: TextStyle(color: AppColors.muted, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Use $to'),
        ),
      ],
    ),
  );
  if (ok == true) await db.setWeightUnit(unit);
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

/// The four text-size steps, each previewing itself.
///
/// A chip drawn at the size it selects is the only honest preview: the point of
/// the control is how big the words get, and a row of same-sized labels says
/// nothing about that.
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
        for (final entry in kTextScaleChoices.entries)
          GestureDetector(
            onTap: () => onSelect(entry.value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (entry.value - chosen).abs() < 0.001
                    ? AppColors.accent.withValues(alpha: 0.14)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: (entry.value - chosen).abs() < 0.001
                      ? AppColors.accent
                      : AppColors.line,
                ),
              ),
              child: Text(
                entry.key,
                // Its own scale, not the page's: the chip shows what it does.
                textScaler: TextScaler.linear(entry.value),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: (entry.value - chosen).abs() < 0.001
                      ? AppColors.accent
                      : AppColors.muted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
