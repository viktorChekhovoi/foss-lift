import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';

/// What the reminder scheduler is handed: every routine's schedule paired with
/// the last time it was actually trained. The pairing is the whole point — a
/// reminder that ignores the session you have already done is a nag.
void main() {
  late AppDatabase db;
  late int routineId;
  late int workoutId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    routineId = await db.createRoutine(
      name: 'Test',
      color: 'FF6A3D',
      restSeconds: 90,
      scheduleDays: kEveryDayMask,
      reminderMinutes: 18 * 60,
    );
    workoutId = await db.createWorkout(routineId, 'Day A');
  });
  tearDown(() => db.close());

  Future<RoutineReminder> reminder() async {
    final all = await db.watchRoutineReminders().first;
    return all.firstWhere((r) => r.routineId == routineId);
  }

  Future<void> logSession({DateTime? at, bool finished = true}) async {
    final when = at ?? DateTime.now();
    // Inserted directly rather than through saveSession, which only knows how
    // to write a session that finished — an abandoned one has no end.
    await db.into(db.sessions).insert(SessionsCompanion.insert(
          routineId: Value(routineId),
          workoutId: Value(workoutId),
          name: 'Day A',
          startedAt: when,
          endedAt: Value(finished ? when.add(const Duration(hours: 1)) : null),
        ));
  }

  test('every routine is listed, trained or not', () async {
    // The two seeded demo routines plus the one built here.
    final all = await db.watchRoutineReminders().first;
    expect(all, hasLength(3));
    expect((await reminder()).lastTrainedAt, isNull);
  });

  test('carries the schedule and the reminder time', () async {
    final r = await reminder();
    expect(r.name, 'Test');
    expect(r.scheduleDays, kEveryDayMask);
    expect(r.reminderMinutes, 18 * 60);
  });

  test('reports the most recent finished session', () async {
    await logSession(at: DateTime(2026, 6, 1, 18));
    await logSession(at: DateTime(2026, 6, 8, 19));
    expect((await reminder()).lastTrainedAt, DateTime(2026, 6, 8, 19));
  });

  test('an unfinished session does not count as having trained', () async {
    await logSession(at: DateTime(2026, 6, 1, 18), finished: false);
    expect((await reminder()).lastTrainedAt, isNull);
  });

  test('a session logged today silences today\'s reminder', () async {
    final now = DateTime(2026, 6, 8, 9);
    await logSession(at: DateTime(2026, 6, 8, 7));
    expect((await reminder()).nextFireAt(now), DateTime(2026, 6, 9, 18));
  });

  test('and without one, today\'s reminder stands', () async {
    expect((await reminder()).nextFireAt(DateTime(2026, 6, 8, 9)),
        DateTime(2026, 6, 8, 18));
  });

  test('a routine with no reminder asked for has nothing to fire', () async {
    final all = await db.watchRoutineReminders().first;
    final seeded = all.firstWhere((r) => r.name == 'Push / Pull / Legs');
    expect(seeded.reminderMinutes, isNull);
    expect(seeded.nextFireAt(DateTime(2026, 6, 8, 9)), isNull);
  });
}
