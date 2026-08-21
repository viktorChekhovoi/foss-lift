// Screens mounted by the text-size and language layout sweeps.

import 'package:flutter/material.dart';
import 'package:foss_lift/data/starter_routines.dart';
import 'package:foss_lift/screens/about_screen.dart';
import 'package:foss_lift/screens/backup_screen.dart';
import 'package:foss_lift/screens/bar_settings_screen.dart';
import 'package:foss_lift/screens/exercise_detail_screen.dart';
import 'package:foss_lift/screens/exercise_form_screen.dart';
import 'package:foss_lift/screens/exercise_progress_screen.dart';
import 'package:foss_lift/screens/history_screen.dart';
import 'package:foss_lift/screens/language_screen.dart';
import 'package:foss_lift/screens/library_screen.dart';
import 'package:foss_lift/screens/plate_inventory_screen.dart';
import 'package:foss_lift/screens/profile_screen.dart';
import 'package:foss_lift/screens/routine_detail_screen.dart';
import 'package:foss_lift/screens/routine_edit_screen.dart';
import 'package:foss_lift/screens/routine_library_screen.dart';
import 'package:foss_lift/screens/routine_share_screen.dart';
import 'package:foss_lift/screens/routines_screen.dart';
import 'package:foss_lift/screens/exercise_settings_screen.dart';
import 'package:foss_lift/screens/summary_screen.dart';
import 'package:foss_lift/screens/appearance_screen.dart';
import 'package:foss_lift/screens/today_screen.dart';
import 'package:foss_lift/screens/workout_detail_screen.dart';
import 'package:foss_lift/screens/workout_edit_screen.dart';

/// Every screen that needs nothing but a database to render.
final Map<String, Widget Function()> kSweepScreens = {
  'today': () => const TodayScreen(),
  'routines': () => const RoutinesScreen(),
  'routine library': () => const RoutineLibraryScreen(),
  // The first program in the library, which needs no row of its own: the library
  // is code, so a preview renders against nothing but the app.
  'routine preview': () =>
      StarterRoutinePreviewScreen(routineKey: kStarterRoutines.first.key),
  'history': () => const HistoryScreen(),
  'profile': () => const ProfileScreen(),
  'library': () => const LibraryScreen(),
  'settings': () => const ExerciseSettingsScreen(),
  'bar': () => const BarSettingsScreen(),
  'plates': () => const PlateInventoryScreen(),
  'theme': () => const AppearanceScreen(),
  'language': () => const LanguageScreen(),
  'about': () => const AboutScreen(),
  // The size it would report needs a filesystem, which a test runner has no
  // plugin for; the screen renders '…' in its place and the words are the point.
  'backup': () => const BackupScreen(),
  'exercise form': () => const ExerciseFormScreen(),
  // A fresh database has never been asked which unit it trains in, so the gate
  // renders the question rather than its child — which is the thing to sweep.
};

/// The rest: screens that only exist pointed at a row, keyed the same way.
Map<String, Widget> idSweepScreens({
  required int exerciseId,
  required int workoutId,
  required int routineId,
  required int sessionId,
}) =>
    {
      'exercise detail': ExerciseDetailScreen(exerciseId: exerciseId),
      'exercise progress': ExerciseProgressScreen(exerciseId: exerciseId),
      'workout detail': WorkoutDetailScreen(workoutId: workoutId),
      'workout edit': WorkoutEditScreen(workoutId: workoutId),
      'routine detail': RoutineDetailScreen(routineId: routineId),
      'routine edit': RoutineEditScreen(routineId: routineId),
      'summary': SummaryScreen(sessionId: sessionId),
      'routine share': RoutineShareScreen(routineId: routineId),
      'custom theme': const CustomThemeEditorScreen(),
    };

// A sweep mounts these with `routedAppUnder(..., scaffold: true)` from
// `harness.dart` — the one way an app is put under test here. Several of these
// screens are tab bodies that never see a Scaffold of their own, which is what
// the flag is for.
