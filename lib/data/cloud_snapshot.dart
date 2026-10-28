/// Portable, data-only backups. No native filesystem or platform imports.
library;

import 'dart:convert';

import 'database.dart';

const kMaxCloudSnapshotBytes = 1024 * 1024;

extension CloudSnapshots on AppDatabase {
  /// Reads one consistent database version, excluding unfinished workouts.
  Future<String> exportCloudSnapshot() => transaction(() async {
    final tables = <String, Object?>{};
    for (final table in allTables) {
      if (table.actualTableName == 'live_sessions') continue;
      tables[table.actualTableName] = (await customSelect(
        'SELECT * FROM "${table.actualTableName}"',
      ).get()).map((row) => row.data).toList();
    }
    final payload = jsonEncode({
      'format': 'foss-lift-cloud-1',
      'schema': schemaVersion,
      'tables': tables,
    });
    if (utf8.encode(payload).length > kMaxCloudSnapshotBytes) {
      throw const FormatException('cloud_backup_too_large');
    }
    return payload;
  });

  /// Validates the shape before writing, then replaces rows in one transaction.
  /// SQLite constraints and foreign-key checks run before committing; a failure
  /// leaves the previous data and every subscribed view intact.
  Future<void> restoreCloudSnapshot(String payload) async {
    if (utf8.encode(payload).length > kMaxCloudSnapshotBytes) {
      throw const FormatException('cloud_backup_too_large');
    }
    final decoded = jsonDecode(payload);
    if (decoded is! Map ||
        decoded['format'] != 'foss-lift-cloud-1' ||
        decoded['schema'] != schemaVersion ||
        decoded['tables'] is! Map) {
      throw const FormatException('cloud_backup_incompatible');
    }
    final data = decoded['tables'] as Map;
    final tables = allTables
        .where((t) => t.actualTableName != 'live_sessions')
        .toList();
    if (data.length != tables.length) {
      throw const FormatException('cloud_backup_incompatible');
    }
    for (final table in tables) {
      final rows = data[table.actualTableName];
      final columns = table.$columns.map((c) => c.$name).toSet();
      if (rows is! List) throw const FormatException('cloud_backup_invalid');
      for (final row in rows) {
        if (row is! Map ||
            row.length != columns.length ||
            !columns.containsAll(row.keys) ||
            row.values.any((v) => v != null && v is! String && v is! num) ||
            row.values.whereType<num>().any((v) => !v.isFinite)) {
          throw const FormatException('cloud_backup_invalid');
        }
        // Apply Drift's type mapping as well as SQLite's storage constraints.
        await table.map(Map<String, dynamic>.from(row));
      }
    }
    final settingsRows = data['settings'] as List;
    if (settingsRows.length != 1 || settingsRows.single['id'] != 1) {
      throw const FormatException('cloud_backup_invalid');
    }
    await transaction(() async {
      // Other tabs share this record without sharing the UI's live controller.
      if (await loadLiveSession() != null) {
        throw const FormatException('workout_running');
      }
      for (final table in allTables.toList().reversed) {
        await customStatement('DELETE FROM "${table.actualTableName}"');
      }
      for (final table in tables) {
        final columns = table.$columns.map((c) => c.$name).toList();
        final sql =
            'INSERT INTO "${table.actualTableName}" '
            '(${columns.map((c) => '"$c"').join(',')}) '
            'VALUES (${List.filled(columns.length, '?').join(',')})';
        // A batch amortizes worker messaging even for years of training logs.
        await batch((b) {
          for (final row in data[table.actualTableName] as List) {
            b.customStatement(sql, columns.map((c) => row[c]).toList());
          }
        });
      }
      if ((await customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
        throw const FormatException('cloud_backup_invalid');
      }
      markTablesUpdated(allTables);
    });
  }
}
