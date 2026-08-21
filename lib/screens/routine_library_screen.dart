import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/progression.dart';
import '../data/starter_routines.dart';
import '../l10n/app_localizations.dart';
import '../providers/db_provider.dart';
import '../theme/app_theme.dart';
import '../util/seed_names.dart';
import '../util/target_label.dart';
import '../widgets/routine_card.dart';

class RoutineLibraryScreen extends StatelessWidget {
  const RoutineLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.routineLibraryTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            for (final program in kStarterRoutines) ...[
              RoutineCard.program(
                key: ValueKey('starter-${program.key}'),
                name: program.name,
                seedKey: program.seedKey,
                colorHex: program.colorHex,
                workoutCount: program.days.length,
                scheduleDays: program.scheduleDays,
                onTap: () => context.push('/routines/library/${program.key}'),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class StarterRoutinePreviewScreen extends ConsumerWidget {
  const StarterRoutinePreviewScreen({super.key, required this.routineKey});

  final String routineKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final program = starterRoutineByKey(routineKey);
    if (program == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.routineLibraryTitle)),
        body: const SizedBox.shrink(),
      );
    }
    final name = seededName(l10n, program.seedKey, program.name);
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
                    child: Text(
                      seededDescription(
                          l10n, program.seedKey, program.description)!,
                      style: TextStyle(
                          fontSize: 14, height: 1.4, color: AppColors.muted),
                    ),
                  ),
                  for (final day in program.days) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                      child: Text(
                        seededName(l10n, kSeedWorkoutKeys[day.name], day.name),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                    _DayCard(day: day),
                    const SizedBox(height: 18),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('add-starter-routine'),
                  onPressed: () async {
                    await ref.read(databaseProvider).addStarterRoutine(program);
                    if (!context.mounted) return;
                    context.go('/routines');
                  },
                  icon: const Icon(Icons.add),
                  label: Text(l10n.routineLibraryAdd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _slotTarget(AppLocalizations l10n, StarterSlot slot) {
  if (slot.cycle.isNotEmpty) return rowsTargetLabel(l10n, slot.cycle.first);
  return setsTargetLabel(
    l10n,
    sets: slot.sets,
    progression:
        slot.holdSeconds == null ? ProgressionMode.reps : ProgressionMode.time,
    toFailure: false,
    holdSeconds: slot.holdSeconds ?? 0,
    repsMin: slot.repsMin,
    repsMax: slot.repsMax,
  );
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});

  final StarterDay day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final (i, slot) in day.items.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                border: i == day.items.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      seededName(l10n, kSeedExerciseKeys[slot.exercise],
                          slot.exercise),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _slotTarget(l10n, slot),
                    style: kMono.copyWith(
                      fontSize: 13,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
