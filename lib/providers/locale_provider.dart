import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../util/locales.dart';
import 'db_provider.dart';

/// The language the app renders in, as a stored tag (`uk`, `pt_BR`).
///
/// **The phone is consulted once, not for ever.** An install that has not
/// chosen yet emits null exactly once; that null is answered by resolving the
/// phone's preference list against the catalogues we ship and writing the
/// answer to `Settings.localeTag`. So there is no "follow the phone" state to
/// be in — the picker always has one of the five selected, and changing the
/// phone's language afterwards leaves the app where the user left it.
final localeTagProvider = StreamProvider<String?>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchLocaleTag().asyncMap((tag) async {
    if (tag != null) return tag;
    final resolved = localeTag(
      resolveLocale(null, WidgetsBinding.instance.platformDispatcher.locales),
    );
    await db.setLocaleTag(resolved);
    return resolved;
  });
});

/// The language to render in.
///
/// Synchronous, and deliberately: the app root needs a locale for the very
/// first frame, and the stored choice has not arrived yet. Until it does — and
/// on the first launch, until the write above lands — this is the phone's own
/// answer, which is what first run is about to store anyway. See
/// [localeReadyProvider] for the gate that keeps that guess off the screen.
final activeLocaleProvider = Provider<Locale>((ref) {
  return resolveLocale(
    ref.watch(localeTagProvider).value,
    WidgetsBinding.instance.platformDispatcher.locales,
  );
});

/// The string catalogue for [activeLocaleProvider].
///
/// **For the parts of the app that render text with no widget tree under
/// them** — the notification shade, the rest alarm, the scheduled reminders.
/// Everywhere there is a `BuildContext`, `AppLocalizations.of(context)` is the
/// answer and this is not.
///
/// Derived rather than remembered, and read at the moment the text is built:
/// switching language rebuilds it in the same pass that rebuilds the screens,
/// so nothing can post yesterday's language.
final appLocalizationsProvider = Provider<AppLocalizations>(
  (ref) => lookupAppLocalizations(ref.watch(activeLocaleProvider)),
);

/// Whether the stored language has arrived. Joined with [themeReadyProvider]
/// at the app root, for the same reason: painting a frame in the wrong
/// language and correcting it is a flicker on every cold launch.
final localeReadyProvider = Provider<bool>((ref) {
  return ref.watch(localeTagProvider).hasValue;
});
