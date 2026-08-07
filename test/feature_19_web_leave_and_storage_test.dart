// Feature 19 — the browser build, second half: not losing the work.
//
// Three behaviours, all of them written down in
// features/catalogue/19-web-build.yaml:
//
//  - leaving-mid-workout-asks-first / leaving-with-unsaved-edits-asks-first:
//    a register of what the app is holding that is not written down, and the
//    browser's own dialog raised over it;
//  - asks-the-browser-to-keep-the-database / says-so-when-storage-will-not-hold:
//    the eviction exemption, asked for once, and what is said when the answer
//    is no or when there was nowhere durable to write in the first place;
//  - rest-tone-sounds-in-the-open-tab: the tone is not a phone-only thing.
//
// None of this can be asserted *in a browser* from the Dart VM. What is
// asserted here is everything either side of the browser: the register, which
// is platform-independent on purpose; the arming decision, through the seam the
// app pushes it out of; and the classification of what a probe came back with.
// The listener itself, and whether Chrome honours it, is a manual check — see
// docs/web-build.md.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/exercise_form_screen.dart';
import 'package:foss_lift/services/rest_tone.dart';
import 'package:foss_lift/state/unsaved_work.dart';
import 'package:foss_lift/util/capabilities.dart';
import 'package:foss_lift/widgets/storage_warning.dart';

import 'support/harness.dart';
import 'support/seeded.dart';

void main() {
  group('the register knows what is not written down yet', () {
    late AppDatabase db;
    setUp(() => db = memoryDb());
    tearDown(() => db.close());

    test('a fresh app is holding nothing', () {
      final container = containerFor(db);
      addTearDown(container.dispose);
      expect(container.read(unsavedWorkProvider), isFalse);
    });

    test('a live session counts from the moment it starts', () async {
      final container = containerFor(db);
      addTearDown(container.dispose);

      await container
          .read(activeWorkoutProvider.notifier)
          .start(workoutId: await workoutIdNamed(db, 'Push'), name: 'Push');
      expect(container.read(unsavedWorkProvider), isTrue,
          reason: 'the session is in memory until Finish — a reload takes '
              'every set logged so far');

      // Discarding is a decision to lose it, so there is nothing left to warn
      // about.
      await container.read(activeWorkoutProvider.notifier).discard();
      expect(container.read(unsavedWorkProvider), isFalse);
    });

    test('a finished session is written down, so it stops counting', () async {
      final container = containerFor(db);
      addTearDown(container.dispose);

      await container
          .read(activeWorkoutProvider.notifier)
          .start(workoutId: await workoutIdNamed(db, 'Push'), name: 'Push');
      await container.read(activeWorkoutProvider.notifier).finish();
      expect(container.read(unsavedWorkProvider), isFalse);
    });

    test('an editor holds and releases by token', () {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final edits = container.read(pendingEditsProvider.notifier);
      final one = Object();
      final two = Object();

      edits.hold(one);
      expect(container.read(unsavedWorkProvider), isTrue);

      // Two screens can be dirty at once — the builder over the form it opened
      // to add a movement — and the first to save must not clear the second.
      edits.hold(two);
      edits.release(one);
      expect(container.read(unsavedWorkProvider), isTrue);

      edits.release(two);
      expect(container.read(unsavedWorkProvider), isFalse);
    });

    test('releasing something that was never held changes nothing', () {
      final container = containerFor(db);
      addTearDown(container.dispose);
      final edits = container.read(pendingEditsProvider.notifier);

      // A dispose racing a save releases twice. A count would go negative and
      // stick; a set does not care.
      final token = Object();
      edits.hold(token);
      edits.release(token);
      edits.release(token);
      expect(container.read(unsavedWorkProvider), isFalse);
    });
  });

  group('the exercise form registers its edits', () {
    late AppDatabase db;
    setUp(() => db = memoryDb());
    tearDown(() => db.close());

    testWidgets('typing a name makes it unsaved, saving clears it',
        (tester) async {
      // Tall enough that the Save button at the foot of the form is on screen
      // without a scroll — the test is about the register, not about layout.
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        routedAppUnder(container, const ExerciseFormScreen()),
      );
      await pumpThroughDatabase(tester);

      expect(container.read(unsavedWorkProvider), isFalse,
          reason: 'an untouched form has nothing to lose');

      await tester.enterText(find.byType(TextField).first, 'Zercher Squat');
      await tester.pump();
      expect(container.read(unsavedWorkProvider), isTrue);

      await tester.tap(find.text(l10nFor().exerciseFormSave));
      await pumpThroughDatabase(tester);
      expect(container.read(unsavedWorkProvider), isFalse,
          reason: 'it is in the database now');
      await stop(tester);
    });

    testWidgets('leaving the form without saving clears it too',
        (tester) async {
      // Tall enough that the Save button at the foot of the form is on screen
      // without a scroll — the test is about the register, not about layout.
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = containerFor(db);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        routedAppUnder(container, const ExerciseFormScreen()),
      );
      await pumpThroughDatabase(tester);

      await tester.enterText(find.byType(TextField).first, 'Zercher Squat');
      await tester.pump();
      expect(container.read(unsavedWorkProvider), isTrue);

      // Backing out is the same decision as discarding a session: the edit is
      // gone on purpose, and the browser must not go on asking about it.
      await stop(tester);
      expect(container.read(unsavedWorkProvider), isFalse);
    });
  });

  group('only a browser asks the question', () {
    late AppDatabase db;
    setUp(() => db = memoryDb());
    tearDown(() => db.close());

    test('a phone has no leave guard and a browser does', () {
      expect(Capabilities.native.leaveGuard, isFalse,
          reason: 'switching away from an Android app does not end it, and '
              'there is no hook to object to a swipe away');
      expect(Capabilities.web.leaveGuard, isTrue);
    });

    test('the guard follows the register on a build that has one', () async {
      final armings = <bool>[];
      final container = containerFor(
        db,
        overrides: [
          capabilitiesProvider.overrideWithValue(Capabilities.web),
          leaveGuardProvider.overrideWithValue(armings.add),
        ],
      );
      addTearDown(container.dispose);

      // Read rather than listen: the provider's *value* is void and never
      // changes, so a listener is never called and would prove nothing. What is
      // being asserted is the side effect, and in the app it is `main.dart`'s
      // `ref.watch` in a rebuild that re-runs the body. A read is that rebuild.
      container.read(leaveGuardSyncProvider);
      expect(armings.last, isFalse);

      await container
          .read(activeWorkoutProvider.notifier)
          .start(workoutId: await workoutIdNamed(db, 'Push'), name: 'Push');
      container.read(leaveGuardSyncProvider);
      expect(armings.last, isTrue);

      await container.read(activeWorkoutProvider.notifier).discard();
      container.read(leaveGuardSyncProvider);
      expect(armings.last, isFalse);
    });

    test('a build without one is never armed, however much is unsaved',
        () async {
      final armings = <bool>[];
      final container = containerFor(
        db,
        overrides: [
          capabilitiesProvider.overrideWithValue(Capabilities.native),
          leaveGuardProvider.overrideWithValue(armings.add),
        ],
      );
      addTearDown(container.dispose);

      container.read(leaveGuardSyncProvider);
      await container
          .read(activeWorkoutProvider.notifier)
          .start(workoutId: await workoutIdNamed(db, 'Push'), name: 'Push');
      container.read(leaveGuardSyncProvider);
      // Not "called with false" — not called at all. There is nothing on the
      // other end of it on a phone.
      expect(armings, isEmpty);
      await container.read(activeWorkoutProvider.notifier).discard();
    });
  });

  group('whether the storage will hold', () {
    test('a phone is durable without being asked', () async {
      expect(StorageHealth.native.durability, StorageDurability.durable);
      expect(StorageHealth.native.isFragile, isFalse);
      expect(StorageHealth.native.implementation, isNull);
    });

    test('the running build probes as a phone under the test runner', () async {
      // The VM is not a browser, so the value the app actually reads must be
      // the native one — the same shape as the capability check in
      // feature_19_web_build_test.dart.
      final health = await probeStorageHealth();
      expect(health.durability, StorageDurability.durable);
    });

    test('only durable storage is quiet', () {
      const evictable =
          StorageHealth(durability: StorageDurability.evictable);
      const ephemeral =
          StorageHealth(durability: StorageDurability.ephemeral);
      expect(evictable.isFragile, isTrue);
      expect(ephemeral.isFragile, isTrue);
    });
  });

  group('a browser that cannot keep the data says so', () {
    late AppDatabase db;
    setUp(() => db = memoryDb());
    tearDown(() => db.close());

    Future<void> pumpWarning(
      WidgetTester tester,
      StorageHealth health,
    ) async {
      final container = containerFor(
        db,
        overrides: [
          storageHealthProvider.overrideWith((ref) async => health),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        appUnder(container, const Scaffold(body: StorageWarning())),
      );
      await pumpThroughDatabase(tester);
    }

    testWidgets('durable storage shows nothing at all', (tester) async {
      await pumpWarning(tester, StorageHealth.native);
      expect(find.byType(Card), findsNothing);
      expect(find.text(l10nFor().storageEphemeralWarning), findsNothing);
      expect(find.text(l10nFor().storageEvictableNotice), findsNothing);
      await stop(tester);
    });

    testWidgets('nowhere to write is said plainly and cannot be dismissed',
        (tester) async {
      final l10n = l10nFor();
      await pumpWarning(
        tester,
        const StorageHealth(
          durability: StorageDurability.ephemeral,
          implementation: 'inMemory',
        ),
      );
      expect(find.text(l10n.storageEphemeralWarning), findsOne);
      // Nothing to dismiss it with: the tab *is* the storage, and the warning
      // is true for as long as the app is open.
      expect(find.text(l10n.commonDismiss), findsNothing);
      await stop(tester);
    });

    testWidgets('a refused exemption is a note you can put away',
        (tester) async {
      final l10n = l10nFor();
      await pumpWarning(
        tester,
        const StorageHealth(
          durability: StorageDurability.evictable,
          implementation: 'sharedIndexedDb',
        ),
      );
      expect(find.text(l10n.storageEvictableNotice), findsOne);

      await tester.tap(find.text(l10n.commonDismiss));
      await tester.pump();
      expect(find.text(l10n.storageEvictableNotice), findsNothing);
      await stop(tester);
    });
  });

  group('a rest still sounds in a tab you are looking at', () {
    test('the tone is not gated on being a phone any more', () {
      // A browser can play audio; what it cannot do is play it once the tab is
      // in the background, and that is `backgroundAlerts`, not this.
      expect(
        restToneSupportedOn(isWeb: true, platform: TargetPlatform.android),
        isTrue,
      );
      expect(
        restToneSupportedOn(isWeb: false, platform: TargetPlatform.android),
        isTrue,
      );
      expect(
        restToneSupportedOn(isWeb: false, platform: TargetPlatform.iOS),
        isTrue,
      );
    });

    test('a desktop build still has nothing to play through', () {
      expect(
        restToneSupportedOn(isWeb: false, platform: TargetPlatform.linux),
        isFalse,
      );
    });

    test('the off-screen ding is still a phone-only promise', () {
      expect(Capabilities.web.backgroundAlerts, isFalse,
          reason: 'a backgrounded tab has its timers throttled and its audio '
              'suspended — the tone in front is not the same promise');
      expect(Capabilities.native.backgroundAlerts, isTrue);
    });
  });
}
