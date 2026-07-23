import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/schedule.dart';

/// The weekly schedule and, more importantly, when the next reminder falls.
/// Deciding that is exactly the part worth testing without a device attached.
void main() {
  // Bit 0 is Monday, so Mon/Wed/Fri is 0b0010101.
  const mwf = 1 | 1 << 2 | 1 << 4;

  group('the day mask', () {
    test('reads back the days it was built from', () {
      expect(scheduledWeekdays(mwf), [DateTime.monday, DateTime.wednesday,
        DateTime.friday]);
      expect(scheduledOn(mwf, DateTime.tuesday), isFalse);
      expect(scheduledOn(kEveryDayMask, DateTime.sunday), isTrue);
      expect(scheduledOn(kNoScheduleMask, DateTime.monday), isFalse);
    });

    test('toggles one day without disturbing the rest', () {
      final withSat = toggleDay(mwf, DateTime.saturday);
      expect(scheduledWeekdays(withSat),
          [DateTime.monday, DateTime.wednesday, DateTime.friday,
            DateTime.saturday]);
      expect(toggleDay(withSat, DateTime.saturday), mwf);
    });

    test('says what it is in words', () {
      expect(scheduleLabel(kNoScheduleMask), 'No fixed days');
      expect(scheduleLabel(kEveryDayMask), 'Every day');
      expect(scheduleLabel(mwf), 'Mon · Wed · Fri');
    });
  });

  test('times read as a 24-hour clock', () {
    expect(timeLabel(18 * 60), '18:00');
    expect(timeLabel(7 * 60 + 5), '07:05');
    expect(timeLabel(0), '00:00');
  });

  group('nextReminderAt', () {
    // Wednesday 1 July 2026, mid-morning.
    final wednesdayMorning = DateTime(2026, 7, 1, 9, 0);

    DateTime? next(DateTime from, {int mask = mwf, DateTime? lastTrained}) =>
        nextReminderAt(
          mask: mask,
          minutes: 18 * 60,
          from: from,
          lastTrainedAt: lastTrained,
        );

    test('is today when today is a training day and the time is still ahead',
        () {
      expect(next(wednesdayMorning), DateTime(2026, 7, 1, 18, 0));
    });

    test('rolls past a slot that has already gone', () {
      // 19:00 on the same Wednesday: the 18:00 nudge is no longer of any use,
      // so the next one is Friday.
      expect(next(DateTime(2026, 7, 1, 19, 0)), DateTime(2026, 7, 3, 18, 0));
    });

    test('skips today once the routine has been trained', () {
      expect(
        next(wednesdayMorning, lastTrained: DateTime(2026, 7, 1, 7, 30)),
        DateTime(2026, 7, 3, 18, 0),
        reason: 'the point of the reminder has already been served',
      );
    });

    test('but yesterday\'s session does not excuse today', () {
      expect(
        next(wednesdayMorning, lastTrained: DateTime(2026, 6, 30, 18, 30)),
        DateTime(2026, 7, 1, 18, 0),
      );
    });

    test('wraps to the same weekday next week on a once-a-week schedule', () {
      // Wednesdays only, and this Wednesday's slot has passed.
      const wednesdays = 1 << 2;
      expect(
        next(DateTime(2026, 7, 1, 19, 0), mask: wednesdays),
        DateTime(2026, 7, 8, 18, 0),
      );
    });

    test('and skips a whole week when today was already trained', () {
      const wednesdays = 1 << 2;
      expect(
        next(wednesdayMorning,
            mask: wednesdays, lastTrained: DateTime(2026, 7, 1, 6, 0)),
        DateTime(2026, 7, 8, 18, 0),
      );
    });

    test('is nothing at all with no days picked', () {
      expect(next(wednesdayMorning, mask: kNoScheduleMask), isNull);
    });
  });

  group('RoutineReminder', () {
    test('has nothing to fire without a time asked for', () {
      const r = RoutineReminder(
        routineId: 1,
        name: 'Push / Pull / Legs',
        scheduleDays: mwf,
      );
      expect(r.nextFireAt(DateTime(2026, 7, 1, 9)), isNull,
          reason: 'a schedule is not a request to be notified about it');
    });

    test('carries its own last-trained day into the decision', () {
      final r = RoutineReminder(
        routineId: 1,
        name: 'Push / Pull / Legs',
        scheduleDays: mwf,
        reminderMinutes: 18 * 60,
        lastTrainedAt: DateTime(2026, 7, 1, 7, 30),
      );
      expect(r.nextFireAt(DateTime(2026, 7, 1, 9)), DateTime(2026, 7, 3, 18));
    });
  });
}
