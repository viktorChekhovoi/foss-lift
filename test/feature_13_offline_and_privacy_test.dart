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

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/data/warmup.dart';
import 'package:foss_lift/screens/about_screen.dart';
import 'package:foss_lift/services/reminders.dart';

import 'support/harness.dart';
import 'support/schema_v1.dart';

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

      // The web build has to reach the browser directly for two things, and
      // `package:web` is the only way to do it: the `beforeunload` listener
      // behind the leave guard, and `navigator.storage` behind the durability
      // check. Neither is networking, but the package that carries them also
      // carries `fetch` — so these files are exempted from the blanket ban by
      // name and held to the stricter check below instead.
      //
      // Adding a file here is a decision, not a formality: it is the one place
      // that records which parts of the app can see the network API at all.
      const browserApiFiles = <String>{
        'lib/util/leave_guard_web.dart',
        'lib/services/storage_probe_web.dart',
        'lib/services/tab_awake_web.dart',
      };

      // What those files must still never touch. Narrower than the list above
      // and aimed at the actual verbs — anything here would be an outbound
      // request, whatever it was imported for.
      const forbiddenBrowserApis = <String>[
        'fetch(',
        'XMLHttpRequest',
        'WebSocket',
        'EventSource',
        'sendBeacon',
        'importScripts',
        'navigator.connection',
      ];

      final offenders = <String>[];
      for (final entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        final exempt = browserApiFiles.contains(entity.path);
        for (final marker in exempt ? forbiddenBrowserApis : forbidden) {
          if (source.contains(marker)) {
            offenders.add('${entity.path} contains "$marker"');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'the app must make no network connections:\n'
              '${offenders.join('\n')}');
    });

    test('the browser-API exemption names files that exist', () {
      // A path that stops existing would silently exempt nothing and look
      // clean, which is the failure mode that matters for an allowlist.
      for (final path in const [
        'lib/util/leave_guard_web.dart',
        'lib/services/storage_probe_web.dart',
        'lib/services/tab_awake_web.dart',
      ]) {
        expect(File(path).existsSync(), isTrue,
            reason: '$path is exempted from the networking-import ban but is '
                'not there — remove the exemption or fix the path');
      }
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

  group('an update finds everything the last build stored', () {
    // A phone on the shipped build holds a v1 database. Opening it under the
    // current build has to climb the ladder rung by rung and leave the training
    // log, the routines and the settings where they were — and hand a
    // preference v1 never had its default rather than nothing.

    /// A v1 database with a settings row, a finished session and one logged set
    /// in it, opened by the current [AppDatabase] so the ladder runs.
    ///
    /// Nothing about the shape is inferred from today's schema: the DDL is the
    /// frozen [kSchemaV1] and the rows are written as SQL, so the upgrade is
    /// handed the same bytes a phone would hand it.
    AppDatabase v1Database() => AppDatabase.forTesting(
          NativeDatabase.memory(setup: (raw) {
            for (final stmt in kSchemaV1) {
              raw.execute(stmt);
            }
            raw.execute(
              'INSERT INTO settings (id, weight_unit, layoff_days, '
              'layoff_percent, theme_preset_id, text_scale) '
              "VALUES (1, 'lb', 21, 15, 'carbon', 1.2)",
            );
            raw.execute(
              'INSERT INTO sessions (id, name, started_at, ended_at, '
              'duration_seconds, total_volume, sets_completed) '
              "VALUES (1, 'Push', 1700000000, 1700003600, 3600, 2400.0, 4)",
            );
            raw.execute(
              'INSERT INTO session_sets (session_id, exercise_name, '
              'set_number, weight, reps, done, goal_reps) '
              "VALUES (1, 'Bench Press', 1, 80.0, 8, 1, 8)",
            );
            raw.execute('PRAGMA user_version = 1');
          }),
        );

    test('the settings a v1 phone chose survive the climb', () async {
      final db = v1Database();
      addTearDown(db.close);

      expect(await db.watchWeightUnit().first, 'lb');
      expect(await db.layoffSettings(), (days: 21, percent: 15));
      expect(await db.watchThemePresetId().first, 'carbon');
    });

    test('so does the training log', () async {
      final db = v1Database();
      addTearDown(db.close);

      final history = await db.watchHistory().first;
      expect(history, hasLength(1));
      expect(history.single.name, 'Push');
      expect(history.single.setsCompleted, 4);

      final sets = await db.setsForSession(history.single.id);
      expect(sets, hasLength(1));
      expect(sets.single.exerciseName, 'Bench Press');
      expect(sets.single.weight, 80.0);
      expect(sets.single.reps, 8);
    });

    test('a preference v1 never had arrives at its default', () async {
      final db = v1Database();
      addTearDown(db.close);

      expect(await db.defaultWarmupSets(), kDefaultWarmupSets);
    });

    test('and the database is left standing on the current rung', () async {
      final db = v1Database();
      addTearDown(db.close);

      final row = await db.customSelect('PRAGMA user_version').getSingle();
      expect(row.data.values.first, 2);
    });

    test('and on the same shape a fresh install gets', () async {
      // Two routes to one schema: `onCreate` builds the table outright, the
      // ladder alters it. If they disagree — a column of a different type, a
      // different default, even a different order — the app is quietly running
      // against two schemas and only one of them was tested.
      final upgraded = v1Database();
      final fresh = memoryDb();
      addTearDown(upgraded.close);
      addTearDown(fresh.close);

      Future<Map<String, String>> shape(AppDatabase db) async {
        final rows = await db
            .customSelect('SELECT name, sql FROM sqlite_master '
                'WHERE sql IS NOT NULL ORDER BY name')
            .get();
        return {
          for (final r in rows) r.data['name'] as String: r.data['sql'] as String,
        };
      }

      expect(await shape(upgraded), await shape(fresh));
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

      final l10n = l10nFor();
      await service.sync(
        [
          (
            reminder: const RoutineReminder(
              routineId: 1,
              name: 'Push / Pull / Legs',
              scheduleDays: 1 << 0,
              reminderMinutes: 600,
            ),
            title: 'Push / Pull / Legs',
            body: l10n.reminderBody,
          ),
        ],
        channel: (
          name: l10n.reminderChannelName,
          description: l10n.reminderChannelDescription,
        ),
        now: DateTime(2024, 1, 1, 8, 0),
      );

      expect(await service.permitted(), isFalse);
    });
  });

  group('About says what the app does with your data, and how to complain', () {
    testWidgets('the promise and the contact address are both on the screen',
        (tester) async {
      final db = memoryDb();
      addTearDown(db.close);
      final container = containerFor(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(appUnder(container, const AboutScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing leaves this phone'), findsOneWidget);
      // Printed as well as linked, so a phone with no mail app still leaves you
      // an address you can write down.
      expect(find.text(kContactEmail), findsOneWidget);
      expect(find.text('Report a bug'), findsOneWidget);

      await stop(tester);
    });
  });
}
