/// What a backup file *is*, with nothing that touches a disk in it.
///
/// The reading and writing lives in `services/backup_service.dart`; this half
/// is the format and the two decisions that go with it — whether a file is one
/// of ours, and whether this build is allowed to open it. Both are worth being
/// able to test without a filesystem, and both are what somebody re-reads in
/// two years when a restore refuses and nobody remembers why it would.
///
/// **The shape.** A zip holding a manifest, the database, and the set video
/// clips if they were asked for:
///
/// ```
/// manifest.json      {"tag":"FLB1","format":1,"schema":3,…}
/// foss_lift.sqlite   the database, snapshotted rather than copied live
/// set_videos/…       one entry per clip, only when they were included
/// ```
///
/// A zip rather than a container with the app's own extension because the file
/// has to survive being mailed, dropped in a cloud drive and handed back by a
/// file picker — and everything on that path already knows what a zip is. What
/// says the file is a backup is the manifest inside it, never the name: a
/// picker that renames on the way through must not turn a backup into something
/// unopenable.
library;

import 'dart:convert';

/// The format's own tag, in the manifest. `FLR1` codes are the routine wire
/// format and `FLT1` a palette; this is the third and it is a file rather than
/// a line of text.
const String kBackupTag = 'FLB1';

/// The version of the *container*, not of the schema inside it. It moves only
/// if the arrangement of entries changes; a new table is a schema bump and
/// leaves this alone.
const int kBackupFormat = 1;

const String kBackupManifestEntry = 'manifest.json';
const String kBackupDatabaseEntry = 'foss_lift.sqlite';

/// The folder clips sit in, inside the archive and on disk alike — it is
/// `SetVideoStore.folder`, and the paths stored against a set are relative to
/// the folder above it, which is what lets a restored row still find its clip.
const String kBackupVideoFolder = 'set_videos';

/// Past this, a backup is worth warning about before it is made.
///
/// Not a limit — nothing refuses to write one. It is the size at which mail
/// bounces it and chat apps decline it, and somebody who is about to sit
/// through a two-minute zip deserves to hear that first. 200 MB is comfortably
/// above a log with a few dozen clips and comfortably below what a phone will
/// actually send.
const int kBackupLargeBytes = 200 * 1024 * 1024;

/// What a backup says about itself.
///
/// [schema] is the drift version that wrote it, which is the whole of the
/// compatibility question — see [refuseBackup]. [clips] is how many set videos
/// travelled with it, so a restore knows whether the archive is authoritative
/// about clips or silent on them.
class BackupManifest {
  const BackupManifest({
    required this.schema,
    required this.created,
    required this.clips,
  });

  final int schema;
  final DateTime created;
  final int clips;

  String encode() => jsonEncode({
        'tag': kBackupTag,
        'format': kBackupFormat,
        'schema': schema,
        'created': created.toIso8601String(),
        'clips': clips,
      });

  /// The manifest [source] describes, or **null when it is not one of ours** —
  /// unparseable, a different tag, a container version this build has never
  /// heard of, or a schema that is not a number. Every one of those means the
  /// same thing to the caller, which is that there is nothing here to restore.
  static BackupManifest? decode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) return null;
      if (decoded['tag'] != kBackupTag) return null;
      if (decoded['format'] is! int || decoded['format'] > kBackupFormat) {
        return null;
      }
      final schema = decoded['schema'];
      if (schema is! int) return null;
      return BackupManifest(
        schema: schema,
        created: DateTime.parse(decoded['created'] as String),
        clips: decoded['clips'] is int ? decoded['clips'] as int : 0,
      );
    } catch (_) {
      // A file picked out of a folder of holiday photos lands here. It is not
      // an error worth a stack trace; it is an answer.
      return null;
    }
  }
}

/// Why a backup cannot be opened, or null when it can.
enum BackupRefusal {
  /// Nothing in the file says it is a backup.
  notABackup,

  /// It was written by a build newer than this one.
  fromANewerVersion,
}

/// Whether [manifest] may be restored onto a build at [schemaVersion].
///
/// **Older is fine, newer is not.** An older backup describes tables this build
/// knows the history of, so it is opened by the same migration ladder that
/// upgrades a database in place — a file made two versions ago restores onto
/// today's app and climbs. A newer one describes tables that do not exist here
/// and there is no rung going down; opening it would half-work, which is worse
/// than refusing.
BackupRefusal? refuseBackup(
  BackupManifest? manifest, {
  required int schemaVersion,
}) {
  if (manifest == null) return BackupRefusal.notABackup;
  if (manifest.schema > schemaVersion) return BackupRefusal.fromANewerVersion;
  return null;
}

/// What the file is called: `fosslift-backup-2026-08-07.zip`.
///
/// The date is ISO order rather than the phone's, so a folder of them sorts by
/// name into the order they were made. It is not a localised string for the
/// same reason a filename never is.
String backupFileName(DateTime day) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'fosslift-backup-${day.year}-${two(day.month)}-${two(day.day)}.zip';
}
