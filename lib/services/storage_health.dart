/// Whether what the app stores will still be there next time.
///
/// On a phone this is not a question — app storage is not reclaimed behind your
/// back, and the answer is [StorageDurability.durable] without asking anyone.
/// In a browser it is two questions, and they are independent:
///
/// 1. **Did the database land somewhere that persists at all?** drift probes
///    the browser and settles on OPFS, IndexedDB, or — if it can reach neither
///    — memory. Memory is the bad one: nothing survives a reload, and a user
///    who logs a session there loses it without ever being told why.
/// 2. **Will the browser keep it?** Storage for an origin sits in a bucket the
///    browser may reclaim when the machine runs short of space, taking the
///    whole bucket at once. A site can ask to be exempt, and the answer is not
///    guaranteed — see [probeStorageHealth].
///
/// The two are separate because a database can be perfectly real and still be
/// evicted, which is the case this warns about most often.
library;

import 'package:flutter/foundation.dart';

import 'storage_probe_native.dart'
    if (dart.library.js_interop) 'storage_probe_web.dart' as probe;

/// How much the storage under the database can be relied on.
enum StorageDurability {
  /// It stays until something deletes it on purpose. Every phone, and a browser
  /// that granted the exemption.
  durable,

  /// Real storage, but the browser refused to exempt it, so it can be reclaimed
  /// under storage pressure. The training log is probably fine and might not be.
  evictable,

  /// Nothing is being written down. The tab is the storage, and closing it is
  /// the deletion.
  ephemeral,
}

/// What the running build found when it looked.
@immutable
class StorageHealth {
  const StorageHealth({required this.durability, this.implementation});

  /// A phone. Not asked for, not refusable, not worth a warning.
  static const StorageHealth native =
      StorageHealth(durability: StorageDurability.durable);

  final StorageDurability durability;

  /// Which storage API drift settled on, for a browser. Null off the web.
  ///
  /// Diagnostic: it names the mechanism (`opfsLocks`, `sharedIndexedDb`, …) for
  /// a bug report. Nothing branches on the string — [durability] is the
  /// decision.
  final String? implementation;

  /// Whether anything should be said to the user about this.
  bool get isFragile => durability != StorageDurability.durable;
}

/// Asks the platform where it stands, and — in a browser — asks it to do
/// better.
///
/// The request half only happens on the web, where it is
/// `navigator.storage.persist()`. Browsers answer it differently and none of
/// them promise: Chrome decides from its own engagement heuristics and usually
/// says no to a site you have just opened, Firefox asks the user, and Safari
/// grants it on the strength of recent use. So a refusal is ordinary rather
/// than a fault, which is why it is a dismissible note and not an alarm.
Future<StorageHealth> probeStorageHealth() => probe.probeStorageHealth();
