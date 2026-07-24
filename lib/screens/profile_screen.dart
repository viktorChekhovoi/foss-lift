import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/tutorial.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              decoration: const BoxDecoration(
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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface2,
                ),
                child: const Icon(Icons.fitness_center_rounded, color: AppColors.text),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('Your profile',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text('Foss Lift — open-source workout tracker',
                style: kMono.copyWith(fontSize: 12, color: AppColors.muted)),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _PStat(value: '$workouts', label: 'Workouts', accent: true),
              const SizedBox(width: 12),
              _PStat(value: '$routineCount', label: 'Routines'),
            ],
          ),
          const SizedBox(height: 20),
          // Named for the screen, not for one thing on it: the row said "Units"
          // when units were all that was behind it, and has since collected the
          // layoff rules, the bar and the plate rack.
          _SettingsTile(
            icon: Icons.tune_rounded,
            label: 'Settings',
            onTap: () => context.push('/settings'),
          ),
          _SettingsTile(
            icon: Icons.list_alt_rounded,
            label: 'Exercise library',
            onTap: () => context.push('/library'),
          ),
          // Replays the first-run tour on demand. Jumps to Today first, where
          // its coach marks are anchored, then starts it.
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            label: 'Help & tour',
            onTap: () {
              ref.read(tutorialProvider.notifier).start();
              context.go('/today');
            },
          ),
          _SettingsTile(
            icon: Icons.cloud_outlined,
            label: 'Backup & export',
            soon: true,
          ),
          _SettingsTile(
            icon: Icons.brightness_6_outlined,
            label: 'Appearance',
            soon: true,
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'About Foss Lift',
            soon: true,
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
    this.onTap,
    this.soon = false,
    this.last = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool soon;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ??
          () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"$label" is coming soon')),
              ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            SizedBox(width: 26, child: Icon(icon, size: 20, color: AppColors.muted)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
            if (soon)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text('SOON',
                    style: kMono.copyWith(
                        fontSize: 10, letterSpacing: 1, color: AppColors.faint)),
              ),
            const Icon(Icons.chevron_right, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}
