// Integration coverage for features/catalogue/24-cloud-backup.yaml.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/cloud_snapshot.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/cloud_provider.dart';
import 'package:foss_lift/screens/cloud_screen.dart';
import 'package:foss_lift/services/cloud_client.dart';
import 'package:foss_lift/services/cloud_models.dart';

import 'support/harness.dart';

class _Cloud extends CloudClient {
  _Cloud({this.signedIn = false});
  final bool signedIn;
  String? requestedEmail;
  String? saved;
  int downloads = 0;
  @override
  Future<CloudAccount> account() async => CloudAccount(
    available: true,
    email: signedIn ? 'lifter@example.com' : null,
    revision: signedIn ? 1 : 0,
  );
  @override
  Future<void> requestLink(String email) async {
    requestedEmail = email;
  }

  @override
  Future<CloudAccount> save(String snapshot, int revision) async {
    saved = snapshot;
    return account();
  }

  @override
  Future<String> download() async {
    downloads++;
    throw StateError('Unexpected restore');
  }
}

void main() {
  testWidgets('email sign-in is requested only by pressing its button', (
    tester,
  ) async {
    final db = memoryDb();
    final cloud = _Cloud();
    final container = containerFor(
      db,
      overrides: [cloudClientProvider.overrideWithValue(cloud)],
    );
    addTearDown(db.close);
    addTearDown(container.dispose);
    final l10n = l10nFor();
    await tester.pumpWidget(appUnder(container, const CloudScreen()));
    await pumpThroughDatabase(tester);
    expect(cloud.requestedEmail, isNull);
    await tester.enterText(find.byType(TextField), 'lifter@example.com');
    await tester.tap(find.text(l10n.cloudSendLink));
    await pumpThroughDatabase(tester);
    expect(cloud.requestedEmail, 'lifter@example.com');
    expect(find.text(l10n.cloudLinkSent), findsOneWidget);
    await stop(tester);
  });

  testWidgets('a signed-in user explicitly saves and can cancel a restore', (
    tester,
  ) async {
    final db = memoryDb();
    final cloud = _Cloud(signedIn: true);
    final container = containerFor(
      db,
      overrides: [cloudClientProvider.overrideWithValue(cloud)],
    );
    addTearDown(db.close);
    addTearDown(container.dispose);
    final l10n = l10nFor();
    await tester.runAsync(
      () => db.createRoutine(
        name: 'My training',
        color: 'FF6A3D',
        restSeconds: 90,
      ),
    );
    await tester.pumpWidget(
      appUnder(container, const CloudScreen(), textScale: 2),
    );
    await pumpThroughDatabase(tester);
    expect(cloud.saved, isNull);
    await tester.tap(find.text(l10n.cloudSave));
    await pumpThroughDatabase(tester);
    expect(cloud.saved, contains('My training'));
    expect(find.text(l10n.cloudSaved), findsOneWidget);
    await tester.ensureVisible(find.text(l10n.cloudRestore));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.cloudRestore));
    await frames(tester);
    expect(find.text(l10n.cloudRestoreWarning), findsOneWidget);
    await tester.tap(find.text(l10n.commonCancel));
    await frames(tester);
    expect(cloud.downloads, 0);
    expect(
      (await tester.runAsync(
        () => db.watchRoutines().first,
      ))!.single.routine.name,
      'My training',
    );
    await stop(tester);
  });

  test(
    'a server backup restores training data without a live session',
    () async {
      final source = memoryDb();
      final target = memoryDb();
      addTearDown(source.close);
      addTearDown(target.close);
      final routine = await source.addStarterRoutine(kStarterRoutines.first);
      await source.setLocaleTag('uk');
      await source.setExerciseNotes(
        (await source.watchExercises().first).first.id,
        'Keep the chest up',
      );
      await source.saveLiveSession('{"private":"unfinished session"}');
      final now = DateTime.utc(2026, 10, 27);
      await source.saveSession(
        name: 'A finished workout',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 30)),
        durationSeconds: 1800,
        totalVolume: 0,
        workoutId: null,
        sets: const [],
        routineId: routine,
      );
      final snapshot = await source.exportCloudSnapshot();
      expect(snapshot, isNot(contains('unfinished session')));
      await target.restoreCloudSnapshot(snapshot);
      expect((await target.watchRoutines().first).single.routine.id, routine);
      expect(await target.watchLocaleTag().first, 'uk');
      expect(
        (await target.watchHistory().first).single.name,
        'A finished workout',
      );
      expect(
        (await target.watchExercises().first).first.notes,
        'Keep the chest up',
      );
      expect(await target.loadLiveSession(), isNull);
      // Restoring explicit IDs must leave SQLite's generated IDs usable.
      final next = await target.createRoutine(
        name: 'Next program',
        color: 'FF6A3D',
        restSeconds: 90,
      );
      expect(next, greaterThan(routine));
    },
  );

  test(
    'an incompatible or malformed backup leaves local training intact',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      await db.createRoutine(
        name: 'Keep this program',
        color: 'FF6A3D',
        restSeconds: 90,
      );
      final snapshot =
          jsonDecode(await db.exportCloudSnapshot()) as Map<String, dynamic>;
      snapshot['schema'] = db.schemaVersion + 1;
      await expectLater(
        db.restoreCloudSnapshot(jsonEncode(snapshot)),
        throwsA(isA<FormatException>()),
      );
      snapshot['schema'] = db.schemaVersion;
      final tables = snapshot['tables'] as Map<String, dynamic>;
      (tables['workouts'] as List).add({
        'id': 700,
        'routine_id': 999999,
        'name': 'Broken reference',
        'position': 0,
        'seed_key': null,
        'warmups_enabled': 1,
      });
      await expectLater(
        db.restoreCloudSnapshot(jsonEncode(snapshot)),
        throwsA(anything),
      );
      expect(
        (await db.watchRoutines().first).single.routine.name,
        'Keep this program',
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  test('restoring a snapshot refreshes subscribed views', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final snapshot = await db.exportCloudSnapshot();
    await db.createRoutine(name: 'Temporary', color: 'FF6A3D', restSeconds: 90);
    final observed = <int>[];
    final sub = db.watchRoutines().listen((rows) => observed.add(rows.length));
    addTearDown(sub.cancel);
    await db.watchRoutines().first;
    await db.restoreCloudSnapshot(snapshot);
    expect(await db.watchRoutines().first, isEmpty);
    expect(observed, contains(1));
  });

  test(
    'restore preserves an unfinished workout in the shared database',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      await db.createRoutine(
        name: 'Backup program',
        color: 'FF6A3D',
        restSeconds: 90,
      );
      final snapshot = await db.exportCloudSnapshot();
      await db.createRoutine(
        name: 'Local program',
        color: 'FF6A3D',
        restSeconds: 90,
      );
      // Another tab can persist a workout without this screen's controller
      // holding it. The database is the shared record of unfinished work.
      const live = '{"private":"workout in another tab"}';
      await db.saveLiveSession(live);
      await expectLater(
        db.restoreCloudSnapshot(snapshot),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'workout_running',
          ),
        ),
      );
      expect((await db.loadLiveSession())?.payload, live);
      expect((await db.watchRoutines().first).length, 2);
      await db.clearLiveSession();
      await db.restoreCloudSnapshot(snapshot);
      expect(
        (await db.watchRoutines().first).single.routine.name,
        'Backup program',
      );
    },
  );

  test('oversized backup is refused before replacing local data', () async {
    final db = memoryDb();
    addTearDown(db.close);
    await db.createRoutine(name: 'Keep me', color: 'FF6A3D', restSeconds: 90);
    await expectLater(
      db.restoreCloudSnapshot(' ' * (kMaxCloudSnapshotBytes + 1)),
      throwsA(isA<FormatException>()),
    );
    expect((await db.watchRoutines().first).single.routine.name, 'Keep me');
  });
}
