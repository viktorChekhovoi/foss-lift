/// When a routine is meant to be trained, and when to nudge about it.
///
/// The days live in a bitmask: bit 0 is Monday, bit 6 is Sunday, matching
/// `DateTime.weekday - 1`. One integer rather than a table of its own, because
/// a weekly schedule is seven yes/no answers and nothing else — there is no
/// "every other Tuesday" to express and no per-day setting to hang anywhere.
///
/// Pure: no drift, no Flutter, no notification plugin. Deciding *when* the next
/// reminder falls is exactly the part worth testing without a device attached.
/// Putting a schedule into words needs both the app's strings and the calendar's
/// weekday names, so that lives in `util/schedule_labels.dart` instead.
library;

/// All seven days set.
const kEveryDayMask = 0x7F;

/// Nothing scheduled — the default, and what "train it when you feel like it"
/// looks like.
const kNoScheduleMask = 0;

/// Whether [mask] includes [weekday], given as a `DateTime.weekday` (1–7).
bool scheduledOn(int mask, int weekday) => mask & (1 << (weekday - 1)) != 0;

/// [mask] with [weekday] flipped on or off.
int toggleDay(int mask, int weekday) => mask ^ (1 << (weekday - 1));

/// The scheduled weekdays as `DateTime.weekday` values, Monday first.
List<int> scheduledWeekdays(int mask) =>
    [for (var d = 1; d <= 7; d++) if (scheduledOn(mask, d)) d];

/// Minutes past midnight as a 24-hour clock time, e.g. 1110 -> "18:30".
String timeLabel(int minutes) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Everything scheduling one routine's reminder needs: what to say, when it is
/// due, and when the routine was last actually trained.
///
/// A plain class rather than a drift row so the reminder service can be handed
/// one — and tested — without a database anywhere near it.
class RoutineReminder {
  const RoutineReminder({
    required this.routineId,
    required this.name,
    required this.scheduleDays,
    this.seedKey,
    this.reminderMinutes,
    this.lastTrainedAt,
  });

  final int routineId;

  /// The routine's canonical English name — see [seedKey].
  final String name;

  /// The routine's seed key, or null for one you built yourself. Whatever puts
  /// this on a notification renders `seededName(l10n, seedKey, name)`, so a
  /// routine the app shipped is announced in the app's language.
  final String? seedKey;
  final int scheduleDays;
  final int? reminderMinutes;
  final DateTime? lastTrainedAt;

  /// The next time this routine's reminder should fire, or null if it should
  /// not: no days picked, or no reminder asked for.
  DateTime? nextFireAt(DateTime from) {
    final minutes = reminderMinutes;
    if (minutes == null) return null;
    return nextReminderAt(
      mask: scheduleDays,
      minutes: minutes,
      from: from,
      lastTrainedAt: lastTrainedAt,
    );
  }
}

/// When the next reminder for this schedule should fire, or null if none can.
///
/// Strictly after [from], so a slot that has already passed today rolls to the
/// next scheduled day — a missed workout is not worth a notification about a
/// time that is gone. If [lastTrainedAt] falls on the same day as [from],
/// today's slot is skipped too: the point of the reminder has already been
/// served by actually training.
///
/// Returns null when nothing is scheduled, which is also what an empty mask
/// means: reminders are opt-in one routine at a time.
DateTime? nextReminderAt({
  required int mask,
  required int minutes,
  required DateTime from,
  DateTime? lastTrainedAt,
}) {
  if (mask & kEveryDayMask == kNoScheduleMask) return null;

  final trainedToday = lastTrainedAt != null &&
      lastTrainedAt.year == from.year &&
      lastTrainedAt.month == from.month &&
      lastTrainedAt.day == from.day;

  // Eight candidates, not seven: today's slot may already have passed, and on
  // a once-a-week schedule the next one is this same weekday a week out.
  for (var offset = 0; offset <= 7; offset++) {
    final day = DateTime(from.year, from.month, from.day + offset);
    if (!scheduledOn(mask, day.weekday)) continue;
    if (offset == 0 && trainedToday) continue;
    final at = DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
    if (at.isAfter(from)) return at;
  }
  return null;
}
