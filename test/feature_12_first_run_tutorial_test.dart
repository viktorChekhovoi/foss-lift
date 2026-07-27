// Integration tests for features/12-first-run-tutorial.md — the one-time
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
import 'package:foss_lift/widgets/tutorial.dart';

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
      expect(find.text(kTutorialSteps.first.title), findsOneWidget,
          reason: 'the tour should open on its welcome step');
      expect(find.text('Take the tour'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);

      // Declining means "don't run again on its own" — it must persist the flag.
      await tester.tap(find.text('Not now'));
      await pumpUntil(
          tester, () => container.read(tutorialSeenProvider).value == true);

      expect(container.read(tutorialSeenProvider).value, isTrue,
          reason: 'dismissing records that the tour has been seen');

      // And the overlay is gone, cleanly — nothing of it left on screen.
      expect(find.text(kTutorialSteps.first.title), findsNothing);
      expect(find.text('Take the tour'), findsNothing);

      await stop(tester);
    });

    testWidgets('taking it goes on to the first coach mark', (tester) async {
      await tester.pumpWidget(
          appUnder(container, TutorialOverlay(child: _anchoredHost(null))));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      await tester.tap(find.text('Take the tour'));
      await tester.pump();

      // The second step is the first one that points at something, and its
      // buttons go back to reading as navigation.
      expect(find.text(kTutorialSteps[1].title), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

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
      expect(find.text(kTutorialSteps.first.title), findsNothing);

      // What Profile → Help & tour does.
      container.read(tutorialProvider.notifier).start();
      await tester.pump();

      expect(find.text(kTutorialSteps.first.title), findsOneWidget,
          reason: 'a replay begins at the greeting, not mid-tour');

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

      expect(find.text(kTutorialSteps.first.title), findsNothing,
          reason: 'a returning user must not see the tour again');

      await stop(tester);
    });
  });
}
