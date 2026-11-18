import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Sends session changes to ActivityKit in order. The widget counts down from the deadline without waking Dart every second.
class WorkoutActivity with WidgetsBindingObserver {
  WorkoutActivity() {
    WidgetsBinding.instance.addObserver(this);
  }

  static const _channel = MethodChannel(
    'com.fosslift.foss_lift/workout_activity',
  );
  Future<void> _pending = Future.value();
  Map<String, Object?>? _latest;
  String? _lastPayload;
  int _revision = 0;

  void handleActions(Future<void> Function(Map<Object?, Object?>) apply) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'performAction') throw MissingPluginException();
      await apply(call.arguments as Map<Object?, Object?>);
      return true;
    });
    unawaited(
      _channel.invokeMethod<void>('ready').catchError((Object error) {
        debugPrint('WorkoutActivity: could not register its controls ($error)');
      }),
    );
  }

  Future<void> sync(Map<String, Object?>? state) {
    // The labels and controls are nested lists. Compare their contents so clock ticks and provider rebuilds don't republish the activity.
    final payload = jsonEncode(state);
    if (payload == _lastPayload) return _pending;
    _lastPayload = payload;
    _latest = state;
    _send();
    return _pending;
  }

  void _send() {
    final revision = ++_revision;
    _pending = _pending
        .then((_) async {
          if (_revision != revision) return;
          await _channel.invokeMethod<void>('sync', _latest);
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

  void dispose() {
    _channel.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
  }
}
