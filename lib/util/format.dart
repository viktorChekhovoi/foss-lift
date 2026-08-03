/// Number formatting for display. Nothing here knows about units — see
/// `util/units.dart` for kg⇄lb.
library;

import 'package:intl/intl.dart';

/// A running total squeezed into a stat tile: grouped digits up to five
/// figures, then k/M. Lifetime volume reaches seven digits within a year of
/// training, and "1.2M" fits a card where "1,248,300" does not.
String fmtTotal(num value) {
  final v = value.round();
  if (v.abs() < 10000) return NumberFormat.decimalPattern().format(v);
  if (v.abs() < 1000000) return '${_mantissa(v / 1000)}k';
  return '${_mantissa(v / 1000000)}M';
}

/// The number in front of a k or an M: one decimal, a bare `.0` dropped, and
/// the language's own decimal mark — 12.0 → "12", 12.45 → "12.5", and "12,5"
/// where that is how it is written.
///
/// Grouping is off because this never reaches four digits by design; the one
/// input that rounds there (999 999 → 1000k) would otherwise pick up a
/// thousands separator inside a figure that is already an abbreviation.
String _mantissa(double v) => (NumberFormat.decimalPattern()
      ..maximumFractionDigits = 1
      ..turnOffGrouping())
    .format(v);

/// A running clock: `m:ss`, counting minutes past the hour rather than wrapping
/// to hours. A session that ran 95 minutes reads "95:12", which is what a lifter
/// wants to know; "1:35:12" makes them do the arithmetic.
String fmtDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// A weight for display: up to two decimals, trailing zeros dropped.
///
/// 100.0 → "100", 102.5 → "102.5", 1.25 → "1.25" — and "102,5" in a language
/// that writes it that way, because every formatter here goes through `intl`
/// and `intl` reads `Intl.defaultLocale`, which the app root keeps in step with
/// the language.
///
/// Two decimals rather than one, everywhere rather than only on the plate line:
/// the smallest pair of plates a metric gym owns makes 1.25 kg, a step that
/// reads "1.3" is a weight nobody can build, and the same number reading two
/// ways on two screens is worse than either.
String fmtWeight(double w) => fmtUpTo(w, 2);

/// Exactly one decimal place, in the app's language: 2.0 → "2.0", 1.44 → "1.4".
///
/// The zero is kept, unlike [fmtWeight]. A storage figure reading "2 kB" beside
/// "1.4 GB" looks like a different measurement rather than a rounder one.
String fmtOneDecimal(double v) => (NumberFormat.decimalPattern()
      ..minimumFractionDigits = 1
      ..maximumFractionDigits = 1)
    .format(v);

/// [v] with at most [max] decimals and no trailing zeros, in the app's
/// language.
String fmtUpTo(double v, int max) =>
    (NumberFormat.decimalPattern()..maximumFractionDigits = max).format(v);
