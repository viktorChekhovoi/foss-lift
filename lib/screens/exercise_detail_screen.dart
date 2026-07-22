import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

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

class _Body extends StatelessWidget {
  const _Body({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
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

class _VideoLink extends StatelessWidget {
  const _VideoLink({required this.url});
  final String url;

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
            label: const Text('Copy demo link'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Demo link copied to clipboard')),
                );
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        SelectableText(url,
            style: kMono.copyWith(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {this.accent = false});
  final String label;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    return Container(
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
  }
}
