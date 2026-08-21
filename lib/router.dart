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

/// Tab roots in navigation-bar order.
const kBranchRoots = ['/today', '/routines', '/history', '/profile'];

/// Returns the tab root containing the current route, or an empty string when the router has no tab shell (for example, in an isolated screen test).
String branchRoot(BuildContext context) =>
    _branchRootOf(GoRouter.maybeOf(context) ?? appRouter);

/// Whether the current route is hosted by the tab shell.
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

/// Browsable screens, their hosting tabs, and their builders. Keep static paths before parameterized paths when adding entries.
typedef _Browsable = ({List<String> tabs, GoRouterWidgetBuilder build});

final _browsable = <String, _Browsable>{
  '/routine/:id': (
    tabs: ['/today', '/routines'],
    build: (c, s) =>
        RoutineDetailScreen(routineId: int.parse(s.pathParameters['id']!)),
  ),
  '/workout/:id': (
    tabs: ['/today', '/routines'],
    build: (c, s) =>
        WorkoutDetailScreen(workoutId: int.parse(s.pathParameters['id']!)),
  ),
  '/library': (tabs: ['/profile'], build: (c, s) => const LibraryScreen()),
  '/exercise/:id/clips': (
    tabs: ['/profile'],
    build: (c, s) =>
        ExerciseClipsScreen(exerciseId: int.parse(s.pathParameters['id']!)),
  ),
  '/exercise/:id/progress': (
    tabs: ['/profile'],
    build: (c, s) =>
        ExerciseProgressScreen(exerciseId: int.parse(s.pathParameters['id']!)),
  ),
  '/exercise/:id': (
    tabs: ['/profile'],
    build: (c, s) =>
        ExerciseDetailScreen(exerciseId: int.parse(s.pathParameters['id']!)),
  ),
  '/about': (tabs: ['/profile'], build: (c, s) => const AboutScreen()),
  '/backup': (tabs: ['/profile'], build: (c, s) => const BackupScreen()),
  '/settings/bar': (
    tabs: ['/profile'],
    build: (c, s) => const BarSettingsScreen(),
  ),
  '/settings/plates': (
    tabs: ['/profile'],
    build: (c, s) => const PlateInventoryScreen(),
  ),
  '/settings/videos': (
    tabs: ['/profile'],
    build: (c, s) => const VideoSettingsScreen(),
  ),
  '/settings/language': (
    tabs: ['/profile'],
    build: (c, s) => const LanguageScreen(),
  ),
  // An id edits an existing theme; `from` seeds a new one from a preset.
  '/settings/appearance/custom/:id': (
    tabs: ['/profile'],
    build: (c, s) => CustomThemeEditorScreen(
      themeId: int.parse(s.pathParameters['id']!),
    ),
  ),
  '/settings/appearance/custom': (
    tabs: ['/profile'],
    build: (c, s) =>
        CustomThemeEditorScreen(fromPresetId: s.uri.queryParameters['from']),
  ),
  '/settings/appearance': (
    tabs: ['/profile'],
    build: (c, s) => const AppearanceScreen(),
  ),
  '/settings': (
    tabs: ['/profile'],
    build: (c, s) => const ExerciseSettingsScreen(),
  ),
};

/// Builds the browsable screens hosted by [tab] as sub-routes.
List<RouteBase> _tabRoutes(String tab) => [
      for (final entry in _browsable.entries)
        if (entry.value.tabs.contains(tab))
          GoRoute(path: entry.key.substring(1), builder: entry.value.build),
    ];

/// Resolves [path] under the current tab when possible, otherwise its first owning tab. Paths with no owner use the current branch root.
String tabPath(BuildContext context, String path) {
  final tabs = _tabsFor(path);
  final here = branchRoot(context);
  if (tabs.isEmpty) return '$here$path';
  return '${tabs.contains(here) ? here : tabs.first}$path';
}

/// Resolves a link to [path] for the current shell context.
String linkPath(BuildContext context, String path) =>
    _overTabShell(GoRouter.maybeOf(context) ?? appRouter)
        ? path
        : tabPath(context, path);

/// Whether a configured route is stacked over the tab shell.
bool _overTabShell(GoRouter go) =>
    go.routerDelegate.currentConfiguration.matches.isNotEmpty &&
    !insideTabShell(go);

/// Finds tabs whose route pattern matches [path].
List<String> _tabsFor(String path) {
  final segments = Uri.parse(path).pathSegments;
  for (final entry in _browsable.entries) {
    final pattern = Uri.parse(entry.key).pathSegments;
    if (pattern.length != segments.length) continue;
    var matches = true;
    for (var i = 0; i < segments.length && matches; i++) {
      matches = pattern[i].startsWith(':') || pattern[i] == segments[i];
    }
    if (matches) return entry.value.tabs;
  }
  return const [];
}

/// Builds the legacy bare route for a browsable screen. It redirects into a hosting tab unless the route is already stacked over the shell.
GoRoute _bareRoute(String path, _Browsable screen) => GoRoute(
      path: path,
      redirect: (context, state) => _overTabShell(
              GoRouter.maybeOf(context) ?? appRouter)
          ? null
          : state.uri.replace(path: tabPath(context, state.uri.path)).toString(),
      builder: screen.build,
    );

final appRouter = GoRouter(
  initialLocation: '/today',
  routes: [
    // The root redirects to the default tab.
    GoRoute(path: '/', redirect: (context, state) => kBranchRoots.first),
    // Browsable screens are branch routes; active tasks stack above the shell.
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => HomeShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/today',
              builder: (c, s) => const TodayScreen(),
              routes: _tabRoutes('/today'),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/routines',
              builder: (c, s) => const RoutinesScreen(),
              routes: [
                ..._tabRoutes('/routines'),
                // The library is browsable, so keep it inside the branch.
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
              routes: _tabRoutes('/profile'),
            ),
          ],
        ),
      ],
    ),
    // Static routine paths must precede `:id`.
    GoRoute(path: '/routine/new', builder: (c, s) => const RoutineEditScreen()),
    // Import only; RoutineImportScreen applies the code after review.
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
    // Import only; ThemeImportScreen applies the code after review.
    GoRoute(
      path: '/settings/appearance/import',
      builder: (c, s) =>
          ThemeImportScreen(code: s.uri.queryParameters['code'] ?? ''),
    ),
    // One camera screen handles both shareable payload types.
    GoRoute(
      path: '/scan',
      builder: (c, s) => switch (s.uri.queryParameters['for']) {
        'routine' => const ScanScreen(host: 'routine'),
        _ => const ScanScreen(host: 'theme'),
      },
    ),
    // The live session, distinct from its workout template.
    GoRoute(path: '/session', builder: (c, s) => const WorkoutScreen()),
    // Records one set, identified by indexes into the in-memory session.
    GoRoute(
      path: '/session/record/:ei/:si',
      builder: (c, s) => SetVideoScreen(
        exerciseIndex: int.parse(s.pathParameters['ei']!),
        setIndex: int.parse(s.pathParameters['si']!),
      ),
    ),
    // Full-screen clip playback; an optional set id enables deletion.
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
        // History summaries omit the completion controls and progression banner.
        fromHistory: s.uri.queryParameters['from'] == 'history',
      ),
    ),
    // Bare routes come last, after standalone static screens.
    for (final entry in _browsable.entries) _bareRoute(entry.key, entry.value),
  ],
);
