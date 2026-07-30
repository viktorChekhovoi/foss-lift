// Integration tests for features/index.html#sec17 — getting around.
//
// The spec:
//   * the app is four tabs, and the bar that switches them belongs to the shell
//     rather than to the screens inside it;
//   * every other screen stacks over the shell, so it carries no navigation bar;
//   * a screen with nothing on it yet says so in a line, and offers the next
//     step only where there is one.
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
import 'package:foss_lift/screens/today_screen.dart';
import 'package:foss_lift/theme/app_theme.dart';

import 'support/harness.dart';
import 'support/settle.dart';

/// The real router under a real database, as the app root builds it.
Widget wholeApp(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.build(kDefaultPalette),
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
      for (final tab in const ['Today', 'Routines', 'History', 'Profile']) {
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
}
