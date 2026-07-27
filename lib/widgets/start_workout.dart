import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../state/active_workout.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';

/// **The one way into a live session.** Every Start goes through here, so the
/// two questions worth asking on the way in are asked once rather than once per
/// entry point: is a session already running, and has this day been left alone
/// long enough to earn a back-off.
///
/// The order matters. A session already running is settled first and without
/// touching the database — tapping Start on the workout you are already doing
/// is not a decision, it is a request to go back to it — and only once there is
/// no session in the way does the layoff offer come up.
Future<void> startWorkout(
  BuildContext context,
  WidgetRef ref,
  int workoutId,
  String name,
) async {
  final live = ref.read(activeWorkoutProvider);
  if (live != null) {
    // The one you are already doing: open it. There is nothing to decide.
    if (live.workoutId == workoutId) {
      context.push('/session');
      return;
    }
    // A different one throws the live session away, which is the same
    // destructive act the abort confirmation exists for.
    final swap = await showDialog<bool>(
      context: context,
      builder: (_) => _SwitchDialog(live: live, starting: name),
    );
    if (swap != true || !context.mounted) return;
    ref.read(activeWorkoutProvider.notifier).discard();
  }

  final db = ref.read(databaseProvider);
  final layoff = await db.layoffFor(workoutId);

  String? notice;
  if (layoff != null && context.mounted) {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => _LayoffDialog(layoff: layoff, workoutName: name),
    );
    if (accepted == true) {
      final moved = await db.applyLayoffDeload(workoutId, layoff.percent);
      // Nothing moved means nothing here had a target to cut. Announcing a
      // deload that did not happen is worse than saying nothing.
      if (moved > 0) {
        notice = 'Targets cut ${layoff.percent}% — '
            '${layoff.gapDays} days since you last trained this.';
      }
    }
  }

  await ref
      .read(activeWorkoutProvider.notifier)
      .start(workoutId: workoutId, name: name, notice: notice);
  if (context.mounted) context.push('/session');
}

/// Asked before a live session is thrown away for a different one.
///
/// It names the session at risk and says how much of it there is to lose,
/// because "you have a workout in progress" is not enough to decide on — three
/// sets in is a different answer from thirty seconds in. Keeping is the default
/// and the plain button; switching is the one that costs something.
class _SwitchDialog extends StatelessWidget {
  const _SwitchDialog({required this.live, required this.starting});
  final ActiveWorkout live;
  final String starting;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Switch to $starting?'),
      content: Text(
        '${live.name} is still running — ${live.doneSets} of '
        '${live.totalSets} sets logged, ${fmtDuration(live.elapsed)} on the '
        'clock. Starting $starting throws it away.',
        style: TextStyle(color: AppColors.muted, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Keep ${live.name}'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.gold),
          child: Text('Discard ${live.name}'),
        ),
      ],
    );
  }
}

/// The one place the user is asked about a layoff: what it noticed, what it
/// proposes, and the option to say no.
///
/// It comes *before* the session is hydrated, so accepting it moves the template
/// and the first set row is drawn at the new weight — there is no moment where
/// the screen shows one number and the programme holds another. Declining is not
/// remembered anywhere: training today resets the gap on its own, so the
/// question cannot come back to nag.
class _LayoffDialog extends StatelessWidget {
  const _LayoffDialog({required this.layoff, required this.workoutName});
  final LayoffDeload layoff;
  final String workoutName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Been a while'),
      content: Text(
        'You last trained $workoutName ${layoff.gapDays} days ago. Coming back '
        'at the same load is how people get hurt.\n\n'
        'Foss Lift can drop every target in this workout by ${layoff.percent}% '
        'to ease you back in. Your logged history is not touched.',
        style: TextStyle(color: AppColors.muted, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep weights'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Deload ${layoff.percent}%'),
        ),
      ],
    );
  }
}
