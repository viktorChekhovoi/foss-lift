import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/router.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/widgets/resume_workout_bar.dart';

/// The resume pill rides in `MaterialApp.router`'s builder, which runs inside
/// the router delegate's own build — so this mounts the *real* router to prove
/// the overlay reads the route without listening to the delegate (which would
/// notify during build and trip the framework's dirty assertion), and that a
/// collapsed session is reachable again from a plain browse.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async {
    appRouter.go('/today'); // reset shared router navigation between runs
    container.dispose();
    await db.close();
  });

  testWidgets('a collapsed session shows a resume pill that reopens it',
      (tester) async {
    await tester.runAsync(() async {
      final ppl = (await db.watchRoutines().first).first.routine;
      final push = (await db.workoutsForRoutine(ppl.id)).first;
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      await container
          .read(activeWorkoutProvider.notifier)
          .start(workoutId: push.id, name: 'Push');
    });

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        routerConfig: appRouter,
        builder: (c, child) => ResumeWorkoutOverlay(child: child!),
      ),
    ));
    await tester.pump();

    // Browsing (on /today) with a live session collapsed: the pill is up, and
    // — the point of this test — mounting it raised no build-phase assertion.
    expect(tester.takeException(), isNull);
    expect(find.text('RESUME'), findsOneWidget);

    // Tapping it drops back into the logging screen, where the pill hides.
    await tester.tap(find.text('RESUME'));
    await tester.pump();
    await tester.pump();
    expect(find.text('RESUME'), findsNothing);
    expect(find.text('Finish'), findsOneWidget, reason: 'the live screen is up');

    await tester.pumpWidget(const SizedBox.shrink()); // cancel timers
  });
}
