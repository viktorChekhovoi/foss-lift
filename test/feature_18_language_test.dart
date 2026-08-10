// Integration tests for features/index.html#sec18 — the app's language.
//
// The behaviour under test, straight from the spec:
//   * the app ships in English, Ukrainian, Spanish and both Portugueses; first
//     run resolves the phone's language against those five and stores the
//     answer, so the picker always has one of them selected and there is no
//     row that defers to the phone;
//   * the choice is a database write like any other setting, so changing it
//     repaints the app rather than asking for a restart;
//   * the muscle/equipment vocabulary and the names of the rows the app shipped
//     with are stored in English and rendered from a key, so the starter
//     library, the demo routines and a logged set all follow the switch — while
//     anything you named yourself keeps your name;
//   * a locale that answers nothing renders in English, never as a key;
//   * and every screen is swept in every language, because Ukrainian runs
//     appreciably longer than English and a layout that fits one need not fit
//     the other.
//
// Two of these are checks over the source rather than over a widget tree: the
// .arb files have to agree with each other key for key, and no screen may still
// hold a user-facing string of its own. Both are the kind of thing that is
// correct on the day it is written and regresses on the next screen anybody
// adds, so they are asserted mechanically.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/l10n/app_localizations.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/screens/history_screen.dart';
import 'package:foss_lift/screens/exercise_form_screen.dart';
import 'package:foss_lift/screens/language_screen.dart';
import 'package:foss_lift/screens/library_screen.dart';
import 'package:foss_lift/screens/routine_detail_screen.dart';
import 'package:foss_lift/screens/summary_screen.dart';
import 'package:foss_lift/screens/workout_detail_screen.dart';
import 'package:foss_lift/screens/workout_screen.dart';
import 'package:foss_lift/theme/app_theme.dart';
import 'package:foss_lift/util/locales.dart';
import 'package:foss_lift/util/seed_names.dart';
import 'package:foss_lift/widgets/exercise_filters.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

import 'support/harness.dart';
import 'support/screens.dart';
import 'support/seeded.dart';
import 'support/settle.dart';
import 'package:foss_lift/util/format.dart';

// ---------------------------------------------------------------------------
// The .arb files, as data
// ---------------------------------------------------------------------------

/// The catalogue for [tag] as it sits on disk, or null if there is no file.
Map<String, dynamic>? _arb(String tag) {
  final file = File('lib/l10n/app_$tag.arb');
  if (!file.existsSync()) return null;
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// The message keys of an .arb, without the `@`-prefixed metadata.
Map<String, String> _messages(Map<String, dynamic> arb) => {
      for (final e in arb.entries)
        if (!e.key.startsWith('@')) e.key: e.value as String,
    };

/// The placeholder names a message interpolates: `{unit}` and the `{count}` of
/// a plural, but not the `=1{…}` selectors around them.
Set<String> _placeholders(String message) => {
      for (final m
          in RegExp(r'\{\s*([a-zA-Z_]\w*)\s*[,}]').allMatches(_arguments(message)))
        m.group(1)!,
    };

/// [message] with every ICU branch opener consumed, so what is left is
/// arguments.
///
/// `other{{count} sets}` and `=0{None}` both open a brace that is not a
/// placeholder. Scanning the raw message for `{word}` reads `None` — and the
/// translation's `Ninguna` — as arguments, and then reports every plural in the
/// file as a mismatch because the branch bodies differ. Which they must; that
/// is what translating one is.
String _arguments(String message) => message.replaceAll(
      RegExp(r'(?:=\d+|zero|one|two|few|many|other)\s*\{'),
      '',
    );

bool _isPlural(String message) =>
    RegExp(r'\{\s*\w+\s*,\s*plural').hasMatch(message);

/// English strings a translation may legitimately leave alone: unit suffixes
/// and initialisms that are the same word in every language the app ships in.
const _sameInEveryLanguage = {'kg', 'lb', 'OK', 'AAA', 'QR', 'RGB', '1RM'};

/// Words a native reviewer decided each language really does say in English.
///
/// A gym borrows vocabulary, and a translation that insists on a native word
/// nobody uses is worse than one that borrows: a Brazilian lifter looking for
/// *leg press* does not want *pressão de pernas*. So the "did you translate
/// this" check has an escape hatch — but a deliberate one, listed per language
/// and per key, so keeping an English word is something somebody signed for
/// rather than something that slipped through.
///
/// Add to it only on a reviewer's say-so, and never to silence a string that
/// was simply missed.
///
/// `seedRoutineStartingStrength` and `seedRoutineStrongLifts5x5` are in every
/// language for the same reason and by the reviewer's decision: they are proper
/// nouns — a book's title and an app's name — and a lifter looking for the
/// programme they have heard of must find the name they have heard.
const Map<String, Set<String>> _keptInEnglish = {
  'uk': {
    'commonAppName', 'exerciseFormDemoLinkHint',
    'seedRoutineStartingStrength', 'seedRoutineStrongLifts5x5',
    'themeChannelBlue',
    'themeChannelGreen', 'themeChannelRed', 'videoSettingsHeight',
  },
  'es': {
    'clipPlayerTitle', 'commonAppName', 'commonClipCount',
    'commonEstimatedMinutes',
    'exerciseClipsTitle', 'exerciseCrunch', 'exerciseDetailDemo',
    'exerciseFormDemoLinkHint', 'exerciseFormMeasureReps',
    'itemEditorAmountReps', 'itemEditorModeReps', 'itemEditorReps',
    'itemEditorSecondsSuffix', 'itemEditorSuffixReps', 'muscleCore',
    'seedRoutineStartingStrength', 'seedRoutineStrongLifts5x5',
    'sessionGoalTimed', 'sessionRestMinus', 'sessionRestPlus',
    'settingsDeloadDaySuffix', 'shadeSetWeightSeconds',
    'summaryBackOffReps', 'summaryBackOffTime', 'summaryMinutesUnit',
    'summaryStepReps', 'summaryStepTime', 'summaryTargetReps',
    'themeChannelBlue', 'themeChannelGreen', 'themeChannelRed',
    'themePreviewRepsHeader', 'todayStatReps', 'unitSecondsShort',
    'videoSettingsHeight', 'videoSettingsMinutes', 'videoSettingsSeconds',
  },
  'pt': {
    'commonAppName', 'commonEstimatedMinutes',
    'exerciseFormDemoLinkHint', 'exerciseFormMeasureReps',
    'itemEditorAmountReps', 'itemEditorModeReps', 'itemEditorReps',
    'itemEditorSecondsSuffix', 'itemEditorSuffixReps', 'muscleCore',
    'seedDayLegs', 'seedDayPull', 'seedDayPush', 'seedRoutinePushPullLegs',
    'seedRoutineStartingStrength', 'seedRoutineStrongLifts5x5',
    'sessionGoalTimed', 'sessionRestMinus', 'sessionRestPlus',
    'settingsDeloadDaySuffix',
    'shadeSetWeightSeconds',
    'startWorkoutDeload', 'summaryBackOffReps', 'summaryBackOffTime',
    'summaryMinutesUnit', 'summaryStepReps', 'summaryStepTime',
    'summaryTargetReps', 'themeChannelBlue', 'themeChannelGreen',
    'themeChannelRed', 'themePreviewRepsHeader', 'todayStatReps',
    'todayStatVolume', 'unitSecondsShort', 'videoSettingsHeight',
    'videoSettingsMinutes', 'videoSettingsSeconds',
  },
  'pt_BR': {
    'commonAppName', 'commonEstimatedMinutes',
    'exerciseFormDemoLinkHint', 'exerciseFormMeasureReps',
    'itemEditorAmountReps', 'itemEditorModeReps', 'itemEditorReps',
    'itemEditorSecondsSuffix', 'itemEditorSuffixReps', 'muscleCore',
    'seedDayLegs', 'seedDayPull', 'seedDayPush', 'seedRoutinePushPullLegs',
    'seedRoutineStartingStrength', 'seedRoutineStrongLifts5x5',
    'sessionGoalTimed', 'sessionRestMinus', 'sessionRestPlus',
    'settingsDeloadDaySuffix',
    'shadeSetWeightSeconds',
    'summaryBackOffReps', 'summaryBackOffTime', 'summaryMinutesUnit',
    'summaryStepReps', 'summaryStepTime', 'summaryTargetReps',
    'themeChannelBlue', 'themeChannelGreen', 'themeChannelRed',
    'themePreviewRepsHeader', 'todayStatReps', 'todayStatVolume',
    'unitSecondsShort', 'videoSettingsHeight', 'videoSettingsMinutes',
    'videoSettingsSeconds',
  },
};

/// Whether [message] is punctuation and placeholders with no words of its own —
/// `{amount} {unit}`, `+{amount} {unit}`, `{group} · {count}`.
///
/// These are layout, not language. There is nothing in them to translate, and
/// demanding they differ from the English would only invite a translator to
/// change something that must not change.
bool _isFormatOnly(String message) =>
    !RegExp(r'[A-Za-z]').hasMatch(_arguments(message).replaceAll(
      RegExp(r'\{[^{}]*\}'),
      '',
    ));

// ---------------------------------------------------------------------------
// Reading a locale's strings without a widget tree
// ---------------------------------------------------------------------------

/// The strings for [locale], through the app's own delegate.
///
/// `load` hands back a `SynchronousFuture`, so awaiting it inside a
/// `testWidgets` body does not need the real event loop.
Future<AppLocalizations> _stringsFor(Locale locale) =>
    AppLocalizations.delegate.load(locale);

/// A handful of keys read through their generated getters, so the tests that
/// are about *rendering* a locale have something concrete to assert on. The
/// full key-by-key comparison is done over the .arb files instead — there is no
/// way to enumerate the getters from Dart, and 146 hand-written entries here
/// would be a second catalogue to keep in step with the first.
final Map<String, String Function(AppLocalizations)> _probes = {
  'commonCancel': (l) => l.commonCancel,
  'commonSave': (l) => l.commonSave,
  'languageTitle': (l) => l.languageTitle,
  'settingsTitle': (l) => l.settingsTitle,
  'muscleChest': (l) => l.muscleChest,
  'equipmentBarbell': (l) => l.equipmentBarbell,
  'exerciseBenchPress': (l) => l.exerciseBenchPress,
  'seedDayPush': (l) => l.seedDayPush,
};

// ---------------------------------------------------------------------------
// Mounting the app in a language
// ---------------------------------------------------------------------------

/// The app root, reduced to the parts a language test needs: it watches the
/// stored choice through [activeLocaleProvider], so writing `Settings.localeTag`
/// repaints the tree exactly as it does in `main.dart`.
class _LocalisedApp extends ConsumerWidget {
  const _LocalisedApp(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      locale: ref.watch(activeLocaleProvider),
      supportedLocales: kSupportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.build(kDefaultPalette),
      home: Scaffold(body: child),
    );
  }
}

Widget _liveApp(ProviderContainer container, Widget child) =>
    UncontrolledProviderScope(
      container: container,
      child: _LocalisedApp(child),
    );

/// Writes [tag] and pumps until the tree has been rebuilt against it.
Future<void> _switchTo(
  WidgetTester tester,
  AppDatabase db,
  ProviderContainer container,
  String tag,
) async {
  await tester.runAsync(() => db.setLocaleTag(tag));
  // The write lands on the real event loop and the drift stream emits there;
  // the widgets watching it only advance when the tree is pumped. Neither tool
  // does this alone — see pumpThroughDatabase.
  await pumpThroughDatabase(tester);
  await pumpUntil(
      tester, () => container.read(activeLocaleProvider) == localeFromTag(tag));
  await tester.pump();
}

/// The language a fresh install lands on, given the locale the test host is
/// running under. Written out rather than hard-coded to `en`: the resolution is
/// the app's own, and asserting against it is asserting that first run stores
/// what the phone asked for.
String _firstRunTag() => localeTag(
      resolveLocale(null, WidgetsBinding.instance.platformDispatcher.locales),
    );

// ---------------------------------------------------------------------------
// The hard-coded-string scan
// ---------------------------------------------------------------------------

/// Where a user-facing string reaches the screen: the `Text` widget itself, the
/// `message:` a `Tooltip` carries, and the `label:`/`hint:`/`title:` arguments
/// the project's own widgets take (`SectionLabel`, `ScreenHeader`,
/// `SettingRow`, `BuilderField`, `builderInput`, `FilterFacetButton`, the
/// `askNote`/`askWeight`/`askBar` dialogs). An `AppBar` title and a `SnackBar`
/// content are both a `Text`, so both are covered by the first alternative.
final _stringSite = RegExp(
  r'''(?:\bText\(|\bmessage:|\blabel:|\bhint:|\btitle:|\bfallback:|\bdefaultLabel:|\bbuilderInput\(|\btooltip:)\s*(?:const\s+)?(?:Text\(\s*)?(?:'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)")''',
);

final _interpolation = RegExp(r'\$\{[^}]*\}|\$\w+');

/// Whether [literal] is a string somebody reads, rather than punctuation or a
/// value spliced in from data. `·`, `—`, `%` and `:` are separators; `'$kg'` is
/// a number.
bool _isUserFacing(String literal) =>
    RegExp(r'[A-Za-z]').hasMatch(literal.replaceAll(_interpolation, ''));

/// Every .dart file under [dir], recursively.
List<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  late AppDatabase db;
  ProviderContainer? container;

  setUp(() => db = memoryDb());
  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  // -------------------------------------------------------------------------

  group('which language the app renders in', () {
    test('five languages ship, English first', () {
      expect(kSupportedLocales, hasLength(5));
      expect(kSupportedLocales.first, const Locale('en'),
          reason: 'English is the fallback, and the fallback is the first');
      expect(kSupportedLocales, contains(const Locale('uk')));
      expect(kSupportedLocales, contains(const Locale('es')));
      expect(kSupportedLocales, contains(const Locale('pt')));
      expect(kSupportedLocales, contains(const Locale('pt', 'BR')));
    });

    test('every language names itself, and only itself', () {
      for (final locale in kSupportedLocales) {
        expect(kLanguageNames[localeTag(locale)], isNotNull,
            reason: '${localeTag(locale)} has no name to show in the picker');
      }
      expect(kLanguageNames, hasLength(kSupportedLocales.length),
          reason: 'a name for a language we do not ship is a dead row');
    });

    test('a tag round-trips through the locale it names', () {
      for (final locale in kSupportedLocales) {
        expect(localeFromTag(localeTag(locale)), locale);
      }
      expect(localeTag(const Locale('pt', 'BR')), 'pt_BR');
      expect(localeTag(const Locale('uk')), 'uk');
      expect(localeFromTag('pt_BR'), const Locale('pt', 'BR'));
      expect(localeFromTag(null), isNull);
      expect(localeFromTag('fr'), isNull,
          reason: 'a language we do not ship is not a locale we can store');
    });

    test('a stored choice wins over the phone', () {
      expect(resolveLocale('uk', const [Locale('es')]), const Locale('uk'));
      expect(resolveLocale('en', const [Locale('uk')]), const Locale('en'),
          reason: 'choosing English on a Ukrainian phone has to stick');
      expect(resolveLocale('pt_BR', const [Locale('pt')]),
          const Locale('pt', 'BR'));
    });

    test('a stored tag for a language we no longer ship is as good as unset',
        () {
      // The shape a removed language leaves behind in Settings.
      expect(resolveLocale('fr', const [Locale('uk')]), const Locale('uk'),
          reason: 'it falls through to the phone rather than to English');
      expect(resolveLocale('fr', const [Locale('fr')]), const Locale('en'));
    });

    test('a Brazilian phone gets Brazilian, and everyone else European', () {
      expect(resolveLocale(null, const [Locale('pt', 'BR')]),
          const Locale('pt', 'BR'));
      expect(resolveLocale(null, const [Locale('pt', 'PT')]),
          const Locale('pt'));
      expect(resolveLocale(null, const [Locale('pt')]), const Locale('pt'));
      expect(resolveLocale(null, const [Locale('pt', 'AO')]),
          const Locale('pt'),
          reason: 'an Angolan phone is closer to Lisbon than to São Paulo');
    });

    test('a phone we cannot answer, or one that says nothing, gets English',
        () {
      expect(resolveLocale(null, const [Locale('fr')]), const Locale('en'));
      expect(resolveLocale(null, const [Locale('de'), Locale('fr')]),
          const Locale('en'));
      expect(resolveLocale(null, const []), const Locale('en'));
      expect(resolveLocale(null, null), const Locale('en'));
    });

    test('the phone list is walked in preference order', () {
      // Second choice answered, first not: the phone's own ranking decides.
      expect(resolveLocale(null, const [Locale('de'), Locale('es')]),
          const Locale('es'));
    });

    test('first run stores the phone\'s answer as a real choice', () async {
      // Nothing asks on first run — but the answer is written down rather than
      // deferred to for ever, so the picker has a row selected and changing
      // the phone's language later leaves the app where it is.
      container = containerFor(db);
      final tag = await readWhen(
          container!, localeTagProvider, (v) => v.value != null);
      expect(tag.value, _firstRunTag());
      expect(await db.watchLocaleTag().first, tag.value,
          reason: 'the resolution is persisted, not recomputed every launch');
    });

    test('a language already chosen is not overwritten on the next launch',
        () async {
      await db.setLocaleTag('uk');
      container = containerFor(db);
      final tag =
          await readWhen(container!, localeTagProvider, (v) => v.value != null);
      expect(tag.value, 'uk');
      expect(await db.watchLocaleTag().first, 'uk');
    });

    test('setLocaleTag round-trips', () async {
      await db.setLocaleTag('uk');
      expect(await db.watchLocaleTag().first, 'uk');
      await db.setLocaleTag('pt_BR');
      expect(await db.watchLocaleTag().first, 'pt_BR');
    });
  });

  // -------------------------------------------------------------------------

  group('the five catalogues agree with each other', () {
    final english = _messages(_arb('en')!);

    for (final locale in kSupportedLocales.where((l) => l != const Locale('en'))) {
      final tag = localeTag(locale);

      test('$tag has a catalogue on disk', () {
        expect(_arb(tag), isNotNull,
            reason: 'lib/l10n/app_$tag.arb is missing, so ${kLanguageNames[tag]} '
                'renders entirely in English');
      });

      test('$tag answers every key English defines', () {
        final theirs = _messages(_arb(tag)!);
        final missing = english.keys.where((k) => !theirs.containsKey(k));
        expect(missing, isEmpty,
            reason: '$tag has not answered: ${missing.join(", ")}');
      });

      test('$tag adds no key English does not have', () {
        final theirs = _messages(_arb(tag)!);
        final extra = theirs.keys.where((k) => !english.containsKey(k));
        expect(extra, isEmpty,
            reason: '$tag defines strings nothing reads: ${extra.join(", ")}');
      });

      test('$tag interpolates the same placeholders, key for key', () {
        final theirs = _messages(_arb(tag)!);
        final wrong = <String>[];
        for (final entry in english.entries) {
          final mine = theirs[entry.key];
          if (mine == null) continue;
          final want = _placeholders(entry.value);
          final got = _placeholders(mine);
          if (want.length != got.length || !want.containsAll(got)) {
            wrong.add('${entry.key}: want $want, got $got');
          }
        }
        expect(wrong, isEmpty,
            reason: 'a placeholder dropped in translation renders as literal '
                'braces: ${wrong.join("; ")}');
      });

      test('$tag keeps a plural message plural', () {
        final theirs = _messages(_arb(tag)!);
        final flattened = [
          for (final entry in english.entries)
            if (_isPlural(entry.value) &&
                theirs[entry.key] != null &&
                !_isPlural(theirs[entry.key]!))
              entry.key,
        ];
        expect(flattened, isEmpty,
            reason: 'these lost their plural form: ${flattened.join(", ")}');
      });

      test('$tag translates rather than copying the English', () {
        final theirs = _messages(_arb(tag)!);
        final kept = _keptInEnglish[tag] ?? const <String>{};
        final untouched = [
          for (final entry in english.entries)
            if (theirs[entry.key] == entry.value &&
                !_sameInEveryLanguage.contains(entry.value) &&
                !kept.contains(entry.key) &&
                !_isFormatOnly(entry.value) &&
                RegExp(r'[A-Za-z]').hasMatch(entry.value))
              entry.key,
        ];
        expect(untouched, isEmpty,
            reason: '$tag left these as the English string: '
                '${untouched.join(", ")}');
      });
    }

    test('a starter movement has a key, and a key has a string', () {
      // The two ends of the seeded-name lookup, checked against each other: a
      // movement with no key cannot follow a language switch, and a key with no
      // string falls back to English forever.
      final keys = {
        ...kSeedExerciseKeys.values,
        ...kSeedRoutineKeys.values,
        ...kSeedWorkoutKeys.values,
      };
      expect(keys, hasLength(kSeedExerciseKeys.length +
          kSeedRoutineKeys.length +
          kSeedWorkoutKeys.length),
          reason: 'two rows sharing a key would translate as each other');

      // And every one of those keys has words behind it: `seededName` falls
      // back to the stored English for a key it does not know, so a key with no
      // string is invisible until somebody who does not read English opens the
      // library.
      final english = l10nFor();
      final unbacked = keys
          .where((k) => seededName(english, k, '\u0000none') == '\u0000none')
          .toList()
        ..sort();
      expect(unbacked, isEmpty,
          reason: 'these seed keys have no string behind them: '
              '${unbacked.join(", ")}');
    });
  });

  // -------------------------------------------------------------------------

  group('the picker', () {
    Future<void> pumpPicker(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      container = containerFor(db);
      await tester.pumpWidget(_liveApp(container!, const LanguageScreen()));
      await tester.pump();
      // First run resolves the phone's language and writes it, so the screen
      // has a database round trip to wait for before a row is selected.
      await pumpThroughDatabase(tester);
    }

    testWidgets('it offers the five languages and nothing else', (tester) async {
      await pumpPicker(tester);

      for (final locale in kSupportedLocales) {
        expect(find.text(kLanguageNames[localeTag(locale)]!), findsOneWidget,
            reason: '${localeTag(locale)} has no row to tap');
      }
      expect(find.byIcon(Icons.radio_button_unchecked).evaluate().length +
              find.byIcon(Icons.radio_button_checked).evaluate().length,
          kSupportedLocales.length,
          reason: 'the five, and no row that defers to the phone');

      await stop(tester);
    });

    testWidgets('a fresh install already has one of them selected',
        (tester) async {
      await pumpPicker(tester);

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget,
          reason: 'exactly one row is selected, and it is a language');
      final selected = tester.widget<Text>(find.descendant(
        of: find.ancestor(
          of: find.byIcon(Icons.radio_button_checked),
          matching: find.byType(Row),
        ),
        matching: find.byType(Text),
      ));
      expect(selected.data, kLanguageNames[_firstRunTag()],
          reason: 'the row selected is what first run resolved the phone to');

      await stop(tester);
    });

    testWidgets('tapping a language writes its tag', (tester) async {
      await pumpPicker(tester);

      await tester.tap(find.text(kLanguageNames['es']!));
      await pumpUntil(
          tester, () => container!.read(localeTagProvider).value == 'es');

      // Read back on the real event loop: opening a fresh drift stream is a
      // query, and a query only runs when the loop turns.
      expect(await tester.runAsync(() => db.watchLocaleTag().first), 'es',
          reason: 'the choice is a settings write like any other');

      await stop(tester);
    });

    testWidgets('and the choice survives leaving the screen', (tester) async {
      await tester.runAsync(() => db.setLocaleTag('uk'));
      await pumpPicker(tester);

      await tester.tap(find.text(kLanguageNames['pt_BR']!));
      await pumpUntil(
          tester, () => container!.read(localeTagProvider).value == 'pt_BR');

      expect(await tester.runAsync(() => db.watchLocaleTag().first), 'pt_BR',
          reason: 'a language is never unset — only replaced by another');

      await stop(tester);
    });
  });

  // -------------------------------------------------------------------------

  group('changing the language repaints at once', () {
    testWidgets('the screen you are on re-reads, with no restart',
        (tester) async {
      container = containerFor(db);
      await tester.pumpWidget(_liveApp(container!, const LanguageScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final en = await _stringsFor(const Locale('en'));
      final uk = await _stringsFor(const Locale('uk'));
      expect(uk.languageTitle, isNot(en.languageTitle),
          reason: 'if the two agree, this test proves nothing');
      expect(find.text(en.languageTitle), findsWidgets);

      await _switchTo(tester, db, container!, 'uk');

      expect(find.text(uk.languageTitle), findsWidgets,
          reason: 'the tree rebuilt against the new locale');
      expect(find.text(en.languageTitle), findsNothing,
          reason: 'and the English is gone, not layered underneath');

      await stop(tester);
    });

    testWidgets('and switching back is the same write in reverse',
        (tester) async {
      await tester.runAsync(() => db.setLocaleTag('uk'));
      container = containerFor(db);
      await tester.pumpWidget(_liveApp(container!, const LanguageScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final es = await _stringsFor(const Locale('es'));
      await _switchTo(tester, db, container!, 'es');
      expect(find.text(es.languageTitle), findsWidgets);

      await stop(tester);
    });
  });

  // -------------------------------------------------------------------------

  group('muscle groups and equipment', () {
    testWidgets('the filter buttons read in the chosen language',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      container = containerFor(db);
      await tester.pumpWidget(_liveApp(container!, const LibraryScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final uk = await _stringsFor(const Locale('uk'));
      await _switchTo(tester, db, container!, 'uk');

      // Open the muscle sheet and read the ticks.
      await tester.tap(find.byKey(filterButtonKey('muscle')));
      await frames(tester);
      for (final group in kMuscleGroups) {
        expect(find.text(muscleGroupLabel(uk, group)), findsWidgets,
            reason: '$group is still English on the filter sheet');
      }

      await stop(tester);
    });

    testWidgets('the exercise form offers them in the chosen language',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      container = containerFor(db);
      await tester.pumpWidget(_liveApp(container!, const ExerciseFormScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final es = await _stringsFor(const Locale('es'));
      await _switchTo(tester, db, container!, 'es');

      for (final group in kMuscleGroups) {
        expect(find.text(muscleGroupLabel(es, group)), findsWidgets,
            reason: '$group is still English on the exercise form');
      }
      for (final kind in kEquipmentTypes) {
        expect(find.text(equipmentLabel(es, kind)), findsWidgets,
            reason: '$kind is still English on the exercise form');
      }

      await stop(tester);
    });

    testWidgets('but the stored vocabulary stays English', (tester) async {
      // The wire format leans on it: a routine code carries an index into
      // kMuscleGroups, so a translated stored value would make the same code
      // mean different things on different phones.
      container = containerFor(db);
      await tester.pumpWidget(_liveApp(container!, const LibraryScreen()));
      await tester.pump();
      await _switchTo(tester, db, container!, 'uk');

      final bench = await tester.runAsync(
          () => exerciseNamed(db, 'Bench Press'));
      expect(bench!.muscleGroup, 'Chest',
          reason: 'the row is untouched by a language switch');
      expect(bench.equipment, 'Barbell');
      expect(kMuscleGroups, contains('Chest'),
          reason: 'and the vocabulary itself is still the English one');

      await stop(tester);
    });

    test('a word of your own is shown as you wrote it', () async {
      final uk = await _stringsFor(const Locale('uk'));
      expect(muscleGroupLabel(uk, 'Forearms'), 'Forearms',
          reason: 'an unrecognised value is the user\'s own word');
      expect(equipmentLabel(uk, 'Sandbag'), 'Sandbag');
    });
  });

  // -------------------------------------------------------------------------

  group('the starter library', () {
    testWidgets('a seeded movement reads in the chosen language, everywhere',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late int pushId;
      await tester.runAsync(() async {
        container = containerFor(db);
        pushId = await workoutIdNamed(db, 'Push');
      });

      final uk = await _stringsFor(const Locale('uk'));
      final es = await _stringsFor(const Locale('es'));
      final benchUk = seededName(uk, 'bench_press', 'Bench Press');
      final benchEs = seededName(es, 'bench_press', 'Bench Press');
      expect(benchUk, isNot('Bench Press'),
          reason: 'if Ukrainian keeps the English name, this proves nothing');

      // In the library. Searched for rather than scrolled to: the list is
      // grouped alphabetically and built lazily, so Chest is well below the
      // fold — and typing the *Ukrainian* name is the thing a Ukrainian user
      // would actually do, which is worth asserting in its own right.
      await tester.pumpWidget(_liveApp(container!, const LibraryScreen()));
      await tester.pump();
      await _switchTo(tester, db, container!, 'uk');
      await tester.enterText(find.byType(TextField).first, benchUk);
      await tester.pump();
      expect(find.text(benchUk), findsWidgets,
          reason: 'the library renders from the seed key, not from the row, '
              'and finds it by the name it is showing');
      expect(find.text('Bench Press'), findsNothing);

      // In a workout.
      await tester.pumpWidget(
          _liveApp(container!, WorkoutDetailScreen(workoutId: pushId)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(benchUk), findsWidgets,
          reason: "a training day's slots follow the language too");

      // And switching again renames it again.
      await _switchTo(tester, db, container!, 'es');
      expect(find.text(benchEs), findsWidgets);

      await stop(tester);
    });

    testWidgets('and on the live board', (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        container = containerFor(db);
        await container!.read(activeWorkoutProvider.notifier).start(
            workoutId: await workoutIdNamed(db, 'Push'), name: 'Push');
      });

      final uk = await _stringsFor(const Locale('uk'));
      await tester.pumpWidget(_liveApp(container!, const WorkoutScreen()));
      await tester.pump();
      await _switchTo(tester, db, container!, 'uk');

      expect(find.text(seededName(uk, 'bench_press', 'Bench Press')),
          findsWidgets,
          reason: 'the board names the movement you are under');

      container!.read(activeWorkoutProvider.notifier).discard();
      await stop(tester);
    });

    testWidgets('a movement you added keeps the name you gave it',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        container = containerFor(db);
        await db.createExercise(
            name: 'Zercher Squat', muscles: MuscleMap.single('Legs'), equipment: 'Barbell');
      });

      await tester.pumpWidget(_liveApp(container!, const LibraryScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(find.byType(TextField).first, 'Zercher');
      await tester.pump();
      for (final tag in ['uk', 'es', 'pt', 'pt_BR', 'en']) {
        await _switchTo(tester, db, container!, tag);
        expect(find.text('Zercher Squat'), findsWidgets,
            reason: 'a movement with no seed key has only one name — $tag');
      }

      await stop(tester);
    });

    testWidgets('the English name is what the database still holds',
        (tester) async {
      container = containerFor(db);
      await tester.pumpWidget(_liveApp(container!, const LibraryScreen()));
      await tester.pump();
      await _switchTo(tester, db, container!, 'uk');

      final bench =
          await tester.runAsync(() => exerciseNamed(db, 'Bench Press'));
      expect(bench!.name, 'Bench Press',
          reason: 'the canonical name is what a shared routine code carries');
      expect(bench.seedKey, 'bench_press');

      await stop(tester);
    });
  });

  // -------------------------------------------------------------------------

  group('what a slot is aiming at', () {
    /// Puts a single slot in the Push day, built from [draft], and returns the
    /// day's id — the workout detail screen renders one row per slot, so one
    /// slot makes the assertion unambiguous.
    Future<int> onlySlot(ItemDraft Function(Exercise) draft,
        {String exercise = 'Bench Press'}) async {
      final push = await workoutIdNamed(db, 'Push');
      await db.replaceWorkoutItems(
        push,
        itemCompanions([draft(await exerciseNamed(db, exercise))],
            workoutId: push),
      );
      return push;
    }

    testWidgets('a to-failure slot says so in the chosen language',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late int push;
      await tester.runAsync(() async {
        container = containerFor(db);
        push = await onlySlot((e) => ItemDraft.forExercise(e)
          ..sets = 3
          ..toFailure = true);
      });

      final uk = await _stringsFor(const Locale('uk'));
      await tester
          .pumpWidget(_liveApp(container!, WorkoutDetailScreen(workoutId: push)));
      await tester.pump();
      await _switchTo(tester, db, container!, 'uk');

      expect(find.text(uk.targetSetsReps(3, uk.targetFailure)), findsOneWidget,
          reason: 'the target is words, so it follows the language');
      expect(find.textContaining('Failure'), findsNothing);

      await stop(tester);
    });

    testWidgets('and a held slot counts its seconds in the chosen language',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late int push;
      await tester.runAsync(() async {
        container = containerFor(db);
        push = await onlySlot(
            (e) => ItemDraft.forExercise(e)
              ..sets = 3
              ..holdSeconds = 45,
            exercise: 'Plank');
      });

      final uk = await _stringsFor(const Locale('uk'));
      await tester
          .pumpWidget(_liveApp(container!, WorkoutDetailScreen(workoutId: push)));
      await tester.pump();
      await _switchTo(tester, db, container!, 'uk');

      expect(
          find.text(uk.targetSetsReps(3, uk.unitSecondsShort('45'))),
          findsOneWidget,
          reason: 'the seconds abbreviation is a word in every language');

      await stop(tester);
    });
  });

  // -------------------------------------------------------------------------

  group('the demo routines', () {
    testWidgets('a routine and its training days read in the chosen language',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      late int routineId;
      await tester.runAsync(() async {
        container = containerFor(db);
        routineId = (await routineNamed(db)).id;
      });

      final uk = await _stringsFor(const Locale('uk'));
      await tester.pumpWidget(
          _liveApp(container!, RoutineDetailScreen(routineId: routineId)));
      await tester.pump();
      await _switchTo(tester, db, container!, 'uk');

      expect(find.text(seededName(uk, 'push_pull_legs', kPpl)), findsWidgets,
          reason: 'the programme names itself in Ukrainian');
      for (final day in ['push', 'pull', 'legs']) {
        expect(find.text(seededName(uk, day, day)), findsWidgets,
            reason: 'the $day day still reads English');
      }

      await stop(tester);
    });

    testWidgets('renaming a training day makes the name yours in every language',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      late int routineId;
      await tester.runAsync(() async {
        container = containerFor(db);
        routineId = (await routineNamed(db)).id;
        await db.renameWorkout(
            await workoutIdNamed(db, 'Push'), 'Chest & Tris');
      });

      // The rename is what clears the key — asserted on the row, because that
      // is the mechanism the name-keeping rests on.
      final renamed = await tester.runAsync(() async {
        final all = await db.workoutsForRoutine(routineId);
        return all.firstWhere((w) => w.name == 'Chest & Tris');
      });
      expect(renamed!.seedKey, isNull,
          reason: 'a day you have named no longer follows the language');

      await tester.pumpWidget(
          _liveApp(container!, RoutineDetailScreen(routineId: routineId)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      for (final tag in ['uk', 'pt_BR', 'en']) {
        await _switchTo(tester, db, container!, tag);
        expect(find.text('Chest & Tris'), findsWidgets, reason: 'at $tag');
      }

      await stop(tester);
    });

    test('every seeded programme and training day renders from its key',
        () async {
      // The three beginner programmes and the workout days they share. A key
      // with nothing behind it renders as the stored English for ever, which
      // is exactly what the seed keys exist to avoid.
      const keys = [
        'starting_strength',
        'stronglifts_5x5',
        'full_body_3x',
        'workout_a',
        'workout_b',
        'workout_c',
      ];

      for (final locale in kSupportedLocales) {
        final l10n = await _stringsFor(locale);
        for (final key in keys) {
          expect(seededName(l10n, key, '\u0000none'), isNot('\u0000none'),
              reason: '${localeTag(locale)}: $key has no string behind it');
        }
      }
    });

    test('the seeded rows carry those keys', () async {
      for (final entry in const {
        'Starting Strength': 'starting_strength',
        'StrongLifts 5x5': 'stronglifts_5x5',
        'Full Body 3x': 'full_body_3x',
      }.entries) {
        final routine = await routineNamed(db, entry.key);
        expect(routine.seedKey, entry.value,
            reason: '${entry.key} cannot follow a language switch');
        final days = await db.workoutsForRoutine(routine.id);
        expect(
            days.map((w) => w.seedKey),
            days
                .map((w) => 'workout_${w.name.split(' ').last.toLowerCase()}')
                .toList(),
            reason: '${entry.key}: the training days share one set of keys');
      }
    });

    test('a programme named after its author reads the same in every language',
        () async {
      // "Starting Strength" and "StrongLifts 5x5" are proper nouns — the title
      // of a book and the name of an app. Translating them would send someone
      // looking for the programme they have heard of to a name that matches
      // nothing they can search for.
      for (final key in ['starting_strength', 'stronglifts_5x5']) {
        final english = seededName(l10nFor(), key, key);
        for (final locale in kSupportedLocales) {
          expect(seededName(await _stringsFor(locale), key, key), english,
              reason: '${localeTag(locale)} translated a proper noun: $key');
        }
      }
      expect(seededName(l10nFor(), 'starting_strength', '?'),
          'Starting Strength');
      expect(seededName(l10nFor(), 'stronglifts_5x5', '?'), 'StrongLifts 5x5');
    });

    testWidgets('a beginner programme reads in the chosen language',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      late int routineId;
      await tester.runAsync(() async {
        container = containerFor(db);
        routineId = (await routineNamed(db, 'Full Body 3x')).id;
      });

      final uk = await _stringsFor(const Locale('uk'));
      await tester.pumpWidget(
          _liveApp(container!, RoutineDetailScreen(routineId: routineId)));
      await tester.pump();
      await _switchTo(tester, db, container!, 'uk');

      expect(find.text(seededName(uk, 'full_body_3x', 'Full Body 3x')),
          findsWidgets,
          reason: 'the programme names itself in Ukrainian');
      for (final day in ['workout_a', 'workout_b', 'workout_c']) {
        expect(find.text(seededName(uk, day, day)), findsWidgets,
            reason: '$day still reads English');
      }

      await stop(tester);
    });

    test('renaming a routine clears its key too', () async {
      final routine = await routineNamed(db);
      expect(routine.seedKey, 'push_pull_legs');
      await db.updateRoutineMeta(routine.id,
          name: 'My Split', color: 'FF6A3D', restSeconds: 120);
      final after = await routineNamed(db, 'My Split');
      expect(after.seedKey, isNull);
      final uk = await _stringsFor(const Locale('uk'));
      expect(seededName(uk, after.seedKey, after.name), 'My Split');
    });
  });

  // -------------------------------------------------------------------------

  group('history', () {
    /// A finished session: one seeded movement and one of your own.
    Future<int> logSession(AppDatabase db) => db.saveSession(
          routineId: null,
          workoutId: null,
          name: 'Push',
          seedKey: 'push',
          startedAt: DateTime(2026, 3, 14, 18),
          endedAt: DateTime(2026, 3, 14, 19),
          durationSeconds: 3600,
          totalVolume: 4200,
          sets: [
            SessionSetsCompanion.insert(
              sessionId: 0,
              exerciseName: 'Bench Press',
              exerciseSeedKey: const Value('bench_press'),
              setNumber: 1,
              weight: const Value(82.5),
              reps: const Value(5),
              done: const Value(true),
            ),
            SessionSetsCompanion.insert(
              sessionId: 0,
              exerciseName: 'Zercher Squat',
              setNumber: 1,
              weight: const Value(60),
              reps: const Value(8),
              done: const Value(true),
            ),
          ],
        );

    testWidgets('a session logged in English reads in Ukrainian afterwards',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        container = containerFor(db);
        await logSession(db);
      });

      final uk = await _stringsFor(const Locale('uk'));
      await tester.pumpWidget(_liveApp(container!, const HistoryScreen()));
      await tester.pump();
      await _switchTo(tester, db, container!, 'uk');

      expect(find.text(seededName(uk, 'push', 'Push')), findsWidgets,
          reason: 'the session names its training day in the app language');
      expect(find.text('Push'), findsNothing);

      await stop(tester);
    });

    testWidgets('and so does the movement each set was logged under',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      late int sessionId;
      await tester.runAsync(() async {
        container = containerFor(db);
        sessionId = await logSession(db);
      });

      final uk = await _stringsFor(const Locale('uk'));
      await tester.pumpWidget(
          _liveApp(container!, SummaryScreen(sessionId: sessionId)));
      await tester.pump();
      await _switchTo(tester, db, container!, 'uk');

      expect(find.text(seededName(uk, 'bench_press', 'Bench Press')),
          findsWidgets,
          reason: 'history stores the seed key beside the name for this');
      expect(find.text('Zercher Squat'), findsWidgets,
          reason: 'a movement of your own reads as whatever you called it');

      await stop(tester);
    });

    testWidgets('the logged rows themselves are untouched', (tester) async {
      late int sessionId;
      await tester.runAsync(() async {
        container = containerFor(db);
        sessionId = await logSession(db);
        await db.setLocaleTag('uk');
      });

      final sets = await tester.runAsync(() => db.setsForSession(sessionId));
      expect(sets!.first.exerciseName, 'Bench Press',
          reason: 'the denormalised name is the English one, always');
      expect(sets.first.exerciseSeedKey, 'bench_press');
      expect(sets.last.exerciseSeedKey, isNull);
    });
  });

  // -------------------------------------------------------------------------

  group('a locale that answers nothing', () {
    test('every shipped language loads through the app delegate', () {
      for (final locale in kSupportedLocales) {
        expect(AppLocalizations.delegate.isSupported(locale), isTrue,
            reason: '${localeTag(locale)} is offered in the picker but the '
                'delegate cannot load it');
      }
    });

    test('a string the locale does not answer renders in English', () async {
      // A half-finished locale is a mixed-language screen, which is usable. A
      // screen of `settings_language_title` is not.
      final english = _messages(_arb('en')!);
      final en = await _stringsFor(const Locale('en'));

      for (final locale in kSupportedLocales) {
        final tag = localeTag(locale);
        final theirs = _messages(_arb(tag) ?? const {});
        final strings = await _stringsFor(locale);
        for (final probe in _probes.entries) {
          final got = probe.value(strings);
          expect(got, isNotEmpty, reason: '$tag: ${probe.key} is blank');
          expect(got, isNot(probe.key),
              reason: '$tag renders ${probe.key} as its own key');
          if (!theirs.containsKey(probe.key)) {
            expect(got, probe.value(en),
                reason: '$tag does not answer ${probe.key}, so it must fall '
                    'back to the English string');
          } else {
            expect(got, theirs[probe.key],
                reason: '$tag renders ${probe.key} from its own catalogue');
          }
        }
        expect(english.keys, contains(_probes.keys.first));
      }
    });

    test('a language we do not ship is rendered in English, not refused',
        () async {
      // What a French phone gets: resolveLocale sends it to English before the
      // delegate is ever asked.
      final chosen = resolveLocale(null, const [Locale('fr')]);
      final strings = await _stringsFor(chosen);
      final en = await _stringsFor(const Locale('en'));
      expect(strings.languageTitle, en.languageTitle);
    });
  });

  // -------------------------------------------------------------------------

  group('every screen, in every language', () {
    // The same sweep the text-size feature runs, over the five locales as well
    // as the scales — Ukrainian and Portuguese run appreciably longer than
    // English, and a fixed-width control that fits one need not fit the other.
    for (final locale in kSupportedLocales) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('${localeTag(locale)} @ $scale', (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          container = containerFor(db);

          final broken = <String>[];
          for (final entry in kSweepScreens.entries) {
            final found = await overflowsDuring(() async {
              await tester.pumpWidget(routedAppUnder(container!, entry.value(),
                  scaffold: true, textScale: scale, locale: locale));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
            });
            if (found.isNotEmpty) {
              broken.add('${entry.key}: ${found.toSet().join(" | ")}');
            }
          }

          expect(broken, isEmpty,
              reason: '${localeTag(locale)} at $scale×: ${broken.join(" ;; ")}');
          await stop(tester);
        });
      }
    }

    for (final locale in kSupportedLocales) {
      testWidgets('id screens in ${localeTag(locale)}', (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        late Map<String, Widget> targets;
        await tester.runAsync(() async {
          container = containerFor(db);
          final routineId = (await routineNamed(db)).id;
          final workoutId = await workoutIdNamed(db, 'Push');
          targets = idSweepScreens(
            exerciseId: (await exerciseNamed(db, 'Bench Press')).id,
            workoutId: workoutId,
            routineId: routineId,
            sessionId: await db.saveSession(
              routineId: routineId,
              workoutId: workoutId,
              name: 'Push',
              seedKey: 'push',
              startedAt: DateTime.now().subtract(const Duration(minutes: 40)),
              endedAt: DateTime.now(),
              durationSeconds: 2400,
              totalVolume: 4200,
              sets: const [],
            ),
          );
        });

        final broken = <String>[];
        for (final target in targets.entries) {
          final found = await overflowsDuring(() async {
            // 2.0 only: overflow only grows with scale, and the id screens are
            // already swept at every scale in English by feature 15.
            await tester.pumpWidget(routedAppUnder(container!, target.value,
                scaffold: true, textScale: 2.0, locale: locale));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          });
          expect(find.byType(Text), findsWidgets,
              reason: '${target.key} rendered nothing to overflow');
          if (found.isNotEmpty) {
            broken.add('${target.key}: ${found.toSet().join(" | ")}');
          }
        }

        expect(broken, isEmpty,
            reason: '${localeTag(locale)} at 2.0×: ${broken.join(" ;; ")}');
        await stop(tester);
      });
    }
  });

  // -------------------------------------------------------------------------

  group('nothing is left hard-coded', () {
    test('no screen or widget holds a user-facing string of its own', () {
      final offenders = <String>[];
      for (final file in [
        ..._dartFiles('lib/screens'),
        ..._dartFiles('lib/widgets'),
      ]) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final match in _stringSite.allMatches(lines[i])) {
            final literal = match.group(1) ?? match.group(2)!;
            if (!_isUserFacing(literal)) continue;
            offenders.add('${file.path}:${i + 1}  $literal');
          }
        }
      }

      // `fail` rather than `expect(…, isEmpty)`: the matcher elides a long
      // list, and the whole point of this one is that the failure *is* the
      // work list.
      if (offenders.isNotEmpty) {
        fail('${offenders.length} user-facing strings still live in the widget '
            'tree rather than in lib/l10n/app_en.arb:\n'
            '${offenders.join("\n")}');
      }
    });
  });

  // -------------------------------------------------------------------------

  group('dates and numbers follow the language', () {
    setUpAll(() async {
      await initializeDateFormatting('uk');
      await initializeDateFormatting('en');
    });

    test('a weight is written with the language\'s decimal separator', () {
      // 82,5 kg on a Ukrainian phone, 82.5 kg on an English one.
      final previous = Intl.defaultLocale;
      addTearDown(() => Intl.defaultLocale = previous);

      Intl.defaultLocale = 'en';
      expect(fmtWeight(82.5), '82.5');

      Intl.defaultLocale = 'uk';
      expect(fmtWeight(82.5), '82,5',
          reason: 'the separator is a property of the language, not of Dart');
    });

    testWidgets('history writes its month in the language', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final when = DateTime(2026, 3, 14, 18);
      await tester.runAsync(() async {
        container = containerFor(db);
        await db.saveSession(
          routineId: null,
          workoutId: null,
          name: 'Push',
          seedKey: 'push',
          startedAt: when,
          endedAt: when.add(const Duration(hours: 1)),
          durationSeconds: 3600,
          totalVolume: 4200,
          sets: const [],
        );
      });

      await tester.pumpWidget(_liveApp(container!, const HistoryScreen()));
      await tester.pump();
      await _switchTo(tester, db, container!, 'uk');

      expect(find.text(DateFormat('MMM', 'uk').format(when).toUpperCase()),
          findsWidgets,
          reason: 'a month name is a translated word like any other');
      expect(find.text(DateFormat('MMM', 'en').format(when).toUpperCase()),
          findsNothing);

      await stop(tester);
    });
  });
}
