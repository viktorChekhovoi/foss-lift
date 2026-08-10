// Integration tests for features/index.html#sec17 — getting around.
//
// The spec:
//   * the app is four tabs, and the bar that switches them belongs to the shell
//     rather than to the screens inside it;
//   * a screen you browse to — a routine, a workout, an exercise, the library,
//     the settings pages — opens inside the shell and keeps the navigation bar,
//     and the tab you left keeps its own stack;
//   * two kinds of screen stack over the shell instead: the live session with
//     its set-recording screen, and a screen that is a single task to finish or
//     abandon (the scanner, an import awaiting review, sharing, clip playback);
//   * a screen with its own bottom furniture sits above the tabs, and the
//     resume-workout bar shows in exactly one place;
//   * a screen with nothing on it yet says so in a line, and offers the next
//     step only where there is one;
//   * the phone's own bars never cover a control.
//
// The last one is measured, not eyeballed: the tests below give the test view a
// bottom system-bar strip the way a phone with three-button navigation does,
// then compare the rectangle of a control against it.
//
// The tab shell is exercised through the real `appRouter` — a stub shell would
// prove the widget works and say nothing about the routes the app actually has.
//
// Database setup runs inside `runAsync`: drift's futures only complete on the
// real event loop, which a `testWidgets` body does not turn on its own.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/router.dart';
import 'package:foss_lift/screens/clip_player_screen.dart';
import 'package:foss_lift/screens/exercise_detail_screen.dart';
import 'package:foss_lift/screens/history_screen.dart';
import 'package:foss_lift/screens/library_screen.dart';
import 'package:foss_lift/screens/routine_detail_screen.dart';
import 'package:foss_lift/screens/routine_import_screen.dart';
import 'package:foss_lift/screens/appearance_screen.dart';
import 'package:foss_lift/screens/scan_screen.dart';
import 'package:foss_lift/screens/today_screen.dart';
import 'package:foss_lift/screens/workout_detail_screen.dart';
import 'package:foss_lift/screens/workout_edit_screen.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/widgets/builder_widgets.dart';
import 'package:foss_lift/widgets/common.dart';
import 'package:foss_lift/widgets/resume_workout_bar.dart';
import 'package:foss_lift/util/locales.dart';

import 'support/harness.dart';
import 'support/seeded.dart';
import 'support/settle.dart';

/// The real router under a real database, as the app root builds it.
///
/// [withResumeBar] adds the app-level slot `main.dart` wraps every route in, so
/// a test can count the bar across *both* of its mount points rather than only
/// the shell's.
Widget wholeApp(ProviderContainer container, {bool withResumeBar = false}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.build(kDefaultPalette),
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kTestDelegates,
        routerConfig: appRouter,
        builder: withResumeBar
            ? (context, child) =>
                ResumeWorkoutOverlay(router: appRouter, child: child!)
            : null,
      ),
    );

/// A tab's label, as opposed to the same word in a screen's own heading.
Finder tabLabel(String name) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(name),
    );

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = memoryDb();
    container = containerFor(db);
    // `appRouter` is a global, so a test that navigated away would otherwise
    // hand the next one whatever screen it finished on.
    appRouter.go('/today');
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('the tab shell', () {
    testWidgets('the app is four tabs', (tester) async {
      await tester.pumpWidget(wholeApp(container));
      await pumpThroughDatabase(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      final l10n = l10nFor();
      for (final tab in [
        l10n.navToday,
        l10n.navRoutines,
        l10n.navHistory,
        l10n.navProfile,
      ]) {
        expect(tabLabel(tab), findsOneWidget, reason: 'the $tab tab');
      }
    });

    testWidgets('the bar belongs to the shell, not to the tab screen',
        (tester) async {
      await tester.pumpWidget(wholeApp(container));
      await pumpThroughDatabase(tester);

      expect(find.byType(TodayScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TodayScreen),
          matching: find.byType(NavigationBar),
        ),
        findsNothing,
        reason: 'the screen does not draw the bar or reserve room for it',
      );
    });
  });

  // ---------------------------------------------------------------------
  // Which screens keep the tabs and which stack over them.
  //
  // Every one of these drives the real `appRouter`: the question is not whether
  // a screen *can* be drawn inside a shell but whether the route the app
  // actually navigates to puts it there, and only the real route table answers
  // that.

  /// Pushes [location] on the app router and lets the screen behind it load.
  Future<void> pushTo(WidgetTester tester, String location) async {
    appRouter.push(location);
    await pumpThroughDatabase(tester);
  }

  /// The app at `/today`, with [location] pushed on top of it.
  Future<void> openOverToday(WidgetTester tester, String location,
      {bool withResumeBar = false}) async {
    await tester.pumpWidget(wholeApp(container, withResumeBar: withResumeBar));
    await pumpThroughDatabase(tester);
    expect(find.byType(NavigationBar), findsOneWidget,
        reason: 'the tabs are there before the push');
    await pushTo(tester, location);
  }

  /// The Push day of the seeded routine.
  Future<int> pushDayId(WidgetTester tester) async {
    late final int id;
    await tester.runAsync(() async {
      id = await workoutIdNamed(db, 'Push');
    });
    return id;
  }

  group('a screen you browse to keeps the tabs', () {
    testWidgets('a workout, with its Start button', (tester) async {
      final id = await pushDayId(tester);
      await openOverToday(tester, '/workout/$id');

      expect(find.byType(WorkoutDetailScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget,
          reason: 'a workout opens inside the shell and keeps the tabs');
      await stop(tester);
    });

    testWidgets('a routine', (tester) async {
      late final int id;
      await tester.runAsync(() async {
        id = (await routineNamed(db)).id;
      });
      await openOverToday(tester, '/routine/$id');

      expect(find.byType(RoutineDetailScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget,
          reason: 'a routine opens inside the shell and keeps the tabs');
      await stop(tester);
    });

    testWidgets('the library, and an exercise in it', (tester) async {
      await openOverToday(tester, '/library');
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget,
          reason: 'the library is browsing, not a task to finish');

      late final int id;
      await tester.runAsync(() async {
        id = (await exerciseNamed(db, 'Bench Press')).id;
      });
      await pushTo(tester, '/exercise/$id');

      expect(find.byType(ExerciseDetailScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget,
          reason: 'an exercise page keeps the tabs too');
      await stop(tester);
    });

    testWidgets('the settings pages', (tester) async {
      await openOverToday(tester, '/settings');
      expect(find.byType(NavigationBar), findsOneWidget,
          reason: 'settings is browsing');

      await pushTo(tester, '/settings/appearance');
      expect(find.byType(NavigationBar), findsOneWidget,
          reason: 'and so is a settings page inside it');
      await stop(tester);
    });
  });

  group('a screen you are finishing does not', () {
    testWidgets('the live session owns the whole screen', (tester) async {
      await tester.runAsync(() async {
        await container
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: await workoutIdNamed(db, 'Push'), name: 'Push');
      });

      await openOverToday(tester, '/session');

      expect(find.byType(WorkoutScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing,
          reason: 'the session owns the screen; its rest bar docks where the '
              'tabs would be');

      container.read(activeWorkoutProvider.notifier).discard();
      await stop(tester);
    });

    testWidgets('the scanner is a single task to finish or abandon',
        (tester) async {
      await openOverToday(tester, '/scan?for=routine');

      expect(find.byType(ScanScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing,
          reason: 'a stray tab tap would walk out of the scan');
      await stop(tester);
    });

    testWidgets('an import waiting to be reviewed', (tester) async {
      await openOverToday(tester, '/routine/import?code=nonsense');

      expect(find.byType(RoutineImportScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing,
          reason: 'the import is pending a decision, not a page to browse away '
              'from');
      await stop(tester);
    });

    testWidgets('clip playback', (tester) async {
      // The player resolves the clip against the app support directory, which
      // is a platform channel a widget test has none of. The file is missing
      // either way — the screen under test is the "clip is gone" one, and it is
      // still the full-screen player.
      const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pathProvider,
        (call) async => '/tmp/foss-lift-test',
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProvider, null));

      await openOverToday(tester, '/clip?path=clips/missing.mp4');

      expect(find.byType(ClipPlayerScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing,
          reason: 'the player is full screen');
      await stop(tester);
    });

    testWidgets('sharing a routine', (tester) async {
      late final int id;
      await tester.runAsync(() async {
        id = (await routineNamed(db)).id;
      });
      await openOverToday(tester, '/routine/$id/share');

      expect(find.byType(NavigationBar), findsNothing,
          reason: 'sharing is a task to finish or abandon');
      await stop(tester);
    });
  });

  group('the bottom of a screen inside the shell', () {
    testWidgets('the resume bar shows in exactly one place', (tester) async {
      await tester.runAsync(() async {
        await container
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: await workoutIdNamed(db, 'Push'), name: 'Push');
      });

      final id = await pushDayId(tester);
      await openOverToday(tester, '/workout/$id', withResumeBar: true);

      // Both mount points are in this tree — the shell's slot above the tabs
      // and the app's last row. Exactly one of them may answer for a screen
      // that is inside the shell, or the bar either doubles up or vanishes.
      expect(find.byKey(resumeWorkoutBarKey), findsOneWidget,
          reason: 'one bar: not two mount points both claiming it, and not '
              'both standing aside');

      final bar = tester.getRect(find.byKey(resumeWorkoutBarKey));
      final nav = tester.getRect(find.byType(NavigationBar));
      expect(bar.bottom, lessThanOrEqualTo(nav.top + 0.5),
          reason: 'the resume bar rides above the tabs');

      container.read(activeWorkoutProvider.notifier).discard();
      await stop(tester);
    });

    testWidgets("a screen's own bottom furniture sits above the tabs",
        (tester) async {
      final id = await pushDayId(tester);
      await openOverToday(tester, '/workout/$id');

      final start =
          find.widgetWithText(FilledButton, l10nFor().workoutDetailStart);
      expect(start, findsOneWidget, reason: 'the Start button is on screen');
      final nav = find.byType(NavigationBar);
      expect(nav, findsOneWidget);

      expect(tester.getRect(start).bottom,
          lessThanOrEqualTo(tester.getRect(nav).top + 0.5),
          reason: 'Start sits above the tabs rather than under them');
      await stop(tester);
    });
  });

  group('leaving a browsed screen for another tab', () {
    testWidgets('is one tap, and the tab you left keeps its stack',
        (tester) async {
      final id = await pushDayId(tester);
      await openOverToday(tester, '/workout/$id');
      expect(find.byType(WorkoutDetailScreen), findsOneWidget);

      await tester.tap(tabLabel(l10nFor().navHistory));
      await pumpThroughDatabase(tester);

      expect(find.byType(HistoryScreen), findsOneWidget,
          reason: 'one tap to History, not a walk back up the stack');
      expect(find.byType(WorkoutDetailScreen), findsNothing);

      await tester.tap(tabLabel(l10nFor().navToday));
      await pumpThroughDatabase(tester);

      expect(find.byType(WorkoutDetailScreen), findsOneWidget,
          reason: "Today is where it was left — on the workout, not back at "
              'the tab root');
      await stop(tester);
    });
  });

  group('a screen with nothing on it', () {
    testWidgets('History before the first session says so, and offers nothing',
        (tester) async {
      await tester.pumpWidget(appUnder(container, const HistoryScreen()));
      await pumpThroughDatabase(tester);

      // The header eyebrow is upper-cased on the way to the screen.
      expect(find.text('NO SESSIONS YET'), findsOneWidget);
      expect(find.text('No workouts logged yet'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('a routine with no training days says so', (tester) async {
      late final int id;
      await tester.runAsync(() async {
        id = await db.createRoutine(
          name: 'Empty',
          color: 'FF6A3D',
          restSeconds: 90,
        );
      });

      await tester.pumpWidget(
        appUnder(container, RoutineDetailScreen(routineId: id)),
      );
      await pumpThroughDatabase(tester);

      expect(find.text('No workouts yet. Tap the edit icon to add one.'),
          findsOneWidget);
    });

    testWidgets('Today with no routines offers the next step', (tester) async {
      await tester.runAsync(() async {
        for (final r in await db.watchRoutines().first) {
          await db.deleteRoutine(r.routine.id);
        }
      });

      await tester.pumpWidget(appUnder(container, const TodayScreen()));
      await pumpThroughDatabase(tester);
      await pumpUntil(
        tester,
        () => find.text('No routines yet').evaluate().isNotEmpty,
      );

      expect(find.text('No routines yet'), findsOneWidget);
      expect(find.text('Build a routine'), findsOneWidget);
    });
  });

  group('the routine page', () {
    testWidgets('lists the training days in order, with what each holds',
        (tester) async {
      late final int id;
      await tester.runAsync(() async {
        id = (await routineNamed(db)).id;
      });

      await tester.pumpWidget(
        appUnder(container, RoutineDetailScreen(routineId: id)),
      );
      await pumpThroughDatabase(tester);
      await pumpUntil(
        tester,
        () => find.text('Push').evaluate().isNotEmpty,
      );

      expect(find.text('Push'), findsOneWidget);
      expect(find.text('Pull'), findsOneWidget);
      expect(find.text('Legs'), findsOneWidget);
      expect(find.textContaining('workouts'), findsOneWidget);
    });
  });

  group("the phone's own bars", () {
    const screen = Size(360, 780);
    const navBar = 48.0;

    /// Puts a bottom system-bar strip on the test view, the way a phone with
    /// three-button navigation has one, plus a [keyboard] over it.
    ///
    /// `padding` is what the framework hands a screen: the strip, less whatever
    /// the keyboard already covers. Setting it by hand is the whole point — a
    /// test view has no bars at all, so nothing here can be measured until it
    /// does.
    void systemBars(WidgetTester tester, {double keyboard = 0}) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = screen;
      tester.view.viewPadding = const FakeViewPadding(bottom: navBar);
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      tester.view.padding =
          FakeViewPadding(bottom: (navBar - keyboard).clamp(0.0, navBar));
      addTearDown(tester.view.reset);
    }

    /// The Push day's editor, loaded and scrolled to its slots.
    Future<void> openEditor(WidgetTester tester) async {
      late final int workoutId;
      await tester.runAsync(() async {
        workoutId = await workoutIdNamed(db, 'Push');
      });
      await tester.pumpWidget(
        appUnder(container, WorkoutEditScreen(workoutId: workoutId)),
      );
      await pumpThroughDatabase(tester);
      await pumpUntil(
        tester,
        () => find.text('Bench Press').evaluate().isNotEmpty,
      );
    }

    /// That editor, with the configuration sheet for Bench Press open on it.
    Future<void> openSlotSheet(WidgetTester tester) async {
      await openEditor(tester);
      await tester.ensureVisible(find.text('Bench Press'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Bench Press'));
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('a sheet keeps its button clear of the navigation strip',
        (tester) async {
      systemBars(tester);
      await openSlotSheet(tester);

      final done = find.widgetWithText(FilledButton, l10nFor().commonDone);
      expect(done, findsOneWidget,
          reason: 'the slot configuration sheet did not open');
      // The sheet is taller than the screen, so the button is scrolled to
      // before it is measured: the question is where the sheet lets it come to
      // rest, not whether it starts on screen.
      await tester.ensureVisible(done);
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.getRect(done).bottom,
          lessThanOrEqualTo(screen.height - navBar),
          reason: 'Done is under the Back / Home / Recents keys');
      await stop(tester);
    });

    testWidgets('a keyboard and the strip are not counted twice',
        (tester) async {
      const keyboard = 300.0;
      systemBars(tester, keyboard: keyboard);
      await openSlotSheet(tester);

      final done = find.widgetWithText(FilledButton, l10nFor().commonDone);
      await tester.ensureVisible(done);
      await tester.pump(const Duration(milliseconds: 300));

      final bottom = tester.getRect(done).bottom;
      expect(bottom, lessThanOrEqualTo(screen.height - keyboard),
          reason: 'Done is behind the keyboard');
      expect(bottom, greaterThan(screen.height - keyboard - navBar),
          reason: 'the strip is being counted on top of the keyboard, which '
              'already covers it');
      await stop(tester);
    });

    testWidgets('the exercise picker scrolls to a last row that is tappable',
        (tester) async {
      systemBars(tester);
      await openEditor(tester);
      // The picker is the other sheet that reaches the bottom of the screen.
      final add = find.text(l10nFor().itemEditorAdd);
      await tester.ensureVisible(add);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(add);
      await tester.pump(const Duration(milliseconds: 400));
      await pumpThroughDatabase(tester);

      // Scoped to the picker: the editor behind it has a list of its own.
      final list = find.descendant(
        of: find.byType(ExercisePicker),
        matching: find.byType(ListView),
      );
      expect(list, findsOneWidget, reason: 'the picker did not open');
      // To the end of the library, where a row would otherwise come to rest
      // under the strip. **Flung until the position stops moving**, not once: the
      // library is well over a hundred movements and one fling leaves the list in
      // the middle of itself, where the last row built is simply a row below the
      // fold rather than the last row there is.
      // The list's own Scrollable, not the picker's: the filter chips scroll too.
      final scrollable =
          find.descendant(of: list, matching: find.byType(Scrollable));
      for (var fling = 0; fling < 30; fling++) {
        final at = tester.state<ScrollableState>(scrollable).position;
        if (at.pixels >= at.maxScrollExtent - 1) break;
        await tester.fling(list, const Offset(0, -6000), 4000);
        await tester.pumpAndSettle();
      }

      expect(tester.getRect(find.byType(ListTile).last).bottom,
          lessThanOrEqualTo(screen.height - navBar),
          reason: 'the last exercise in the picker sits under the strip');
      await stop(tester);
    });

    testWidgets('a dialog keeps its buttons clear of the strip',
        (tester) async {
      systemBars(tester);
      await tester.pumpWidget(
        appUnder(container, const CustomThemeEditorScreen()),
      );
      await pumpThroughDatabase(tester);
      // The colour picker: three channel sliders, a hex field and the copy and
      // paste controls, which makes it the tallest dialog in the app.
      final role = find.text(l10nFor().themeRoleAccent);
      if (role.evaluate().isEmpty) {
        await tester.scrollUntilVisible(role, 120,
            scrollable: find.byType(Scrollable).first);
      } else {
        await tester.ensureVisible(role);
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(role);
      await tester.pump(const Duration(milliseconds: 400));

      final cancel = find.widgetWithText(TextButton, l10nFor().commonCancel);
      expect(cancel, findsOneWidget, reason: 'the colour picker did not open');
      expect(tester.getRect(cancel).bottom,
          lessThanOrEqualTo(screen.height - navBar),
          reason: 'the dialog runs under the strip');
      await stop(tester);
    });

    testWidgets('the tab bar sits above the strip', (tester) async {
      systemBars(tester);
      await tester.pumpWidget(wholeApp(container));
      await pumpThroughDatabase(tester);

      final tab = tabLabel(l10nFor().navProfile);
      expect(tab, findsOneWidget);
      expect(tester.getRect(tab).bottom,
          lessThanOrEqualTo(screen.height - navBar),
          reason: 'the Profile tab is under the strip');
      await stop(tester);
    });
  });

  // -------------------------------------------------------------------------

  group('one type scale, in the shared widgets', () {
    // The sizes are a property of ScreenHeader and SectionLabel, so they are
    // read back off what those widgets actually render rather than off the
    // constants — a screen that retyped a fontSize would pass a test of the
    // constants and still look flat.
    TextStyle styleOf(WidgetTester tester, String text) =>
        tester.widget<Text>(find.text(text)).style!;

    testWidgets('a title, an eyebrow and a section heading are three sizes',
        (tester) async {
      await tester.pumpWidget(appUnder(
        containerFor(db),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(eyebrow: 'eyebrow', title: 'Title'),
            SectionLabel('heading'),
          ],
        ),
      ));
      await tester.pump();

      final title = styleOf(tester, 'Title').fontSize!;
      final eyebrow = styleOf(tester, 'EYEBROW').fontSize!;
      final heading = styleOf(tester, 'HEADING').fontSize!;

      expect(title / heading, greaterThanOrEqualTo(2.5),
          reason: 'a screen title has to dwarf a section heading, not edge it');
      expect(eyebrow, greaterThan(heading),
          reason: 'the line above a title outranks a heading in a list');
      expect(title / eyebrow, greaterThanOrEqualTo(1.8),
          reason: 'the title has to be the thing you see first');
      await stop(tester);
    });

    testWidgets('the same sizes wherever the widgets are used', (tester) async {
      // Two SectionLabels in different places render identically: the size
      // belongs to the widget, not to the screen that mounted it.
      await tester.pumpWidget(appUnder(
        containerFor(db),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [SectionLabel('one'), SectionLabel('two')],
        ),
      ));
      await tester.pump();
      expect(styleOf(tester, 'ONE').fontSize, styleOf(tester, 'TWO').fontSize);
      expect(styleOf(tester, 'ONE').color, styleOf(tester, 'TWO').color);
      await stop(tester);
    });
  });
}
