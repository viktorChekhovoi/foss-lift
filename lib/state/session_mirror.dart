import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/db_provider.dart';
import 'active_workout.dart';
import 'session_snapshot.dart';

/// Queued crash snapshot for the in-memory live session.
///
/// **The session is still in memory and still writes its history only on
/// Finish.** This does not make it database-backed — nothing reads the snapshot
/// while the app is running, and the board never waits for it. It exists because
/// Android kills backgrounded processes, and a workout that evaporates because
/// somebody looked at a text message is not a tracker. See [LiveSessions].
///
/// Writes are queued and never awaited by the caller: two overlapping ones could
/// leave the older session on disk, and a write racing a clear could resurrect a
/// finished one. A failure is swallowed with a line in the log — the session on
/// screen is unaffected, and the only cost is a snapshot that is a mutation
/// behind.
class SessionMirror {
  SessionMirror(this._db);

  final AppDatabase _db;

  Future<void> _queue = Future<void>.value();

  /// Queues a snapshot of [session].
  void save(ActiveWorkout session) {
    final payload = encodeSession(session);
    _next(() => _db.saveLiveSession(payload), 'mirror the session');
  }

  /// Drops the snapshot — the session was finished or thrown away.
  void clear() => _next(_db.clearLiveSession, 'drop the snapshot');

  /// Loads and ages the previous snapshot, if any.
  Future<ActiveWorkout?> load() async {
    final row = await _db.loadLiveSession();
    if (row == null) return null;
    return decodeSession(
      row.payload,
      dead: DateTime.now().difference(row.savedAt),
    );
  }

  void _next(Future<void> Function() write, String what) {
    _queue = _queue.then((_) => write()).catchError(
        (Object e) => debugPrint('SessionMirror: could not $what ($e)'));
  }
}

/// Provides the live-session snapshot service.
///
/// Null in a widget test, and deliberately: a test drives the app under a fake
/// clock, a database future completes on the real event loop, and an unawaited
/// write issued from the one cannot finish under the other — it hangs the test
/// and then the close that follows it. `test/support/harness.dart` switches this
/// off for that reason and back on for the tests that are about the snapshot
/// itself.
final sessionMirrorProvider = Provider<SessionMirror?>(
  (ref) => SessionMirror(ref.watch(databaseProvider)),
);
