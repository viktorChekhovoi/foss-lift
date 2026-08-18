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

/// The settings that are about training: the weight unit, the bar and plates,
/// the set-video caps, the warm-up rung count and the layoff rules.
///
/// How the app *looks* — theme, text size, language — is the other half, and
/// lives on `appearance_screen.dart`. The split is by what a setting is about,
/// which is the only thing somebody looking for one has to go on.
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
              // Tapping the unit you are already on is not a switch and gets no
              // dialog about one.
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
              onTap: () => context.push('${branchRoot(context)}/settings/bar'),
            ),
            const SizedBox(height: 10),
            SettingRow(
              label: l10n.settingsAvailablePlates,
              value: l10n.settingsPlateSizes(plates.plates.length),
              onTap: () => context.push('${branchRoot(context)}/settings/plates'),
            ),
            // Nothing to size or cap on a build that cannot film. The whole
            // section goes rather than showing 0 B and a quality picker for a
            // camera that is never offered.
            if (ref.watch(capabilitiesProvider).setVideos) ...[
              const SizedBox(height: 28),
              Text(l10n.settingsSetVideos,
                  style: sectionLabelStyle()),
              const SizedBox(height: 10),
              SettingRow(
                label: l10n.settingsStorage,
                value: fmtBytes(ref.watch(videoUsageProvider).value ?? 0),
                onTap: () => context.push('${branchRoot(context)}/settings/videos'),
              ),
            ],
            const SizedBox(height: 28),
            builderCard(l10n.settingsWarmups, [
              builderGrid([
                BuilderField(
                  label: l10n.settingsWarmupSets,
                  // The one state worth naming: a stepper reading 0 has stopped
                  // being a count.
                  note: warmupSets == 0 ? l10n.settingsWarmupsOff : null,
                  child: NumberStepper(
                    value: warmupSets,
                    // None is an answer: somebody who warms up before the app is
                    // open wants the app to stop suggesting it, everywhere,
                    // rather than to shut a group on every exercise.
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
                    // Zero is not a threshold, it is the feature switched off,
                    // so it gets a word rather than a number.
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
            // Last on the screen, and the only destructive thing on it. Nothing
            // that empties the log belongs beside a stepper somebody is
            // adjusting.
            const SizedBox(height: 36),
            Text(l10n.settingsStartingOver, style: sectionLabelStyle()),
            const SizedBox(height: 10),
            _DangerRow(
              label: l10n.settingsResetProfile,
              onTap: () => _resetProfile(context, ref, l10n),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empties the app back to a fresh install, once the user has agreed to it in
/// those words.
///
/// The running-workout refusal comes first and comes before the dialog: a
/// session lives in memory until Finish, so wiping the database under one would
/// throw it away as a side effect of a button that says nothing about sessions.
/// The same refusal restore is held to, in the same sentence.
///
/// The clips are files rather than rows, so the database cannot take them with
/// it — see [AppDatabase.resetEverything]. A build that cannot film has none to
/// remove, and no store to ask.
Future<void> _resetProfile(
    BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
  void say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  if (ref.read(activeWorkoutProvider) != null) {
    say(l10n.backupFinishWorkoutFirst);
    return;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(l10n.settingsResetTitle),
      content: Text(
        l10n.settingsResetBody,
        style: TextStyle(color: AppColors.muted, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(l10n.settingsResetConfirm,
              style: TextStyle(color: AppColors.gold)),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  await ref.read(databaseProvider).resetEverything();
  if (ref.read(capabilitiesProvider).setVideos) {
    await ref.read(setVideoStoreProvider).deleteEverything();
  }
  if (!context.mounted) return;
  say(l10n.settingsResetDone);
}

/// A settings row that destroys something. The gold the app warns in, and no
/// value beside the label — there is nothing this one is currently set to.
class _DangerRow extends StatelessWidget {
  const _DangerRow({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => settingRowShell(
        onTap: onTap,
        border: AppColors.gold.withValues(alpha: 0.55),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ),
            ),
            Icon(Icons.delete_outline, size: 20, color: AppColors.gold),
          ],
        ),
      );
}

/// The deepest a layoff can ever cut, given the per-period rate — the periods
/// stack only [kMaxLayoffPeriods] deep and stop at [kMaxLayoffCutPercent].
int _maxCut(int percent) {
  final stacked = kMaxLayoffPeriods * percent;
  return stacked > kMaxLayoffCutPercent ? kMaxLayoffCutPercent : stacked;
}

/// Changes the unit, once the user has seen what it will do.
///
/// History is never rewritten — a set stays the weight it was lifted at. What
/// does move is the configuration: `AppDatabase.setWeightUnit` snaps each
/// slot's target to a weight the new unit can be loaded to, and swaps any step
/// rate still sitting on the old unit's default. The plate rack for the new
/// unit is whatever was set up for it (a standard gym, until it is edited).
/// Both are worth going to look at, so the dialog says so rather than letting
/// them be discovered mid-set.
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

/// One of the two unit rows: its label, its suffix, and whether it is the one
/// in force. Lives here because the settings screen is where the unit normally
/// changes, and is reused by the first-run question — one row drawn the same
/// way in both places, so the choice looks like the same choice.
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
