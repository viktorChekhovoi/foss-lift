/// Backup manifest format and compatibility checks.
///
/// A backup is a zip containing a manifest, the database, and optionally set video clips:
///
/// ```
/// manifest.json      {"tag":"FLB1","format":1,"schema":3,…}
/// foss_lift.sqlite   the database, snapshotted rather than copied live
/// set_videos/…       one entry per clip, only when they were included
/// ```
///
/// The manifest identifies the archive; the filename is not trusted because file pickers and cloud storage may rename it.
library;

import 'dart:convert';

/// Tag identifying a Foss Lift backup manifest.
const String kBackupTag = 'FLB1';

/// Container version. Database schema changes use [BackupManifest.schema].
const int kBackupFormat = 1;

const String kBackupManifestEntry = 'manifest.json';
const String kBackupDatabaseEntry = 'foss_lift.sqlite';

/// Archive folder containing set clips.
const String kBackupVideoFolder = 'set_videos';

/// Size at which the UI warns before creating a backup. This is not a limit.
const int kBackupLargeBytes = 200 * 1024 * 1024;

/// Metadata stored in a backup manifest.
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

  /// Parses [source], returning null when it is not a valid manifest.
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
      // Invalid files are treated as non-backups.
      return null;
    }
  }
}

/// Why a backup cannot be opened, or null when it can.
enum BackupRefusal {
  /// The file does not contain a valid backup manifest.
  notABackup,

  /// The backup requires a newer database schema.
  fromANewerVersion,
}

/// Returns a refusal reason when [manifest] cannot be restored at [schemaVersion]; older schemas upgrade normally and newer schemas are rejected.
BackupRefusal? refuseBackup(
  BackupManifest? manifest, {
  required int schemaVersion,
}) {
  if (manifest == null) return BackupRefusal.notABackup;
  if (manifest.schema > schemaVersion) return BackupRefusal.fromANewerVersion;
  return null;
}

/// Returns a sortable filename for a backup created on [day].
String backupFileName(DateTime day) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'fosslift-backup-${day.year}-${two(day.month)}-${two(day.day)}.zip';
}
