// Shared database, provider, router, and widget-test harness.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/l10n/app_localizations.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/util/locales.dart';

/// The delegates `main.dart` installs, in the same order.
///
/// Not `AppLocalizations.localizationsDelegates`: that list is generated from
/// the catalogues that exist, so a test mounting a language whose `.arb` has
/// not landed yet would silently be handed English by a different route than
/// the app takes.
const List<LocalizationsDelegate<dynamic>> kTestDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// The catalogue itself, for a test that has to name a string the app shows.
///
/// Assert against the getter, never against a re-typed English literal: the
/// test then keeps meaning something when the wording changes, and it reads the
/// words from the same place the app does.
AppLocalizations l10nFor([Locale locale = const Locale('en')]) {
  // The date symbols come with the Flutter delegates when there is a widget
  // tree; a catalogue looked up on its own has to load them, or every message
  // with a date in it throws.
  initializeDateFormatting(localeTag(locale));
  return lookupAppLocalizations(locale);
}

/// A fresh in-memory database, seeded exactly like a first install (the two demo
/// routines and the starter exercise library). This is the app a new user sees.
AppDatabase memoryDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// A [ProviderContainer] wired to [db]. Dispose it in `tearDown` — disposing the
/// container tears down drift's stream subscriptions.
///
/// Pass [overrides] to swap in additional fakes (e.g. a stubbed service).
///
/// The live session's crash snapshot is **off** unless [mirrorSession] asks for
/// it. It is a database write nobody awaits, and a widget test's fake clock
/// cannot complete one: the write hangs, and so does the `db.close()` behind it.
/// The tests that are about the snapshot switch it back on and drive it from a
/// plain `test()`, on the real event loop, where a write can finish.
ProviderContainer containerFor(
  AppDatabase db, {
  List<Override> overrides = const [],
  bool mirrorSession = false,
}) =>
    ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        if (!mirrorSession) sessionMirrorProvider.overrideWithValue(null),
        ...overrides,
      ],
    );

/// The `MediaQuery` every mount below hangs its text scale on.
///
/// The scale has to be injected *below* `MaterialApp`, where the screen's own
/// `MediaQuery` is, so a caller cannot simply wrap the result.
TransitionBuilder _scaledBy(double textScale) => (context, page) => MediaQuery(
      // copyWith, not a fresh MediaQueryData — a bare one has no size, and
      // everything downstream lays out against zero.
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: page!,
    );

/// Wraps [child] in the app's real theme and a provider scope over [container],
/// ready to `pumpWidget`.
///
/// A live session ticks its duration every second and the rest banner counts
/// down alongside it, so a tree containing one is *never* quiet: never
/// `pumpAndSettle` it — use plain `pump()`s and end the test with [stop].
///
/// [textScale] renders at a text size other than the phone's own, and [locale]
/// in a language other than English. The delegates and `supportedLocales` are
/// `main.dart`'s own, so a screen mounted here resolves its strings exactly as
/// it does in the app — including the fallback to English for a locale that
/// answers nothing.
Widget appUnder(
  ProviderContainer container,
  Widget child, {
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(kDefaultPalette),
        locale: locale,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kTestDelegates,
        home: child,
        builder: _scaledBy(textScale),
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
///
/// [scaffold] wraps the screen in one, for the tab bodies that never see a
/// `Scaffold` of their own; [textScale] and [locale] behave as in [appUnder].
Widget routedAppUnder(
  ProviderContainer container,
  Widget child, {
  List<String> alsoRoutes = const [],
  bool scaffold = false,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.build(kDefaultPalette),
        // As in [appUnder]: a screen reads its words from AppLocalizations, so
        // the delegates have to be here too or the tree cannot build.
        locale: locale,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kTestDelegates,
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
                GoRoute(
                  path: 'under-test',
                  builder: (_, _) => scaffold ? Scaffold(body: child) : child,
                ),
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
        builder: _scaledBy(textScale),
      ),
    );
