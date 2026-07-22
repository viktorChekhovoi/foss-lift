import 'package:flutter_test/flutter_test.dart';
import 'package:foss_lift/data/progression.dart';

/// The arithmetic behind #10/#11, with no database in the way: when a target
/// moves, by how much, and what the streaks do in between.
void main() {
  /// One session's outcome under the default rules: step up after a single
  /// clean session, back off by twice the step after two misses in a row.
  ProgressionStep run(
    bool success, {
    int successes = 0,
    int failures = 0,
    int successThreshold = defaultSuccessThreshold,
    int failureThreshold = defaultFailureThreshold,
    double increment = 2.5,
    double deload = 5,
  }) =>
      stepProgression(
        success: success,
        successes: successes,
        failures: failures,
        successThreshold: successThreshold,
        failureThreshold: failureThreshold,
        increment: increment,
        deload: deload,
      );

  group('stepping up', () {
    test('one clean session is enough by default', () {
      final s = run(true);
      expect(s.delta, 2.5);
      expect(s.successes, 0, reason: 'the counter resets once the step fires');
    });

    test('a higher threshold makes the step wait', () {
      final first = run(true, successThreshold: 3);
      expect(first.delta, 0);
      expect(first.successes, 1);

      final second = run(true, successes: 1, successThreshold: 3);
      expect(second.delta, 0);
      expect(second.successes, 2);

      final third = run(true, successes: 2, successThreshold: 3);
      expect(third.delta, 2.5);
      expect(third.successes, 0, reason: 'the next step must be re-earned');
    });
  });

  group('backing off', () {
    test('one miss is a bad night, not a deload', () {
      final s = run(false);
      expect(s.delta, 0);
      expect(s.failures, 1);
    });

    test('the second miss in a row backs the target off', () {
      final s = run(false, failures: 1);
      expect(s.delta, -5);
      expect(s.failures, 0);
    });
  });

  group('consecutive means consecutive', () {
    test('a miss wipes the success streak', () {
      final s = run(false, successes: 2, successThreshold: 3);
      expect(s.successes, 0);
      expect(s.failures, 1);
    });

    test('a clean session wipes the failure streak', () {
      // One miss away from a deload, then a good day: the deload is off.
      final s = run(true, failures: 1, successThreshold: 5);
      expect(s.failures, 0);
      expect(s.delta, 0);

      // And the next miss starts counting from one again.
      expect(run(false, failures: 0).delta, 0);
    });
  });

  group('mode defaults', () {
    test('each axis steps in its own unit', () {
      expect(ProgressionMode.weight.defaultIncrement, 2.5);
      expect(ProgressionMode.reps.defaultIncrement, 1);
      expect(ProgressionMode.time.defaultIncrement, 5);
    });

    test('a back-off undoes more than the last step up', () {
      for (final m in ProgressionMode.values) {
        expect(m.defaultDeload, greaterThan(m.defaultIncrement),
            reason: 'undoing only the last step lands you back on the weight '
                'that just beat you');
      }
    });

    test('only weight may be driven to zero', () {
      expect(ProgressionMode.weight.floor, 0);
      expect(ProgressionMode.reps.floor, greaterThan(0));
      expect(ProgressionMode.time.floor, greaterThan(0));
    });
  });

  group('advanceTarget', () {
    test('moves the target by the delta', () {
      expect(advanceTarget(80, 2.5, ProgressionMode.weight), 82.5);
      expect(advanceTarget(80, -5, ProgressionMode.weight), 75);
    });

    test('never goes below the mode floor', () {
      expect(advanceTarget(2, -5, ProgressionMode.weight), 0);
      expect(advanceTarget(2, -5, ProgressionMode.reps), 1);
      expect(advanceTarget(8, -20, ProgressionMode.time), 5);
    });
  });
}
