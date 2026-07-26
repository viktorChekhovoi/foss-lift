// Shared test harness. Every feature test builds its world from here so the
// database wiring, the provider scope, and the live-session pump discipline are
// written once, not thirteen times.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/theme/app_theme.dart';

/// A fresh in-memory database, seeded exactly like a first install (the two demo
/// routines and the starter exercise library). This is the app a new user sees.
AppDatabase memoryDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// A [ProviderContainer] wired to [db]. Dispose it in `tearDown` — disposing the
/// container tears down drift's stream subscriptions.
///
/// Pass [overrides] to swap in additional fakes (e.g. a stubbed service).
ProviderContainer containerFor(
  AppDatabase db, {
  List<Override> overrides = const [],
}) =>
    ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        ...overrides,
      ],
    );

/// Wraps [child] in the app's real theme and a provider scope over [container],
/// ready to `pumpWidget`.
///
/// A live session ticks its duration every second and the rest banner counts
/// down alongside it, so a tree containing one is *never* quiet: never
/// `pumpAndSettle` it — use plain `pump()`s and end the test with [stop].
Widget appUnder(ProviderContainer container, Widget child) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(kDefaultPalette),
        home: child,
      ),
    );

/// Unmounts the widget tree, cancelling any rest-countdown timer the screen
/// owns before the binding checks for pending timers as the body returns.
Future<void> stop(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

/// A few frames — enough for a dialog to open or close. Not a settle.
Future<void> frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
