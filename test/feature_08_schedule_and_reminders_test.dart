// Feature 08 — Schedule & reminders.
//
// The behaviour under test is entirely the *decision*: given a day mask, a
// reminder time, "now", and when the routine was last trained, when should the
// next local notification fire? That decision is the pure `nextReminderAt`
// (and its `RoutineReminder.nextFireAt` wrapper), driven here across every edge
// the spec names — no schedule, a once-weekly day, a multi-day week, a slot
// already trained today, and the week-wrap. The stored side of it — the mask
// and the (nullable) reminder time per routine, re-derived through
// `watchRoutineReminders` — is asserted against the seeded install and after a
// schedule edit and a finished session, the two events the spec says converge
// on the same pending reminder. The scheduler itself is Android-only, so off a
// device it must be an inert no-op that never reaches a platform channel.
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/providers/providers.dart';
import 'package:foss_lift/services/notifications.dart';
import 'package:foss_lift/services/reminders.dart';

import 'support/harness.dart';

// Week 1 of 2024 lines the day-of-month up with the weekday: the 1st is a
// Monday, the 7th a Sunday, so `_on(3, ...)` is unambiguously Wednesday.
DateTime _on(int day, int hour, int minute) =>
    DateTime(2024, 1, day, hour, minute);

const _mon = 1 << 0;
const _wed = 1 << 2;
const _fri = 1 << 4;
const _mwf = _mon | _wed | _fri; // the seeded PPL schedule
const _eighteenHundred = 18 * 60; // 18:00 as minutes past midnight

RoutineReminder _byName(List<RoutineReminder> rs, String name) =>
    rs.firstWhere((r) => r.name == name);

/// The channel labels and the words of a reminder, as the provider layer
/// resolves them — read from the catalogue rather than typed out again.
final _l10n = l10nFor();
final NotificationChannelCopy _channel = (
  name: _l10n.reminderChannelName,
  description: _l10n.reminderChannelDescription,
);

ReminderPost _post(int mask, int minutes) => (
      reminder: RoutineReminder(
        routineId: 1,
        name: 'Push / Pull / Legs',
        scheduleDays: mask,
        reminderMinutes: minutes,
      ),
      title: 'Push / Pull / Legs',
      body: _l10n.reminderBody,
    );

/// A [ReminderService] stand-in that records the sync calls instead of touching
/// a plugin, so the "one place re-lays every reminder" wiring can be observed
/// without a device.
class _RecordingReminderService extends ReminderService {
  final List<List<ReminderPost>> calls = [];

  @override
  Future<void> sync(
    List<ReminderPost> posts, {
    required NotificationChannelCopy channel,
    DateTime? now,
  }) async {
    calls.add(posts);
  }
}

void main() {
  // The reminder funnel resolves the language before it posts anything, and
  // the active locale is read off the platform dispatcher — which needs a
  // binding, even for the pure-Dart tests below.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the next reminder is computed, not stored', () {
    test('no scheduled days means no reminder at all', () {
      expect(
        nextReminderAt(
          mask: kNoScheduleMask,
          minutes: _eighteenHundred,
          from: _on(1, 8, 0),
        ),
        isNull,
      );
    });

    test('a once-weekly day fires on that day when its slot is still ahead', () {
      // Wednesday-only, asked on Monday: the next Wednesday at 18:00.
      expect(
        nextReminderAt(mask: _wed, minutes: _eighteenHundred, from: _on(1, 8, 0)),
        _on(3, 18, 0),
      );
    });

    test('today counts when the slot has not yet passed', () {
      // Wednesday-only, asked on Wednesday morning: today at 18:00.
      expect(
        nextReminderAt(mask: _wed, minutes: _eighteenHundred, from: _on(3, 8, 0)),
        _on(3, 18, 0),
      );
    });

    test('a once-weekly slot that has already passed wraps a full week', () {
      // Wednesday-only, asked on Wednesday evening after 18:00: same weekday,
      // seven days on (2024-01-10 is the following Wednesday).
      expect(
        nextReminderAt(
            mask: _wed, minutes: _eighteenHundred, from: _on(3, 19, 0)),
        _on(10, 18, 0),
      );
    });

    test('a multi-day week picks today while its slot is still ahead', () {
      expect(
        nextReminderAt(
            mask: _mwf, minutes: _eighteenHundred, from: _on(1, 8, 0)),
        _on(1, 18, 0), // Monday 18:00
      );
    });

    test('a multi-day week rolls to the next scheduled day once today passes',
        () {
      // Monday evening after the slot: the next scheduled day is Wednesday.
      expect(
        nextReminderAt(
            mask: _mwf, minutes: _eighteenHundred, from: _on(1, 19, 0)),
        _on(3, 18, 0),
      );
      // Wednesday evening: on to Friday.
      expect(
        nextReminderAt(
            mask: _mwf, minutes: _eighteenHundred, from: _on(3, 19, 0)),
        _on(5, 18, 0),
      );
    });

    test('the last scheduled day of the week wraps to the first of the next',
        () {
      // Friday evening on Mon/Wed/Fri: the next slot is the following Monday
      // (2024-01-08).
      expect(
        nextReminderAt(
            mask: _mwf, minutes: _eighteenHundred, from: _on(5, 19, 0)),
        _on(8, 18, 0),
      );
    });

    test("training today skips today's slot even while it is still ahead", () {
      // Wednesday morning, slot at 18:00 still to come — but the routine was
      // already trained earlier today, so the point of the nudge is served and
      // it jumps to Friday.
      expect(
        nextReminderAt(
          mask: _mwf,
          minutes: _eighteenHundred,
          from: _on(3, 8, 0),
          lastTrainedAt: _on(3, 6, 30),
        ),
        _on(5, 18, 0),
      );
    });

    test('training yesterday does not skip today', () {
      expect(
        nextReminderAt(
          mask: _mwf,
          minutes: _eighteenHundred,
          from: _on(3, 8, 0),
          lastTrainedAt: _on(2, 18, 0), // Tuesday
        ),
        _on(3, 18, 0),
      );
    });
  });

  group('RoutineReminder.nextFireAt gates on the reminder time', () {
    test('no reminder time means nothing fires, whatever the schedule', () {
      const r = RoutineReminder(
        routineId: 1,
        name: 'PPL',
        scheduleDays: _mwf,
        reminderMinutes: null,
      );
      expect(r.nextFireAt(_on(1, 8, 0)), isNull);
    });

    test('a reminder time drives the same decision as the pure function', () {
      const r = RoutineReminder(
        routineId: 1,
        name: 'PPL',
        scheduleDays: _mwf,
        reminderMinutes: _eighteenHundred,
      );
      expect(r.nextFireAt(_on(1, 8, 0)), _on(1, 18, 0));
    });

    test('a reminder time with no scheduled days still fires nothing', () {
      const r = RoutineReminder(
        routineId: 1,
        name: 'PPL',
        scheduleDays: kNoScheduleMask,
        reminderMinutes: _eighteenHundred,
      );
      expect(r.nextFireAt(_on(1, 8, 0)), isNull);
    });
  });

  group('the stored schedule is re-derived through watchRoutineReminders', () {
    test('the seeded install carries a scheduled routine and an unscheduled one',
        () async {
      final db = memoryDb();
      addTearDown(db.close);

      final reminders = await db.watchRoutineReminders().first;

      final ppl = _byName(reminders, 'Push / Pull / Legs');
      expect(ppl.scheduleDays, _mwf, reason: 'seeded Mon/Wed/Fri');
      expect(ppl.reminderMinutes, isNull, reason: 'no reminder asked for');
      expect(ppl.lastTrainedAt, isNull, reason: 'never trained yet');

      final ul = _byName(reminders, 'Upper / Lower');
      expect(ul.scheduleDays, kNoScheduleMask, reason: 'no fixed days');
      expect(ul.reminderMinutes, isNull);
    });

    test('a schedule edit turns the reminder on and gives it a next fire time',
        () async {
      final db = memoryDb();
      addTearDown(db.close);

      final before = _byName(
          await db.watchRoutineReminders().first, 'Push / Pull / Legs');
      final routine = await db.routineById(before.routineId);

      await db.updateRoutineMeta(
        routine.id,
        name: routine.name,
        color: routine.colorHex,
        restSeconds: routine.restSeconds,
        scheduleDays: routine.scheduleDays,
        reminderMinutes: _eighteenHundred,
      );

      final after = _byName(
          await db.watchRoutineReminders().first, 'Push / Pull / Legs');
      expect(after.reminderMinutes, _eighteenHundred);
      expect(after.nextFireAt(_on(1, 8, 0)), _on(1, 18, 0));
    });

    test('a finished session shows up as the routine having been trained',
        () async {
      final db = memoryDb();
      addTearDown(db.close);

      final ppl = _byName(
          await db.watchRoutineReminders().first, 'Push / Pull / Legs');
      expect(ppl.lastTrainedAt, isNull);

      final trainedAt = _on(1, 10, 0);
      await db.saveSession(
        routineId: ppl.routineId,
        workoutId: null,
        name: 'Push',
        startedAt: trainedAt,
        endedAt: _on(1, 11, 0),
        durationSeconds: 3600,
        totalVolume: 0,
        sets: const [],
      );

      final after = _byName(
          await db.watchRoutineReminders().first, 'Push / Pull / Legs');
      expect(after.lastTrainedAt, trainedAt);
    });
  });

  group('reminders re-sync from a single place', () {
    test('reminderSyncProvider hands the whole reminder list to the scheduler',
        () async {
      final db = memoryDb();
      final recording = _RecordingReminderService();
      final container = containerFor(
        db,
        overrides: [reminderServiceProvider.overrideWithValue(recording)],
      );

      // Keep the sync funnel alive — it is the single place every routine's
      // reminder is re-laid, where everything (edits, sessions, launch) reaches
      // the scheduler. Holding a listener subscribes the reminder stream
      // underneath it; once that emits, the funnel hands the whole list on.
      final syncSub = container.listen(reminderSyncProvider, (_, _) {});
      for (var i = 0; i < 400 && recording.calls.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      // Tear the drift subscription down before closing the db, or the close
      // races an in-flight stream event ("cannot close sink while adding").
      syncSub.close();
      container.dispose();
      await Future<void>.delayed(Duration.zero);
      await db.close();

      expect(
        recording.calls.last.map((p) => p.reminder.name),
        containsAll(<String>['Push / Pull / Legs', 'Upper / Lower']),
      );
    });
  });

  group('the reminder service is Android-only and inert off a device', () {
    test('it reports unsupported and schedules nothing off Android', () async {
      final service = ReminderService();

      // The host test runner is never Android, so every entry point must be a
      // harmless no-op rather than a reach for a platform channel that is not
      // there (which would throw MissingPluginException).
      expect(service.supported, isFalse);

      await service.init();
      await service.sync(
        [_post(_mwf, _eighteenHundred)],
        channel: _channel,
        now: _on(1, 8, 0),
      );

      expect(await service.requestPermission(), isFalse);
      expect(await service.permitted(), isFalse);
    });
  });
}
