import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../widgets/builder_widgets.dart';

/// Read-only detail for one library exercise: how to do it + a demo link.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});
  final int exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(exerciseLibraryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise')),
      body: SafeArea(
        top: false,
        child: library.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          error: (e, _) =>
              Center(child: Text('$e', style: const TextStyle(color: AppColors.muted))),
          data: (all) {
            Exercise? ex;
            for (final e in all) {
              if (e.id == exerciseId) {
                ex = e;
                break;
              }
            }
            if (ex == null) {
              return const Center(
                child: Text('This exercise no longer exists.',
                    style: TextStyle(color: AppColors.muted)),
              );
            }
            return _Body(exercise: ex);
          },
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(exercise.name,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(exercise.muscleGroup),
            _Chip(exercise.equipment),
            if (exercise.isCustom) _Chip('Custom', accent: true),
          ],
        ),
        const SizedBox(height: 22),
        Text('LOADED AS',
            style: kMono.copyWith(
                fontSize: 11, letterSpacing: 1.2, color: AppColors.faint)),
        const SizedBox(height: 8),
        // Editable here rather than only on the create form: the starter
        // library is where the barbell lifts live, and whether your gym's bench
        // has a 20 kg bar or a fixed-weight EZ curl bar is a fact the seed
        // cannot know. Writes straight through — there is nothing to save.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in WeightType.values)
              _Chip(
                t.label,
                accent: t == exercise.weightType,
                onTap: t == exercise.weightType
                    ? null
                    : () => ref
                        .read(databaseProvider)
                        .setExerciseWeightType(exercise.id, t),
              ),
          ],
        ),
        if (exercise.weightType == WeightType.bar) ...[
          const SizedBox(height: 12),
          _BarWeightRow(exercise: exercise),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => context.push('/settings/plates'),
            child: Text('Available plates →',
                style: kMono.copyWith(
                    fontSize: 11.5, height: 1.5, color: AppColors.accent)),
          ),
        ],
        const SizedBox(height: 22),
        Text('HOW TO',
            style: kMono.copyWith(
                fontSize: 11, letterSpacing: 1.2, color: AppColors.faint)),
        const SizedBox(height: 8),
        Text(
          exercise.instructions.isEmpty
              ? 'No instructions yet.'
              : exercise.instructions,
          style: const TextStyle(fontSize: 15, height: 1.55, color: AppColors.text),
        ),
        if (exercise.videoUrl != null) ...[
          const SizedBox(height: 24),
          Text('DEMO',
              style: kMono.copyWith(
                  fontSize: 11, letterSpacing: 1.2, color: AppColors.faint)),
          const SizedBox(height: 8),
          _VideoLink(url: exercise.videoUrl!),
        ],
      ],
    );
  }
}

/// This exercise's bar, and the gym default it falls back to.
///
/// Lives on the exercise rather than in settings because a gym is not one bar:
/// the EZ curl bar is 10, the trap bar 25, and both are facts about the
/// movement, not about the app.
class _BarWeightRow extends ConsumerWidget {
  const _BarWeightRow({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final fallback = ref.watch(plateSettingsProvider).barKg;
    final own = exercise.barWeight;
    final u = unitLabel(unit);

    Future<void> edit() async {
      final choice = await askWeight(
        context,
        title: 'Bar for ${exercise.name}',
        unit: unit,
        initialKg: own ?? fallback,
        defaultLabel: own == null ? null : 'Use default',
      );
      if (choice == null) return;
      await ref
          .read(databaseProvider)
          .setExerciseBarWeight(exercise.id, choice.kg);
    }

    return SettingRow(
      label: 'Bar weight',
      note: own == null ? 'the gym default' : 'set for this exercise',
      value: '${fmtPlateWeight(toDisplayWeight(own ?? fallback, unit))} $u',
      onTap: edit,
    );
  }
}

/// The demo link: opens in whatever the phone uses for the web.
///
/// Handing the URL to another app is the only outward-facing thing Foss Lift
/// does, and it is still the browser that does the talking — the app asks for
/// no network permission of its own. The address is printed underneath so you
/// can see where you are being sent before you tap, and long-press copies it
/// for the case where there is nothing installed to open it with.
class _VideoLink extends StatelessWidget {
  const _VideoLink({required this.url});
  final String url;

  Future<void> _copy(BuildContext context, {required String reason}) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(reason)));
  }

  Future<void> _open(BuildContext context) async {
    // externalApplication, not the in-app browser: a demo video belongs in
    // YouTube or the browser, not in a web view bolted onto a workout tracker.
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      // No browser, or the intent was refused. Falling back to the clipboard
      // leaves the user somewhere they can still act, rather than with a tap
      // that silently did nothing.
      await _copy(context, reason: 'Nothing here can open links — copied it '
          'to the clipboard instead');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.line),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.play_circle_outline, color: AppColors.accent),
            label: const Text('Watch a demo'),
            onPressed: () => _open(context),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onLongPress: () =>
              _copy(context, reason: 'Demo link copied to clipboard'),
          child: Text(url,
              style: kMono.copyWith(fontSize: 12, color: AppColors.muted)),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {this.accent = false, this.onTap});
  final String label;
  final bool accent;

  /// Null for a chip that only states a fact (the muscle group, the equipment).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: accent ? AppColors.accent.withValues(alpha: 0.14) : AppColors.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent ? AppColors.accent : AppColors.line),
      ),
      child: Text(label,
          style: kMono.copyWith(
              fontSize: 12,
              color: accent ? AppColors.accent : AppColors.muted,
              fontWeight: FontWeight.w600)),
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
  }
}
