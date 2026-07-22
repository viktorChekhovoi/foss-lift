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
  if (v.abs() < 1000000) return '${_oneDecimal(v / 1000)}k';
  return '${_oneDecimal(v / 1000000)}M';
}

/// One decimal place, with a bare `.0` dropped: 12.0 → "12", 12.45 → "12.5".
String _oneDecimal(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}
