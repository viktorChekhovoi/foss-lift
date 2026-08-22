// Integration tests for on-disk backup and restore (features/index.html#sec20).

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/backup_archive.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/backup_screen.dart';
import 'package:foss_lift/screens/profile_screen.dart';
import 'package:foss_lift/services/backup_service.dart';
import 'package:foss_lift/util/capabilities.dart';
import 'package:path/path.dart' as p;

import 'support/harness.dart';
import 'support/seeded.dart';

void main() {
  late Directory root;
  late Directory storage;
  late File dbFile;
  late AppDatabase db;

  final l10n = l10nFor();

  /// A database in a file, as the app has — not `memoryDb()`, which has no file
  /// to copy anywhere.
  AppDatabase openAt(File file) => AppDatabase.forTesting(NativeDatabase(file));

  BackupService serviceFor(
    AppDatabase database, {
    int? schemaVersion,
    DateTime? now,
  }) => BackupService(
    snapshotDatabase: (path) => database.snapshotTo(path),
    databaseFile: () async => dbFile,
    storageDirectory: () async => storage,
    workDirectory: () async => root,
    closeDatabase: database.close,
    schemaVersion: schemaVersion ?? database.schemaVersion,
    now: () => now ?? DateTime(2026, 8, 7),
  );

  /// A routine, by the only field these tests look at.
  Future<void> addRoutine(AppDatabase into, String name) =>
      into.createRoutine(name: name, color: '#E8543F', restSeconds: 120);

  /// What is in a database, cheaply.
  Future<Iterable<String>> routinesIn(AppDatabase from) async =>
      (await from.select(from.routines).get()).map((r) => r.name);

  /// A clip on disk, as filming a set leaves one.
  Future<File> clip(String name, {int bytes = 1024}) async {
    final dir = Directory(p.join(storage.path, kBackupVideoFolder));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(List.filled(bytes, 7));
    return file;
  }

  Future<File> archiveWithDatabase(String name, List<int> bytes) async {
    final manifest = BackupManifest(
      schema: db.schemaVersion,
      created: DateTime(2026, 8, 7),
      clips: 0,
    );
    final file = File(p.join(root.path, name));
    await file.writeAsBytes(
      ZipEncoder().encodeBytes(
        Archive()
          ..add(ArchiveFile.string(kBackupManifestEntry, manifest.encode()))
          ..add(ArchiveFile(kBackupDatabaseEntry, bytes.length, bytes)),
      ),
    );
    return file;
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fosslift-backup-test');
    storage = await Directory(p.join(root.path, 'storage')).create();
    dbFile = File(p.join(root.path, 'foss_lift.sqlite'));
    db = openAt(dbFile);
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('A backup is one file holding everything', () {
    test(
      'it carries the database, and the database still has your log in it',
      () async {
        await addRoutine(db, 'Upper / Lower');

        final file = await serviceFor(db).save(clips: false);

        expect(await file.exists(), isTrue);
        final entries = ZipDecoder()
            .decodeBytes(await file.readAsBytes())
            .files
            .map((f) => f.name)
            .toList();
        expect(entries, contains(kBackupManifestEntry));
        expect(entries, contains(kBackupDatabaseEntry));

        // The proof is opening it: a copy of a file is not a database until
        // something reads a routine back out of it.
        final restored = File(p.join(root.path, 'read-back.sqlite'));
        await restored.writeAsBytes(
          ZipDecoder()
              .decodeBytes(await file.readAsBytes())
              .findFile(kBackupDatabaseEntry)!
              .readBytes()!,
        );
        final reopened = openAt(restored);
        addTearDown(reopened.close);
        expect(await routinesIn(reopened), contains('Upper / Lower'));
      },
    );

    test('and a manifest saying which schema wrote it', () async {
      final file = await serviceFor(db).save(clips: false);

      final manifest = BackupManifest.decode(
        String.fromCharCodes(
          ZipDecoder()
              .decodeBytes(await file.readAsBytes())
              .findFile(kBackupManifestEntry)!
              .readBytes()!,
        ),
      );

      expect(manifest, isNotNull);
      expect(manifest!.schema, db.schemaVersion);
      expect(manifest.created, DateTime(2026, 8, 7));
      expect(manifest.clips, 0);
    });

    test('it is named for the day it was made', () {
      expect(
        backupFileName(DateTime(2026, 8, 7)),
        'fosslift-backup-2026-08-07.zip',
      );
    });

    test('set videos are left out unless they are asked for', () async {
      await clip('a.mp4');
      await clip('b.mp4');

      final without = await serviceFor(db).save(clips: false);

      expect(
        ZipDecoder()
            .decodeBytes(await without.readAsBytes())
            .files
            .where((f) => f.name.startsWith(kBackupVideoFolder)),
        isEmpty,
      );
    });

    test('and are carried, with their count, when they are', () async {
      await clip('a.mp4');
      await clip('b.mp4');

      final with_ = await serviceFor(db).save(clips: true);
      final archive = ZipDecoder().decodeBytes(await with_.readAsBytes());

      expect(
        archive.files.map((f) => f.name),
        containsAll([
          p.join(kBackupVideoFolder, 'a.mp4'),
          p.join(kBackupVideoFolder, 'b.mp4'),
        ]),
      );
      final manifest = BackupManifest.decode(
        String.fromCharCodes(
          archive.findFile(kBackupManifestEntry)!.readBytes()!,
        ),
      );
      expect(manifest!.clips, 2);
    });

    test(
      'the size offered up front counts the clips only when they are in',
      () async {
        await routinesIn(
          db,
        ); // drift opens the file lazily; a read makes it real
        await clip('a.mp4', bytes: 4096);
        final service = serviceFor(db);

        final bare = await service.size(clips: false);
        final full = await service.size(clips: true);

        expect(bare, greaterThan(0), reason: 'the database is never nothing');
        expect(full - bare, 4096);
      },
    );
  });

  group('Restore replaces everything on the phone', () {
    test('what was in the backup is what is there afterwards', () async {
      await addRoutine(db, 'The one in the backup');
      final backup = await serviceFor(db).save(clips: false);

      // Life goes on: the phone gains a routine the backup has never heard of.
      await addRoutine(db, 'Made after the backup');

      final refusal = await serviceFor(db).restore(backup);
      expect(refusal, isNull);

      final reopened = openAt(dbFile);
      addTearDown(reopened.close);
      final names = await routinesIn(reopened);
      expect(names, contains('The one in the backup'));
      expect(
        names,
        isNot(contains('Made after the backup')),
        reason: 'restore replaces, it does not merge',
      );
    });

    test('clips come back when they were put in', () async {
      await clip('a.mp4');
      final backup = await serviceFor(db).save(clips: true);
      await Directory(
        p.join(storage.path, kBackupVideoFolder),
      ).delete(recursive: true);

      await serviceFor(db).restore(backup);

      expect(
        await File(p.join(storage.path, kBackupVideoFolder, 'a.mp4')).exists(),
        isTrue,
      );
    });

    test(
      'and a backup without them leaves the clips already on the phone',
      () async {
        // Relative paths, so the sets in the restored database still find the
        // files that are already there — see features/index.html#sec20.
        final backup = await serviceFor(db).save(clips: false);
        await clip('filmed-since.mp4');

        await serviceFor(db).restore(backup);

        expect(
          await File(
            p.join(storage.path, kBackupVideoFolder, 'filmed-since.mp4'),
          ).exists(),
          isTrue,
        );
      },
    );
  });

  group('Restore replaces the database under a running app', () {
    test('closing it twice is not an error', () async {
      // The restore closes the database itself, and then the app rebuilds the
      // provider that holds it — whose own teardown closes it again. If the
      // second close threw, every restore would end in an error the user could
      // do nothing about, after the work had already succeeded.
      final second = openAt(File(p.join(root.path, 'twice.sqlite')));
      await second.customSelect('SELECT 1').get();

      await second.close();
      await expectLater(second.close(), completes);
    });
  });

  group('What restore refuses', () {
    /// The database as it stands, by the one name a test can check cheaply.
    Future<Iterable<String>> routineNames() async {
      final reopened = openAt(dbFile);
      addTearDown(reopened.close);
      return routinesIn(reopened);
    }

    test(
      'corrupt SQLite is refused while the current database stays usable',
      () async {
        await addRoutine(db, 'Current profile');
        final backup = await archiveWithDatabase(
          'corrupt-sqlite.zip',
          List<int>.generate(4096, (i) => i % 251),
        );

        expect(await serviceFor(db).restore(backup), BackupRefusal.notABackup);
        expect(
          await routinesIn(db),
          contains('Current profile'),
          reason: 'validation happens before the live database is closed',
        );
      },
    );

    test(
      'an unrelated valid SQLite database is refused without replacement',
      () async {
        await addRoutine(db, 'Current profile');
        final unrelatedFile = File(p.join(root.path, 'unrelated.sqlite'));
        final unrelated = openAt(unrelatedFile);
        await unrelated.customStatement(
          'CREATE TABLE unrelated_notes (id INTEGER PRIMARY KEY, note TEXT)',
        );
        await unrelated.close();
        final backup = await archiveWithDatabase(
          'unrelated-valid-sqlite.zip',
          await unrelatedFile.readAsBytes(),
        );

        expect(await serviceFor(db).restore(backup), BackupRefusal.notABackup);
        expect(
          await routinesIn(db),
          contains('Current profile'),
          reason: 'a valid SQLite header is not proof it is a Foss Lift backup',
        );
      },
    );

    test('a file that is not a backup at all', () async {
      await addRoutine(db, 'Still here afterwards');
      await db.close();
      final photo = File(p.join(root.path, 'holiday.jpg'));
      await photo.writeAsBytes(List.filled(2048, 3));

      expect(await serviceFor(db).restore(photo), BackupRefusal.notABackup);
      expect(
        await routineNames(),
        contains('Still here afterwards'),
        reason: 'nothing is touched until the file is known to be a backup',
      );
    });

    test('a zip with no manifest in it', () async {
      final zip = File(p.join(root.path, 'something-else.zip'));
      await zip.writeAsBytes(
        ZipEncoder().encodeBytes(
          Archive()..add(ArchiveFile.string('readme.txt', 'hi')),
        ),
      );

      expect(await serviceFor(db).restore(zip), BackupRefusal.notABackup);
    });

    test('and one written by a newer version of the app', () async {
      final backup = await serviceFor(db).save(clips: false);

      // The same file, read by a build one schema version behind it.
      final refusal = await serviceFor(
        db,
        schemaVersion: db.schemaVersion - 1,
      ).restore(backup);

      expect(refusal, BackupRefusal.fromANewerVersion);
    });

    test('an older backup is not refused — the ladder is what it climbs', () {
      expect(
        refuseBackup(
          BackupManifest(schema: 1, created: DateTime(2026), clips: 0),
          schemaVersion: 9,
        ),
        isNull,
      );
    });

    test('nothing that is not ours decodes as a manifest', () {
      expect(BackupManifest.decode('not json at all'), isNull);
      expect(BackupManifest.decode('{"hello":"world"}'), isNull);
      expect(refuseBackup(null, schemaVersion: 1), BackupRefusal.notABackup);
    });
  });

  group('The screen', () {
    late AppDatabase memory;

    setUp(() => memory = memoryDb());
    tearDown(() => memory.close());

    testWidgets('Profile offers it', (tester) async {
      final container = containerFor(memory);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        routedAppUnder(container, const ProfileScreen(), scaffold: true),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.profileBackup), findsOneWidget);
    });

    testWidgets('and does not, where there is no filesystem to write to', (
      tester,
    ) async {
      final container = containerFor(
        memory,
        overrides: [capabilitiesProvider.overrideWithValue(Capabilities.web)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        routedAppUnder(container, const ProfileScreen(), scaffold: true),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.profileBackup), findsNothing);
    });

    testWidgets('the unticked box is the whole of the telling', (tester) async {
      // No line under the checkbox repeating what the checkbox says. What is
      // worth a note is the size, which appears once clips are in.
      final container = containerFor(memory);
      addTearDown(container.dispose);

      await tester.pumpWidget(routedAppUnder(container, const BackupScreen()));
      await tester.pumpAndSettle();

      final tick = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(tick.value, isFalse, reason: 'clips are out until asked for');
      expect(
        find.textContaining(RegExp('videos? are not', caseSensitive: false)),
        findsNothing,
      );
    });

    testWidgets('a backup big enough to be a nuisance says so', (tester) async {
      final container = containerFor(
        memory,
        overrides: [
          backupSizeProvider.overrideWith(
            (ref) async => (bare: 2048, withClips: kBackupLargeBytes + 1),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(routedAppUnder(container, const BackupScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.backupIncludeVideos));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.backupTooBig(fmtBytes(kBackupLargeBytes))),
        findsOneWidget,
      );
    });

    testWidgets('and it will not restore over a running workout', (
      tester,
    ) async {
      final container = containerFor(memory);
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        final id = await workoutIdNamed(memory, 'Push');
        await container
            .read(activeWorkoutProvider.notifier)
            .start(workoutId: id, name: 'Push');
      });

      await tester.pumpWidget(routedAppUnder(container, const BackupScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.backupChooseFile));
      await tester.pumpAndSettle();

      expect(find.text(l10n.backupFinishWorkoutFirst), findsOneWidget);
      container.read(activeWorkoutProvider.notifier).discard();
    });
  });
}
