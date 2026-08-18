// Starting over — features/index.html#sec23.
//
// One button that puts the app back where a first launch leaves it. The
// interesting assertion is not "the routines are gone" but "the database is
// indistinguishable from a fresh one", so most of what is below compares a
// reset database against a freshly opened one table by table, reading the table
// list off the schema rather than writing it out. A test that named the tables
// would pass for ever while a table added next release quietly survived the
// wipe.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/exercise_settings_screen.dart';
import 'package:foss_lift/util/capabilities.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

void main() {
  final l10n = l10nFor();

  /// Every table's row count, keyed by table name — the whole database as one
  /// comparable value. The table list is the schema's, so a table added later
  /// is counted here without anybody editing this test.
  Future<Map<String, int>> census(AppDatabase db) async {
    final counts = <String, int>{};
    for (final table in db.allTables) {
      final name = table.actualTableName;
      final row = await db
          .customSelect('SELECT COUNT(*) AS c FROM "$name"')
          .getSingle();
      counts[name] = row.read<int>('c');
    }
    return counts;
  }

  /// A database with a bit of everything in it: a program, a finished session,
  /// an exercise of your own, a bar of your own, and settings you have chosen.
  Future<void> fillItUp(AppDatabase db) async {
    await db.seedWeightUnit('lb');
    await db.addStarterRoutine(
      kStarterRoutines.firstWhere((p) => p.name == kPpl),
    );
    await db.createExercise(
      name: 'Zercher Squat',
      muscles: MuscleMap.single('legs'),
      equipment: 'barbell',
    );
    await db.addBar(unit: 'lb', name: 'Log bar', kg: 30);
    await db.setDefaultWarmupSets(1);
    await db.setLayoffDays(21);
    await db.setTutorialSeen(true);
    final workoutId = await workoutIdNamed(db, 'Push');
    await db.saveSession(
      routineId: (await routineNamed(db)).id,
      workoutId: workoutId,
      name: 'Push',
      startedAt: DateTime(2026, 8, 1, 9),
      endedAt: DateTime(2026, 8, 1, 10),
      durationSeconds: 3600,
      totalVolume: 1234,
      sets: const [],
    );
  }

  group('what a reset does', () {
    late AppDatabase db;

    setUp(() => db = memoryDb());
    tearDown(() => db.close());

    test('leaves a database indistinguishable from a fresh one', () async {
      final fresh = memoryDb();
      addTearDown(fresh.close);
      final baseline = await census(fresh);

      await fillItUp(db);
      expect(await census(db), isNot(baseline),
          reason: 'the fixture wrote nothing, so the reset proves nothing');

      await db.resetEverything();

      expect(await census(db), baseline);
    });

    test('keeps the starter library, which is what a first launch writes',
        () async {
      await fillItUp(db);
      await db.resetEverything();

      final exercises = await db.watchExercises().first;
      expect(exercises, isNotEmpty);
      expect(exercises.map((e) => e.name), contains('Bench Press'));
      expect(exercises.map((e) => e.name), isNot(contains('Zercher Squat')),
          reason: 'a movement you added is yours, and yours is what goes');
      expect((await db.barsFor('kg')).map((b) => b.name),
          contains('Olympic bar'));
      expect((await db.barsFor('lb')).map((b) => b.name),
          isNot(contains('Log bar')));
    });

    test('hands back the first run: no unit chosen, no tour seen', () async {
      await fillItUp(db);
      await db.resetEverything();

      expect(await db.watchUnitChosen().first, isFalse,
          reason: 'the unit question is triggered by exactly this being blank');
      expect(await db.watchTutorialSeen().first, isFalse);
      expect(await db.watchRoutines().first, isEmpty);
      expect(await db.watchActiveRoutineId().first, isNull);
    });

    test('takes the history with it', () async {
      await fillItUp(db);
      expect(await db.watchHistory().first, isNotEmpty);

      await db.resetEverything();

      expect(await db.watchHistory().first, isEmpty);
    });

    test('completes while the app is watching the tables it empties', () async {
      // The screen the button is on is watching several of these streams when
      // it runs, and the wipe is a transaction over every table at once. If
      // delivering those updates could block the transaction that caused
      // them, the reset would hang the app on a real phone — so this holds
      // live subscriptions open across the call rather than reading with
      // `.first` afterwards, which subscribes once the work is already done.
      await fillItUp(db);
      final seen = <String>[];
      final subs = [
        db.watchRoutines().listen((_) => seen.add('routines')),
        db.watchHistory().listen((_) => seen.add('history')),
        db.watchWeightUnit().listen((_) => seen.add('unit')),
        db.watchExercises().listen((_) => seen.add('exercises')),
      ];
      addTearDown(() => Future.wait(subs.map((s) => s.cancel())));
      await pumpEventQueue();

      await db.resetEverything().timeout(const Duration(seconds: 10));

      await pumpEventQueue();
      expect(seen, isNotEmpty, reason: 'the watchers were never delivered to');
      expect(await db.watchRoutines().first, isEmpty);
    });

    test('resetting a database that is already fresh changes nothing',
        () async {
      final before = await census(db);
      await db.resetEverything();
      expect(await census(db), before);
    });
  });

  group('the clips go too', () {
    test('the whole clip folder is removed', () async {
      // One directory, returned every time it is asked for. A callback that
      // made a fresh temp dir per call would hand the store a different base
      // than the assertions look at, and the test would fail on its own fixture.
      final base = await Directory.systemTemp.createTemp('fosslift-reset-clips');
      addTearDown(() => base.delete(recursive: true));
      final store = SetVideoStore(baseDirectory: () async => base);
      final dir = await store.directory();
      await File('${dir.path}/one.mp4').writeAsBytes(const [1, 2, 3]);
      await File('${dir.path}/one.jpg').writeAsBytes(const [4]);

      await store.deleteEverything();

      expect(await dir.exists(), isFalse);
      expect(await store.bytesUsed(), 0);
    });

    test('a build with no clips to take is not an error', () async {
      final base = await Directory.systemTemp.createTemp('fosslift-reset-empty');
      addTearDown(() => base.delete(recursive: true));
      final store = SetVideoStore(baseDirectory: () async => base);

      await expectLater(store.deleteEverything(), completes);
    });
  });

  group('the button', () {
    late AppDatabase db;

    setUp(() async {
      db = memoryDb();
      await fillItUp(db);
    });
    tearDown(() => db.close());

    /// The settings screen, scrolled down to the reset row.
    Future<void> openSettings(WidgetTester tester, ProviderContainer c) async {
      await tester
          .pumpWidget(routedAppUnder(c, const ExerciseSettingsScreen()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(l10n.settingsResetProfile), 200);
    }

    /// Taps [button] and lets the work behind it actually run.
    ///
    /// A `testWidgets` body runs in a fake-async zone, where a drift future
    /// never completes: the tap would return with the wipe still pending and
    /// the assertion after it would read the database as it was. `runAsync`
    /// puts the tap on the real event loop, and the settle afterwards is what
    /// paints the result.
    Future<void> tapAndRun(WidgetTester tester, Finder button) async {
      // The tap itself stays on the fake clock. Calling pump() inside
      // runAsync is unsupported and deadlocks — the zone waits on a frame the
      // fake clock is no longer driving, and nothing, including the test
      // timeout, gets a chance to fire.
      await tester.tap(button);
      await tester.pump();
      // runAsync is only for waiting: the handler carries on after the dialog
      // is popped, and the wipe behind it is a real future that the fake clock
      // will never complete.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
    }

    /// The database read on the real event loop, for the same reason.
    Future<T> read<T>(WidgetTester tester, Future<T> Function() query) async =>
        (await tester.runAsync(query)) as T;

    testWidgets('sits at the bottom of Settings', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);

      await openSettings(tester, container);

      expect(find.text(l10n.settingsResetProfile), findsOneWidget);
    });

    testWidgets('says what it will destroy, and does nothing until confirmed',
        (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);

      await openSettings(tester, container);
      await tapAndRun(tester, find.text(l10n.settingsResetProfile));

      expect(find.text(l10n.settingsResetTitle), findsOneWidget);
      expect(find.text(l10n.settingsResetBody), findsOneWidget);

      await tapAndRun(tester, find.text(l10n.commonCancel));

      expect(await read(tester, () => db.watchRoutines().first), isNotEmpty,
          reason: 'backing out of the dialog is not a reset');
    });

    // There is deliberately no test driving the confirm button all the way
    // through to an empty database. Doing that means running a drift
    // transaction, a directory delete and four provider rebuilds against a
    // widget test's fake clock, and every arrangement of runAsync that makes
    // the real work complete also stops the tree settling. What such a test
    // would add over what is here is that the confirm button calls the wipe —
    // one line, next to a dialog whose appearance, whose wording and whose
    // cancel are covered above, and a wipe covered exhaustively against the
    // database, live subscriptions and all. It is not worth a test that hangs
    // for ten minutes on the way to timing out.

    testWidgets('will not run over a running workout', (tester) async {
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        final id = await workoutIdNamed(db, 'Push');
        await container
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: id, name: 'Push');
      });

      await openSettings(tester, container);
      await tapAndRun(tester, find.text(l10n.settingsResetProfile));

      expect(find.text(l10n.backupFinishWorkoutFirst), findsOneWidget);
      expect(find.text(l10n.settingsResetTitle), findsNothing,
          reason: 'the refusal comes before the dialog, not after it');
      expect(await read(tester, () => db.watchRoutines().first), isNotEmpty);
      container.read(activeWorkoutProvider.notifier).discard();
    });

    testWidgets('is offered on a build with no filesystem too', (tester) async {
      final container = containerFor(db, overrides: [
        capabilitiesProvider.overrideWithValue(Capabilities.web),
      ]);
      addTearDown(container.dispose);

      await openSettings(tester, container);

      expect(find.text(l10n.settingsResetProfile), findsOneWidget,
          reason: 'the wipe is rows, so a browser can do all of it');
    });
  });
}
