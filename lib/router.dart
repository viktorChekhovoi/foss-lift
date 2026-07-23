import 'package:go_router/go_router.dart';

import 'screens/exercise_detail_screen.dart';
import 'screens/exercise_form_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_shell.dart';
import 'screens/library_screen.dart';
import 'screens/plate_inventory_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/routine_detail_screen.dart';
import 'screens/routine_edit_screen.dart';
import 'screens/routines_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/summary_screen.dart';
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
    // Routine builder (static path first so "/new" isn't captured by ":id").
    GoRoute(path: '/routine/new', builder: (c, s) => const RoutineEditScreen()),
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
      path: '/exercise/:id',
      builder: (c, s) =>
          ExerciseDetailScreen(exerciseId: int.parse(s.pathParameters['id']!)),
    ),
    GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
    GoRoute(
      path: '/settings/plates',
      builder: (c, s) => const PlateInventoryScreen(),
    ),
    // The live session in progress (distinct from /workout/:id, its template).
    GoRoute(path: '/session', builder: (c, s) => const WorkoutScreen()),
    GoRoute(
      path: '/summary/:id',
      builder: (c, s) =>
          SummaryScreen(sessionId: int.parse(s.pathParameters['id']!)),
    ),
  ],
);
