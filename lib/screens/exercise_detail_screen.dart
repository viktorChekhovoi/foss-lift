import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/seed_names.dart';
import '../util/units.dart';
import '../widgets/builder_widgets.dart';
import '../util/format.dart';

/// Finds the loading chips in a test — absent on a movement whose equipment
/// settles how it is loaded, where the loading is stated rather than offered.
const kLoadingChoiceKey = ValueKey('loading-choice');

/// Read-only detail for one library exercise: how to do it + a demo link.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});
  final int exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(exerciseLibraryProvider);

    // The edit pencil hangs off the app bar, so it needs the exercise before
    // the body has resolved it — hence the lookup here as well as below.
    final ex = library.value?.where((e) => e.id == exerciseId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.exerciseDetailTitle),
        actions: [
          // Only a custom exercise: the starter library's names and
          // classifications are shared vocabulary — see updateCustomExercise.
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
            _Chip(muscleGroupLabel(l10n, exercise.muscleGroup)),
            _Chip(equipmentLabel(l10n, exercise.equipment)),
            if (exercise.isCustom)
              _Chip(l10n.exerciseDetailCustomChip, accent: true),
          ],
        ),
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
            onPressed: () => context.push('/exercise/${exercise.id}/progress'),
          ),
        ),
        // Only once there is something to watch. An empty reel is a button
        // that teaches you the feature exists by disappointing you.
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
              onPressed: () => context.push('/exercise/${exercise.id}/clips'),
            ),
          ),
        ],
        const SizedBox(height: 22),
        ExerciseLoadingSection(exercise: exercise),
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

/// A caption over one of the library-property sections below.
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

/// How this movement is loaded, which bar it is over, and where its plates come
/// from.
///
/// A section rather than part of the screen, because the builder's slot sheet
/// shows the same three things: they are facts about the exercise, and a second
/// copy of them would answer the question differently within a fortnight.
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
        // A fact on a seeded barbell, dumbbell, machine or cable movement, and a
        // choice everywhere else — see `Exercise.loadingIsFixed`. A barbell curl
        // is loaded on a bar; offering three chips there invites a library where
        // it counts as bodyweight, and the one thing the seed genuinely cannot
        // know — what that bar weighs — is the row below.
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
          // Editable here rather than only on the create form: a weighted
          // pull-up and a kettlebell swing are the seed's guesses, and a
          // movement you made is yours throughout. Writes straight through —
          // there is nothing to save.
          //
          // Tapping the selected chip clears it, which is how a movement is told
          // it carries nothing — a dead hang, a push-up. No "None" chip: three
          // loadings and a way to want none of them.
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
            onTap: () => context.push('/settings/plates'),
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

/// The personal note on a movement, under its caption. Shared with the
/// builder's slot sheet for the same reason [ExerciseLoadingSection] is.
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

/// What you need to remember about this movement at your gym.
///
/// Tapping anywhere on it opens an editor — including when it is empty, which
/// is why the empty state is a line of text rather than a blank space: there
/// has to be something to aim at, and "nothing noted yet" reads as a state the
/// app meant rather than a box it failed to fill.
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

/// This exercise's bar, and the gym default it falls back to.
///
/// Lives on the exercise rather than in settings because a gym is not one bar:
/// the EZ curl bar is 10, the trap bar 25, and both are facts about the
/// movement, not about the app.
class ExerciseBarRow extends ConsumerWidget {
  const ExerciseBarRow({super.key, required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
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

    // The bar's name is the useful half — "trap bar", not "25". The weight goes
    // in the note beside where it came from, and a weight matching no bar on the
    // list still has to read as something.
    final kg = own ?? fallback;
    final named = ref.watch(barsProvider).value?.atWeight(kg);
    final weight =
        l10n.unitWeightShort(fmtWeight(toDisplayWeight(kg, unit)), u);

    return SettingRow(
      label: l10n.exerciseDetailBarWeight,
      // Two whole sentences rather than one with a word swapped in: which half
      // of the note the condition decides is not the same in every language.
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
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

  /// Null for a chip that only states a fact (the muscle group, the equipment).
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
