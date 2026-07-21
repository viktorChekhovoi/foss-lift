import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';

/// The single app-wide database instance. Kept in its own file so both the
/// providers layer and the active-workout notifier can depend on it without
/// creating an import cycle.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
