/// Opens the browser database using drift's WebAssembly executor.
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
      // Migrate existing databases when OPFS becomes available.
      moveExistingIndexedDbToOpfs: true,
    );
    lastWebStorage = result.chosenImplementation.name;
    return result.resolvedExecutor;
  });
}
