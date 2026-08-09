// Integration tests for the exercise filter control — the one line of buttons
// shared by the library screen and the builder's exercise picker.
//
// The control has been wrong twice. First it was two strips that scrolled
// sideways, which read as text cut off at the edge of the phone rather than as
// something you could drag. Then it was every chip laid out in the open: fifteen
// identical pills in two unlabelled blocks, four lines of the screen spent
// saying what two buttons say in one. What is asserted here is the third shape —
// a Muscle button and an Equipment button that name what they are narrowed to,
// each opening a sheet of its own vocabulary, and a Clear that appears only
// while something is on.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/screens/library_screen.dart';
import 'package:foss_lift/widgets/builder_widgets.dart';
import 'package:foss_lift/widgets/exercise_filters.dart';

import 'support/harness.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  /// Mounts the library on a Pixel-4a-width viewport.
  Future<ProviderContainer> pumpLibrary(
    WidgetTester tester, {
    Size size = const Size(390, 780),
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = containerFor(db);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      appUnder(container, const LibraryScreen(), textScale: textScale),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Ticks [label] in the sheet the [dimension] button opens, and comes back out.
  Future<void> narrowBy(
    WidgetTester tester,
    String dimension,
    String label,
  ) async {
    await tester.tap(find.byKey(filterButtonKey(dimension)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(filterChipKey(dimension, label)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kFilterSheetDoneKey));
    await tester.pumpAndSettle();
  }

  group('the control is one line, and says what it is doing', () {
    testWidgets('it opens as two buttons naming their dimension', (
      tester,
    ) async {
      await pumpLibrary(tester);

      expect(find.byKey(filterButtonKey('muscle')), findsOneWidget);
      expect(find.byKey(filterButtonKey('equipment')), findsOneWidget);
      // Both on one line: the control costs the list a row, not a block.
      final muscle = tester.getRect(find.byKey(filterButtonKey('muscle')));
      final equipment = tester.getRect(
        find.byKey(filterButtonKey('equipment')),
      );
      expect(equipment.top, closeTo(muscle.top, 1.0));
      expect(equipment.right, lessThanOrEqualTo(390.0));
      // And no vocabulary is spilled across the screen before it is asked for.
      // By key, not by word: "Dumbbell" is also what half the rows in the list
      // underneath say about themselves.
      for (final key in [
        filterChipKey('equipment', 'Dumbbell'),
        filterChipKey('muscle', 'Shoulders'),
      ]) {
        expect(
          find.byKey(key),
          findsNothing,
          reason: '$key is on screen unasked',
        );
      }

      await stop(tester);
    });

    testWidgets('a ticked value replaces the dimension on the button', (
      tester,
    ) async {
      await pumpLibrary(tester);

      expect(
        find.widgetWithText(FilterFacetButton, 'Muscle'),
        findsOneWidget,
        reason: 'nothing is ticked, so the button names the question',
      );

      await narrowBy(tester, 'muscle', 'Legs');

      expect(
        find.widgetWithText(FilterFacetButton, 'Legs'),
        findsOneWidget,
        reason: 'the button is the summary of what the list is showing',
      );
      expect(find.widgetWithText(FilterFacetButton, 'Muscle'), findsNothing);

      await narrowBy(tester, 'muscle', 'Arms');

      expect(
        find.widgetWithText(FilterFacetButton, 'Legs, Arms'),
        findsOneWidget,
        reason: 'two groups are two alternatives, and both are named',
      );

      await stop(tester);
    });

    testWidgets('Clear shows up only while something is on', (tester) async {
      await pumpLibrary(tester);

      expect(
        find.byKey(kFilterClearKey),
        findsNothing,
        reason: 'nothing is on, so there is nothing to undo',
      );

      await narrowBy(tester, 'equipment', 'Barbell');
      expect(find.byKey(kFilterClearKey), findsOneWidget);

      await tester.tap(find.byKey(kFilterClearKey));
      await tester.pumpAndSettle();

      expect(find.byKey(kFilterClearKey), findsNothing);
      expect(
        find.widgetWithText(FilterFacetButton, 'Equipment'),
        findsOneWidget,
      );

      await stop(tester);
    });
  });

  group('every filter still works', () {
    testWidgets('both dimensions narrow the library, and Clear lets them go', (
      tester,
    ) async {
      await pumpLibrary(tester);

      // Arms sorts first, so the library opens on it.
      expect(find.text('Barbell Curl'), findsOneWidget);

      // A barbell movement for legs, and no name needed to get here.
      await narrowBy(tester, 'equipment', 'Barbell');
      await narrowBy(tester, 'muscle', 'Legs');

      expect(find.text('Back Squat'), findsOneWidget);
      expect(find.text('Leg Press'), findsNothing, reason: 'a machine');
      expect(find.text('Barbell Curl'), findsNothing, reason: 'arms');

      await tester.tap(find.byKey(kFilterClearKey));
      await tester.pumpAndSettle();
      expect(find.text('Barbell Curl'), findsOneWidget);

      await stop(tester);
    });

    testWidgets(
      'the sheet narrows the list as it is ticked, not on the way out',
      (tester) async {
        // The list is the feedback: ticking Legs with the sheet still up should
        // already have narrowed what is underneath it.
        await pumpLibrary(tester);

        await tester.tap(find.byKey(filterButtonKey('muscle')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(filterChipKey('muscle', 'Legs')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(kFilterSheetDoneKey));
        await tester.pumpAndSettle();

        expect(find.text('Back Squat'), findsOneWidget);
        expect(find.text('Barbell Curl'), findsNothing);

        await stop(tester);
      },
    );

    testWidgets('the search text survives clearing the buttons', (
      tester,
    ) async {
      await pumpLibrary(tester);

      await tester.enterText(find.byType(TextField).first, 'squat');
      await tester.pumpAndSettle();
      await narrowBy(tester, 'equipment', 'Barbell');
      await tester.tap(find.byKey(kFilterClearKey));
      await tester.pumpAndSettle();

      // Clearing the buttons is undoing the buttons: "squat" is still the
      // question.
      expect(find.text('Back Squat'), findsOneWidget);
      expect(find.text('Bench Press'), findsNothing);

      await stop(tester);
    });

    testWidgets('the picker filters through the same control', (tester) async {
      tester.view.physicalSize = const Size(390, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        appUnder(
          container,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => pickExercise(context),
                child: const Text('Add exercise'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add exercise'));
      await tester.pumpAndSettle();

      expect(find.byType(ExerciseFilterChips), findsOneWidget);
      await narrowBy(tester, 'muscle', 'Legs');

      expect(find.text('Back Squat'), findsOneWidget);
      expect(find.text('Barbell Curl'), findsNothing);

      await stop(tester);
    });
  });

  group('a filter you set stays set', () {
    testWidgets('the library is still narrowed on the way back from a movement',
        (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = containerFor(db);
      addTearDown(container.dispose);

      // A router underneath, because opening a movement is a push: the row
      // navigates, and the question is what the library is showing on the way
      // back.
      // Both spellings of the detail route: the library opens a movement in
      // the tab it is being browsed from, and under a bare router that tab is
      // Today.
      Widget library() => routedAppUnder(
            container,
            const LibraryScreen(),
            alsoRoutes: ['exercise/:id', 'today/exercise/:id'],
          );
      await tester.pumpWidget(library());
      await tester.pumpAndSettle();

      await narrowBy(tester, 'muscle', 'Legs');
      await narrowBy(tester, 'muscle', 'Back');
      expect(
        find.widgetWithText(FilterFacetButton, 'Back, Legs'),
        findsOneWidget,
        reason: 'the button is what says the list is hiding things, and it '
            'says so without the sheet being opened to check',
      );

      // Open a movement, and come back out of it. Back sorts above Legs, so
      // the squat is scrolled to first — as it would be on a phone.
      await tester.dragUntilVisible(
        find.text('Back Squat'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back Squat'));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryScreen), findsNothing,
          reason: 'the row did not open anything');
      GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(FilterFacetButton, 'Back, Legs'),
        findsOneWidget,
        reason: 'the list came back showing all eighty-seven again',
      );
      expect(find.text('Barbell Curl'), findsNothing, reason: 'arms');

      // And leaving the library itself is the same journey: what was narrowed
      // is a choice about the library, not about the copy of the screen that
      // was showing it when the choice was made.
      await tester.pumpWidget(
        routedAppUnder(container, const SizedBox.shrink()),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(library());
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(FilterFacetButton, 'Back, Legs'),
        findsOneWidget,
        reason: 'the filter went with the screen that was showing it',
      );
      // A remounted list is back at the top, and Back sorts above Legs — so the
      // squat is below the fold exactly as it was the first time round. Scroll
      // to it the same way: what is being asserted is that it survived the
      // filter, not that it happens to fit on screen.
      await tester.dragUntilVisible(
        find.text('Back Squat'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Back Squat'), findsOneWidget);
      expect(find.text('Barbell Curl'), findsNothing);

      await stop(tester);
    });

    testWidgets('the picker is still narrowed for the next exercise',
        (tester) async {
      // Picking a movement closes the picker — and with the config sheet now
      // opening straight after it, adding three legs movements means opening
      // the picker three times. Re-ticking Legs each time is the same filter
      // set three times.
      tester.view.physicalSize = const Size(390, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        appUnder(
          container,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => pickExercise(context),
                child: const Text('Add exercise'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add exercise'));
      await tester.pumpAndSettle();
      await narrowBy(tester, 'muscle', 'Legs');
      expect(find.text('Back Squat'), findsOneWidget);

      // One movement taken, and back for the next.
      await tester.tap(find.text('Back Squat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add exercise'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(FilterFacetButton, 'Legs'),
        findsOneWidget,
        reason: 'the picker opened on the whole library again',
      );
      expect(find.text('Barbell Curl'), findsNothing, reason: 'arms');

      await stop(tester);
    });
  });

  group('it survives a large font', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('the library lays out cleanly at $scale×', (tester) async {
        final overflows = await overflowsDuring(() async {
          // 360 dp is the tightest common Android width.
          await pumpLibrary(
            tester,
            size: const Size(360, 780),
            textScale: scale,
          );
        });
        expect(overflows, isEmpty);
        await stop(tester);
      });
    }

    testWidgets('and so does the sheet, with every value reachable', (
      tester,
    ) async {
      final overflows = await overflowsDuring(() async {
        await pumpLibrary(tester, size: const Size(360, 780), textScale: 2.0);
        await tester.tap(find.byKey(filterButtonKey('muscle')));
        await tester.pumpAndSettle();
      });
      expect(overflows, isEmpty);

      // Every group is in the sheet — scrolled to if the font is large enough
      // to need it, which is what a sheet is for.
      for (final group in kMuscleGroups) {
        await tester.scrollUntilVisible(
          find.byKey(filterChipKey('muscle', group)),
          80,
          scrollable: find.descendant(
            of: find.byType(FilterFacetSheet),
            matching: find.byType(Scrollable),
          ),
        );
        expect(find.byKey(filterChipKey('muscle', group)), findsOneWidget);
      }

      await stop(tester);
    });
  });
}
