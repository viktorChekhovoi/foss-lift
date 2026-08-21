// Polls stream-backed providers until a test condition is met.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

/// Keeps [provider] alive on [container] and returns its value once [test]
/// passes, pumping the event loop between reads. Throws if it never settles.
Future<T> readWhen<T>(
  ProviderContainer container,
  ProviderListenable<T> provider,
  bool Function(T) test, {
  String? reason,
}) async {
  final sub = container.listen(provider, (_, _) {});
  try {
    for (var i = 0; i < 200; i++) {
      final value = sub.read();
      if (test(value)) return value;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError(
        'readWhen timed out${reason == null ? '' : ': $reason'} (last=${sub.read()})');
  } finally {
    sub.close();
  }
}

/// Pumps [tester] a frame at a time until [condition] holds or [maxFrames] is
/// reached. Used inside `testWidgets`, where the fake clock only advances on a
/// pump — so a drift write propagates to the providers only as frames are
/// pumped. Unlike [readWhen] (real-time delays, for pure-Dart tests) this drives
/// the widget clock and so is safe under the test binding.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxFrames = 60,
  Duration step = const Duration(milliseconds: 20),
}) async {
  for (var i = 0; i < maxFrames; i++) {
    if (condition()) return;
    await tester.pump(step);
  }
}
