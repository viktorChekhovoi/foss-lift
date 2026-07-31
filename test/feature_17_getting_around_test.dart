// Integration tests for features/index.html#sec17 — getting around.
//
// The spec:
//   * the app is four tabs, and the bar that switches them belongs to the shell
//     rather than to the screens inside it;
//   * every other screen stacks over the shell, so it carries no navigation bar;
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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/router.dart';
import 'package:foss_lift/screens/history_screen.dart';
import 'package:foss_lift/screens/routine_detail_screen.dart';
import 'package:foss_lift/screens/theme_settings_screen.dart';
import 'package:foss_lift/screens/today_screen.dart';
import 'package:foss_lift/screens/workout_edit_screen.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/widgets/builder_widgets.dart';
import 'package:foss_lift/util/locales.dart';

import 'support/harness.dart';
import 'support/seeded.dart';
import 'support/settle.dart';

/// The real router under a real database, as the app root builds it.
Widget wholeApp(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.build(kDefaultPalette),
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kTestDelegates,
        routerConfig: appRouter,
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

    testWidgets('a screen opened over the tabs carries no navigation bar',
        (tester) async {
      await tester.pumpWidget(wholeApp(container));
      await pumpThroughDatabase(tester);
      expect(find.byType(NavigationBar), findsOneWidget);

      appRouter.push('/library');
      await pumpThroughDatabase(tester);

      expect(find.byType(NavigationBar), findsNothing,
          reason: 'the library stacks over the shell, not inside a tab');
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
        final routines = await db.watchRoutines().first;
        id = routines
            .firstWhere((r) => r.routine.name == 'Push / Pull / Legs')
            .routine
            .id;
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
      // under the strip.
      await tester.fling(list, const Offset(0, -6000), 4000);
      await tester.pumpAndSettle();

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
}
