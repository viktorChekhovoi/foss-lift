/// Which language the app renders in.
///
/// One list, read by everything: the picker on the settings screen, the
/// resolver below, `MaterialApp.supportedLocales`, and the test sweep that
/// mounts every screen in every language. Adding a sixth language is
/// `lib/l10n/app_<tag>.arb` plus an entry here — nothing else counts them.
library;

import 'package:flutter/widgets.dart';

/// The languages the app ships in, in the order the picker lists them.
///
/// **English is first, and that placement is the fallback rule**: a phone set
/// to a language with no catalogue here lands on the first supported locale.
///
/// The two Portugueses are separate entries, and `pt` before `pt_BR` matters —
/// see [resolveLocale].
const List<Locale> kSupportedLocales = [
  Locale('en'),
  Locale('uk'),
  Locale('es'),
  Locale('pt'),
  Locale('pt', 'BR'),
];

/// What each language calls itself.
///
/// In its own language, never translated: the point of this list is to be
/// legible to someone who cannot read the language the app is currently in —
/// which, if they are on this screen, is often exactly the situation.
const Map<String, String> kLanguageNames = {
  'en': 'English',
  'uk': 'Українська',
  'es': 'Español',
  'pt': 'Português (Portugal)',
  'pt_BR': 'Português (Brasil)',
};

/// A locale as it is stored in `Settings.localeTag` and keyed in
/// [kLanguageNames]: `uk`, or `pt_BR` when the region is part of the answer.
String localeTag(Locale locale) => locale.countryCode == null
    ? locale.languageCode
    : '${locale.languageCode}_${locale.countryCode}';

/// The inverse. Returns null for a tag that is not one of [kSupportedLocales],
/// which is what a stored value from a language since removed looks like.
Locale? localeFromTag(String? tag) {
  if (tag == null) return null;
  for (final locale in kSupportedLocales) {
    if (localeTag(locale) == tag) return locale;
  }
  return null;
}

/// The language to render in, given what the user chose and what the phone is
/// set to.
///
/// [chosen] wins when it names a language we have. Otherwise the phone's list
/// is walked in preference order and the first one we can answer is taken:
///
/// - an exact language-and-region match first, so a Brazilian phone gets the
///   Brazilian catalogue rather than the European one;
/// - then any catalogue in the same language, so pt-PT — and a bare pt, and
///   pt-AO — all land on European Portuguese, because it is listed before
///   pt-BR;
/// - then English, which is [kSupportedLocales] first.
///
/// Flutter's own resolution already does very nearly this. It is written out
/// here so the rule is a function a test can call with a locale and an
/// expectation, rather than a behaviour of the framework that has to be
/// discovered by mounting an app.
Locale resolveLocale(String? chosen, Iterable<Locale>? deviceLocales) {
  final picked = localeFromTag(chosen);
  if (picked != null) return picked;

  for (final device in deviceLocales ?? const <Locale>[]) {
    for (final supported in kSupportedLocales) {
      if (supported.languageCode == device.languageCode &&
          supported.countryCode == device.countryCode) {
        return supported;
      }
    }
    for (final supported in kSupportedLocales) {
      if (supported.languageCode == device.languageCode) return supported;
    }
  }
  return kSupportedLocales.first;
}
