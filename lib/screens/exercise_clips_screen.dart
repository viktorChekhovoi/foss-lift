import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/exercise_stats.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/clip_label.dart';
import '../util/seed_names.dart';
import '../util/units.dart';

/// Every clip of one movement, newest first.
///
/// This is the view the whole feature is for: your squat over months, in one
/// place, so today's depth can be held against the same lift at a lighter
/// weight in March. A clip filed only under the session it happened in would be
/// a clip nobody ever finds again.
class ExerciseClipsScreen extends ConsumerWidget {
  const ExerciseClipsScreen({super.key, required this.exerciseId});
  final int exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final clips = ref.watch(exerciseClipsProvider(exerciseId));
    final exercise = ref.watch(exerciseLibraryProvider).value?.
        where((e) => e.id == exerciseId).firstOrNull;
    // Every clip here is the same movement, so every label is read in that
    // movement's unit — the reel exists to be held against itself.
    final unit = unitForExercise(
      ref.watch(weightUnitProvider).value ?? 'kg',
      exercise?.unitOverride,
    );
    final name = exercise == null
        ? null
        : seededName(l10n, exercise.seedKey, exercise.name);

    return Scaffold(
      appBar: AppBar(title: Text(name ?? l10n.exerciseClipsTitle)),
      body: SafeArea(
        top: false,
        child: clips.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (list) => list.isEmpty
              ? _empty(l10n)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ClipRow(
                    clipPath: list[i].videoPath!,
                    label: clipLabel(l10n, list[i], unit),
                    onTap: () => _open(context, l10n, list[i], unit),
                  ),
                ),
        ),
      ),
    );
  }

  void _open(BuildContext context, AppLocalizations l10n, ExerciseSetEntry set,
      String unit) {
    context.push(
      Uri(
        path: '/clip',
        queryParameters: {
          'path': set.videoPath!,
          'caption': clipLabel(l10n, set, unit),
          'set': '${set.setId}',
        },
      ).toString(),
    );
  }

  Widget _empty(AppLocalizations l10n) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            l10n.exerciseClipsEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 15),
          ),
        ),
      );
}

/// One clip in the reel: what it was, a frame of it, and a way in.
class _ClipRow extends StatelessWidget {
  const _ClipRow({
    required this.clipPath,
    required this.label,
    required this.onTap,
  });
  final String clipPath;
  final String label;
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              _Still(clipPath: clipPath),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: kMono.copyWith(fontSize: 13, color: AppColors.text),
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}

/// A frame of the clip, or the play symbol until there is one.
///
/// Six squat sets should look like six squats rather than six identical
/// symbols — picking the session you meant out of the list is what the reel is
/// for. A clip the decoder will not read keeps the symbol and loses nothing
/// else.
class _Still extends ConsumerWidget {
  const _Still({required this.clipPath});
  final String clipPath;

  static const double _width = 62;
  static const double _height = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final still = ref.watch(clipStillProvider(clipPath)).value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: _width,
        height: _height,
        alignment: Alignment.center,
        color: AppColors.accent.withValues(alpha: 0.12),
        child: still == null
            ? Icon(Icons.play_arrow_rounded, color: AppColors.accent, size: 24)
            : Image.file(
                still,
                width: _width,
                height: _height,
                fit: BoxFit.cover,
                // A frame that decoded and then would not draw — a file
                // truncated by a crash mid-write — is the same to the reader as
                // one that never decoded.
                errorBuilder: (_, _, _) => Icon(Icons.play_arrow_rounded,
                    color: AppColors.accent, size: 24),
              ),
      ),
    );
  }
}
