import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../state/active_workout.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../util/seed_names.dart';

/// **The one way into a live session.** Every Start goes through here, so the
/// two questions worth asking on the way in are asked once rather than once per
/// entry point: is a session already running, and has this day been left alone
/// long enough to earn a back-off.
///
/// The order matters. A session already running is settled first and without
/// touching the database — tapping Start on the workout you are already doing
/// is not a decision, it is a request to go back to it — and only once there is
/// no session in the way does the layoff offer come up.
/// [name] is the training day's name as stored — English, for a day the app
/// shipped — because it is what the finished session is written to history
/// under. [seedKey] is that day's key, so the questions asked on the way in can
/// still be phrased in the language on screen.
Future<void> startWorkout(
  BuildContext context,
  WidgetRef ref,
  int workoutId,
  String name, {
  String? seedKey,
}) async {
  final l10n = AppLocalizations.of(context);
  final shown = seededName(l10n, seedKey, name);
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
      builder: (_) => _SwitchDialog(live: live, starting: shown),
    );
    if (swap != true || !context.mounted) return;
    ref.read(activeWorkoutProvider.notifier).discard();
  }

  final db = ref.read(databaseProvider);
  final layoff = await db.layoffFor(workoutId);

  LayoffNotice? notice;
  if (layoff != null && context.mounted) {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => _LayoffDialog(layoff: layoff, workoutName: shown),
    );
    if (accepted == true) {
      final moved = await db.applyLayoffDeload(workoutId, layoff.percent);
      // Nothing moved means nothing here had a target to cut. Announcing a
      // deload that did not happen is worse than saying nothing.
      //
      // The two numbers rather than the finished sentence: the notice is on
      // screen for the whole workout, and the board composes it from the
      // catalogue on every build. See [LayoffNotice].
      if (moved > 0) {
        notice = (percent: layoff.percent, days: layoff.gapDays);
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
    final l10n = AppLocalizations.of(context);
    final running = seededName(l10n, live.seedKey, live.name);
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(l10n.startWorkoutSwitchTitle(starting)),
      content: Text(
        l10n.startWorkoutSwitchBody(
            running, live.doneSets, live.totalSets, fmtDuration(live.elapsed)),
        style: TextStyle(color: AppColors.muted, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.startWorkoutKeepRunning(running)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.gold),
          child: Text(l10n.startWorkoutDiscardRunning(running)),
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
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(l10n.startWorkoutLayoffTitle),
      content: Text(
        l10n.startWorkoutLayoffBody(
            workoutName, layoff.gapDays, layoff.percent),
        style: TextStyle(color: AppColors.muted, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.startWorkoutKeepWeights),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.startWorkoutDeload(layoff.percent)),
        ),
      ],
    );
  }
}
