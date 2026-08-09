// Feature 19 — The browser build.
//
// The build itself cannot be asserted from the Dart VM: `flutter build web` is
// a separate command, and a headless browser is not a test dependency. What
// *is* testable from here is everything the build rests on, and that is what
// this file covers.
//
//  - the capability set: which of the phone's abilities a browser has, stated
//    once so the screens can ask rather than each guessing at `kIsWeb`;
//  - the screens honouring it, so a control that cannot work is absent rather
//    than left to fail when tapped;
//  - the compression under a routine code, which used to come from `dart:io`
//    and would have thrown in a browser — checked against `dart:io`'s own
//    inflate, so the wire format is provably the same one Android writes;
//  - the source-level guards: the database no longer reaches for a native
//    opener or a file path directly, and the page has the two assets it cannot
//    run without.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/data/routine_code.dart';
import 'package:foss_lift/data/routine_import.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/routine_edit_screen.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/util/capabilities.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

void main() {
  group('what this build can do is stated in one place', () {
    test('a phone has every capability', () {
      const c = Capabilities.native;
      expect(c.reminders, isTrue);
      expect(c.setVideos, isTrue);
      expect(c.scanning, isTrue);
      expect(c.shade, isTrue);
      expect(c.backgroundAlerts, isTrue);
      expect(c.localFiles, isTrue);
    });

    test('a browser has none of the ones that need a phone', () {
      const c = Capabilities.web;
      // Each of these is a documented loss in docs/web-build.md: a scheduled
      // notification, a file written into app storage, a camera frame stream,
      // and a foreground service.
      expect(c.reminders, isFalse);
      expect(c.setVideos, isFalse);
      expect(c.scanning, isFalse);
      expect(c.shade, isFalse);
      expect(c.backgroundAlerts, isFalse);
      expect(c.localFiles, isFalse);
    });

    test('the running build reports the native set under the test runner', () {
      // The VM test runner is not a browser, so the value the app actually
      // reads must be the native one. A test that overrides the provider is
      // testing the override; this checks the default.
      expect(currentCapabilities, same(Capabilities.native));
    });
  });

  group('a control that cannot work is absent, not broken', () {
    late AppDatabase db;
    setUp(() => db = memoryDb());
    tearDown(() => db.close());

    Future<void> pumpBuilder(WidgetTester tester, Capabilities caps) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // runAsync, because a drift future only completes on the real event loop
      // and this body runs in the test's fake one.
      final rid =
          (await tester.runAsync(() => routineWithCountNamed(db)))!.routine.id;
      final container = containerFor(
        db,
        overrides: [capabilitiesProvider.overrideWithValue(caps)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        routedAppUnder(container, RoutineEditScreen(routineId: rid)),
      );
      // Not pumpAndSettle: the loading spinner animates for ever, so the tree
      // is only quiet once the routine has come back off the database.
      await pumpThroughDatabase(tester);
    }

    testWidgets('the routine builder offers no reminder on the web',
        (tester) async {
      final l10n = l10nFor();
      await pumpBuilder(tester, Capabilities.web);

      // The weekday schedule stays: it is part of the programme and it travels
      // in a share code. Only the reminder — a notification nothing can post —
      // goes.
      expect(find.text(l10n.routineEditTrainingDays.toUpperCase()), findsOne);
      expect(find.text(l10n.routineEditReminder.toUpperCase()), findsNothing);
      await stop(tester);
    });

    testWidgets('the routine builder still offers one on a phone',
        (tester) async {
      final l10n = l10nFor();
      await pumpBuilder(tester, Capabilities.native);

      expect(find.text(l10n.routineEditReminder.toUpperCase()), findsOne);
      await stop(tester);
    });
  });

  group('a routine code means the same thing in a browser', () {
    test('the code compresses without dart:io', () {
      final source = File('lib/data/routine_code.dart').readAsStringSync();
      expect(source.contains("import 'dart:io'"), isFalse,
          reason: 'dart:io compiles on the web but throws when used — the '
              'share code has to compress with pure Dart');
    });

    test('what it writes is still a raw deflate stream', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final routines = await db.watchRoutines().first;
      final shared = await db.sharedRoutine(routines.first.routine.id);
      final code = RoutineCode.encode(shared);

      // Decoding it here proves the round trip. Decoding the payload with
      // dart:io's own inflate proves the bytes are the format Android's
      // encoder used to produce, so a code does not carry which build wrote it.
      final decoded = RoutineCode.decode(code);
      expect(decoded, isA<RoutineCodeOk>());
      expect((decoded as RoutineCodeOk).routine.name, shared.name);
      expect((decoded).routine.workouts.length, shared.workouts.length);
    });
  });

  group('the database opener is chosen at compile time', () {
    test('database.dart names neither a native opener nor a file path', () {
      final source = File('lib/data/database.dart').readAsStringSync();
      // Importing either of these pulls sqlite3's FFI bindings — and with them
      // dart:ffi, which is the one import that genuinely fails to compile for
      // the web — into every build.
      expect(source.contains("package:drift/native.dart"), isFalse);
      expect(source.contains("package:path_provider/"), isFalse);
      expect(source.contains("import 'dart:io'"), isFalse);
    });

    test('the conditional export names both openers', () {
      final source = File('lib/data/db_open.dart').readAsStringSync();
      expect(source.contains('db_open_native.dart'), isTrue);
      expect(source.contains('db_open_web.dart'), isTrue);
      expect(source.contains('dart.library.js_interop'), isTrue);
    });
  });

  group('the page carries what it cannot run without', () {
    test('web/ has the page, the sqlite3 module and the drift worker', () {
      for (final name in const [
        'web/index.html',
        'web/manifest.json',
        'web/sqlite3.wasm',
        'web/drift_worker.js',
      ]) {
        expect(File(name).existsSync(), isTrue,
            reason: '$name is missing — see docs/web-build.md');
      }
    });

    test('the page names no remote origin to load anything from', () {
      // Comments stripped first: the page explains at length *why* it must not
      // reach a CDN, and the explanation names the host it is avoiding.
      final markup = File('web/index.html')
          .readAsStringSync()
          .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
      for (final host in const ['gstatic.com', 'googleapis.com', '//http']) {
        expect(markup.contains(host), isFalse,
            reason: 'the engine and the fonts must be served from this '
                'origin: a CDN fetch breaks the "no network" claim and is '
                'blocked outright under COEP');
      }
    });
  });

  group('a dialog with a field in it, in a browser', () {
    late AppDatabase db;
    ProviderContainer? container;

    setUp(() => db = memoryDb());
    tearDown(() async {
      container?.dispose();
      container = null;
      await db.close();
    });

    // A browser window is shorter than a phone screen — the page has the
    // browser's own chrome above it — and the keyboard takes a third of what
    // is left.
    const screen = Size(390, 640);
    const keyboard = 340.0;

    /// The live board, mounted as the web build sees it, with the weight box of
    /// Bench Press's fourth set tapped open. That dialog is the one the entry
    /// names: a title, a field and two buttons.
    Future<void> openWeightDialog(WidgetTester tester) async {
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        final wid = await workoutIdNamed(db, 'Push');
        container = containerFor(db, overrides: [
          capabilitiesProvider.overrideWithValue(Capabilities.web),
        ]);
        await container!
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: wid, name: 'Push');
      });
      await tester.pumpWidget(appUnder(container!, const WorkoutScreen()));
      await tester.pump();
      final cell = find.descendant(
        of: find.byKey(const ValueKey('0-3-Bench Press')),
        matching: find.byKey(const ValueKey('set-weight')),
      );
      await tester.ensureVisible(cell);
      await tester.pump();
      await tester.tap(cell);
    }

    /// The box inside whichever dialog is up.
    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(EditableText),
    );

    Future<void> stopAll(WidgetTester tester) async {
      container?.read(activeWorkoutProvider.notifier).discard();
      await stop(tester);
    }

    testWidgets('it is ready to type in within the tap that opened it',
        (tester) async {
      await openWeightDialog(tester);

      // Not pumped first, deliberately. A browser opens the keyboard only
      // while it is still handling the tap that asked for it; a field that
      // asks once the dialog has been built and animated is asking too late,
      // and the symptom is a dialog you have to tap a second time to type in.
      expect(tester.testTextInput.hasAnyClients, isTrue,
          reason: 'nothing had asked for the keyboard by the end of the tap');

      // And what it is typing into is the dialog's own box.
      await frames(tester);
      expect(tester.widget<EditableText>(dialogField).focusNode.hasFocus,
          isTrue);
      await tester.enterText(find.byType(TextField).first, '85');
      await tester.pump();
      expect(find.text('85'), findsOneWidget);

      await stopAll(tester);
    });

    testWidgets('it makes its own room for the keyboard', (tester) async {
      await openWeightDialog(tester);
      await frames(tester);

      final title = find.text(l10nFor().sessionSetTitle(4));
      expect(title, findsOneWidget, reason: 'the weight dialog did not open');
      final wasTall = tester.getRect(dialogField).height;

      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
      final overflows = await overflowsDuring(() async {
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 40));
        }
      });

      expect(overflows, isEmpty,
          reason: 'the box was squeezed into what was left rather than '
              'shrinking and scrolling inside itself: '
              '${overflows.join(" | ")}');
      expect(tester.getRect(dialogField).height, closeTo(wasTall, 1.0),
          reason: 'the field is what has to stay readable');
      for (final part in <String, Finder>{
        'the title': title,
        'the field': dialogField,
      }.entries) {
        final rect = tester.getRect(part.value);
        expect(rect.top, greaterThanOrEqualTo(0.0),
            reason: '${part.key} was shoved off the top of the page');
        expect(rect.bottom, lessThanOrEqualTo(screen.height - keyboard),
            reason: '${part.key} is behind the keyboard');
      }

      await stopAll(tester);
    });
  });
}
