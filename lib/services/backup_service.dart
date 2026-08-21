/// Creates and restores backup archives with injected dependencies for temporary-directory tests. Restore validates and stages the archive before replacing the live database.

library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

    final destination = File(p.join(work.path, backupFileName(manifest.created)));
    if (await destination.exists()) await destination.delete();

    final archive = Archive()
      ..add(ArchiveFile.string(kBackupManifestEntry, manifest.encode()))
      ..add(ArchiveFile.stream(
          kBackupDatabaseEntry, InputFileStream(snapshot.path)));
    for (final file in videos) {
      // Always a forward slash: it is a zip entry name, not a path on this
      // machine.
      archive.add(ArchiveFile.stream(
        '$kBackupVideoFolder/${p.basename(file.path)}',
        InputFileStream(file.path),
      ));
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

    final entry = archive.findFile(kBackupManifestEntry);
    final manifest = entry == null
        ? null
        : BackupManifest.decode(
            utf8.decode(entry.readBytes() ?? const [], allowMalformed: true));
    final refusal = refuseBackup(manifest, schemaVersion: schemaVersion);
    if (refusal != null) return refusal;

    final database = archive.findFile(kBackupDatabaseEntry);
    final bytes = database?.readBytes();
    // A manifest with no database under it is not half a backup, it is not one.
    if (bytes == null) return BackupRefusal.notABackup;

    final work = await workDirectory();
    final staged = File(p.join(work.path, 'backup-restore.sqlite'));
    await staged.writeAsBytes(bytes, flush: true);

    await closeDatabase();
    final target = await databaseFile();
    await staged.copy(target.path);
    await staged.delete();
    // The journal beside the old database describes the old database. Left in
    // place, SQLite would replay it over the file that just arrived.
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      final sidecar = File('${target.path}$suffix');
      if (await sidecar.exists()) await sidecar.delete();
    }

    // A backup that carried no clips says nothing about clips, so the ones on
    // the phone stay: restoring onto the phone that filmed them is the common
    // case, and their paths are relative, so the restored rows still find them.
    if ((manifest?.clips ?? 0) > 0) await _restoreClips(archive);
    return null;
  }

  Future<void> _restoreClips(Archive archive) async {
    final dir = Directory(p.join((await storageDirectory()).path, kBackupVideoFolder));
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      if (!entry.name.startsWith('$kBackupVideoFolder/')) continue;
      final bytes = entry.readBytes();
      if (bytes == null) continue;
      // The basename only: an entry naming its way up out of the folder is not
      // something to be following.
      final file = File(p.join(dir.path, p.basename(entry.name)));
      await file.writeAsBytes(bytes, flush: true);
    }
  }

  /// Every clip on disk. Stills are included deliberately — they are cheap, and
  /// a restore that brought the clips back without them would leave the reel
  /// decoding every frame again on the first visit.
  Future<List<File>> _clipFiles() async {
    final dir = Directory(p.join((await storageDirectory()).path, kBackupVideoFolder));
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
        p.join((await getApplicationDocumentsDirectory()).path,
            'foss_lift.sqlite')),
    storageDirectory: getApplicationSupportDirectory,
    workDirectory: getTemporaryDirectory,
    closeDatabase: db.close,
    schemaVersion: db.schemaVersion,
  );
});
