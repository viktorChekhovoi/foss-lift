import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../data/routine_code.dart';
import '../data/routine_import.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/seed_names.dart';
import '../util/target_label.dart';
import '../widgets/common.dart';
import '../widgets/share_widgets.dart';

/// Confirms a routine that arrived from outside the app before adding it.
///
/// Every inbound path lands here — a scanned QR, a tapped `fosslift://` link, a
/// pasted code — so the rule holds everywhere it needs to: **a
/// routine is shown in full and accepted, never added on arrival.** A code from
/// someone else's screen is untrusted input, and quietly writing exercises into
/// a stranger's library because they pointed a camera at something would be a
/// poor trade for saving one tap.
///
/// The one decision this screen asks for is the one it cannot make: an incoming
/// exercise whose name is already taken. Keeping what you have is the default,
/// because it is the choice that loses nothing.
///
/// A code that will not read is a dead end by design: there is no button to add
/// something we could not fully decode.
class RoutineImportScreen extends ConsumerStatefulWidget {
  const RoutineImportScreen({super.key, required this.code});

  /// The raw scanned/pasted/linked text. Decoding happens here rather than at
  /// the call sites so every entry point reports failures identically.
  final String code;

  @override
  ConsumerState<RoutineImportScreen> createState() =>
      _RoutineImportScreenState();
}

class _RoutineImportScreenState extends ConsumerState<RoutineImportScreen> {
  /// Indices into the incoming exercise list the user chose to overwrite.
  final Set<int> _replace = {};
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = RoutineCode.decode(widget.code);
    final library = ref.watch(exerciseLibraryProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.routineImportTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: switch (result) {
            RoutineCodeOk(:final routine) => _offer(l10n, routine, library),
            RoutineCodeFailure(:final problem) =>
              _refuse(l10n, problem.routineMessage(l10n)),
          },
        ),
      ),
    );
  }

  List<Widget> _offer(
      AppLocalizations l10n, SharedRoutine routine, List<Exercise>? library) {
    // The library is a stream; until it arrives there is nothing to compare
    // against and so nothing honest to say about clashes.
    if (library == null) {
      return [
        const SizedBox(height: 40),
        Center(child: CircularProgressIndicator(color: AppColors.accent)),
      ];
    }

    final arrivals = planExerciseArrivals(routine.exercises, library);
    final fresh = [
      for (final (i, a) in arrivals.indexed)
        if (a.isNew) (i, a)
    ];
    final clashes = [
      for (final (i, a) in arrivals.indexed)
        if (a.clashes) (i, a)
    ];

    return [
      Text(routine.name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(
        l10n.routineImportSharedWithYou,
        style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
      ),
      const SizedBox(height: 18),
      for (final workout in routine.workouts) ...[
        _DayCard(workout: workout, routine: routine, l10n: l10n),
        const SizedBox(height: 10),
      ],
      if (fresh.isNotEmpty) ...[
        const SizedBox(height: 12),
        shareSectionLabel(l10n.routineImportNewExercises),
        const SizedBox(height: 10),
        Text(
          l10n.routineImportAddedToLibrary,
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 8),
        for (final (_, a) in fresh)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('· ${_shownName(l10n, a.incoming)}',
                style: TextStyle(color: AppColors.text, fontSize: 14)),
          ),
      ],
      if (clashes.isNotEmpty) ...[
        const SizedBox(height: 18),
        shareSectionLabel(l10n.routineImportNameClashes),
        const SizedBox(height: 10),
        Text(
          l10n.routineImportClashHelp,
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 10),
        for (final (i, a) in clashes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ClashRow(
              l10n: l10n,
              name: _shownName(l10n, a.incoming),
              replace: _replace.contains(i),
              onChanged: (on) => setState(
                  () => on ? _replace.add(i) : _replace.remove(i)),
            ),
          ),
      ],
      const SizedBox(height: 22),
      FilledButton(
        onPressed: _adding ? null : () => _add(routine),
        child: Text(l10n.routineImportAdd),
      ),
      const SizedBox(height: 10),
      OutlinedButton(
        onPressed: _leave,
        child: Text(l10n.commonCancel),
      ),
      const SizedBox(height: 14),
      Text(
        l10n.routineImportFootnote,
        style: TextStyle(color: AppColors.faint, fontSize: 12, height: 1.5),
      ),
    ];
  }

  List<Widget> _refuse(AppLocalizations l10n, String message) {
    return [
      const SizedBox(height: 24),
      Icon(Icons.error_outline, size: 40, color: AppColors.muted),
      const SizedBox(height: 14),
      Text(message,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.text, fontSize: 15, height: 1.5)),
      const SizedBox(height: 24),
      OutlinedButton(onPressed: _leave, child: Text(l10n.commonBack)),
    ];
  }

  Future<void> _add(SharedRoutine routine) async {
    setState(() => _adding = true);
    final id = await ref
        .read(databaseProvider)
        .importSharedRoutine(routine, replace: _replace);
    if (!mounted) return;
    // Land on the routine that was just added — the thing the user came for.
    leaveShareScreen(context, () => GoRouter.maybeOf(context)?.go('/routines'));
    GoRouter.maybeOf(context)?.push('/routine/$id');
  }

  void _leave() =>
      leaveShareScreen(context, () => GoRouter.maybeOf(context)?.go('/routines'));
}

/// An incoming exercise's name as this phone says it.
///
/// A code carries the canonical English name and no key, so the key is derived
/// back from the name here — the same one the import will store. Without it
/// this would be the only screen in the app naming a starter movement in
/// English: "Bench Press" on the confirmation, "Жим лежачи" the moment it
/// lands. A name the sender invented has no key and is shown as they wrote it.
String _shownName(AppLocalizations l10n, SharedExercise e) =>
    seededName(l10n, seedKeyForName(e.name), e.name);

/// One training day as it would arrive: its name and every slot in it.
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.workout,
    required this.routine,
    required this.l10n,
  });
  final SharedWorkout workout;
  final SharedRoutine routine;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: hexColor(routine.colorHex),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(workout.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in workout.items)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                        _shownName(l10n, routine.exercises[item.exercise]),
                        style:
                            TextStyle(color: AppColors.text, fontSize: 13.5)),
                  ),
                  Text(_target(l10n, item),
                      style: kMono.copyWith(
                          fontSize: 12.5, color: AppColors.muted)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// "4 × 6–8", "3 × 45s", "3 × Failure" — the same phrase the training day
  /// itself shows, built from the shared slot rather than a database row.
  static String _target(AppLocalizations l10n, SharedItem it) =>
      setsTargetLabel(
        l10n,
        sets: it.targetSets,
        progression: it.progression,
        toFailure: it.toFailure,
        holdSeconds: it.holdSeconds,
        repsMin: it.repsMin,
        repsMax: it.repsMax,
      );
}

/// One name clash: whose definition wins.
class _ClashRow extends StatelessWidget {
  const _ClashRow({
    required this.l10n,
    required this.name,
    required this.replace,
    required this.onChanged,
  });
  final AppLocalizations l10n;
  final String name;
  final bool replace;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(replace
                        ? l10n.routineImportUseTheirs
                        : l10n.routineImportKeepMine,
                    style: kMono.copyWith(
                        fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          Switch(value: replace, onChanged: onChanged),
        ],
      ),
    );
  }
}
