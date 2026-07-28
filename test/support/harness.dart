// Shared test harness. Every feature test builds its world from here so the
// database wiring, the provider scope, and the live-session pump discipline are
// written once, not thirteen times.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
/// Pass [textScale] to render at a text size other than the phone's own — the
/// scale has to be injected below `MaterialApp`, where the screen's own
/// `MediaQuery` is, so a caller cannot simply wrap the result.
Widget appUnder(
  ProviderContainer container,
  Widget child, {
  double textScale = 1.0,
}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(kDefaultPalette),
        home: child,
        builder: textScale == 1.0
            ? null
            : (context, page) => MediaQuery(
                  // copyWith, not a fresh MediaQueryData — a bare one has no
                  // size, and everything downstream lays out against zero.
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(textScale)),
                  child: page!,
                ),
      ),
    );

/// Collects render-overflow errors raised while [body] runs.
///
/// Overflow is reported through `FlutterError.onError` during layout, so it has
/// to be intercepted as it happens — by the time a test ends, the render object
/// that overflowed has been disposed and says so instead of saying where.
Future<List<String>> overflowsDuring(Future<void> Function() body) async {
  final found = <String>[];
  final prev = FlutterError.onError;
  FlutterError.onError = (d) {
    final text = d.exception.toString();
    if (text.contains('overflowed')) {
      found.add(text.split('\n').first);
    } else {
      prev?.call(d);
    }
  };
  try {
    await body();
  } finally {
    FlutterError.onError = prev;
  }
  return found;
}

/// Unmounts the widget tree, cancelling any rest-countdown timer the screen
/// owns before the binding checks for pending timers as the body returns.
Future<void> stop(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

/// A few frames — enough for a dialog to open or close. Not a settle.
Future<void> frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Lets work started by a tap finish when part of it goes through the database.
///
/// Neither tool does this alone. A handler fired by a tap runs in the test's
/// *fake* zone, so its continuations only advance when the tree is pumped; the
/// drift futures it awaits only complete on the *real* event loop, which is what
/// `runAsync` turns — and pumping inside `runAsync` is forbidden. So they take
/// turns until the work is through.
Future<void> pumpThroughDatabase(WidgetTester tester, {int rounds = 12}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  }
}

/// [appUnder], but with a real router underneath.
///
/// Screens that finish by navigating — a form that pops on save — call
/// `context.pop()`, which needs a GoRouter above them. Pumping such a screen
/// bare works right up until the moment the test taps the button that leaves,
/// so anything exercising that path wants this instead.
///
/// `/today` is deliberately blank — a screen that leaves for home needs
/// somewhere to land, not a home screen to assert on.
///
/// [alsoRoutes] adds further destinations the screen under test can navigate
/// to, each rendering `at /<path>` so a test can assert *where* it went when
/// that is the point (`alsoRoutes: ['session']` → `find.text('at /session')`).
Widget routedAppUnder(
  ProviderContainer container,
  Widget child, {
  List<String> alsoRoutes = const [],
}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.build(kDefaultPalette),
        routerConfig: GoRouter(
          initialLocation: '/under-test',
          routes: [
            // Nested, so go_router builds the blank page *underneath* the
            // screen being tested. A screen that pops needs something to pop
            // back to; as a top-level route it would be the whole stack.
            GoRoute(
              path: '/',
              builder: (_, _) => const SizedBox.shrink(),
              routes: [
                GoRoute(path: 'under-test', builder: (_, _) => child),
                GoRoute(path: 'today', builder: (_, _) => const SizedBox.shrink()),
                for (final p in alsoRoutes)
                  GoRoute(
                    path: p,
                    builder: (_, _) => Scaffold(body: Text('at /$p')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
