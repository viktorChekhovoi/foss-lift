import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/database.dart';
import '../data/warmup.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme/app_theme.dart';
import '../util/seed_names.dart';
import '../util/units.dart';
import '../widgets/builder_widgets.dart';
import '../util/format.dart';

const kLoadingChoiceKey = ValueKey('loading-choice');

const kUnitChoiceKey = ValueKey('unit-choice');

const kWarmupCountKey = ValueKey('exercise-warmup-count');

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});
  final int exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(exerciseLibraryProvider);

    final ex = library.value?.where((e) => e.id == exerciseId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.exerciseDetailTitle),
        actions: [
          if (ex != null && ex.isCustom)
            IconButton(
              tooltip: l10n.commonEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/exercise/$exerciseId/edit'),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: library.when(
          loading: () =>
              Center(child: CircularProgressIndicator(color: AppColors.accent)),
          error: (e, _) => Center(
            child: Text('$e', style: TextStyle(color: AppColors.muted)),
          ),
          data: (all) {
            Exercise? ex;
            for (final e in all) {
              if (e.id == exerciseId) {
                ex = e;
                break;
              }
            }
            if (ex == null) {
              return Center(
                child: Text(
                  l10n.commonExerciseGone,
                  style: TextStyle(color: AppColors.muted),
                ),
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
    final l10n = AppLocalizations.of(context);
    final clipCount =
        ref.watch(exerciseClipsProvider(exercise.id)).value?.length ?? 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          seededName(l10n, exercise.seedKey, exercise.name),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final group in exercise.muscles.primary)
              _Chip(muscleGroupLabel(l10n, group)),
            _Chip(equipmentLabel(l10n, exercise.equipment)),
            if (exercise.isCustom)
              _Chip(l10n.exerciseDetailCustomChip, accent: true),
          ],
        ),
        if (exercise.muscles.secondary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.exerciseMusclesAssisted,
                style: kMono.copyWith(fontSize: 11, color: AppColors.muted),
              ),
              for (final group in exercise.muscles.secondary)
                _Chip(muscleGroupLabel(l10n, group)),
            ],
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: BorderSide(color: AppColors.line),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(Icons.show_chart, color: AppColors.accent),
            label: Text(l10n.commonProgress),
            onPressed: () => context.push(
                linkPath(context, '/exercise/${exercise.id}/progress')),
          ),
        ),
        if (clipCount > 0) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                side: BorderSide(color: AppColors.line),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(Icons.videocam_rounded, color: AppColors.accent),
              label: Text(l10n.commonClipCount(clipCount)),
              onPressed: () => context.push(
                  linkPath(context, '/exercise/${exercise.id}/clips')),
            ),
          ),
        ],
        const SizedBox(height: 22),
        ExerciseLoadingSection(exercise: exercise),
        const SizedBox(height: 22),
        _UnitSection(exercise: exercise),
        if ((ref.watch(defaultWarmupSetsProvider).value ?? kDefaultWarmupSets) >
            0) ...[
          const SizedBox(height: 22),
          _WarmupSection(exercise: exercise),
        ],
        const SizedBox(height: 22),
        ExerciseNoteSection(exercise: exercise),
        if (exercise.videoUrl != null) ...[
          const SizedBox(height: 22),
          Text(
            l10n.exerciseDetailDemo,
            style: kMono.copyWith(
              fontSize: 11,
              letterSpacing: 1.2,
              color: AppColors.faint,
            ),
          ),
          const SizedBox(height: 8),
          _VideoLink(url: exercise.videoUrl!),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: kMono.copyWith(
      fontSize: 11,
      letterSpacing: 1.2,
      color: AppColors.faint,
    ),
  );
}

class ExerciseLoadingSection extends ConsumerWidget {
  const ExerciseLoadingSection({super.key, required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionLabel(l10n.exerciseDetailLoadedAs),
        const SizedBox(height: 8),
        if (exercise.loadingIsFixed)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              weightTypeLabel(l10n, exercise.weightType),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          Wrap(
            key: kLoadingChoiceKey,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in WeightType.loadable)
                _Chip(
                  weightTypeLabel(l10n, t),
                  accent: t == exercise.weightType,
                  onTap: () => ref
                      .read(databaseProvider)
                      .setExerciseWeightType(
                        exercise.id,
                        t == exercise.weightType ? WeightType.none : t,
                      ),
                ),
            ],
          ),
        if (exercise.weightType == WeightType.bar) ...[
          const SizedBox(height: 12),
          ExerciseBarRow(exercise: exercise),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => context.push(linkPath(context, '/settings/plates')),
            child: Text(
              l10n.exerciseDetailAvailablePlates,
              style: kMono.copyWith(
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _UnitSection extends ConsumerWidget {
  const _UnitSection({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final appUnit = ref.watch(weightUnitProvider).value ?? 'kg';
    final unit = unitForExercise(appUnit, exercise.unitOverride);

    Future<void> pick(String to) async {
      if (to == unit) return;
      final word = to == 'lb' ? l10n.unitPoundsWord : l10n.unitKilogramsWord;
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(l10n.settingsSwitchUnitTitle(word)),
          content: Text(
            l10n.exerciseDetailUnitSwitchBody(word),
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.settingsSwitchUnitConfirm(word)),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await ref
          .read(databaseProvider)
          .setExerciseUnit(exercise.id, to == appUnit ? null : to);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionLabel(l10n.exerciseDetailUnit),
        const SizedBox(height: 8),
        Wrap(
          key: kUnitChoiceKey,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final u in const ['kg', 'lb'])
              _Chip(
                u == 'lb' ? l10n.settingsPounds : l10n.settingsKilograms,
                accent: u == unit,
                onTap: () => pick(u),
              ),
          ],
        ),
      ],
    );
  }
}

class _WarmupSection extends ConsumerWidget {
  const _WarmupSection({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final appWide =
        ref.watch(defaultWarmupSetsProvider).value ?? kDefaultWarmupSets;
    final own = exercise.warmupSets;
    final db = ref.read(databaseProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionLabel(l10n.exerciseDetailWarmups),
        const SizedBox(height: 8),
        Row(
          children: [
            BuilderField(
              label: l10n.settingsWarmupSets,
              note: warmupCountFor(appWide, own) == 0
                  ? l10n.settingsWarmupsOff
                  : null,
              child: NumberStepper(
                key: kWarmupCountKey,
                value: warmupCountFor(appWide, own),
                min: 0,
                max: kMaxWarmupSets,
                onChanged: (n) => db.setExerciseWarmupSets(exercise.id, n),
              ),
            ),
            const Spacer(),
            if (own != null)
              GestureDetector(
                onTap: () => db.setExerciseWarmupSets(exercise.id, null),
                child: Text(
                  l10n.exerciseDetailUseDefault,
                  style: kMono.copyWith(
                    fontSize: 11.5,
                    height: 1.5,
                    color: AppColors.accent,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class ExerciseNoteSection extends StatelessWidget {
  const ExerciseNoteSection({super.key, required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionLabel(AppLocalizations.of(context).exerciseDetailMyNote),
        const SizedBox(height: 8),
        _NoteBlock(exercise: exercise),
      ],
    );
  }
}

class _NoteBlock extends ConsumerWidget {
  const _NoteBlock({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final note = exercise.notes;

    Future<void> edit() async {
      final written = await askNote(
        context,
        title: seededName(l10n, exercise.seedKey, exercise.name),
        initial: note,
      );
      if (written == null) return;
      await ref.read(databaseProvider).setExerciseNotes(exercise.id, written);
    }

    return GestureDetector(
      onTap: edit,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                note ?? l10n.exerciseDetailNoteEmpty,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: note == null ? AppColors.faint : AppColors.text,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              note == null ? Icons.add : Icons.edit_outlined,
              size: 18,
              color: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

class ExerciseBarRow extends ConsumerWidget {
  const ExerciseBarRow({super.key, required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unit = unitForExercise(
      ref.watch(weightUnitProvider).value ?? 'kg',
      exercise.unitOverride,
    );
    final fallback = ref.watch(plateSettingsProvider).barKg;
    final own = exercise.barWeight;
    final u = unitSuffix(l10n, unit);

    Future<void> edit() async {
      final choice = await askBar(
        context,
        title: l10n.exerciseDetailBarFor(
          seededName(l10n, exercise.seedKey, exercise.name),
        ),
        unit: unit,
        currentKg: own ?? fallback,
        defaultLabel: own == null ? null : l10n.exerciseDetailUseDefault,
      );
      if (choice == null) return;
      await ref
          .read(databaseProvider)
          .setExerciseBarWeight(exercise.id, choice.kg);
    }

    final kg = own ?? fallback;
    final named = ref.watch(barsProvider).value?.atWeight(kg);
    final weight =
        l10n.unitWeightShort(fmtWeight(toDisplayWeight(kg, unit)), u);

    return SettingRow(
      label: l10n.exerciseDetailBarWeight,
      note: own == null
          ? l10n.exerciseDetailBarNoteDefault(weight)
          : l10n.exerciseDetailBarNoteOwn(weight),
      value: named == null
          ? weight
          : seededName(l10n, named.seedKey, named.name),
      onTap: edit,
    );
  }
}

class _VideoLink extends StatelessWidget {
  const _VideoLink({required this.url});
  final String url;

  Future<void> _copy(BuildContext context, {required String reason}) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
  }

  Future<void> _open(BuildContext context) async {
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
      await _copy(
        context,
        reason: AppLocalizations.of(context).exerciseDetailNoOpener,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: BorderSide(color: AppColors.line),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(Icons.play_circle_outline, color: AppColors.accent),
            label: Text(l10n.exerciseDetailWatchDemo),
            onPressed: () => _open(context),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onLongPress: () =>
              _copy(context, reason: l10n.exerciseDetailLinkCopied),
          child: Text(
            url,
            style: kMono.copyWith(fontSize: 12, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {this.accent = false, this.onTap});
  final String label;
  final bool accent;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.accent.withValues(alpha: 0.14)
            : AppColors.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent ? AppColors.accent : AppColors.line),
      ),
      child: Text(
        label,
        style: kMono.copyWith(
          fontSize: 12,
          color: accent ? AppColors.accent : AppColors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
  }
}
