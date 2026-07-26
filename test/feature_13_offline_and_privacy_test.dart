// Feature 13 — Offline & privacy.
//
// The claim is a negative one — the app makes no network connections and
// collects nothing — so the honest test is a guardrail that scans the whole of
// lib/ for any networking import and asserts there are none, plus a check that
// the one datastore is a local drift/SQLite database that opens and seeds with
// no network anywhere near it, and that the sole platform integration (the
// Android reminder) is inert off a device. Nothing here invents behaviour the
// spec does not state.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/services/reminders.dart';

import 'support/harness.dart';

void main() {
  group('nothing in the app reaches the network', () {
    test('no lib/ source imports a networking package or an HTTP client', () {
      final lib = Directory('lib');
      expect(lib.existsSync(), isTrue, reason: 'run from the package root');

      // Markers of an outbound connection: the common HTTP/websocket packages,
      // the browser networking libraries, and dart:io's HttpClient. dart:io
      // itself is allowed — it is used for File and Platform, not sockets.
      const forbidden = <String>[
        'package:http/',
        'package:http.',
        'package:dio',
        'package:web/',
        'package:web_socket',
        'package:socket',
        'dart:html',
        'dart:js',
        'HttpClient',
        'WebSocket',
      ];

      final offenders = <String>[];
      for (final entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        for (final marker in forbidden) {
          if (source.contains(marker)) {
            offenders.add('${entity.path} contains "$marker"');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'the app must make no network connections:\n'
              '${offenders.join('\n')}');
    });
  });

  group('all data lives in a local on-device store', () {
    test('the database opens and seeds fully offline', () async {
      // memoryDb() opens a drift/SQLite database with no connectivity of any
      // kind; that it seeds the starter routines proves the whole datastore is
      // local and self-contained.
      final db = memoryDb();
      addTearDown(db.close);

      expect(db, isA<AppDatabase>());

      final routines = await db.watchRoutines().first;
      expect(routines, isNotEmpty,
          reason: 'seeded on first open with no network');
    });
  });

  group('the only platform integration is a local Android reminder', () {
    test('the reminder scheduler is a no-op off Android and touches no channel',
        () async {
      // Off a device the reminder service does nothing — no server, no plugin
      // call — so a reminder that would schedule on Android is silently ignored
      // here rather than reaching for a platform channel.
      final service = ReminderService();
      expect(service.supported, isFalse);

      await service.sync(
        const [
          RoutineReminder(
            routineId: 1,
            name: 'Push / Pull / Legs',
            scheduleDays: 1 << 0,
            reminderMinutes: 600,
          ),
        ],
        now: DateTime(2024, 1, 1, 8, 0),
      );

      expect(await service.permitted(), isFalse);
    });
  });
}
