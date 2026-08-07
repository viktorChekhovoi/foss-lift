/// The durability probe on a phone: there is nothing to probe.
///
/// Reached through `storage_health.dart` — never imported directly.
///
/// App storage is the app's own directory. Android does not reclaim it while
/// the app is installed, there is no exemption to request, and the only things
/// that remove it are an uninstall and the user clearing the app's data — both
/// of which are somebody deciding to. So the answer is a constant.
library;

import 'storage_health.dart';

Future<StorageHealth> probeStorageHealth() async => StorageHealth.native;
