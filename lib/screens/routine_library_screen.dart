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

/// The programs the app ships, offered rather than installed.
///
/// The list is [kStarterRoutines] — code, not rows, so there is nothing to load
/// and nothing that can differ from one phone to the next. Each program is drawn
/// with the same card the routine list uses, because it is the same thing: what
/// separates them is that one of these is not yours until you say so.
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

/// One shipped program, in full, with the button that makes a copy of it.
///
/// Every training day and every exercise in it: what you are agreeing to, before
/// anything is written. Backing out writes nothing at all, which is the whole
/// reason this screen is between the library and your routine list.
class StarterRoutinePreviewScreen extends ConsumerWidget {
  const StarterRoutinePreviewScreen({super.key, required this.routineKey});

  final String routineKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final program = starterRoutineByKey(routineKey);
    // A key this build does not ship — a link from a build that had a program
    // this one has dropped. The library is one tap back.
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
                  // What the program is, before the days it is made of: the
                  // preview is where the choice between nine of them is made.
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
                    // The day's own name, not a heading made of it: these are
                    // "Workout A" and "Upper 1", and the small capitals the
                    // section headings use would be shouting a proper noun.
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
                    // Back to the list it just landed in — the row being there
                    // is the confirmation, so nothing has to say so.
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

/// What one slot of a shipped program is aiming at, in words.
///
/// A cycled slot has no set count of its own — its week is written out in full,
/// so how many rows it has is how many sets there are — and its rep targets
/// differ from one another. So the week it opens on is listed the way the day
/// screen and the builder list it, rather than multiplied: "5/5/5+". A
/// multiplication here has to read the two numbers a cycled slot does not
/// carry, and did, as "0 × 0".
String _slotTarget(AppLocalizations l10n, StarterSlot slot) {
  if (slot.cycle.isNotEmpty) return rowsTargetLabel(l10n, slot.cycle.first);
  return setsTargetLabel(
    l10n,
    sets: slot.sets,
    // The axis is not settled until the copy is written — it comes from the
    // exercise's own measure. A work period is only ever put on a movement the
    // library measures in time, so it is what says which of the two this slot
    // is: an interval program reads in seconds and everything else in reps.
    progression:
        slot.holdSeconds == null ? ProgressionMode.reps : ProgressionMode.time,
    toFailure: false,
    holdSeconds: slot.holdSeconds ?? 0,
    repsMin: slot.repsMin,
    repsMax: slot.repsMax,
  );
}

/// One training day of a shipped program: its exercises and what each is aiming
/// at, in the same shape the day screen draws.
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
