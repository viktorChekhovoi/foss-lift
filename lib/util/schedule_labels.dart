/// Formats weekly schedules using the caller's localized weekday labels.

library;

import 'package:intl/intl.dart';

import '../data/schedule.dart';
import '../l10n/app_localizations.dart';

/// 1 January 2024 was a Monday, so `_dayOfWeek(1)`…`_dayOfWeek(7)` walk Monday
/// to Sunday. Formatting a real date is what makes the order certain — the
/// symbol tables `intl` exposes are indexed from Sunday, which is one
/// off-by-one waiting to happen.
DateTime _dayOfWeek(int weekday) => DateTime(2024, 1, weekday);

/// The single letters on the day toggles, Monday first.
///
/// Not unique in most languages — English has two Ts and two Ss — which is why
/// they sit in a row shaped like a week rather than in a list.
List<String> dayInitials(AppLocalizations l10n) {
  final fmt = DateFormat('EEEEE', l10n.localeName);
  return [for (var d = 1; d <= 7; d++) fmt.format(_dayOfWeek(d))];
}

/// Human-readable schedule: "No fixed days", "Every day", or "Mon · Wed · Fri".
String scheduleLabel(AppLocalizations l10n, int mask) {
  if (mask & kEveryDayMask == kNoScheduleMask) return l10n.scheduleNoFixedDays;
  if (mask & kEveryDayMask == kEveryDayMask) return l10n.scheduleEveryDay;
  final fmt = DateFormat('EEE', l10n.localeName);
  return scheduledWeekdays(mask).map((d) => fmt.format(_dayOfWeek(d))).join(' · ');
}
