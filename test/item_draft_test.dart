import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/database.dart';
import 'package:foss_lift/widgets/workout_items_editor.dart';

/// The builder's working copy of an exercise slot: what switching the axis does
/// to the rates, and how the card summarises the result.
void main() {
  ItemDraft draft({
    ProgressionMode mode = ProgressionMode.weight,
    int sets = 4,
    int repsMin = 6,
    int? repsMax = 8,
    bool toFailure = false,
    double? weightKg = 80,
    int holdSeconds = 45,
  }) =>
      ItemDraft(
        exerciseId: 1,
        name: 'Bench Press',
        muscle: 'Chest',
        sets: sets,
        repsMin: repsMin,
        repsMax: repsMax,
        toFailure: toFailure,
        weightKg: weightKg,
        progression: mode,
        holdSeconds: holdSeconds,
      );

  group('rates follow the axis', () {
    test('a fresh draft starts on the weight defaults', () {
      final d = draft();
      expect([d.increment, d.deload], [2.5, 5]);
    });

    test('switching the axis re-bases the rates on its own unit', () {
      // 2.5 is a sane step in kilograms and nonsense in repetitions.
      final d = draft()..setMode(ProgressionMode.reps);
      expect([d.increment, d.deload], [1, 2]);

      d.setMode(ProgressionMode.time);
      expect([d.increment, d.deload], [5, 10]);
    });

    test('re-selecting the axis already chosen leaves a custom rate alone', () {
      final d = draft()..increment = 1.25;
      d.setMode(ProgressionMode.weight);
      expect(d.increment, 1.25);
    });
  });

  group('the card summary', () {
    test('reads sets, range, load and step', () {
      expect(draftSummary(draft(), 'kg'), '4 × 6–8 · 80 kg · +2.5 kg');
    });

    test('collapses a range that is not one', () {
      expect(draftSummary(draft(repsMax: null), 'kg'), '4 × 6 · 80 kg · +2.5 kg');
    });

    test('omits a load nobody set', () {
      final d = draft(weightKg: null)..setMode(ProgressionMode.reps);
      expect(draftSummary(d, 'kg'), '4 × 6–8 · +1 rep');
    });

    test('a timed slot reads in seconds, not reps', () {
      final d = draft(weightKg: null)..setMode(ProgressionMode.time);
      expect(draftSummary(d, 'kg'), '4 × 45s · +5s');
    });

    test('to failure says so', () {
      expect(draftSummary(draft(toFailure: true), 'kg'),
          '4 × to failure · 80 kg · +2.5 kg');
    });

    test('weights and steps alike are shown in the display unit', () {
      // 80 kg and a 2.5 kg step, read off in pounds.
      expect(draftSummary(draft(), 'lb'), '4 × 6–8 · 176.4 lb · +5.5 lb');
    });
  });

  test('a range set to fail is stored without its upper bound', () {
    // "6–8, to failure" is a contradiction; the flag wins and repsMin becomes
    // the number to beat.
    final rows = itemCompanions([draft(toFailure: true)]);
    expect(rows.single.repsMax.value, isNull);
    expect(rows.single.repsMin.value, 6);
  });

  test('progression settings survive a round trip through the drafts', () {
    final rows = itemCompanions([
      draft(mode: ProgressionMode.time)
        ..successThreshold = 3
        ..failureThreshold = 4
        ..successStreak = 2,
    ]);
    final r = rows.single;
    expect(r.progression.value, ProgressionMode.time);
    expect(r.holdSeconds.value, 45);
    expect([r.increment.value, r.deload.value], [5, 10]);
    expect([r.successThreshold.value, r.failureThreshold.value], [3, 4]);
    expect(r.successStreak.value, 2);
  });
}
