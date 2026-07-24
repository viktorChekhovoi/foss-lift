import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../router.dart';
import '../state/active_workout.dart';
import '../theme/app_theme.dart';

/// Wraps the whole app so a live workout survives being collapsed. The logging
/// screen minimises by popping itself; the session stays in memory, and this
/// bar is how the user gets back to it from anywhere they wander.
///
/// It rides above every route (via `MaterialApp.router`'s builder) rather than
/// inside a single screen, because "browse the app and come back" means the
/// routine list, the library, the settings — not just the four tabs.
class ResumeWorkoutOverlay extends ConsumerWidget {
  const ResumeWorkoutOverlay({super.key, required this.child});
  final Widget child;

  /// The tab roots — the routes that draw the bottom navigation bar, so the
  /// pill has to float above it rather than under it. Every other route is
  /// full-bleed to the bottom.
  static const _tabRoots = {'/today', '/routines', '/history', '/profile'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched, so the pill's clock ticks with the session. `child` is the same
    // widget instance each rebuild, so the app below it is not rebuilt — only
    // the thin Stack around it.
    final session = ref.watch(activeWorkoutProvider);

    // Rebuild on navigation via the route-information provider, *not* the router
    // delegate: this widget lives in `MaterialApp.router`'s builder, above the
    // Router, so the builder does not re-run when the route changes on its own.
    // The delegate notifies during its build (subscribing there trips the
    // framework's dirty assertion); the route-information provider reports the
    // new location after the frame, which is a safe moment to rebuild.
    return ListenableBuilder(
      listenable: appRouter.routeInformationProvider,
      builder: (context, _) {
        final path = appRouter.routeInformationProvider.value.uri.path;

        // Never over the logging screen itself — that is where "resume" leads —
        // nor over the template screen of the very workout in progress, where
        // it would double up with that screen's own "Start workout" button.
        final ownTemplate = session?.workoutId == null
            ? null
            : '/workout/${session!.workoutId}';
        final show =
            session != null && path != '/session' && path != ownTemplate;

        return Stack(
          children: [
            child,
            if (show)
              _ResumeBar(
                session: session,
                aboveNavBar: _tabRoots.contains(path),
                onTap: () => appRouter.push('/session'),
              ),
          ],
        );
      },
    );
  }
}

String _clock(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

class _ResumeBar extends StatelessWidget {
  const _ResumeBar({
    required this.session,
    required this.aboveNavBar,
    required this.onTap,
  });
  final ActiveWorkout session;
  final bool aboveNavBar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final systemInset = MediaQuery.of(context).padding.bottom;
    // Clear the navigation bar (64 tall, drawn into the bottom inset) on the
    // tab routes; on a pushed screen only the system inset is in the way.
    final bottom = (aboveNavBar ? 64.0 + systemInset : systemInset) + 12;

    return Positioned(
      left: 12,
      right: 12,
      bottom: bottom,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      size: 20, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_clock(session.elapsed)} · ${session.doneSets}/${session.totalSets} sets',
                        style: kMono.copyWith(
                            fontSize: 11.5, color: AppColors.faint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'RESUME',
                  style: kMono.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
