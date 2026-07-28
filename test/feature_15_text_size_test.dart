// Integration tests for features/index.html#sec15 — the app at every text size.
//
// The app follows the phone's text setting, and the user can nudge it on top of
// that. Both halves are here: the arithmetic that combines and clamps them, and
// a sweep that mounts every screen at every scale the pair can produce and
// fails on any overflow.
//
// The sweep is the point. Most of the app's text carries a hard-coded fontSize
// and several layouts are built from fixed widths, so "it survives a large
// font" is not something anybody can hold in their head — it has to be checked
// mechanically, on every screen, every time.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/about_screen.dart';
import 'package:foss_lift/screens/exercise_detail_screen.dart';
import 'package:foss_lift/screens/exercise_progress_screen.dart';
import 'package:foss_lift/screens/routine_detail_screen.dart';
import 'package:foss_lift/screens/routine_edit_screen.dart';
import 'package:foss_lift/screens/routine_share_screen.dart';
import 'package:foss_lift/screens/summary_screen.dart';
import 'package:foss_lift/screens/workout_detail_screen.dart';
import 'package:foss_lift/screens/workout_edit_screen.dart';
import 'package:foss_lift/screens/bar_settings_screen.dart';
import 'package:foss_lift/screens/exercise_form_screen.dart';
import 'package:foss_lift/screens/history_screen.dart';
import 'package:foss_lift/screens/library_screen.dart';
import 'package:foss_lift/screens/plate_inventory_screen.dart';
import 'package:foss_lift/screens/profile_screen.dart';
import 'package:foss_lift/screens/routines_screen.dart';
import 'package:foss_lift/screens/settings_screen.dart';
import 'package:foss_lift/screens/theme_settings_screen.dart';
import 'package:foss_lift/screens/today_screen.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/util/text_scale.dart';
import 'package:foss_lift/widgets/builder_widgets.dart';
import 'package:foss_lift/widgets/share_widgets.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

/// Mounts [child] at [scale], on a phone-sized viewport.
Widget scaled(ProviderContainer c, Widget child, double scale) =>
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        theme: AppTheme.build(kDefaultPalette),
        routerConfig: GoRouter(
          initialLocation: '/under-test',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const SizedBox.shrink(),
              routes: [
                GoRoute(
                  path: 'under-test',
                  // A Scaffold, because several of these are tab bodies that
                  // never see the screen without one.
                  builder: (_, _) => Scaffold(body: child),
                ),
              ],
            ),
          ],
        ),
        builder: (context, page) => MediaQuery(
          // copyWith, not a fresh MediaQueryData — a bare one has no size,
          // and everything downstream lays out against zero.
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: page!,
        ),
      ),
    );

void main() {
  late AppDatabase db;
  ProviderContainer? container;
  setUp(() => db = memoryDb());
  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  final screens = <String, Widget Function()>{
    'today': () => const TodayScreen(),
    'routines': () => const RoutinesScreen(),
    'history': () => const HistoryScreen(),
    'profile': () => const ProfileScreen(),
    'library': () => const LibraryScreen(),
    'settings': () => const SettingsScreen(),
    'bar': () => const BarSettingsScreen(),
    'plates': () => const PlateInventoryScreen(),
    'theme': () => const ThemeSettingsScreen(),
    'about': () => const AboutScreen(),
    'exercise form': () => const ExerciseFormScreen(),
  };

  for (final scale in [1.0, 1.3, 2.0]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} @ $scale', (tester) async {
        // 360 dp is the common budget-Android width and the tightest case.
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        container = containerFor(db);

        final errors = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) {
          final s = d.exception.toString();
          if (s.contains('overflowed')) {
            final chain = d.toString();
            final creator = RegExp(r'creator: ([^\n]+(?:\n\s+[^\n]+){0,4})')
                .firstMatch(chain);
            errors.add('${s.split('\n').first}  <<< ${creator?.group(1) ?? '?'}');
          } else {
            prev?.call(d);
          }
        };
        await tester.pumpWidget(scaled(container!, entry.value(), scale));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        FlutterError.onError = prev;

        expect(errors, isEmpty,
            reason: '${entry.key} at $scale×: ${errors.toSet().join(" | ")}');
        await stop(tester);
      });
    }
  }

  // Screens that need something to point at.
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('id screens @ $scale', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late int exerciseId, workoutId, routineId, sessionId;
      await tester.runAsync(() async {
        container = containerFor(db);
        exerciseId = (await exerciseNamed(db, 'Bench Press')).id;
        workoutId = await workoutIdNamed(db, 'Push');
        routineId = (await routineNamed(db)).id;
        sessionId = await db.saveSession(
          routineId: routineId,
          workoutId: workoutId,
          name: 'Push',
          startedAt: DateTime.now().subtract(const Duration(minutes: 40)),
          endedAt: DateTime.now(),
          durationSeconds: 2400,
          totalVolume: 4200,
          sets: const [],
        );
      });

      final targets = <String, Widget>{
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

      for (final t in targets.entries) {
        final errors = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) {
          final s = d.exception.toString();
          if (s.contains('overflowed')) {
            errors.add(s.split('\n').first);
          } else {
            prev?.call(d);
          }
        };
        await tester.pumpWidget(scaled(container!, t.value, scale));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        FlutterError.onError = prev;
        expect(find.byType(Text), findsWidgets,
            reason: '${t.key} rendered nothing to overflow');
        expect(errors, isEmpty,
            reason: '${t.key} at $scale×: ${errors.toSet().join(" | ")}');
      }
      await stop(tester);
    });
  }

  // The live board, which the issue calls out as the tightest layout.
  for (final scale in [1.3, 2.0]) {
    testWidgets('live board @ $scale', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        container = containerFor(db);
        await container!.read(activeWorkoutProvider.notifier).start(
            workoutId: await workoutIdNamed(db, 'Push'), name: 'Push');
      });

      final errors = <String>[];
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        final s = d.exception.toString();
        if (s.contains('overflowed')) {
          final chain = d.toString();
          final creator = RegExp(r'creator: ([^\n]+(?:\n\s+[^\n]+){0,4})')
              .firstMatch(chain);
          errors.add('${s.split('\n').first}  <<< ${creator?.group(1) ?? '?'}');
        } else {
          prev?.call(d);
        }
      };
      await tester.pumpWidget(scaled(container!, const WorkoutScreen(), scale));
      await tester.pump();
      // Open the warm-up group too — it has its own rows and stepper.
      final warm = find.text('WARM-UP');
      if (warm.evaluate().isNotEmpty) {
        await tester.tap(warm.first);
        await tester.pump();
      }
      FlutterError.onError = prev;

      expect(errors, isEmpty,
          reason: 'the live board at $scale×: ${errors.toSet().join(" | ")}');
      await stop(tester);
    });
  }

  group('the two settings combine, and the product is held in range', () {
    test('following the phone is the default', () {
      expect(resolveTextScale(system: 1.0, chosen: 1.0), 1.0);
      expect(resolveTextScale(system: 1.6, chosen: 1.0), 1.6,
          reason: 'a phone set large is followed, untouched');
    });

    test('the nudge multiplies the phone rather than replacing it', () {
      expect(resolveTextScale(system: 1.2, chosen: 1.15),
          closeTo(1.38, 0.001));
      expect(resolveTextScale(system: 1.0, chosen: 0.9), closeTo(0.9, 0.001));
    });

    test('and the product never leaves the range the layouts are swept at', () {
      // A phone at 2.0 and the app at 1.3 is 2.6 — a size nothing has been
      // checked at, which is not an accessibility feature.
      expect(resolveTextScale(system: 2.0, chosen: 1.3), kMaxTextScale);
      expect(resolveTextScale(system: 0.5, chosen: 0.9), kMinTextScale);
    });

    test('every offered step lands inside the range on an untouched phone', () {
      for (final choice in kTextScaleChoices.entries) {
        final got = resolveTextScale(system: 1.0, chosen: choice.value);
        expect(got, choice.value,
            reason: '${choice.key} is clamped on a default phone');
        expect(got, lessThanOrEqualTo(kMaxTextScale));
        expect(got, greaterThanOrEqualTo(kMinTextScale));
      }
    });

    test('the app never renders past the scale its screens are swept at', () {
      // The guard that keeps the sweep honest: if the ceiling ever rises above
      // what the sweep covers, this says so before a user finds out.
      expect(kMaxTextScale, 2.0);
    });
  });

  group('dialogs and sheets survive it too', () {
    // The screen sweep only sees what is laid out on the page, so anything
    // behind a tap is invisible to it — and a dialog is the tightest box in the
    // app, bounded on both axes by its own insets.
    //
    // Overflow only grows with scale, so these run at the ceiling and at 1.0.
    // Anything that holds at 2.0 holds below it.

    /// Scrolls [what] into view if the screen is long enough to have pushed it
    /// off, then taps it. At 2.0x a control that was on screen at 1.0x often is
    /// not, and the control is not what is under test here — the dialog is.
    Future<void> reach(WidgetTester tester, Finder what) async {
      if (what.evaluate().isEmpty) {
        await tester.scrollUntilVisible(what, 120,
            scrollable: find.byType(Scrollable).first);
      } else {
        await tester.ensureVisible(what);
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(what);
      await tester.pump(const Duration(milliseconds: 400));
    }

    /// A host with one button that opens [open], mounted at [scale].
    Future<void> pumpOpener(
      WidgetTester tester,
      double scale,
      Future<void> Function(BuildContext) open,
    ) async {
      await tester.pumpWidget(scaled(
        container!,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
        scale,
      ));
      await tester.pump();
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets('the shared asks @ $scale', (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        container = containerFor(db);

        final asks = <String, Future<void> Function(BuildContext)>{
          'a note': (c) => askNote(c, title: 'Bulgarian Split Squat',
              initial: 'Seat 4, pin 7 — and mind the left knee on the way down'),
          'a weight': (c) => askWeight(c,
              title: 'Bar for Bulgarian Split Squat', unit: 'kg',
              initialKg: 20, defaultLabel: 'Use default'),
          'a bar by name': (c) => askBar(c,
              title: 'Bar for Bulgarian Split Squat', unit: 'kg',
              currentKg: 20, defaultLabel: 'Use default'),
          'a pasted code': (c) => promptForCode(c,
              title: 'Paste a routine', hint: 'FLR1.… or a fosslift:// link'),
          'the exercise picker': (c) => pickExercise(c),
        };

        for (final ask in asks.entries) {
          final found = await overflowsDuring(() async {
            await pumpOpener(tester, scale, ask.value);
            await tester.tap(find.text('open'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            expect(find.text('open'), findsOneWidget);
          });
          expect(found, isEmpty,
              reason: '${ask.key} at $scale×: ${found.toSet().join(" | ")}');
        }
        await stop(tester);
      });

      testWidgets('the live board asks @ $scale', (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.runAsync(() async {
          container = containerFor(db);
          await container!.read(activeWorkoutProvider.notifier).start(
              workoutId: await workoutIdNamed(db, 'Push'), name: 'Push');
        });

        final found = await overflowsDuring(() async {
          await tester.pumpWidget(
              scaled(container!, const WorkoutScreen(), scale));
          await tester.pump();

          // The weight, typed in.
          await reach(tester, find.byKey(const ValueKey('working-weight-0')));
          expect(find.byType(TextField), findsWidgets);
          await tester.tap(find.text('Cancel'));
          await tester.pump(const Duration(milliseconds: 400));

          // The result, typed in.
          final cell = find.descendant(
            of: find.byKey(const ValueKey('0-0-Bench Press')),
            matching: find.byKey(const ValueKey('set-result')),
          );
          await tester.ensureVisible(cell);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.longPress(cell);
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Reps done'), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pump(const Duration(milliseconds: 400));

          // And the one that destroys work, which is the wordiest.
          await tester.tap(find.byTooltip('Abort workout'));
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Abort this workout?'), findsOneWidget);
          await tester.tap(find.text('Keep going'));
          await tester.pump(const Duration(milliseconds: 400));
        });

        expect(found, isEmpty,
            reason: 'the board at $scale×: ${found.toSet().join(" | ")}');
        await stop(tester);
      });

      testWidgets('switching workouts and units @ $scale', (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        late int pull;
        await tester.runAsync(() async {
          container = containerFor(db);
          pull = await workoutIdNamed(db, 'Pull');
          await container!.read(activeWorkoutProvider.notifier).start(
              workoutId: await workoutIdNamed(db, 'Push'), name: 'Push');
        });
        container!.read(activeWorkoutProvider.notifier).cycleSet(0, 0);

        var found = await overflowsDuring(() async {
          await tester.pumpWidget(
              scaled(container!, WorkoutDetailScreen(workoutId: pull), scale));
          await tester.pump(const Duration(milliseconds: 400));
          await reach(tester, find.text('Start workout'));
          // Names the live session and everything at stake in it — the longest
          // body text in any dialog the app shows.
          expect(find.text('Switch to Pull?'), findsOneWidget);
          await tester.tap(find.textContaining('Keep '));
          await tester.pump(const Duration(milliseconds: 400));
        });
        expect(found, isEmpty,
            reason: 'the switch ask at $scale×: ${found.toSet().join(" | ")}');

        found = await overflowsDuring(() async {
          await tester.pumpWidget(
              scaled(container!, const SettingsScreen(), scale));
          await tester.pump(const Duration(milliseconds: 400));
          await reach(tester, find.text('Pounds · lb'));
          expect(find.text('Switch to pounds?'), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pump(const Duration(milliseconds: 400));
        });
        expect(found, isEmpty,
            reason: 'the unit ask at $scale×: ${found.toSet().join(" | ")}');

        container!.read(activeWorkoutProvider.notifier).discard();
        await stop(tester);
      });

      testWidgets('the QR and the colour picker @ $scale', (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        late int routineId;
        await tester.runAsync(() async {
          container = containerFor(db);
          routineId = (await routineNamed(db)).id;
        });

        var found = await overflowsDuring(() async {
          await tester.pumpWidget(scaled(
              container!, RoutineShareScreen(routineId: routineId), scale));
          await tester.pump(const Duration(milliseconds: 400));
          await reach(tester, find.text('Show QR'));
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.tap(find.text('Done'));
          await tester.pump(const Duration(milliseconds: 400));
        });
        expect(found, isEmpty,
            reason: 'the QR dialog at $scale×: ${found.toSet().join(" | ")}');

        found = await overflowsDuring(() async {
          await tester.pumpWidget(
              scaled(container!, const CustomThemeEditorScreen(), scale));
          await tester.pump(const Duration(milliseconds: 400));
          await reach(tester, find.text('Accent'));
          // Two notations, three channels and the copy/paste controls, in a
          // dialog — the busiest row of controls in the app.
          expect(find.text('HSL'), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pump(const Duration(milliseconds: 400));
        });
        expect(found, isEmpty,
            reason: 'the colour picker at $scale×: ${found.toSet().join(" | ")}');

        await stop(tester);
      });

      testWidgets('the slot configuration sheet @ $scale', (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        late int workoutId;
        await tester.runAsync(() async {
          container = containerFor(db);
          workoutId = await workoutIdNamed(db, 'Push');
        });

        final found = await overflowsDuring(() async {
          await tester.pumpWidget(scaled(
              container!, WorkoutEditScreen(workoutId: workoutId), scale));
          await tester.pump(const Duration(milliseconds: 400));
          await reach(tester, find.text('Bench Press'));
          // Three captioned cards of two-column fields — the densest grid the
          // app draws, and the one most likely to break under a big font. The
          // steppers identify it: the screen behind the sheet has none.
          expect(find.byType(NumberStepper), findsWidgets,
              reason: 'the configuration sheet did not open');
        });
        expect(found, isEmpty,
            reason: 'the config sheet at $scale×: ${found.toSet().join(" | ")}');
        await stop(tester);
      });
    }
  });
}
