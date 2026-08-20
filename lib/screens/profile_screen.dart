import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme/app_theme.dart';
import '../widgets/tutorial.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workouts = ref.watch(sessionCountProvider).value ?? 0;
    final routineCount = ref.watch(routinesProvider).value?.length ?? 0;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    AppColors.accent,
                    AppColors.gold,
                    AppColors.good,
                    AppColors.accent,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface2,
                ),
                child: Icon(Icons.fitness_center_rounded, color: AppColors.text),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(l10n.profileTitle,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(l10n.profileTagline,
                style: kMono.copyWith(fontSize: 12, color: AppColors.muted)),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _PStat(
                  value: '$workouts',
                  label: l10n.commonStatWorkouts,
                  accent: true),
              const SizedBox(width: 12),
              _PStat(value: '$routineCount', label: l10n.profileStatRoutines),
            ],
          ),
          const SizedBox(height: 20),
          // Two settings screens, split by what a setting is about. This one is
          // the training half — units, the bar and the plate rack, the deload
          // rules, the set-video caps; Appearance below is how the app looks.
          _SettingsTile(
            icon: Icons.tune_rounded,
            label: l10n.settingsTitle,
            onTap: () => context.push(linkPath(context, '/settings')),
          ),
          _SettingsTile(
            icon: Icons.list_alt_rounded,
            label: l10n.profileExerciseLibrary,
            onTap: () => context.push(linkPath(context, '/library')),
          ),
          // Replays a tour on demand. It asks which one and then starts where
          // you are: every tour opens on the navigation bar, which is under
          // this screen as much as any other.
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            label: l10n.profileHelpAndTour,
            onTap: () => showTutorialPicker(context, ref),
          ),
          _SettingsTile(
            icon: Icons.brightness_6_outlined,
            label: l10n.profileAppearance,
            onTap: () => context.push(linkPath(context, '/settings/appearance')),
          ),
          // Absent where there is no filesystem to write a file to: the browser
          // build has no database file to copy and nowhere to put one.
          if (ref.watch(capabilitiesProvider).localFiles)
            _SettingsTile(
              icon: Icons.save_alt_rounded,
              label: l10n.profileBackup,
              onTap: () => context.push(linkPath(context, '/backup')),
            ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: l10n.aboutTitle,
            onTap: () => context.push(linkPath(context, '/about')),
            last: true,
          ),
        ],
      ),
    );
  }
}

class _PStat extends StatelessWidget {
  const _PStat({required this.value, required this.label, this.accent = false});
  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(
              value,
              style: kMono.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: accent ? AppColors.accent : AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: kMono.copyWith(fontSize: 10, letterSpacing: 0.8, color: AppColors.faint),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.last = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            SizedBox(width: 26, child: Icon(icon, size: 20, color: AppColors.muted)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
            Icon(Icons.chevron_right, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}
