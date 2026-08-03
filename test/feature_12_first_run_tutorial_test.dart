// Integration tests for features/index.html#sec12 — the guided tours.
//
// The spec, from the catalogue:
//   * first launch offers a choice of two tours rather than starting one;
//   * the full tour walks the four tabs, then Today, then the live workout it
//     cannot show; the quick tour is the four tabs and stops;
//   * a third tour covers building a routine and starts on its own;
//   * a step that asks you to tap something lets the tap through to the real
//     widget, and the tour moves on with it;
//   * skipping says where to replay it from, and it runs once by itself.
//
// Tested through the real surface: the [AppDatabase] seen flag, the
// [tutorialSeenProvider], and the [TutorialOverlay] widget with real anchors.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/profile_screen.dart';
import 'package:foss_lift/screens/today_screen.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/widgets/tutorial.dart';
import 'package:foss_lift/widgets/tutorial_demo.dart';

import 'support/harness.dart';
import 'support/settle.dart';

/// The English catalogue: a step carries the way to ask for its words rather
/// than the words, so a test that wants to read one has to ask too.
final _l10n = l10nFor();

/// A minimal host carrying the tour's Today anchor plus a stand-in navigation
/// bar, so the overlay can measure a target instead of guessing a position —
/// mirroring how the app hangs the keys on Today and on `HomeShell`'s nav bar.
///
/// [onNavTap] and [onCardTap] record that the *real* widget got the tap, which
/// is the whole question a tap-through step asks.
Widget _anchoredHost({
  void Function(int)? onNavTap,
  VoidCallback? onCardTap,
}) =>
    Scaffold(
      body: Center(
        child: SizedBox(
          key: tutorialTodayWorkoutKey,
          width: 200,
          height: 60,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCardTap,
            child: const SizedBox.expand(),
          ),
        ),
      ),
      bottomNavigationBar: SizedBox(
        key: tutorialNavBarKey,
        height: 64,
        child: Row(
          children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onNavTap?.call(i),
                  child: const SizedBox.expand(),
                ),
              ),
          ],
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

  /// Everything a track says, lower-cased, for a "does it mention X" check.
  String saidBy(TutorialTrack track) => kTutorialTracks[track]!
      .map((step) => '${step.title(_l10n)} ${step.body(_l10n)}')
      .join(' ')
      .toLowerCase();

  group('the seen flag lifecycle', () {
    test('a fresh install has not seen the tour', () async {
      expect(await db.watchTutorialSeen().first, isFalse);

      final seen = await readWhen(
        container,
        tutorialSeenProvider,
        (v) => v.hasValue,
      );
      expect(seen.value, isFalse,
          reason: 'first launch should offer the tour');
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

  group('the tracks', () {
    test('every track begins at the four tabs, in order', () {
      for (final track in [TutorialTrack.full, TutorialTrack.quick]) {
        final steps = kTutorialTracks[track]!;
        for (var slot = 0; slot < 4; slot++) {
          expect(steps[slot].anchors, contains(tutorialNavBarKey),
              reason: '$track step $slot should point at the nav bar');
          expect(steps[slot].navSlot, slot,
              reason: '$track should walk the tabs left to right');
          expect(steps[slot].tapThrough, isTrue,
              reason: 'a tab step is a tab you actually tap');
        }
      }
    });

    test('the quick tour is the four tabs and little else', () {
      final steps = kTutorialTracks[TutorialTrack.quick]!;
      expect(steps.length, lessThanOrEqualTo(6));
      expect(steps.where((s) => s.demo != null), isEmpty,
          reason: 'the quick tour shows no mock workout');
    });

    test('the full tour covers Today and the live workout', () {
      final said = saidBy(TutorialTrack.full);
      for (final subject in ['set', 'rest', 'notification', 'note', 'clip']) {
        expect(said, contains(subject),
            reason: 'the full tour never mentions $subject');
      }
      expect(kTutorialTracks[TutorialTrack.full]!.length,
          lessThanOrEqualTo(16),
          reason: 'still one sitting, not a manual');
    });

    test('the full tour explains the gym words it uses', () {
      final said = saidBy(TutorialTrack.full);
      for (final word in ['routine', 'training day', 'rep']) {
        expect(said, contains(word),
            reason: 'somebody new to the gym is left guessing at "$word"');
      }
    });

    test('the builder tour covers making a routine', () {
      final steps = kTutorialTracks[TutorialTrack.builder]!;
      // It starts by sending you to Routines, then points at the real controls.
      expect(steps.first.anchors, contains(tutorialNavBarKey));
      expect(steps.first.navSlot, 1);
      final anchors = steps.expand((s) => s.anchors).toSet();
      for (final key in [
        tutorialNewRoutineKey,
        tutorialRoutineNameKey,
        tutorialRoutineDaysKey,
        tutorialRoutineSaveKey,
      ]) {
        expect(anchors, contains(key),
            reason: 'the builder tour never points at $key');
      }
    });

    test('the builder tour says what each per-exercise setting does', () {
      final said = saidBy(TutorialTrack.builder);
      for (final setting in ['sets', 'rep target', 'rest', 'step up', 'back off']) {
        expect(said, contains(setting),
            reason: 'the builder tour never explains "$setting"');
      }
    });

    test('the builder tour is not chained onto the first-run one', () {
      final builderAnchors =
          kTutorialTracks[TutorialTrack.builder]!.expand((s) => s.anchors);
      for (final track in [TutorialTrack.full, TutorialTrack.quick]) {
        final anchors = kTutorialTracks[track]!.expand((s) => s.anchors);
        expect(anchors, isNot(contains(tutorialNewRoutineKey)),
            reason: '$track should end without walking into the builder');
      }
      expect(builderAnchors, contains(tutorialNewRoutineKey));
    });

    test('the live-workout steps carry a mock rather than an anchor', () {
      final demos =
          kTutorialTracks[TutorialTrack.full]!.where((s) => s.demo != null);
      expect(
          demos.map((s) => s.demo).toSet(),
          containsAll(<Object>[
            TutorialDemo.screen,
            TutorialDemo.shade,
          ]),
          reason: 'the session screen and the shade should both be drawn');
      expect(
          demos.map((s) => s.focus).toSet(),
          containsAll(<Object>[
            TutorialDemoFocus.nextSet,
            TutorialDemoFocus.rest,
            TutorialDemoFocus.note,
            TutorialDemoFocus.camera,
          ]),
          reason: 'the set rows, the rest bar, the note and the clip each get '
              'their own step against the same screen');
      for (final step in demos) {
        expect(step.anchors, isEmpty,
            reason: 'a mock step points at its picture, not at a widget behind '
                'it: ${step.id}');
      }
    });

    test('the live workout follows the training day that starts one', () {
      final ids = kTutorialTracks[TutorialTrack.full]!.map((s) => s.id).toList();
      final next = ids.indexOf('today-next');
      final session = ids.where((id) => id.startsWith('session-')).toList();
      expect(next, greaterThan(0));
      expect(session, isNotEmpty);

      // The chapter opens on the transition, immediately after the card that
      // leads to it — a card you tap, a screen it opens, the thing you do there.
      expect(ids[next + 1], 'session-open');
      expect(ids.sublist(next + 1, next + 1 + session.length), session,
          reason: 'the session chapter is one unbroken run');
      expect(ids.indexOf('today-lifetime'), next + 1 + session.length,
          reason: 'the lifetime totals come out the other side of it');
    });

    test('the chapter opens by naming the transition', () {
      final open = kTutorialTracks[TutorialTrack.full]!
          .firstWhere((s) => s.id == 'session-open');
      expect(open.demo, TutorialDemo.screen);
      final said =
          '${open.title(_l10n)} ${open.body(_l10n)}'.toLowerCase();
      expect(said, contains('start workout'),
          reason: 'nothing on screen moved, so the tour has to say why the '
              'picture changed');
    });

    test('the shade step is titled for what it is about', () {
      final shade = kTutorialTracks[TutorialTrack.full]!
          .where((s) => s.body(_l10n).toLowerCase().contains('notification'));
      expect(shade, isNotEmpty, reason: 'no step covers the shade at all');
      for (final step in shade) {
        expect(step.title(_l10n).toLowerCase(), contains('notification'),
            reason: 'the shade step is titled "${step.title(_l10n)}"');
      }
      expect(saidBy(TutorialTrack.full), isNot(contains('pocket')));
    });
  });

  group('the opening choice', () {
    testWidgets('a first run offers two tours and neither', (tester) async {
      await tester
          .pumpWidget(appUnder(container, TutorialOverlay(child: _anchoredHost())));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.text(_l10n.tutorialChooseTitle), findsOneWidget);
      // Both tracks, each with the one line saying what is in it — the choice
      // is informative, not a ranking.
      for (final label in [
        _l10n.tutorialTrackFull,
        _l10n.tutorialTrackFullHint,
        _l10n.tutorialTrackQuick,
        _l10n.tutorialTrackQuickHint,
        _l10n.tutorialNotNow,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      // No coach mark yet: nothing has been chosen.
      expect(container.read(tutorialProvider).track, isNull);

      await stop(tester);
    });

    testWidgets('choosing a tour starts it at its first step', (tester) async {
      await tester
          .pumpWidget(appUnder(container, TutorialOverlay(child: _anchoredHost())));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      await tester.tap(find.text(_l10n.tutorialTrackQuick));
      await tester.pump();

      final state = container.read(tutorialProvider);
      expect(state.track, TutorialTrack.quick);
      expect(state.step, 0);
      expect(find.text(kTutorialTracks[TutorialTrack.quick]!.first.title(_l10n)),
          findsOneWidget);
      expect(find.text(_l10n.tutorialSkip), findsOneWidget);

      await stop(tester);
    });

    testWidgets('declining records that it has been seen', (tester) async {
      await tester
          .pumpWidget(appUnder(container, TutorialOverlay(child: _anchoredHost())));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      await tester.tap(find.text(_l10n.tutorialNotNow));
      await pumpUntil(
          tester, () => container.read(tutorialSeenProvider).value == true);

      expect(container.read(tutorialSeenProvider).value, isTrue);
      expect(find.text(_l10n.tutorialChooseTitle), findsNothing);

      await stop(tester);
    });

    testWidgets('and says where to replay it from', (tester) async {
      await tester
          .pumpWidget(appUnder(container, TutorialOverlay(child: _anchoredHost())));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      await tester.tap(find.text(_l10n.tutorialNotNow));
      await tester.pump();

      expect(find.text(_l10n.tutorialReplayHint), findsOneWidget,
          reason: 'somebody who declines must be told where the tour lives');

      // It gets out of the way on its own — no button to dismiss.
      await tester.pump(const Duration(seconds: 6));
      expect(find.text(_l10n.tutorialReplayHint), findsNothing);

      await stop(tester);
    });

    testWidgets('never reappears once the flag is set', (tester) async {
      await db.setTutorialSeen(true);

      await tester
          .pumpWidget(appUnder(container, TutorialOverlay(child: _anchoredHost())));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.text(_l10n.tutorialChooseTitle), findsNothing,
          reason: 'a returning user must not see the tour again');

      await stop(tester);
    });
  });

  group('tapping through', () {
    testWidgets('a tab step hands the tap to the real tab', (tester) async {
      await db.setTutorialSeen(true);
      final tapped = <int>[];
      await tester.pumpWidget(appUnder(
          container,
          TutorialOverlay(child: _anchoredHost(onNavTap: tapped.add))));
      container.read(tutorialProvider.notifier).start(TutorialTrack.quick);
      await tester.pump();
      // Step 1 spotlights the Routines tab.
      container.read(tutorialProvider.notifier).next();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      final bar = tester.getRect(find.byKey(tutorialNavBarKey));
      await tester.tapAt(Offset(bar.left + bar.width * 3 / 8, bar.center.dy));
      await tester.pump();

      expect(tapped, [1],
          reason: 'the tour is meant to feel like the app, not sit over it');
      expect(container.read(tutorialProvider).step, 2,
          reason: 'doing what the step asked moves the tour on');

      await stop(tester);
    });

    testWidgets('outside the spotlight the scrim eats the tap', (tester) async {
      await db.setTutorialSeen(true);
      final tapped = <int>[];
      var cards = 0;
      await tester.pumpWidget(appUnder(
          container,
          TutorialOverlay(
              child: _anchoredHost(
                  onNavTap: tapped.add, onCardTap: () => cards++))));
      container.read(tutorialProvider.notifier).start(TutorialTrack.quick);
      await tester.pump();
      container.read(tutorialProvider.notifier).next();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      // The Today card is nowhere near the spotlit tab.
      await tester.tap(find.byKey(tutorialTodayWorkoutKey), warnIfMissed: false);
      await tester.pump();

      expect(cards, 0, reason: 'the app is not poked mid-sentence');
      expect(tapped, isEmpty);
      expect(container.read(tutorialProvider).step, 2,
          reason: 'a tap on the scrim is still the forgiving way through');

      await stop(tester);
    });

    testWidgets('an informational step does not hand the tap on',
        (tester) async {
      await db.setTutorialSeen(true);
      var cards = 0;
      await tester.pumpWidget(appUnder(container,
          TutorialOverlay(child: _anchoredHost(onCardTap: () => cards++))));
      container.read(tutorialProvider.notifier).start(TutorialTrack.full);
      await tester.pump();
      final steps = kTutorialTracks[TutorialTrack.full]!;
      final target =
          steps.indexWhere((s) => s.anchors.contains(tutorialTodayWorkoutKey));
      expect(target, greaterThan(0));
      for (var i = 0; i < target; i++) {
        container.read(tutorialProvider.notifier).next();
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(steps[target].tapThrough, isFalse,
          reason: 'the tour should not send you off Today mid-tour');

      await tester.tap(find.byKey(tutorialTodayWorkoutKey), warnIfMissed: false);
      await tester.pump();

      expect(cards, 0, reason: 'this step is "look at this", not "tap this"');
      expect(container.read(tutorialProvider).step, target + 1);

      await stop(tester);
    });

    testWidgets('a step whose anchor is missing still reads', (tester) async {
      // Tapping Next instead of the control leaves a later step pointing at a
      // screen nobody is on. It must still say its piece.
      await db.setTutorialSeen(true);
      await tester.pumpWidget(
          appUnder(container, TutorialOverlay(child: const Scaffold())));
      final steps = kTutorialTracks[TutorialTrack.builder]!;
      final target =
          steps.indexWhere((s) => s.anchors.contains(tutorialRoutineNameKey));
      expect(target, greaterThan(0));
      container.read(tutorialProvider.notifier).start(TutorialTrack.builder);
      for (var i = 0; i < target; i++) {
        container.read(tutorialProvider.notifier).next();
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text(steps[target].title(_l10n)), findsOneWidget);

      await stop(tester);
    });
  });

  group('the mock workout', () {
    /// Walks a freshly started full tour to [index] and lets the frame settle.
    Future<void> walkTo(WidgetTester tester, int index) async {
      container.read(tutorialProvider.notifier).start(TutorialTrack.full);
      for (var i = 0; i < index; i++) {
        container.read(tutorialProvider.notifier).next();
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
    }

    int stepWith(TutorialDemo demo) {
      final i =
          kTutorialTracks[TutorialTrack.full]!.indexWhere((s) => s.demo == demo);
      expect(i, greaterThan(0), reason: 'no step draws $demo');
      return i;
    }

    /// The step whose mock board is focused on [focus].
    int boardStepFocused(TutorialDemoFocus focus) {
      final i = kTutorialTracks[TutorialTrack.full]!.indexWhere(
          (s) => s.demo == TutorialDemo.screen && s.focus == focus);
      expect(i, greaterThan(0), reason: 'no board step focuses on $focus');
      return i;
    }

    /// Every icon the *focused* exercise of the mock session is painting, with
    /// its colour. Scoped to the first block: the day has a second lift under
    /// it, drawn at rest, which no step is ever about.
    List<Icon> boardIcons(WidgetTester tester, Key key) => tester
        .widgetList<Icon>(find.descendant(
          of: find.descendant(
              of: find.byType(TutorialBoardDemo).first, matching: find.byKey(key)),
          matching: find.byType(Icon),
        ))
        .toList();

    /// True when the mock board is painting a session in progress: a set behind
    /// you, or the next one outlined.
    bool showsProgress(WidgetTester tester) =>
        find.byKey(kTutorialDemoDoneRowKey).evaluate().isNotEmpty ||
        find.byKey(kTutorialDemoNextRowKey).evaluate().isNotEmpty;

    for (final scale in [1.0, 2.0]) {
      testWidgets('the session chapter survives $scale× text on a 360 dp phone',
          (tester) async {
        // The mock is a whole screen now, so it is swept like one — the screen
        // sweep in feature 15 cannot see it, because it is drawn by an overlay
        // over whatever route happens to be up.
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await db.setTutorialSeen(true);

        final overflows = await overflowsDuring(() async {
          await tester.pumpWidget(appUnder(
              container, TutorialOverlay(child: _anchoredHost()),
              textScale: scale));
          for (final step in kTutorialTracks[TutorialTrack.full]!) {
            if (step.demo == null) continue;
            await walkTo(
                tester,
                kTutorialTracks[TutorialTrack.full]!
                    .indexWhere((s) => s.id == step.id));
            await tester.pump(const Duration(milliseconds: 300));
          }
        });

        expect(overflows, isEmpty, reason: overflows.toSet().join(' | '));
        await stop(tester);
      });
    }

    testWidgets('the session steps fill the screen with the session',
        (tester) async {
      await db.setTutorialSeen(true);
      await tester
          .pumpWidget(appUnder(container, TutorialOverlay(child: _anchoredHost())));
      await walkTo(tester, stepWith(TutorialDemo.screen));

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final mock = tester.getSize(find.byType(TutorialSessionDemo));
      expect(mock.width, closeTo(screen.width, 1),
          reason: 'a thumbnail of a screen teaches the thumbnail');
      expect(mock.height, closeTo(screen.height, 1));
      // Two exercises, so the mock reads as a training day rather than as one
      // lift somebody was shown in isolation.
      expect(find.byType(TutorialBoardDemo), findsNWidgets(2));

      await stop(tester);
    });

    testWidgets('the rest bar is docked only on the step about resting',
        (tester) async {
      await db.setTutorialSeen(true);
      await tester
          .pumpWidget(appUnder(container, TutorialOverlay(child: _anchoredHost())));

      await walkTo(tester, boardStepFocused(TutorialDemoFocus.nextSet));
      expect(find.byType(TutorialRestDemo), findsNothing);

      await walkTo(tester, boardStepFocused(TutorialDemoFocus.rest));
      expect(find.byType(TutorialRestDemo), findsOneWidget);

      await stop(tester);
    });

    testWidgets('the board step draws a board, not a hole in the screen',
        (tester) async {
      await db.setTutorialSeen(true);
      await tester
          .pumpWidget(appUnder(container, TutorialOverlay(child: _anchoredHost())));
      await walkTo(tester, stepWith(TutorialDemo.screen));

      expect(find.byType(TutorialBoardDemo), findsWidgets);
      expect(find.byKey(kTutorialDemoNoteKey), findsWidgets);
      expect(find.byKey(kTutorialDemoCameraKey), findsWidgets);

      await stop(tester);
    });

    testWidgets('the note step rings the note and nothing else',
        (tester) async {
      await db.setTutorialSeen(true);
      await tester
          .pumpWidget(appUnder(container, TutorialOverlay(child: _anchoredHost())));
      await walkTo(tester, boardStepFocused(TutorialDemoFocus.note));

      expect(find.byKey(kTutorialDemoRingKey), findsOneWidget,
          reason: 'the ring points at one thing at a time');
      expect(
          find.descendant(
              of: find.byKey(kTutorialDemoRingKey),
              matching: find.byKey(kTutorialDemoNoteKey)),
          findsOneWidget);
      expect(find.byKey(kTutorialDemoNoteKey), findsNWidgets(2),
          reason: 'the second lift has a note icon too, just not a ring');
      expect(boardIcons(tester, kTutorialDemoNoteKey).single.color,
          AppColors.accent);
      for (final camera in boardIcons(tester, kTutorialDemoCameraKey)) {
        expect(camera.color, isNot(AppColors.accent),
            reason: 'a camera in the accent pulls the eye off the note');
      }
      expect(showsProgress(tester), isFalse);

      await stop(tester);
    });

    testWidgets('the clip step rings one camera and nothing else',
        (tester) async {
      await db.setTutorialSeen(true);
      await tester
          .pumpWidget(appUnder(container, TutorialOverlay(child: _anchoredHost())));
      await walkTo(tester, boardStepFocused(TutorialDemoFocus.camera));

      expect(find.byKey(kTutorialDemoRingKey), findsOneWidget);
      final cameras = boardIcons(tester, kTutorialDemoCameraKey);
      expect(cameras.where((i) => i.color == AppColors.accent), hasLength(1));
      expect(boardIcons(tester, kTutorialDemoNoteKey).single.color,
          isNot(AppColors.accent));
      expect(showsProgress(tester), isFalse);

      await stop(tester);
    });

    testWidgets('the set-row step is the one that shows a session under way',
        (tester) async {
      await db.setTutorialSeen(true);
      await tester
          .pumpWidget(appUnder(container, TutorialOverlay(child: _anchoredHost())));
      await walkTo(tester, boardStepFocused(TutorialDemoFocus.nextSet));

      expect(showsProgress(tester), isTrue);
      expect(find.byKey(kTutorialDemoRingKey), findsNothing);
      for (final camera in boardIcons(tester, kTutorialDemoCameraKey)) {
        expect(camera.color, isNot(AppColors.accent));
      }
      expect(boardIcons(tester, kTutorialDemoNoteKey).single.color,
          isNot(AppColors.accent));

      await stop(tester);
    });

    testWidgets('the rest step draws the bar with its controls',
        (tester) async {
      await db.setTutorialSeen(true);
      await tester
          .pumpWidget(appUnder(container, TutorialOverlay(child: _anchoredHost())));
      await walkTo(tester, boardStepFocused(TutorialDemoFocus.rest));

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
      await db.setTutorialSeen(true);
      await tester
          .pumpWidget(appUnder(container, TutorialOverlay(child: _anchoredHost())));
      await walkTo(tester, stepWith(TutorialDemo.screen));

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
      await tester
          .pumpWidget(appUnder(container, TutorialOverlay(child: _anchoredHost())));
      await walkTo(tester, stepWith(TutorialDemo.shade));

      expect(find.byType(TutorialShadeDemo), findsOneWidget);
      for (final action in ['DONE', 'MISSED']) {
        expect(find.text(action), findsOneWidget);
      }

      await stop(tester);
    });

    testWidgets('tapping the mock advances the tour rather than logging a set',
        (tester) async {
      await db.setTutorialSeen(true);
      await tester
          .pumpWidget(appUnder(container, TutorialOverlay(child: _anchoredHost())));
      final index = stepWith(TutorialDemo.screen);
      await walkTo(tester, index);

      await tester.tap(find.byKey(kTutorialDemoCameraKey).first,
          warnIfMissed: false);
      await tester.pump();

      expect(container.read(tutorialProvider).step, index + 1,
          reason: 'the mock is a picture: a tap on it is a tap on the tour');
      expect(container.read(activeWorkoutProvider), isNull);

      await stop(tester);
    });
  });

  group('replaying', () {
    testWidgets('Profile offers all three tours', (tester) async {
      await db.setTutorialSeen(true);
      await tester.pumpWidget(
          routedAppUnder(container, const ProfileScreen(), scaffold: true));
      await pumpThroughDatabase(tester);

      await tester.tap(find.text(_l10n.profileHelpAndTour));
      await frames(tester);

      for (final label in [
        _l10n.tutorialTrackFull,
        _l10n.tutorialTrackQuick,
        _l10n.tutorialTrackBuilder,
      ]) {
        expect(find.text(label), findsOneWidget,
            reason: 'Help & tour should offer $label');
      }

      await tester.tap(find.text(_l10n.tutorialTrackBuilder));
      await frames(tester);

      expect(container.read(tutorialProvider).track, TutorialTrack.builder,
          reason: 'the builder tour starts on its own, not after the others');

      await stop(tester);
    });

    testWidgets('an anchor below the fold is scrolled into view',
        (tester) async {
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

      final steps = kTutorialTracks[TutorialTrack.full]!;
      final target =
          steps.indexWhere((s) => s.anchors.contains(tutorialLifetimeKey));
      expect(target, greaterThan(0));
      container.read(tutorialProvider.notifier).start(TutorialTrack.full);
      for (var i = 0; i < target; i++) {
        container.read(tutorialProvider.notifier).next();
        await tester.pump();
      }
      expect(find.text(steps[target].title(_l10n)), findsOneWidget);

      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }

      final rect = tester.getRect(anchor);
      expect(rect.top, greaterThanOrEqualTo(0.0));
      expect(rect.bottom, lessThanOrEqualTo(480.0),
          reason: 'the tour did not bring its anchor into view');

      await stop(tester);
    });
  });
}
