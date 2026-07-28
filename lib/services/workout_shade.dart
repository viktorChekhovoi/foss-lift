import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../state/workout_cue.dart';
import '../util/format.dart';
import '../util/units.dart';

/// The live workout in the notification shade.
///
/// Start a workout, put the phone in a pocket, and the session used to be
/// invisible until the app came back. This puts it where a straightforward set
/// needs no screen at all: what to lift, or how long is left of the rest, and
/// two buttons.
///
/// ## Why a foreground service
///
/// Not for the notification — an ordinary one would draw the same thing. It is
/// for the *process*. The live session is deliberately in memory and never
/// written to the database until Finish, so a **Done** press has to reach the
/// isolate that holds it. Without a foreground service Android is free to kill
/// the app once it is backgrounded, and the press would arrive somewhere with no
/// workout in it. The service is what makes "in memory" survivable rather than
/// a reason to start persisting mid-workout.
///
/// ## What it does not do
///
/// **Rest is not skippable from here.** Cutting a rest short is a decision, and
/// a decision does not belong on a control you brush past through a coat.
///
/// Everything is gated on Android. On any other platform — the iOS port to
/// come, and the test runner — every method is a no-op rather than a crash, the
/// same shape `ReminderService` uses.
class WorkoutShade {
  static const _channelId = 'live_workout';
  static const _channelName = 'Live workout';
  static const _channelDescription =
      'Shows the set you are on while a workout is running.';

  /// The button ids, which are also what crosses the isolate boundary.
  static const doneAction = 'set_done';
  static const missedAction = 'set_missed';

  bool _ready = false;
  bool _running = false;

  /// Android is the only platform this ships on, and the only one with a
  /// foreground service to put a workout in. See issue #33.
  bool get supported => !kIsWeb && Platform.isAndroid;

  /// Whether the service is currently up. Read by the tests and by [show].
  bool get running => _running;

  void _init() {
    if (_ready || !supported) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: _channelName,
        channelDescription: _channelDescription,
        // Low importance and silent: this notification is *furniture* for the
        // length of a workout, not an alert. The one thing that should make a
        // sound — the rest ending — is the tone, which has its own switch.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        playSound: false,
        enableVibration: false,
        // It is rewritten every second while a rest runs; alerting once keeps
        // that from being a heads-up notification sixty times over.
        onlyAlertOnce: true,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // The app drives every update from the session, so the task itself has
        // nothing periodic to do.
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        autoRunOnBoot: false,
        allowAutoRestart: false,
      ),
    );
    _ready = true;
  }

  /// Puts [cue] in the shade, starting the service if it is not up yet.
  ///
  /// Safe to call on every change of the session: an update is cheap and the
  /// alternative is tracking what changed.
  Future<void> show(WorkoutCue cue, {required String unit}) async {
    if (!supported) return;
    if (cue.kind == CueKind.finished) return hide();
    _init();

    final title = _title(cue, unit);
    final text = _text(cue, unit);
    final buttons = _buttons(cue);

    try {
      if (_running) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
          notificationButtons: buttons,
        );
        return;
      }
      final result = await FlutterForegroundTask.startService(
        serviceTypes: const [ForegroundServiceTypes.specialUse],
        notificationTitle: title,
        notificationText: text,
        notificationButtons: buttons,
        // Tapping the notification itself goes to the session, not to Today.
        notificationInitialRoute: '/session',
        callback: startWorkoutShade,
      );
      _running = result is ServiceRequestSuccess;
    } catch (e) {
      // A refused permission, an OEM that will not start the service, a
      // platform channel that is not there. None of it is worth interrupting a
      // workout over — the app on screen is unaffected.
      debugPrint('WorkoutShade: could not show the live workout ($e)');
    }
  }

  /// Takes it down. Finishing and aborting both end here.
  Future<void> hide() async {
    if (!supported || !_running) return;
    try {
      await FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint('WorkoutShade: could not stop the service ($e)');
    }
    _running = false;
  }

  // ---- What it says --------------------------------------------------------
  //
  // Public for the tests: this is the part with judgement in it, and it is the
  // part that has to read right at a glance through a coat pocket.

  /// The bold line: what you are doing, or how long is left.
  static String _title(WorkoutCue cue, String unit) => switch (cue.kind) {
        CueKind.resting => 'Rest · ${fmtDuration(cue.restLeft ?? 0)}',
        CueKind.hold => cue.warmup ? 'Warm-up · ${cue.exercise}' : cue.exercise,
        CueKind.lift => cue.warmup ? 'Warm-up · ${cue.exercise}' : cue.exercise,
        CueKind.finished => 'Workout',
      };

  /// The second line: the set itself, in enough detail to load a bar from.
  static String _text(WorkoutCue cue, String unit) {
    final what = describeCue(cue, unit);
    // While resting, the set named is the one *after* the rest, so say so —
    // "next" is the difference between a countdown and an instruction.
    return cue.kind == CueKind.resting ? 'Next: $what' : what;
  }

  /// The two buttons — and only while there is a set to answer for.
  ///
  /// A rest offers none. There is nothing to log yet, and the one control that
  /// might belong here (skip) is deliberately absent.
  static List<NotificationButton> _buttons(WorkoutCue cue) {
    if (cue.kind == CueKind.resting || cue.kind == CueKind.finished) {
      return const [];
    }
    return [
      // A hold cannot be "done at the goal" from a pocket — how long you held
      // it is the whole measurement — so it gets one button that opens the app
      // at the stopwatch instead.
      if (cue.kind == CueKind.hold)
        const NotificationButton(id: missedAction, text: 'Open')
      else ...const [
        NotificationButton(id: doneAction, text: 'Done'),
        NotificationButton(id: missedAction, text: 'Missed'),
      ],
    ];
  }
}

/// One line describing a set: the load and the target.
///
/// Kept out of [WorkoutShade] so it can be read and tested without a platform
/// anywhere near it — "80 kg × 8", "45s", "Bodyweight × 12".
String describeCue(WorkoutCue cue, String unit) {
  final weight = cue.weightKg == null
      ? null
      : '${fmtCueWeight(cue.weightKg!, unit)} ${unitLabel(unit)}';
  if (cue.seconds != null) {
    return weight == null ? '${cue.seconds}s' : '$weight · ${cue.seconds}s';
  }
  final reps = '${cue.reps ?? 0}';
  return weight == null ? 'Bodyweight × $reps' : '$weight × $reps';
}

/// A weight for the shade: no trailing `.0`, converted to the display unit.
String fmtCueWeight(double kg, String unit) {
  final v = toDisplayWeight(kg, unit);
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// The service's entry point, which Android calls in its own isolate.
///
/// It holds no session state and makes no decisions — it cannot, since the
/// workout is in the main isolate's memory. Its whole job is to pass a button
/// press back across, where the session is.
@pragma('vm:entry-point')
void startWorkoutShade() {
  FlutterForegroundTask.setTaskHandler(_ShadeHandler());
}

class _ShadeHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    // Straight back to the isolate that holds the workout. "Missed" also brings
    // the app forward, because the number it seeds is one you are meant to
    // correct — see the note on missedSeed.
    FlutterForegroundTask.sendDataToMain(id);
    if (id == WorkoutShade.missedAction) {
      FlutterForegroundTask.launchApp('/session');
    }
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp('/session');
}
