import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'screens/about_screen.dart';
import 'screens/backup_screen.dart';
import 'screens/bar_settings_screen.dart';
import 'screens/exercise_detail_screen.dart';
import 'screens/clip_player_screen.dart';
import 'screens/exercise_clips_screen.dart';
import 'screens/exercise_form_screen.dart';
import 'screens/exercise_progress_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_shell.dart';
import 'screens/language_screen.dart';
import 'screens/library_screen.dart';
import 'screens/plate_inventory_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/routine_detail_screen.dart';
import 'screens/routine_edit_screen.dart';
import 'screens/routine_import_screen.dart';
import 'screens/routine_library_screen.dart';
import 'screens/routine_share_screen.dart';
import 'screens/training_max_screen.dart';
import 'screens/routines_screen.dart';
import 'screens/set_video_screen.dart';
import 'screens/exercise_settings_screen.dart';
import 'screens/video_settings_screen.dart';
import 'screens/summary_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/theme_import_screen.dart';
import 'screens/appearance_screen.dart';
import 'screens/today_screen.dart';
import 'screens/workout_detail_screen.dart';
import 'screens/workout_edit_screen.dart';
import 'screens/workout_screen.dart';

/// The tab roots, in the order the navigation bar shows them. Every screen you
/// browse to lives under one of these, so it keeps the tabs and keeps the tab
/// it was reached from.
const kBranchRoots = ['/today', '/routines', '/history', '/profile'];

/// The tab root a screen is being browsed from, so a link opens in that tab
/// rather than throwing you into another one.
///
/// Read off the shell's own match rather than off the calling screen's
/// location: a screen stacked over the shell — an editor, the scanner — has a
/// location outside every branch, and it still has to send you back to the tab
/// you came from.
///
/// Empty where there is no tab shell in the route at all. That never happens in
/// the app, where the shell is the first thing the router builds; it is the
/// case of a test mounting one screen under a router of its own, and an empty
/// root leaves the path it is prefixing exactly as it was written.
String branchRoot(BuildContext context) =>
    _branchRootOf(GoRouter.maybeOf(context) ?? appRouter);

/// Whether the route on top right now is one the tab shell hosts.
///
/// This is shell membership as go_router itself records it — the top-level
/// match is the shell's — rather than a list of paths kept in step by hand. A
/// screen that moves into a branch, or a new one added to it, is inside the
/// shell the moment its route is, with nothing else to update.
bool insideTabShell(GoRouter go) {
  final matches = go.routerDelegate.currentConfiguration.matches;
  return matches.isNotEmpty && matches.last is ShellRouteMatch;
}

String _branchRootOf(GoRouter go) {
  for (final match in go.routerDelegate.currentConfiguration.matches) {
    if (match is ShellRouteMatch) return _rootOf(_leafOf(match).matchedLocation);
  }
  return '';
}

/// The deepest route under [match] — the branch's current screen.
RouteMatchBase _leafOf(RouteMatchBase match) =>
    match is ShellRouteMatch ? _leafOf(match.matches.last) : match;

/// The tab root [location] sits under, or Today if it sits under none.
String _rootOf(String location) {
  final segments = Uri.parse(location).pathSegments;
  final root = segments.isEmpty ? '' : '/${segments.first}';
  return kBranchRoots.contains(root) ? root : kBranchRoots.first;
}

/// A routine, as browsed from a tab. Registered under every branch that can
/// reach one, so opening it keeps you in the tab you were in.
GoRoute _routineRoute() => GoRoute(
      path: 'routine/:id',
      builder: (c, s) =>
          RoutineDetailScreen(routineId: int.parse(s.pathParameters['id']!)),
    );

/// A workout — one training day inside a routine — as browsed from a tab.
GoRoute _workoutRoute() => GoRoute(
      path: 'workout/:id',
      builder: (c, s) =>
          WorkoutDetailScreen(workoutId: int.parse(s.pathParameters['id']!)),
    );

/// Everything reachable from Profile: the library, an exercise, and the
/// settings pages. All of it is browsing, so all of it keeps the tabs.
List<RouteBase> _profileRoutes() => [
      GoRoute(path: 'library', builder: (c, s) => const LibraryScreen()),
      GoRoute(
        path: 'exercise/:id/clips',
        builder: (c, s) =>
            ExerciseClipsScreen(exerciseId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: 'exercise/:id/progress',
        builder: (c, s) => ExerciseProgressScreen(
            exerciseId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: 'exercise/:id',
        builder: (c, s) =>
            ExerciseDetailScreen(exerciseId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(path: 'about', builder: (c, s) => const AboutScreen()),
      GoRoute(path: 'backup', builder: (c, s) => const BackupScreen()),
      GoRoute(path: 'settings/bar', builder: (c, s) => const BarSettingsScreen()),
      GoRoute(
        path: 'settings/plates',
        builder: (c, s) => const PlateInventoryScreen(),
      ),
      GoRoute(
        path: 'settings/videos',
        builder: (c, s) => const VideoSettingsScreen(),
      ),
      GoRoute(path: 'settings/language', builder: (c, s) => const LanguageScreen()),
      // No id builds a new theme; an id edits (and renames, and deletes) that
      // one. `?from=<slug>` seeds a new one from a preset — the pencil on a
      // preset row, which copies rather than edits.
      GoRoute(
        path: 'settings/appearance/custom/:id',
        builder: (c, s) => CustomThemeEditorScreen(
          themeId: int.parse(s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: 'settings/appearance/custom',
        builder: (c, s) =>
            CustomThemeEditorScreen(fromPresetId: s.uri.queryParameters['from']),
      ),
      GoRoute(
        path: 'settings/appearance',
        builder: (c, s) => const AppearanceScreen(),
      ),
      GoRoute(path: 'settings', builder: (c, s) => const ExerciseSettingsScreen()),
    ];

/// The paths the browse screens answered to before they moved inside the tabs.
///
/// Each still resolves: anything holding one — a link, a path saved by an older
/// build — lands where it always did, now with the navigation bar under it.
///
/// The value is the tabs that host that screen, because not every screen hangs
/// off every tab: a workout is reachable from Today and from Routines, the
/// library only from Profile. The forward keeps you in the tab you are on when
/// that tab has the screen, and goes to a tab that does when it has not.
const _movedPaths = <String, List<String>>{
  '/routine/:id': ['/today', '/routines'],
  '/workout/:id': ['/today', '/routines'],
  '/library': ['/profile'],
  '/exercise/:id/clips': ['/profile'],
  '/exercise/:id/progress': ['/profile'],
  '/exercise/:id': ['/profile'],
  '/about': ['/profile'],
  '/backup': ['/profile'],
  '/settings/bar': ['/profile'],
  '/settings/plates': ['/profile'],
  '/settings/videos': ['/profile'],
  '/settings/language': ['/profile'],
  '/settings/appearance/custom/:id': ['/profile'],
  '/settings/appearance/custom': ['/profile'],
  '/settings/appearance': ['/profile'],
  '/settings': ['/profile'],
};

/// One of those, forwarded into a tab that has it, with its query intact.
GoRoute _movedRoute(String path, List<String> hosts) => GoRoute(
      path: path,
      redirect: (context, state) {
        // hosts.first rather than the empty root, so a path always forwards
        // somewhere: forwarding to itself would be a redirect loop.
        final here = branchRoot(context);
        final root = hosts.contains(here) ? here : hosts.first;
        return state.uri.replace(path: '$root${state.uri.path}').toString();
      },
    );

final appRouter = GoRouter(
  initialLocation: '/today',
  routes: [
    // The tab shell. A screen you browse to is a sub-route of the tab that
    // reaches it, which is what keeps the navigation bar under it and keeps
    // each tab's stack its own. A screen you are finishing — a session, an
    // editor, an import — is a top-level route below, stacked over all of it.
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => HomeShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/today',
              builder: (c, s) => const TodayScreen(),
              routes: [_routineRoute(), _workoutRoute()],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/routines',
              builder: (c, s) => const RoutinesScreen(),
              routes: [
                _routineRoute(),
                _workoutRoute(),
                // Inside the branch, so browsing what the app ships keeps the
                // navigation bar under it: the library is somewhere you look
                // around, not something you are in the middle of finishing.
                GoRoute(
                  path: 'library',
                  builder: (c, s) => const RoutineLibraryScreen(),
                  routes: [
                    GoRoute(
                      path: ':key',
                      builder: (c, s) => StarterRoutinePreviewScreen(
                        routineKey: s.pathParameters['key']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/history', builder: (c, s) => const HistoryScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (c, s) => const ProfileScreen(),
              routes: _profileRoutes(),
            ),
          ],
        ),
      ],
    ),
    // Routine builder (static paths first so they aren't captured by ":id").
    GoRoute(path: '/routine/new', builder: (c, s) => const RoutineEditScreen()),
    // Where a shared routine lands, however it arrived: a scanned QR, a pasted
    // code, a saved file, or a `fosslift://routine/...` link the OS handed us.
    // Never adds anything on its own — see RoutineImportScreen.
    GoRoute(
      path: '/routine/import',
      builder: (c, s) =>
          RoutineImportScreen(code: s.uri.queryParameters['code'] ?? ''),
    ),
    GoRoute(
      path: '/routine/:id/share',
      builder: (c, s) =>
          RoutineShareScreen(routineId: int.parse(s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/routine/:id/edit',
      builder: (c, s) =>
          RoutineEditScreen(routineId: int.parse(s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/routine/:id/training-maxes',
      builder: (c, s) =>
          TrainingMaxScreen(routineId: int.parse(s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/workout/:id/edit',
      builder: (c, s) =>
          WorkoutEditScreen(workoutId: int.parse(s.pathParameters['id']!)),
    ),
    GoRoute(path: '/library/new', builder: (c, s) => const ExerciseFormScreen()),
    GoRoute(
      path: '/exercise/:id/edit',
      builder: (c, s) =>
          ExerciseFormScreen(exerciseId: int.parse(s.pathParameters['id']!)),
    ),
    // Where a shared theme lands, however it arrived: a scanned QR, a pasted
    // code, or a `fosslift://theme/...` link the OS handed us. Never applies
    // anything on its own — see ThemeImportScreen.
    GoRoute(
      path: '/settings/appearance/import',
      builder: (c, s) =>
          ThemeImportScreen(code: s.uri.queryParameters['code'] ?? ''),
    ),
    // One camera screen for everything shareable; "for" says which.
    GoRoute(
      path: '/scan',
      builder: (c, s) => switch (s.uri.queryParameters['for']) {
        'routine' => const ScanScreen(host: 'routine'),
        _ => const ScanScreen(host: 'theme'),
      },
    ),
    // The live session in progress (distinct from a workout, its template).
    GoRoute(path: '/session', builder: (c, s) => const WorkoutScreen()),
    // Filming one set of it. Indexes into the live session in memory, which is
    // the only place the set exists until Finish.
    GoRoute(
      path: '/session/record/:ei/:si',
      builder: (c, s) => SetVideoScreen(
        exerciseIndex: int.parse(s.pathParameters['ei']!),
        setIndex: int.parse(s.pathParameters['si']!),
      ),
    ),
    // One clip, full screen. Carries what it is and — when it is a saved set —
    // the row it hangs on, which is what makes it deletable from here.
    GoRoute(
      path: '/clip',
      builder: (c, s) => ClipPlayerScreen(
        relativePath: s.uri.queryParameters['path'] ?? '',
        caption: s.uri.queryParameters['caption'],
        setId: int.tryParse(s.uri.queryParameters['set'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/summary/:id',
      builder: (c, s) => SummaryScreen(
        sessionId: int.parse(s.pathParameters['id']!),
        // Reached from History rather than the end of a session: show a back
        // button and no celebration, and never a progression banner.
        fromHistory: s.uri.queryParameters['from'] == 'history',
      ),
    ),
    // Last, so a path that is still a screen of its own — /routine/new,
    // /library/new, /settings/appearance/import — is matched before the
    // forwarding rule that shares its shape.
    for (final moved in _movedPaths.entries)
      _movedRoute(moved.key, moved.value),
  ],
);
