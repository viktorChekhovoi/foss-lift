import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef WorkoutActivityState = ({
  int session,
  String workout,
  String movement,
  String detail,
  int? restEndsAt,
});

/// Sends session changes to ActivityKit in order. The widget counts down from the deadline without waking Dart every second.
class WorkoutActivity with WidgetsBindingObserver {
  WorkoutActivity() {
    WidgetsBinding.instance.addObserver(this);
  }

  static const _channel = MethodChannel(
    'com.fosslift.foss_lift/workout_activity',
  );
  Future<void> _pending = Future.value();
  WorkoutActivityState? _latest;
  int _revision = 0;

  void sync(WorkoutActivityState? state) {
    if (_revision != 0 && state == _latest) return;
    _latest = state;
    _send();
  }

  void _send() {
    final revision = ++_revision;
    _pending = _pending
        .then((_) async {
          if (_revision != revision) return;
          final state = _latest;
          await _channel.invokeMethod<void>(
            'sync',
            state == null
                ? null
                : {
                    'session': state.session,
                    'workout': state.workout,
                    'movement': state.movement,
                    'detail': state.detail,
                    'restEndsAt': state.restEndsAt,
                  },
          );
        })
        .catchError((Object error) {
          debugPrint(
            'WorkoutActivity: could not update the iPhone workout ($error)',
          );
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // An activity can only start when the app is active. Retry a restored session on foreground entry and pick up changes to the system setting.
    if (state == AppLifecycleState.resumed && _latest != null) _send();
  }

  void dispose() => WidgetsBinding.instance.removeObserver(this);
}
