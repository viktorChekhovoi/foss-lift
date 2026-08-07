/// The durability probe in a browser: what drift settled on, and what the
/// browser says when asked to keep it.
///
/// Reached through `storage_health.dart` — never imported directly.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../data/db_open_web.dart';
import 'storage_health.dart';

/// drift's name for the no-storage-at-all fallback.
///
/// Matched as a string because it is the name of an enum value in drift's
/// package and importing `WasmStorageImplementation` here to compare against it
/// would tie a warning message to drift's API surface. If drift ever renames
/// the value the check quietly stops matching, so the constant is named and the
/// test pins it.
const String kEphemeralWebStorage = 'inMemory';

Future<StorageHealth> probeStorageHealth() async {
  final implementation = lastWebStorage;

  // Nothing is being written down, and no amount of asking changes that.
  // Checked before the request so a browser in this state is not also asked for
  // an exemption over storage it does not have.
  if (implementation == kEphemeralWebStorage) {
    return StorageHealth(
      durability: StorageDurability.ephemeral,
      implementation: implementation,
    );
  }

  final persisted = await _requestPersistence();
  return StorageHealth(
    durability:
        persisted ? StorageDurability.durable : StorageDurability.evictable,
    implementation: implementation,
  );
}

/// Whether the origin's storage is exempt from eviction, asking for the
/// exemption if it is not already held.
///
/// `persisted()` first: the request is not free — Firefox turns it into a
/// permission prompt — and re-prompting on every launch of a site that already
/// has the exemption would be its own bug.
///
/// Never throws. `navigator.storage` is absent in an insecure context and in
/// older browsers, and a failure to ask is not different, from the app's point
/// of view, from being told no: both mean "assume it can be evicted and say
/// so".
Future<bool> _requestPersistence() async {
  try {
    final storage = web.window.navigator.storage;
    if (storage.isUndefinedOrNull) return false;
    if ((await storage.persisted().toDart).toDart) return true;
    return (await storage.persist().toDart).toDart;
  } catch (_) {
    return false;
  }
}
