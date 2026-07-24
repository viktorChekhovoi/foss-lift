import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/router.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/widgets/resume_workout_bar.dart';
import 'package:foss_lift/widgets/tutorial.dart';

/// The first-run tour is an overlay in `MaterialApp.router`'s builder, above the
/// resume pill and pointing at real widgets on Today. These tests mount the real
/// router — like the resume pill's — so the coach marks measure the same tree a
/// device would, and prove the two things the spec cares about: it runs itself
/// once on a genuine first run and is skippable, and it never runs on its own
/// again once that flag is set, but is still replayable on demand.
///
/// Today reads live SQLite, which never completes under a widget test's faked
/// clock — so the whole body runs inside [WidgetTester.runAsync] with a real one.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async {
    appRouter.go('/today'); // reset the shared router between runs
    container.dispose();
    await db.close();
  });

  Widget app() => UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: appRouter,
          builder: (c, child) =>
              TutorialOverlay(child: ResumeWorkoutOverlay(child: child!)),
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('runs itself on a first launch and is skippable', (tester) async {
    await tester.runAsync(() async {
      await db.watchRoutines().first; // trigger the seed
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      await tester.pumpWidget(app());
      await settle(tester);

      // The first coach mark is up, anchored to the next workout, with a Skip
      // control right there on it.
      expect(find.text('Your next workout'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('1/${kTutorialSteps.length}'), findsOneWidget);

      // Skipping closes the tour and records it as seen, so it will not return.
      await tester.tap(find.text('Skip'));
      await settle(tester);

      expect(find.text('Your next workout'), findsNothing);
      expect(await db.watchTutorialSeen().first, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('steps forward through to the end', (tester) async {
    await tester.runAsync(() async {
      await db.watchRoutines().first;
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      await tester.pumpWidget(app());
      await settle(tester);

      expect(find.text('Your next workout'), findsOneWidget);

      // Walk the whole tour on the Next button; the last step reads "Done".
      for (var i = 0; i < kTutorialSteps.length - 1; i++) {
        expect(find.text('Next'), findsOneWidget);
        await tester.tap(find.text('Next'));
        await settle(tester);
      }
      expect(find.text('Done'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await settle(tester);

      // Reaching the end is the same as skipping: gone, and marked seen.
      expect(find.text('Skip'), findsNothing);
      expect(await db.watchTutorialSeen().first, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('does not run again once seen, but can be replayed',
      (tester) async {
    await tester.runAsync(() async {
      await db.watchRoutines().first;
      await db.setTutorialSeen(true); // as if a previous launch dismissed it
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      await tester.pumpWidget(app());
      await settle(tester);

      // No auto-run: the flag says it has been seen.
      expect(find.text('Your next workout'), findsNothing);

      // The help menu replays it on demand.
      container.read(tutorialProvider.notifier).start();
      await settle(tester);
      expect(find.text('Your next workout'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await settle(tester);
      expect(find.text('Your next workout'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
