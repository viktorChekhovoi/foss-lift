/// Creates and restores backup archives with injected dependencies for temporary-directory tests. Restore validates and stages the archive before replacing the live database.

library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../data/backup_archive.dart';
import '../providers/db_provider.dart';

class BackupService {
  BackupService({
    required this.snapshotDatabase,
    required this.databaseFile,
    required this.storageDirectory,
    required this.workDirectory,
    required this.closeDatabase,
    required this.schemaVersion,
    this.onDatabaseClosed,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  /// Writes a consistent copy of the live database to a path — `VACUUM INTO`.
  final Future<void> Function(String path) snapshotDatabase;

  /// The database file itself, which a restore overwrites.
  final Future<File> Function() databaseFile;

  /// The directory `set_videos` sits in — clip paths are stored relative to it.
  final Future<Directory> Function() storageDirectory;

  /// Somewhere to build the archive and stage a restore. The file handed to the
  /// share sheet lives here; the app keeps no copy of a backup anywhere else.
  final Future<Directory> Function() workDirectory;

  final Future<void> Function() closeDatabase;

  /// This build's schema version, written into the manifest and checked against
  /// the one in a file being restored.
  final int schemaVersion;
  final void Function()? onDatabaseClosed;

  final DateTime Function() now;

  /// What the backup will be made of, in bytes: the database, plus every clip
  /// when [clips] is set.
  ///
  /// The file itself comes out smaller — it is compressed — so this is the
  /// honest upper bound rather than a promise. Measuring the clips rather than
  /// guessing at them is the point: the number decides whether somebody taps
  /// Save on a train.
  Future<int> size({required bool clips}) async {
    var total = 0;
    final db = await databaseFile();
    if (await db.exists()) total += await db.length();
    if (clips) {
      for (final file in await _clipFiles()) {
        total += await file.length();
      }
    }
    return total;
  }

  /// Builds the backup and returns the file, ready to hand to the share sheet.
  Future<File> save({required bool clips}) async {
    final work = await workDirectory();
    final snapshot = File(p.join(work.path, 'backup-snapshot.sqlite'));
    if (await snapshot.exists()) await snapshot.delete();
    await snapshotDatabase(snapshot.path);

    final videos = clips ? await _clipFiles() : const <File>[];
    final manifest = BackupManifest(
      schema: schemaVersion,
      created: now(),
      clips: videos.length,
    );

    final destination = File(
      p.join(work.path, backupFileName(manifest.created)),
    );
    if (await destination.exists()) await destination.delete();

    final archive = Archive()
      ..add(ArchiveFile.string(kBackupManifestEntry, manifest.encode()))
      ..add(
        ArchiveFile.stream(
          kBackupDatabaseEntry,
          InputFileStream(snapshot.path),
        ),
      );
    for (final file in videos) {
      // Always a forward slash: it is a zip entry name, not a path on this
      // machine.
      archive.add(
        ArchiveFile.stream(
          '$kBackupVideoFolder/${p.basename(file.path)}',
          InputFileStream(file.path),
        ),
      );
    }

    final out = OutputFileStream(destination.path);
    // autoClose lets go of each clip as it is written rather than holding every
    // handle open until the end — a reel is hundreds of files.
    ZipEncoder().encodeStream(archive, out, autoClose: true);
    await out.close();
    await snapshot.delete();
    return destination;
  }

  /// Reads [file] back onto the phone, or says why it will not.
  ///
  /// Returns null when the phone now holds what the backup held.
  Future<BackupRefusal?> restore(File file) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeStream(InputFileStream(file.path));
    } catch (_) {
      return BackupRefusal.notABackup;
    }

    final manifests = archive.files
        .where((entry) => entry.name == kBackupManifestEntry)
        .toList();
    final databases = archive.files
        .where((entry) => entry.name == kBackupDatabaseEntry)
        .toList();
    if (manifests.length != 1 || databases.length != 1) {
      return BackupRefusal.notABackup;
    }
    final entry = manifests.single;
    final manifest = BackupManifest.decode(
      utf8.decode(entry.readBytes() ?? const [], allowMalformed: true),
    );
    final refusal = refuseBackup(manifest, schemaVersion: schemaVersion);
    if (refusal != null) return refusal;

    final database = databases.single;
    if (!database.isFile ||
        database.size <= 0 ||
        database.size > _maxDatabaseBytes) {
      return BackupRefusal.notABackup;
    }

    final work = await workDirectory();
    final staged = File(p.join(work.path, 'backup-restore.sqlite'));
    if (await staged.exists()) await staged.delete();
    final stagedOut = OutputFileStream(staged.path);
    database.writeContent(stagedOut);
    await stagedOut.close();
    if (!_validDatabase(staged, manifest!.schema)) {
      await staged.delete();
      return BackupRefusal.notABackup;
    }

    final target = await databaseFile();
    if (p.basename(target.path) != 'foss_lift.sqlite') {
      await staged.delete();
      return BackupRefusal.notABackup;
    }
    final recovery = File('${target.path}.restore-recovery');
    var closed = false;
    try {
      await closeDatabase();
      closed = true;
      if (await recovery.exists()) await recovery.delete();
      if (await target.exists()) await target.copy(recovery.path);
      for (final suffix in const ['-wal', '-shm', '-journal']) {
        final sidecar = File('${target.path}$suffix');
        if (await sidecar.exists()) await sidecar.delete();
      }
      await staged.copy(target.path);
      if (!_validDatabase(target, manifest.schema)) {
        throw const FormatException('installed database failed validation');
      }
      if (await recovery.exists()) await recovery.delete();
    } catch (_) {
      if (await recovery.exists()) await recovery.copy(target.path);
      rethrow;
    } finally {
      if (await staged.exists()) await staged.delete();
      if (closed) onDatabaseClosed?.call();
    }

    // A backup that carried no clips says nothing about clips, so the ones on
    // the phone stay: restoring onto the phone that filmed them is the common
    // case, and their paths are relative, so the restored rows still find them.
    if (manifest.clips > 0) await _restoreClips(archive);
    return null;
  }

  bool _validDatabase(File file, int claimedSchema) {
    Database? db;
    try {
      db = sqlite3.open(file.path, mode: OpenMode.readOnly);
      final integrity = db
          .select('PRAGMA integrity_check')
          .single
          .values
          .single;
      if (integrity != 'ok') return false;
      final actualSchema = db.userVersion;
      if (actualSchema != claimedSchema || actualSchema > schemaVersion) {
        return false;
      }
      const required = <String, Set<String>>{
        'exercises': {'id', 'name'},
        'routines': {'id', 'name'},
        'workouts': {'id', 'routine_id', 'name'},
        'workout_items': {'id', 'workout_id', 'exercise_id'},
        'sessions': {'id', 'name', 'started_at', 'ended_at'},
        'session_sets': {'id', 'session_id', 'exercise_name'},
        'settings': {'id'},
      };
      final tables = db
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row['name'] as String)
          .toSet();
      for (final entry in required.entries) {
        if (!tables.contains(entry.key)) return false;
        final columns = db
            .select('PRAGMA table_info("${entry.key}")')
            .map((row) => row['name'] as String)
            .toSet();
        if (!columns.containsAll(entry.value)) return false;
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      db?.close();
    }
  }

  Future<void> _restoreClips(Archive archive) async {
    final storage = await storageDirectory();
    final dir = Directory(p.join(storage.path, kBackupVideoFolder));
    final staged = Directory(
      p.join(storage.path, '$kBackupVideoFolder.staged'),
    );
    final recovery = Directory(
      p.join(storage.path, '$kBackupVideoFolder.restore-recovery'),
    );
    if (await staged.exists()) await staged.delete(recursive: true);
    await staged.create(recursive: true);
    final names = <String>{};
    try {
      for (final entry in archive.files) {
        if (!entry.isFile || !entry.name.startsWith('$kBackupVideoFolder/')) {
          continue;
        }
        final name = p.basename(entry.name);
        if (entry.name != '$kBackupVideoFolder/$name' ||
            name.isEmpty ||
            !names.add(name) ||
            entry.size > _maxClipBytes) {
          throw const FormatException('invalid clip entry');
        }
        final out = OutputFileStream(p.join(staged.path, name));
        entry.writeContent(out);
        await out.close();
      }
      if (await recovery.exists()) await recovery.delete(recursive: true);
      if (await dir.exists()) await dir.rename(recovery.path);
      await staged.rename(dir.path);
      if (await recovery.exists()) await recovery.delete(recursive: true);
    } catch (_) {
      if (!await dir.exists() && await recovery.exists()) {
        await recovery.rename(dir.path);
      }
      rethrow;
    } finally {
      if (await staged.exists()) await staged.delete(recursive: true);
    }
  }

  /// Every clip on disk. Stills are included deliberately — they are cheap, and
  /// a restore that brought the clips back without them would leave the reel
  /// decoding every frame again on the first visit.
  Future<List<File>> _clipFiles() async {
    final dir = Directory(
      p.join((await storageDirectory()).path, kBackupVideoFolder),
    );
    if (!await dir.exists()) return const [];
    return dir.list().where((e) => e is File).cast<File>().toList();
  }
}

/// The app's own backup service, wired to the phone.
///
/// `getApplicationDocumentsDirectory` is where `db_open_native.dart` puts the
/// database and `getApplicationSupportDirectory` is where `SetVideoStore` puts
/// clips; both are resolved at call time rather than remembered, because the
/// iOS container path changes on reinstall.
final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(databaseProvider);
  return BackupService(
    snapshotDatabase: db.snapshotTo,
    databaseFile: () async => File(
      p.join(
        (await getApplicationDocumentsDirectory()).path,
        'foss_lift.sqlite',
      ),
    ),
    storageDirectory: getApplicationSupportDirectory,
    workDirectory: getTemporaryDirectory,
    closeDatabase: db.close,
    schemaVersion: db.schemaVersion,
    onDatabaseClosed: () => ref.invalidate(databaseProvider),
  );
});

const int _maxDatabaseBytes = 2 * 1024 * 1024 * 1024;
const int _maxClipBytes = 4 * 1024 * 1024 * 1024;
