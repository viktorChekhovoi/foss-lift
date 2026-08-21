/// Cardio console readouts and their display units; speed and distance are stored in metric and converted using the app-wide weight-unit setting.

library;

import '../data/database.dart' show SessionSet;
import '../l10n/app_localizations.dart';
import 'format.dart';

/// The four readouts, as one value.
///
/// A record rather than four parameters everywhere: they are set together (the
/// details panel writes all four at once, and a field left blank is a null being
/// written, not a field being skipped), and carrying them as one is what lets a
/// caller say "these are the numbers now" without a separate way to clear one.
typedef ConsoleMetrics = ({
  /// Speed in kilometres per hour, or null when nobody wrote it down.
  double? speedKph,

  /// The incline as a percentage. Zero is a flat treadmill somebody typed;
  /// null is an incline nobody looked at.
  double? inclinePercent,

  /// The level the machine was set to, as it reads on the machine.
  int? resistanceLevel,

  /// Distance covered, in kilometres.
  double? distanceKm,
});

/// A set nobody has typed a readout on — the state every set opens in.
const ConsoleMetrics kNoConsoleMetrics = (
  speedKph: null,
  inclinePercent: null,
  resistanceLevel: null,
  distanceKm: null,
);

/// Whether any of the four has been filled in.
bool hasConsoleMetrics(ConsoleMetrics m) =>
    m.speedKph != null ||
    m.inclinePercent != null ||
    m.resistanceLevel != null ||
    m.distanceKm != null;

/// The four columns of a logged set, read as the one value they are.
///
/// Here rather than beside the table because the reading needs [ConsoleMetrics],
/// and the database layer deliberately knows nothing about the display side of
/// units — see `data/seed_keys.dart` for the same split.
extension LoggedSetConsole on SessionSet {
  ConsoleMetrics get console => (
    speedKph: speedKph,
    inclinePercent: inclinePercent,
    resistanceLevel: resistanceLevel,
    distanceKm: distanceKm,
  );
}

/// Kilometres in a mile — the one constant both conversions stand on.
const double kKmPerMile = 1.609344;

/// A stored speed in the display unit: km/h in a metric gym, mph in a pounds
/// one.
double toDisplaySpeed(double kph, String unit) =>
    unit == 'lb' ? kph / kKmPerMile : kph;

/// A speed typed by the user, back in kilometres per hour.
double speedToKph(double display, String unit) =>
    unit == 'lb' ? display * kKmPerMile : display;

/// A stored distance in the display unit: kilometres, or miles.
double toDisplayDistance(double km, String unit) =>
    unit == 'lb' ? km / kKmPerMile : km;

/// A distance typed by the user, back in kilometres.
double distanceToKm(double display, String unit) =>
    unit == 'lb' ? display * kKmPerMile : display;

/// The speed suffix for [unit], in the app's language.
String speedSuffix(AppLocalizations l10n, String unit) =>
    unit == 'lb' ? l10n.unitMphSuffix : l10n.unitKmhSuffix;

/// The distance suffix for [unit], in the app's language.
String distanceSuffix(AppLocalizations l10n, String unit) =>
    unit == 'lb' ? l10n.unitMiSuffix : l10n.unitKmSuffix;

/// The readouts as one line — "9.5 km/h · 2% · 3.2 km" — or null when none of
/// them was filled in.
///
/// **Only what was written down is printed.** A set carrying no readouts reads
/// exactly as it did before there were any, rather than growing empty labels
/// standing in for numbers nobody recorded.
String? cardioSummary(
  AppLocalizations l10n,
  ConsoleMetrics m, {
  required String unit,
}) {
  final parts = [
    if (m.speedKph case final v?)
      l10n.unitCardioShort(
        fmtUpTo(toDisplaySpeed(v, unit), 2),
        speedSuffix(l10n, unit),
      ),
    if (m.inclinePercent case final v?) l10n.unitInclineShort(fmtUpTo(v, 2)),
    if (m.resistanceLevel case final v?) l10n.unitResistanceShort('$v'),
    if (m.distanceKm case final v?)
      l10n.unitCardioShort(
        fmtUpTo(toDisplayDistance(v, unit), 2),
        distanceSuffix(l10n, unit),
      ),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
