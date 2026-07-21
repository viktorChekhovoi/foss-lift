import 'package:go_router/go_router.dart';

import 'screens/history_screen.dart';
import 'screens/home_shell.dart';
import 'screens/profile_screen.dart';
import 'screens/routine_detail_screen.dart';
import 'screens/routines_screen.dart';
import 'screens/summary_screen.dart';
import 'screens/today_screen.dart';
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
    GoRoute(
      path: '/routine/:id',
      builder: (c, s) =>
          RoutineDetailScreen(routineId: int.parse(s.pathParameters['id']!)),
    ),
    GoRoute(path: '/workout', builder: (c, s) => const WorkoutScreen()),
    GoRoute(
      path: '/summary/:id',
      builder: (c, s) =>
          SummaryScreen(workoutId: int.parse(s.pathParameters['id']!)),
    ),
  ],
);
