// Integration tests for text scaling and overflow across the app (features/index.html#sec15).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/routine_share_screen.dart';
import 'package:foss_lift/screens/exercise_settings_screen.dart';
import 'package:foss_lift/screens/appearance_screen.dart';
import 'package:foss_lift/screens/workout_detail_screen.dart';
import 'package:foss_lift/screens/workout_edit_screen.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/util/text_scale.dart';
import 'package:foss_lift/widgets/builder_widgets.dart';
import 'package:foss_lift/widgets/pinch_text_scale.dart';
import 'package:foss_lift/widgets/share_widgets.dart';

import 'support/harness.dart';
import 'support/screens.dart';
import 'support/seeded.dart';

/// Mounts [child] at [scale], on a phone-sized viewport. The language sweep
/// mounts the same screens the same way — see `support/screens.dart`.
Widget scaled(ProviderContainer c, Widget child, double scale) =>
    routedAppUnder(c, child, scaffold: true, textScale: scale);

/// The one text-size chip Appearance is marking as selected, or null when the
/// stored scale sits between two steps and none of them is what is rendering.
TextScaleChoice? selectedScaleChip(WidgetTester tester) {
  final on = tester
      .widgetList<TextScaleChip>(find.byType(TextScaleChip))
      .where((c) => c.selected);
  return on.isEmpty ? null : on.single.choice;
}

void main() {
  late AppDatabase db;
  ProviderContainer? container;
  setUp(() => db = memoryDb());
  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    for (final entry in kSweepScreens.entries) {
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

      final targets = idSweepScreens(
        exerciseId: exerciseId,
        workoutId: workoutId,
        routineId: routineId,
        sessionId: sessionId,
      );

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
      // The warm-up group is open from the start, so its own rows, stepper and
      // disclaimer are already in the sweep.
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
      for (final choice in kTextScaleChoices) {
        final got = resolveTextScale(system: 1.0, chosen: choice.scale);
        expect(got, choice.scale,
            reason: '${choice.name} is clamped on a default phone');
        expect(got, lessThanOrEqualTo(kMaxTextScale));
        expect(got, greaterThanOrEqualTo(kMinTextScale));
      }
    });

    test('the app never renders past the scale its screens are swept at', () {
      // The guard that keeps the sweep honest: if the ceiling ever rises above
      // what the sweep covers, this says so before a user finds out.
      expect(kMaxTextScale, 2.0);
    });

    test('the four chips span the whole range the pinch does', () {
      expect(kTextScaleChoices.map((c) => c.scale).toList(),
          [0.85, 1.0, 1.3, 2.0]);
      // The two ends are the two the gesture stops at, so pinching all the way
      // out lands on a chip rather than somewhere past the last one.
      expect(kTextScaleChoices.first.scale, kMinTextScale);
      expect(kTextScaleChoices.last.scale, kMaxTextScale);
      expect(clampTextNudge(9), kTextScaleChoices.last.scale);
      expect(clampTextNudge(0.1), kTextScaleChoices.first.scale);
    });
  });

  group('a two-finger pinch scales the text', () {
    // The gesture is mounted once, above every route — so it is tested the way
    // it is mounted: a scrolling list under a PinchTextScale, pinched, with the
    // scale read back off the MediaQuery the list actually renders under.

    /// The text scale the tree under [PinchTextScale] is rendering at.
    double renderedScale(WidgetTester tester) => MediaQuery.textScalerOf(
          tester.element(find.byKey(const ValueKey('pinch-probe'))),
        ).scale(1);

    /// A long list under the pinch handler, so a scroll and a pinch compete for
    /// the same pointers exactly as they do in the app.
    Widget host(ProviderContainer c) => UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            localizationsDelegates: kTestDelegates,
            home: Scaffold(
              body: PinchTextScale(
                child: ListView(
                  key: const ValueKey('pinch-probe'),
                  children: [
                    for (var i = 0; i < 60; i++)
                      const SizedBox(height: 40, child: Text('row')),
                  ],
                ),
              ),
            ),
          ),
        );

    /// Moves two fingers apart (or together, for [factor] < 1) about the centre
    /// of the screen and lifts them.
    Future<void> pinch(WidgetTester tester, double factor) async {
      const centre = Offset(200, 400);
      const half = 60.0;
      final a = await tester.startGesture(centre - const Offset(half, 0));
      final b = await tester.startGesture(centre + const Offset(half, 0));
      await tester.pump();
      // In steps, as a finger actually moves — one jump is a teleport the
      // recognizer would see as a single enormous frame.
      for (var i = 1; i <= 8; i++) {
        final reach = half * (1 + (factor - 1) * i / 8);
        await a.moveTo(centre - Offset(reach, 0));
        await b.moveTo(centre + Offset(reach, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await tester.pump();
    }

    testWidgets('spreading two fingers makes the app text bigger',
        (tester) async {
      container = containerFor(db);
      await tester.pumpWidget(host(container!));
      await pumpThroughDatabase(tester);
      expect(renderedScale(tester), closeTo(1.0, 0.001));

      await pinch(tester, 1.4);
      expect(renderedScale(tester), greaterThan(1.1),
          reason: 'the pinch did not reach the text');
      await stop(tester);
    });

    testWidgets('pinching together makes it smaller', (tester) async {
      container = containerFor(db);
      await tester.pumpWidget(host(container!));
      await pumpThroughDatabase(tester);

      await pinch(tester, 0.5);
      expect(renderedScale(tester), lessThan(0.95));
      await stop(tester);
    });

    testWidgets('the scale it lands on is written down', (tester) async {
      container = containerFor(db);
      await tester.pumpWidget(host(container!));
      await pumpThroughDatabase(tester);

      await pinch(tester, 1.5);
      final onScreen = renderedScale(tester);
      await pumpThroughDatabase(tester);
      final stored = container!.read(textScaleProvider).value ?? 1.0;
      expect(stored, closeTo(onScreen, 0.01),
          reason: 'the gesture ended without persisting what it set');
      await stop(tester);
    });

    testWidgets('it is held to the same bounds the chips are', (tester) async {
      container = containerFor(db);
      await tester.pumpWidget(host(container!));
      await pumpThroughDatabase(tester);

      // Far past the ceiling, then far past the floor.
      await pinch(tester, 4.0);
      expect(renderedScale(tester), closeTo(kMaxTextScale, 0.001));
      await pinch(tester, 0.1);
      await pinch(tester, 0.1);
      expect(renderedScale(tester), closeTo(kMinTextScale, 0.001));
      await stop(tester);
    });

    testWidgets('a one-finger drag scrolls and does not scale', (tester) async {
      container = containerFor(db);
      await tester.pumpWidget(host(container!));
      await pumpThroughDatabase(tester);

      await tester.drag(
          find.byKey(const ValueKey('pinch-probe')), const Offset(0, -300));
      await tester.pump();

      expect(renderedScale(tester), closeTo(1.0, 0.001),
          reason: 'a scroll was read as a pinch');
      // And the list did move: the gesture handler did not eat the scroll.
      final position =
          tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(position.pixels, greaterThan(0),
          reason: 'the pinch handler swallowed an ordinary scroll');
      await stop(tester);
    });

    testWidgets('the current scale is shown while the fingers are down',
        (tester) async {
      container = containerFor(db);
      await tester.pumpWidget(host(container!));
      await pumpThroughDatabase(tester);

      const centre = Offset(200, 400);
      final a = await tester.startGesture(centre - const Offset(60, 0));
      final b = await tester.startGesture(centre + const Offset(60, 0));
      for (var i = 1; i <= 8; i++) {
        await a.moveTo(centre - Offset(60 + i * 10, 0));
        await b.moveTo(centre + Offset(60 + i * 10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.textContaining('%'), findsOneWidget,
          reason: 'nothing said what scale the pinch was on');
      await a.up();
      await b.up();
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('%'), findsNothing,
          reason: 'the readout outstayed the gesture');
      await stop(tester);
    });

    testWidgets('pinching to a chip\'s percentage selects that chip',
        (tester) async {
      container = containerFor(db);
      await tester.pumpWidget(host(container!));
      await pumpThroughDatabase(tester);

      // All the way out is the ceiling, which is exactly what Largest is.
      await pinch(tester, 4.0);
      await pumpThroughDatabase(tester);
      expect(container!.read(textScaleProvider).value,
          closeTo(TextScaleChoice.largest.scale, 0.001));

      // Appearance marks the step the stored value is on, however it got there.
      await tester.pumpWidget(appUnder(container!, const AppearanceScreen()));
      await pumpThroughDatabase(tester);
      expect(selectedScaleChip(tester), TextScaleChoice.largest,
          reason: 'the gesture and the chips write the same setting');
      await stop(tester);
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
              scaled(container!, const ExerciseSettingsScreen(), scale));
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
          // Three channels, a hex field and the copy/paste controls, in a
          // dialog — the busiest row of controls in the app.
          expect(find.text('R'), findsOneWidget);
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
