/// The phone's database: a file in the app's own documents directory.
///
/// Reached through `db_open.dart` — never imported directly, or the web build
/// gets `dart:ffi` in its import graph and stops compiling.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens `foss_lift.sqlite` on a background isolate.
///
/// The directory is resolved at open time and never stored: the iOS container
/// path contains a UUID that changes on reinstall, so a remembered absolute
/// path dangles there while working perfectly on Android.
QueryExecutor openAppDatabase() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'foss_lift.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
