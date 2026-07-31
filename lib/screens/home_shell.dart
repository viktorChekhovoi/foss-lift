import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/resume_workout_bar.dart';
import '../widgets/tutorial.dart';

/// The bottom-tab scaffold that hosts Today / Routines / History / Profile.
///
/// **It takes its colours from the palette it watches, not from `AppColors`.**
/// Everywhere else in the app can read the live globals, because the app root
/// re-keys `MaterialApp` on a palette change and the tree underneath is rebuilt
/// against the freshly applied values. This shell is the exception: go_router
/// holds its branch navigators by `GlobalKey`, so the re-key *moves* the shell's
/// elements instead of rebuilding them, and a `NavigationBarTheme` built from
/// mutable globals keeps whatever it read the first time. That is how a cold
/// launch came to paint the navigation bar in the previous theme and hold it
/// there until any tap marked it dirty.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched, not read: this is the subscription that gets the shell rebuilt
    // when nothing else will.
    final palette = ref.watch(activePaletteProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: shell,
      // The resume bar rides in the bottom bar rather than over the body, so a
      // live session never costs a tab screen the bottom of its list. Scaffold
      // measures whatever it is given here and insets the body by it, which is
      // the whole point — see ResumeWorkoutOverlay for the other mount point.
      // The slot, not the bar itself: the shell only holds it while a tab root
      // is the current route, which is what keeps the two mount points from
      // both drawing one during a push.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ResumeWorkoutBarSlot(mount: ResumeBarMount.shell),
          _navBar(palette, l10n),
        ],
      ),
    );
  }

  Widget _navBar(AppPalette palette, AppLocalizations l10n) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: palette.ground,
        indicatorColor: palette.accent.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? palette.accent : palette.faint,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? palette.accent : palette.faint,
          );
        }),
      ),
      child: NavigationBar(
        // Anchors the tour's tab coach marks; each slot is a quarter of it.
        key: tutorialNavBarKey,
        height: 64,
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l10n.navToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_alt_outlined),
            selectedIcon: const Icon(Icons.list_alt_rounded),
            label: l10n.navRoutines,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart_rounded),
            label: l10n.navHistory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
