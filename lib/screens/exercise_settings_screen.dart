import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../data/warmup.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../util/units.dart';
import '../widgets/builder_widgets.dart';
import '../util/format.dart';

class ExerciseSettingsScreen extends ConsumerWidget {
  const ExerciseSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final plates = ref.watch(plateSettingsProvider);
    final layoff = ref.watch(layoffSettingsProvider).value ??
        (days: kDefaultLayoffDays, percent: kDefaultLayoffPercent);
    final warmupSets =
        ref.watch(defaultWarmupSetsProvider).value ?? kDefaultWarmupSets;
    final db = ref.read(databaseProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Text(l10n.settingsWeightUnit,
                style: sectionLabelStyle()),
            const SizedBox(height: 10),
            UnitOption(
              label: l10n.settingsKilograms,
              suffix: unitSuffix(l10n, 'kg'),
              selected: unit == 'kg',
              onTap: () =>
                  unit == 'kg' ? null : _switchUnit(context, l10n, db, 'kg'),
            ),
            const SizedBox(height: 10),
            UnitOption(
              label: l10n.settingsPounds,
              suffix: unitSuffix(l10n, 'lb'),
              selected: unit == 'lb',
              onTap: () =>
                  unit == 'lb' ? null : _switchUnit(context, l10n, db, 'lb'),
            ),
            const SizedBox(height: 28),
            Text(l10n.settingsBarAndPlates,
                style: sectionLabelStyle()),
            const SizedBox(height: 10),
            SettingRow(
              label: l10n.settingsDefaultBar,
              value: l10n.unitWeightShort(
                  fmtWeight(toDisplayWeight(plates.barKg, unit)),
                  unitSuffix(l10n, unit)),
              onTap: () => context.push(linkPath(context, '/settings/bar')),
            ),
            const SizedBox(height: 10),
            SettingRow(
              label: l10n.settingsAvailablePlates,
              value: l10n.settingsPlateSizes(plates.plates.length),
              onTap: () => context.push(linkPath(context, '/settings/plates')),
            ),
            if (ref.watch(capabilitiesProvider).setVideos) ...[
              const SizedBox(height: 28),
              Text(l10n.settingsSetVideos,
                  style: sectionLabelStyle()),
              const SizedBox(height: 10),
              SettingRow(
                label: l10n.settingsStorage,
                value: fmtBytes(ref.watch(videoUsageProvider).value ?? 0),
                onTap: () => context.push(linkPath(context, '/settings/videos')),
              ),
            ],
            const SizedBox(height: 28),
            builderCard(l10n.settingsWarmups, [
              builderGrid([
                BuilderField(
                  label: l10n.settingsWarmupSets,
                  note: warmupSets == 0 ? l10n.settingsWarmupsOff : null,
                  child: NumberStepper(
                    value: warmupSets,
                    min: 0,
                    max: kMaxWarmupSets,
                    onChanged: db.setDefaultWarmupSets,
                  ),
                ),
              ]),
            ]),
            const SizedBox(height: 28),
            builderCard(l10n.settingsDeload, [
              builderGrid([
                BuilderField(
                  label: l10n.settingsDeloadAfter,
                  child: NumberStepper(
                    value: layoff.days,
                    suffix: l10n.settingsDeloadDaySuffix,
                    min: 7,
                    max: 120,
                    step: 7,
                    isEmpty: layoff.days == 0,
                    emptyLabel: l10n.settingsDeloadOff,
                    onClear: () => db.setLayoffDays(0),
                    onChanged: db.setLayoffDays,
                  ),
                ),
                BuilderField(
                  label: l10n.settingsDeloadCut,
                  note: l10n.settingsDeloadPerPeriod,
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
                  ? l10n.settingsDeloadOffNote
                  : l10n.settingsDeloadOnNote(layoff.days, layoff.percent,
                      layoff.days * 2, _maxCut(layoff.percent)),
              style: TextStyle(
                  color: AppColors.muted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

int _maxCut(int percent) {
  final stacked = kMaxLayoffPeriods * percent;
  return stacked > kMaxLayoffCutPercent ? kMaxLayoffCutPercent : stacked;
}

Future<void> _switchUnit(BuildContext context, AppLocalizations l10n,
    AppDatabase db, String unit) async {
  final to = unit == 'lb' ? l10n.unitPoundsWord : l10n.unitKilogramsWord;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(l10n.settingsSwitchUnitTitle(to)),
      content: Text(
        l10n.settingsSwitchUnitBody(to),
        style: TextStyle(color: AppColors.muted, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.settingsSwitchUnitConfirm(to)),
        ),
      ],
    ),
  );
  if (ok == true) await db.setWeightUnit(unit);
}

class UnitOption extends StatelessWidget {
  const UnitOption({
    super.key,
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
