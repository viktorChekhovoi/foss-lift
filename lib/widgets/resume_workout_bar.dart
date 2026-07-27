import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../router.dart';
import '../state/active_workout.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';

/// Finds the resume bar in a test.
const resumeWorkoutBarKey = ValueKey('resume-workout-bar');

/// Wraps the whole app so a live workout survives being collapsed. The logging
/// screen minimises by popping itself; the session stays in memory, and the bar
/// is how the user gets back to it from anywhere they wander.
///
/// **It docks rather than floats.** A control hiding the thing you are trying to
/// read is worse than one you have to go and find, and a floating pill hid the
/// bottom of every list for as long as a session was open. So the bar takes real
/// room: here it is the last row of the app, and on a tab screen [HomeShell]
/// stacks it above the navigation bar instead — which is why this skips the tab
/// roots. Two mount points, one bar; nothing is ever underneath it.
class ResumeWorkoutOverlay extends ConsumerWidget {
  const ResumeWorkoutOverlay({super.key, required this.child, this.router});
  final Widget child;

  /// The router to read the current path from. Defaults to the app's; a test
  /// building its own navigation supplies that one instead.
  final GoRouter? router;

  /// The tab roots — the routes that draw the bottom navigation bar. On those,
  /// the shell mounts the bar itself so it lands above the nav bar rather than
  /// below it.
  static const _tabRoots = {'/today', '/routines', '/history', '/profile'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final go = router ?? appRouter;
    // The route decides only *which* mount point owns the bar. It comes from
    // the route-information provider rather than the delegate's configuration:
    // the delegate notifies during its own build, which would trip the
    // framework's dirty assertion, and reading one while listening to the other
    // leaves the two a frame apart — long enough to draw a second bar.
    return ListenableBuilder(
      listenable: go.routeInformationProvider,
      builder: (context, _) {
        final path = go.routeInformationProvider.value.uri.path;
        return Column(
          children: [
            Expanded(child: child),
            if (!_tabRoots.contains(path))
              const ResumeWorkoutBar(clearSystemInset: true),
          ],
        );
      },
    );
  }
}

/// The bar itself: nothing when no session is collapsed, a one-line strip back
/// to it when there is.
///
/// One line, because it is permanent furniture for as long as a session is open
/// and every pixel of it is a pixel off the screen underneath. The name, the
/// clock and the set count are the three things worth knowing without going
/// back.
class ResumeWorkoutBar extends ConsumerWidget {
  const ResumeWorkoutBar({super.key, this.clearSystemInset = false});

  /// Whether the bar has to keep itself clear of the system gesture area. True
  /// where it is the last thing on screen; false where a navigation bar below
  /// it is already doing that.
  final bool clearSystemInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched, so the clock ticks with the session and the bar goes the instant
    // the logging screen appears.
    final session = ref.watch(activeWorkoutProvider);
    final onSessionScreen = ref.watch(workoutScreenVisibleProvider);
    if (session == null || onSessionScreen) return const SizedBox.shrink();

    return Material(
      color: AppColors.surface3,
      child: InkWell(
        key: resumeWorkoutBarKey,
        onTap: () => appRouter.push('/session'),
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.accent)),
          ),
          child: SafeArea(
            top: false,
            left: false,
            right: false,
            bottom: clearSystemInset,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 18,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // The name is the only part that gives: it is the one thing
                  // here with no length to it, and a narrow phone must not push
                  // the clock off the end of the bar.
                  Expanded(
                    child: Text(
                      session.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${fmtDuration(session.elapsed)} · '
                    '${session.doneSets}/${session.totalSets}',
                    maxLines: 1,
                    style: kMono.copyWith(
                      fontSize: 11.5,
                      color: AppColors.faint,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'RESUME',
                    style: kMono.copyWith(
                      fontSize: 11,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
