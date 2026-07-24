import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

/// Browsable, searchable exercise library. Tap a row for details; the FAB adds
/// a custom exercise.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(exerciseLibraryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise library')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/library/new'),
        backgroundColor: AppColors.accent,
        foregroundColor: const Color(0xFF1A0E07),
        icon: const Icon(Icons.add),
        label: const Text('New exercise'),
      ),
      body: SafeArea(
        top: false,
        child: library.when(
          loading: () =>
              Center(child: CircularProgressIndicator(color: AppColors.accent)),
          error: (e, _) =>
              Center(child: Text('$e', style: TextStyle(color: AppColors.muted))),
          data: (all) {
            final q = _query.trim().toLowerCase();
            final list = q.isEmpty
                ? all
                : all
                    .where((e) =>
                        e.name.toLowerCase().contains(q) ||
                        e.muscleGroup.toLowerCase().contains(q) ||
                        e.equipment.toLowerCase().contains(q))
                    .toList();

            // Group by muscle, preserving the already-sorted order.
            final groups = <String, List<Exercise>>{};
            for (final e in list) {
              groups.putIfAbsent(e.muscleGroup, () => []).add(e);
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: _SearchField(onChanged: (v) => setState(() => _query = v)),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                    children: [
                      if (list.isEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(
                            child: Text('No exercises match your search.',
                                style: TextStyle(color: AppColors.muted)),
                          ),
                        ),
                      for (final entry in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
                          child: Text(
                            '${entry.key.toUpperCase()} · ${entry.value.length}',
                            style: kMono.copyWith(
                                fontSize: 11,
                                letterSpacing: 1.2,
                                color: AppColors.faint,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.line),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Column(
                            children: [
                              for (var i = 0; i < entry.value.length; i++)
                                _ExerciseTile(
                                  exercise: entry.value[i],
                                  last: i == entry.value.length - 1,
                                  onTap: () =>
                                      context.push('/exercise/${entry.value[i].id}'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Search exercises…',
        prefixIcon: Icon(Icons.search, color: AppColors.muted),
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise, required this.last, required this.onTap});
  final Exercise exercise;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(exercise.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                      if (exercise.isCustom) ...[
                        const SizedBox(width: 8),
                        _customBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(exercise.equipment,
                      style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.faint),
          ],
        ),
      ),
    );
  }

  Widget _customBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('CUSTOM',
            style: kMono.copyWith(
                fontSize: 9, letterSpacing: 0.8, color: AppColors.accent)),
      );
}
