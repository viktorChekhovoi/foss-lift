import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../state/active_workout.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../util/seed_names.dart';

const resumeWorkoutBarKey = ValueKey('resume-workout-bar');

enum ResumeBarMount {
  shell,

  app,
}

class ResumeWorkoutBarSlot extends StatelessWidget {
  const ResumeWorkoutBarSlot({super.key, required this.mount, this.router});

  final ResumeBarMount mount;

  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    final go = router ?? GoRouter.maybeOf(context) ?? appRouter;
    return ListenableBuilder(
      listenable: Listenable.merge([
        go.routerDelegate,
        go.routeInformationProvider,
      ]),
      builder: (context, _) {
        if (insideTabShell(go) != (mount == ResumeBarMount.shell)) {
          return const SizedBox.shrink();
        }
        return ResumeWorkoutBar(clearSystemInset: mount == ResumeBarMount.app);
      },
    );
  }
}

class ResumeWorkoutOverlay extends StatelessWidget {
  const ResumeWorkoutOverlay({super.key, required this.child, this.router});
  final Widget child;

  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: child),
        ResumeWorkoutBarSlot(mount: ResumeBarMount.app, router: router),
      ],
    );
  }
}

class ResumeWorkoutBar extends ConsumerWidget {
  const ResumeWorkoutBar({super.key, this.clearSystemInset = false});

  final bool clearSystemInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeWorkoutProvider);
    final onSessionScreen = ref.watch(workoutScreenVisibleProvider);
    if (session == null || onSessionScreen) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

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
                  Expanded(
                    child: Text(
                      seededName(l10n, session.seedKey, session.name),
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
                    l10n.resumeBarResume,
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
