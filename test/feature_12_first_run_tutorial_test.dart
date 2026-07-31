// Integration tests for features/index.html#sec12 — the one-time
// coach-mark tour.
//
// The spec, kept modest by design:
//   * on first launch the tour shows (tutorialSeen defaults false on a fresh
//     install);
//   * it runs ONCE — a "seen" flag is recorded and remembered, so it never
//     reappears on its own;
//   * it is anchored to real UI (a light, robust widget check — not a
//     transcription of the callout copy).
//
// Tested through the real surface: the [AppDatabase] seen flag, the
// [tutorialSeenProvider], and the [TutorialOverlay] widget with a real anchor.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/today_screen.dart';
import 'package:foss_lift/widgets/tutorial.dart';
import 'package:foss_lift/widgets/tutorial_demo.dart';

import 'support/harness.dart';
import 'support/settle.dart';

/// A minimal host that carries the tour's first real anchor, so the overlay can
/// measure a target instead of guessing a position — mirroring how the app
/// hangs [tutorialTodayWorkoutKey] on Today's next-workout card.
Widget _anchoredHost(Widget? overlayChildExtra) => Scaffold(
      body: Center(
        child: SizedBox(
          key: tutorialTodayWorkoutKey,
          width: 200,
          height: 60,
          child: overlayChildExtra,
        ),
      ),
    );

/// The English catalogue: a step carries the way to ask for its words rather
/// than the words, so a test that wants to read one has to ask too.
final _l10n = l10nFor();

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = memoryDb();
    container = containerFor(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('the seen flag lifecycle', () {
    test('a fresh install has not seen the tour', () async {
      expect(await db.watchTutorialSeen().first, isFalse);

      final seen = await readWhen(
        container,
        tutorialSeenProvider,
        (v) => v.hasValue,
      );
      expect(seen.value, isFalse,
          reason: 'first launch should trigger the tour');
    });

    test('marking it seen is remembered', () async {
      await db.setTutorialSeen(true);
      expect(await db.watchTutorialSeen().first, isTrue);

      // And once more to prove it is idempotent, not toggled.
      await db.setTutorialSeen(true);
      expect(await db.watchTutorialSeen().first, isTrue);
    });

    test('the provider reflects the persisted flag', () async {
      await db.setTutorialSeen(true);
      final seen = await readWhen(
        container,
        tutorialSeenProvider,
        (v) => v.value == true,
        reason: 'watchTutorialSeen should propagate through the provider',
      );
      expect(seen.value, isTrue);
    });
  });

  group('what the tour covers', () {
    // Issue #64. The tour was written in week one and pointed at the app as it
    // was then; everything a new user would not find on their own — the live
    // board, the rest timer, the workout in the shade — went unmentioned.

    String saidAltogether() => kTutorialSteps
        .map((step) => '${step.title(_l10n)} ${step.body(_l10n)}')
        .join(' ')
        .toLowerCase();

    test('it introduces the live board, the rest timer and the shade', () {
      final said = saidAltogether();
      for (final subject in ['set', 'rest', 'notification']) {
        expect(said, contains(subject),
            reason: 'the tour never mentions $subject');
      }
    });

    test('the other tabs are told about, not navigated to', () {
      // The tour stays on the tab it opened on. A step about another tab
      // highlights that tab's button and describes what is behind it; it never
      // pushes a route, so nobody is left somewhere they did not ask to be.
      final onToday = {tutorialTodayWorkoutKey, tutorialLifetimeKey};
      for (final step in kTutorialSteps) {
        final key = step.key;
        if (key == null) continue; // the greeting points at nothing
        expect(key == tutorialNavBarKey || onToday.contains(key), isTrue,
            reason: 'a step is anchored to a screen the tour cannot reach: '
                '${step.title}');
      }
    });

    test('and it is still one sitting, not a manual', () {
      expect(kTutorialSteps.length, lessThanOrEqualTo(12));
    });

    test('it explains the note and the clip', () {
      final said = saidAltogether();
      for (final subject in ['note', 'clip']) {
        expect(said, contains(subject),
            reason: 'the tour never mentions the $subject');
      }
    });

    test('the shade step is titled for what it is about', () {
      // "Phone in your pocket" said where the phone was, not what the step was
      // about. Whichever step describes the notification says so in its title.
      final shade = kTutorialSteps.where(
          (s) => s.body(_l10n).toLowerCase().contains('notification'));
      expect(shade, isNotEmpty, reason: 'no step covers the shade at all');
      for (final step in shade) {
        expect(step.title(_l10n).toLowerCase(), contains('notification'),
            reason: 'the shade step is titled "${step.title(_l10n)}"');
      }
      expect(saidAltogether(), isNot(contains('pocket')));
    });

    test('the live-workout steps carry a demo rather than an anchor', () {
      final demos = kTutorialSteps.where((s) => s.demo != null).toList();
      expect(
          demos.map((s) => s.demo).toSet(),
          containsAll(<Object>[
            TutorialDemo.board,
            TutorialDemo.restBar,
            TutorialDemo.shade,
          ]),
          reason: 'the board, the rest bar and the shade should all be drawn');
      for (final step in demos) {
        expect(step.key, isNull,
            reason: 'a demo step points at the mock, not at a widget behind it: '
                '${step.title}');
      }
    });
  });

  group('the mock workout', () {
    /// Walks a freshly started tour to [index] and lets the frame settle.
    Future<void> walkTo(WidgetTester tester, int index) async {
      container.read(tutorialProvider.notifier).start();
      for (var i = 0; i < index; i++) {
        container.read(tutorialProvider.notifier).next();
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
    }

    int stepWith(TutorialDemo demo) {
      final i = kTutorialSteps.indexWhere((s) => s.demo == demo);
      expect(i, greaterThan(0), reason: 'no step draws $demo');
      return i;
    }

    testWidgets('the board step draws a board, not a hole in the screen',
        (tester) async {
      await db.setTutorialSeen(true);
      await tester.pumpWidget(
          appUnder(container, TutorialOverlay(child: _anchoredHost(null))));
      await walkTo(tester, stepWith(TutorialDemo.board));

      expect(find.byType(TutorialBoardDemo), findsOneWidget);
      // The parts the step is talking about are actually on it: the exercise
      // with its note icon, and set rows with a camera each.
      expect(find.byKey(kTutorialDemoNoteKey), findsOneWidget);
      expect(find.byKey(kTutorialDemoCameraKey), findsWidgets);

      await stop(tester);
    });

    testWidgets('the rest step draws the bar with its controls',
        (tester) async {
      await db.setTutorialSeen(true);
      await tester.pumpWidget(
          appUnder(container, TutorialOverlay(child: _anchoredHost(null))));
      await walkTo(tester, stepWith(TutorialDemo.restBar));

      expect(find.byType(TutorialRestDemo), findsOneWidget);
      for (final control in [
        _l10n.sessionRestMinus,
        _l10n.sessionRestPlus,
        _l10n.sessionRestSkip,
      ]) {
        expect(
            find.descendant(
              of: find.byType(TutorialRestDemo),
              matching: find.text(control),
            ),
            findsOneWidget,
            reason: 'the mock bar should offer $control');
      }

      await stop(tester);
    });

    testWidgets('the mock is drawn under a Material, so its text is styled',
        (tester) async {
      // Text with no Material above it paints in the framework's unstyled
      // red-on-yellow. The overlay is a bare Stack, so the mock has to bring
      // one — this caught exactly that on a device.
      await db.setTutorialSeen(true);
      await tester.pumpWidget(
          appUnder(container, TutorialOverlay(child: _anchoredHost(null))));
      await walkTo(tester, stepWith(TutorialDemo.board));

      expect(
          find.ancestor(
            of: find.byType(TutorialBoardDemo),
            matching: find.byType(Material),
          ),
          findsWidgets);

      await stop(tester);
    });

    testWidgets('the shade step draws the notification it describes',
        (tester) async {
      await db.setTutorialSeen(true);
      await tester.pumpWidget(
          appUnder(container, TutorialOverlay(child: _anchoredHost(null))));
      await walkTo(tester, stepWith(TutorialDemo.shade));

      expect(find.byType(TutorialShadeDemo), findsOneWidget);
      for (final action in ['DONE', 'MISSED']) {
        expect(find.text(action), findsOneWidget,
            reason: 'the mock notification should offer $action');
      }

      await stop(tester);
    });

    testWidgets('tapping the mock advances the tour rather than logging a set',
        (tester) async {
      await db.setTutorialSeen(true);
      await tester.pumpWidget(
          appUnder(container, TutorialOverlay(child: _anchoredHost(null))));
      final index = stepWith(TutorialDemo.board);
      await walkTo(tester, index);

      await tester.tap(find.byKey(kTutorialDemoCameraKey).first,
          warnIfMissed: false);
      await tester.pump();

      expect(container.read(tutorialProvider).step, index + 1,
          reason: 'the mock is a picture: a tap on it is a tap on the tour');
      // And nothing behind it started a session.
      expect(container.read(activeWorkoutProvider), isNull);

      await stop(tester);
    });
  });

  group('the overlay', () {
    testWidgets('shows on a genuine first run and dismissing remembers it',
        (tester) async {
      await tester.pumpWidget(
          appUnder(container, TutorialOverlay(child: _anchoredHost(null))));
      // Let the seen-flag stream emit false and the auto-start post-frame fire.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      // It opens on the greeting, not mid-sentence on a coach mark: the app
      // says what it is and offers the tour before pointing at anything.
      expect(find.text(kTutorialSteps.first.title(_l10n)), findsOneWidget,
          reason: 'the tour should open on its welcome step');
      expect(find.text(_l10n.tutorialTakeTour), findsOneWidget);
      expect(find.text(_l10n.tutorialNotNow), findsOneWidget);

      // Declining means "don't run again on its own" — it must persist the flag.
      await tester.tap(find.text(_l10n.tutorialNotNow));
      await pumpUntil(
          tester, () => container.read(tutorialSeenProvider).value == true);

      expect(container.read(tutorialSeenProvider).value, isTrue,
          reason: 'dismissing records that the tour has been seen');

      // And the overlay is gone, cleanly — nothing of it left on screen.
      expect(find.text(kTutorialSteps.first.title(_l10n)), findsNothing);
      expect(find.text(_l10n.tutorialTakeTour), findsNothing);

      await stop(tester);
    });

    testWidgets('taking it goes on to the first coach mark', (tester) async {
      await tester.pumpWidget(
          appUnder(container, TutorialOverlay(child: _anchoredHost(null))));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      await tester.tap(find.text(_l10n.tutorialTakeTour));
      await tester.pump();

      // The second step is the first one that points at something, and its
      // buttons go back to reading as navigation.
      expect(find.text(kTutorialSteps[1].title(_l10n)), findsOneWidget);
      expect(find.text(_l10n.tutorialSkip), findsOneWidget);
      expect(find.text(_l10n.tutorialNext), findsOneWidget);

      await stop(tester);
    });

    testWidgets('a replay from the help menu starts at the welcome too',
        (tester) async {
      // A returning user: the flag is already set, so nothing auto-starts.
      await db.setTutorialSeen(true);
      await tester.pumpWidget(
          appUnder(container, TutorialOverlay(child: _anchoredHost(null))));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text(kTutorialSteps.first.title(_l10n)), findsNothing);

      // What Profile → Help & tour does.
      container.read(tutorialProvider.notifier).start();
      await tester.pump();

      expect(find.text(kTutorialSteps.first.title(_l10n)), findsOneWidget,
          reason: 'a replay begins at the greeting, not mid-tour');

      await stop(tester);
    });

    testWidgets('an anchor below the fold is scrolled into view',
        (tester) async {
      // The whole point of a coach mark is that it points at something. On a
      // short screen with three training days queued, the lifetime card is off
      // the bottom of the Today tab — so the tour brings it up before
      // spotlighting it, rather than cutting a hole in a screen nobody can see.
      tester.view.physicalSize = const Size(390, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(routedAppUnder(
        container,
        Scaffold(body: TutorialOverlay(child: const TodayScreen())),
      ));
      await pumpThroughDatabase(tester);

      final anchor = find.byKey(tutorialLifetimeKey);
      expect(anchor, findsOneWidget);
      expect(tester.getRect(anchor).bottom, greaterThan(480.0),
          reason: 'the anchor should start off screen for this to mean '
              'anything');

      // Walk the tour to the step that points at it.
      final target =
          kTutorialSteps.indexWhere((s) => s.key == tutorialLifetimeKey);
      expect(target, greaterThan(0));
      container.read(tutorialProvider.notifier).start();
      for (var i = 0; i < target; i++) {
        container.read(tutorialProvider.notifier).next();
        await tester.pump();
      }
      expect(find.text(kTutorialSteps[target].title(_l10n)), findsOneWidget);

      // Let the scroll run.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }

      final rect = tester.getRect(anchor);
      expect(rect.top, greaterThanOrEqualTo(0.0));
      expect(rect.bottom, lessThanOrEqualTo(480.0),
          reason: 'the tour did not bring its anchor into view');

      await stop(tester);
    });

    testWidgets('never reappears once the flag is set', (tester) async {
      // The flag is written before the overlay ever subscribes, so its stream's
      // first emission is already `true` — the tour has no window to auto-start.
      await db.setTutorialSeen(true);

      await tester.pumpWidget(
          appUnder(container, TutorialOverlay(child: _anchoredHost(null))));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.text(kTutorialSteps.first.title(_l10n)), findsNothing,
          reason: 'a returning user must not see the tour again');

      await stop(tester);
    });
  });
}
