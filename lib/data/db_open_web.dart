/// The browser's database: sqlite3 compiled to WebAssembly, over whichever
/// storage API the browser actually offers.
///
/// Reached through `db_open.dart` — never imported directly.
///
/// ## What is being loaded
///
/// Two files served beside the app, both checked into `web/` and both taken
/// from the drift release matching the pinned package version:
///
/// - `sqlite3.wasm` — the SQLite C library, compiled for the browser.
/// - `drift_worker.js` — drift's own worker, which hosts the database off the
///   UI thread and, in the shared-worker modes, gives every tab a view of the
///   same database with the stream queries kept in step.
///
/// ## Which storage it lands on
///
/// [WasmDatabase.open] probes the browser and picks the best of:
/// OPFS in a shared worker, OPFS with `Atomics` locks, IndexedDB in a shared
/// worker, IndexedDB with no worker at all, and finally memory. An existing
/// database pins the choice to the storage API it is already in, so a browser
/// update that unlocks a better mode cannot strand the training log in the old
/// one.
///
/// Chrome reaches OPFS only when the page is cross-origin isolated — see the
/// `COOP`/`COEP` headers in `docs/web-build.md`. Without them it lands on
/// IndexedDB in a shared worker, which is durable and safe across tabs, just
/// slower. Nothing here fails if the headers are missing; it degrades.
///
/// The one genuinely bad outcome is `inMemory`, which persists nothing. It
/// needs a browser with neither workers nor IndexedDB, and the app does not
/// pretend otherwise: the chosen implementation is left on the result for a
/// caller that wants to warn.
library;

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// The last storage implementation [openAppDatabase] settled on, or null before
/// the database has been opened. Diagnostic only — nothing branches on it.
String? lastWebStorage;

QueryExecutor openAppDatabase() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'foss_lift',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
      // Off by default in drift, and worth having on: a browser that gains
      // OPFS support should move an IndexedDB database over rather than keep
      // it on the slower API for good.
      moveExistingIndexedDbToOpfs: true,
    );
    lastWebStorage = result.chosenImplementation.name;
    return result.resolvedExecutor;
  });
}
