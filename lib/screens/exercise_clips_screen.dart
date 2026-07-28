import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/exercise_stats.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/clip_label.dart';

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
    final clips = ref.watch(exerciseClipsProvider(exerciseId));
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final name = ref.watch(exerciseLibraryProvider).value?.
        where((e) => e.id == exerciseId).firstOrNull?.name;

    return Scaffold(
      appBar: AppBar(title: Text(name ?? 'Clips')),
      body: SafeArea(
        top: false,
        child: clips.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (list) => list.isEmpty
              ? _empty()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ClipRow(
                    label: clipLabel(list[i], unit),
                    onTap: () => _open(context, list[i], unit),
                  ),
                ),
        ),
      ),
    );
  }

  void _open(BuildContext context, ExerciseSetEntry set, String unit) {
    context.push(
      Uri(
        path: '/clip',
        queryParameters: {
          'path': set.videoPath!,
          'caption': clipLabel(set, unit),
          'set': '${set.setId}',
        },
      ).toString(),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'Nothing filmed yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 15),
          ),
        ),
      );
}

/// One clip in the reel: what it was, and a way in.
class _ClipRow extends StatelessWidget {
  const _ClipRow({required this.label, required this.onTap});
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
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.play_arrow_rounded,
                    color: AppColors.accent, size: 24),
              ),
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
