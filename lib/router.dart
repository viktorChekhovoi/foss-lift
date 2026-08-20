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

/// Every screen you browse to: which tabs host it, and how it is built.
///
/// One table because the same two facts are wanted in three places — the
/// sub-routes under each tab, the prefix a link to the screen wears, and the
/// tab-less route the bare path resolves to — and three lists kept in step by
/// hand are three lists that stop being in step. That is what this is fixing:
/// a link that wore the tab it was tapped from resolved to nothing whenever
/// that tab had not got the screen.
///
/// Not every screen hangs off every tab. A workout is reachable from Today and
/// from Routines; the library, an exercise and the settings pages only from
/// Profile. Order matters the way it does in any route table: a static path
/// comes before the `:id` that would swallow it.
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
  // No id builds a new theme; an id edits (and renames, and deletes) that one.
  // `?from=<slug>` seeds a new one from a preset — the pencil on a preset row,
  // which copies rather than edits.
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

/// The browsable screens [tab] hosts, as its sub-routes — which is what keeps
/// the navigation bar under them and keeps the tab's stack its own.
List<RouteBase> _tabRoutes(String tab) => [
      for (final entry in _browsable.entries)
        if (entry.value.tabs.contains(tab))
          GoRoute(path: entry.key.substring(1), builder: entry.value.build),
    ];

/// [path] under a tab that has the screen: the tab you are in where that tab
/// has it, the first tab that does where it has not.
///
/// The fallback is the whole point. Prefixing the tab you happen to be in
/// composes `/today/settings/plates`, which no route matches, and the tap lands
/// on Page Not Found.
///
/// A path no tab claims is left to whatever [branchRoot] prefixes it with,
/// which is how it behaved before there was a table to consult.
String tabPath(BuildContext context, String path) {
  final tabs = _tabsFor(path);
  final here = branchRoot(context);
  if (tabs.isEmpty) return '$here$path';
  return '${tabs.contains(here) ? here : tabs.first}$path';
}

/// Where a link to [path] goes from here.
///
/// Inside the tabs, [tabPath] — the screen opens in a tab, keeping the bar.
/// Stacked over them it is the bare path, which is the same screen with no tabs
/// under it, over the task you are in the middle of. The builder's slot sheet
/// links to the plate inventory that way: it sits three screens above any tab,
/// and pushing a tab's route from up there would rebuild that tab's pages
/// underneath a stack that already holds them, which go_router refuses.
String linkPath(BuildContext context, String path) =>
    _overTabShell(GoRouter.maybeOf(context) ?? appRouter)
        ? path
        : tabPath(context, path);

/// Whether what is on top is a task stacked over the tabs rather than a screen
/// inside them.
///
/// Not the negation of [insideTabShell]: a router with no configuration yet —
/// the cold start, still resolving the location the app was launched with — is
/// over nothing, and a link resolved then belongs in a tab.
bool _overTabShell(GoRouter go) =>
    go.routerDelegate.currentConfiguration.matches.isNotEmpty &&
    !insideTabShell(go);

/// The tabs that host [path], matching it against the table's patterns so a
/// concrete `/exercise/7` finds the `/exercise/:id` that describes it. Empty
/// for a path the table does not name.
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

/// A browsable screen at its bare path — the one the browse screens answered to
/// before they moved inside the tabs.
///
/// From inside the tabs it forwards into one that has the screen, with its
/// query intact, so anything holding an old path — a link, a location saved by
/// an earlier build — lands where it always did, now with the navigation bar
/// under it. Never to itself, which would be a redirect loop: every path here
/// is one the table names, so [tabPath] always finds a tab to put in front of
/// it.
///
/// From over the tabs it builds the screen where it is, tab-less, over the task
/// rather than pushed into a branch beneath it.
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
    // The root is not a screen — the app opens on a tab — but it is where the
    // not-found page's way home points, so it has to lead somewhere.
    GoRoute(path: '/', redirect: (context, state) => kBranchRoots.first),
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
              routes: _tabRoutes('/profile'),
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
    for (final entry in _browsable.entries) _bareRoute(entry.key, entry.value),
  ],
);
