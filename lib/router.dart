import 'package:go_router/go_router.dart';

import 'screens/about_screen.dart';
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
import 'screens/routine_share_screen.dart';
import 'screens/routines_screen.dart';
import 'screens/set_video_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/video_settings_screen.dart';
import 'screens/summary_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/theme_import_screen.dart';
import 'screens/theme_settings_screen.dart';
import 'screens/today_screen.dart';
import 'screens/workout_detail_screen.dart';
import 'screens/workout_edit_screen.dart';
import 'screens/workout_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/today',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => HomeShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/today', builder: (c, s) => const TodayScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/routines', builder: (c, s) => const RoutinesScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/history', builder: (c, s) => const HistoryScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen())],
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
      path: '/routine/:id',
      builder: (c, s) =>
          RoutineDetailScreen(routineId: int.parse(s.pathParameters['id']!)),
    ),
    // A workout is one training day inside a routine.
    GoRoute(
      path: '/workout/:id/edit',
      builder: (c, s) =>
          WorkoutEditScreen(workoutId: int.parse(s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/workout/:id',
      builder: (c, s) =>
          WorkoutDetailScreen(workoutId: int.parse(s.pathParameters['id']!)),
    ),
    GoRoute(path: '/library', builder: (c, s) => const LibraryScreen()),
    GoRoute(path: '/library/new', builder: (c, s) => const ExerciseFormScreen()),
    GoRoute(
      path: '/exercise/:id/edit',
      builder: (c, s) =>
          ExerciseFormScreen(exerciseId: int.parse(s.pathParameters['id']!)),
    ),
    // Progress chart for one exercise (the static segment before ":id" catches
    // nothing here, but keep the more specific path listed first).
    GoRoute(
      path: '/exercise/:id/clips',
      builder: (c, s) =>
          ExerciseClipsScreen(exerciseId: int.parse(s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/exercise/:id/progress',
      builder: (c, s) =>
          ExerciseProgressScreen(exerciseId: int.parse(s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/exercise/:id',
      builder: (c, s) =>
          ExerciseDetailScreen(exerciseId: int.parse(s.pathParameters['id']!)),
    ),
    GoRoute(path: '/about', builder: (c, s) => const AboutScreen()),
    GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
    GoRoute(
      path: '/settings/bar',
      builder: (c, s) => const BarSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/plates',
      builder: (c, s) => const PlateInventoryScreen(),
    ),
    GoRoute(
      path: '/settings/videos',
      builder: (c, s) => const VideoSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/language',
      builder: (c, s) => const LanguageScreen(),
    ),
    GoRoute(
      path: '/settings/theme',
      builder: (c, s) => const ThemeSettingsScreen(),
    ),
    // No id builds a new theme; an id edits (and renames, and deletes) that one.
    // `?from=<slug>` seeds a new one from a preset — the pencil on a preset row,
    // which copies rather than edits.
    GoRoute(
      path: '/settings/theme/custom',
      builder: (c, s) =>
          CustomThemeEditorScreen(fromPresetId: s.uri.queryParameters['from']),
    ),
    GoRoute(
      path: '/settings/theme/custom/:id',
      builder: (c, s) => CustomThemeEditorScreen(
        themeId: int.parse(s.pathParameters['id']!),
      ),
    ),
    // Where a shared theme lands, however it arrived: a scanned QR, a pasted
    // code, or a `fosslift://theme/...` link the OS handed us. Never applies
    // anything on its own — see ThemeImportScreen.

    GoRoute(
      path: '/settings/theme/import',
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
    // The live session in progress (distinct from /workout/:id, its template).
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
  ],
);
