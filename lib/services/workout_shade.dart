import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/workout_cue.dart';
import '../util/format.dart';
import '../util/seed_names.dart';
import '../util/units.dart';
import 'notifications.dart' show NotificationChannelCopy;

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
/// ## The rest is controllable from here
///
/// It was not, on the argument that cutting a rest short is a decision and a
/// decision does not belong on a control you brush past through a coat. That
/// was wrong in the gym: the rest is the one stretch of a session you are
/// certainly *not* holding the phone for, and unlocking the phone to press Skip
/// costs more, every time, than an accidental press costs once. So a running
/// rest offers the same three controls the screen does — **−15s**, **+15s** and
/// **Skip** — with the same step, so the two places you can nudge a rest from do
/// not disagree about what a nudge is. See issue #62.
///
/// ## Logging a set sends you to the board
///
/// **Done**, **Missed** and **Start** all put the board in front of you on their
/// way past: the next thing after a set is logged is the weight for the next
/// one, the ramp, the rest that is now running — and after Missed, the number
/// that wants correcting. The rest controls do not, because the whole point of a
/// rest control in the shade is that you did not want the phone out.
///
/// **Sends you to, not raises.** A notification button cannot bring an app to
/// the front on Android 12 and up — see [_ShadeHandler.onNotificationButtonPressed]
/// for why, and for what it would cost to change that. So the press routes the
/// app to the board rather than lighting the screen up: unlock the phone and the
/// board is what is there. The way to raise it deliberately is to tap the
/// notification itself, which does work.
///
/// Everything is gated on Android. On any other platform — the iOS port to
/// come, and the test runner — every method is a no-op rather than a crash, the
/// same shape `ReminderService` uses.
///
/// ## Asking to post notifications
///
/// Declaring `POST_NOTIFICATIONS` in the manifest is not the same as holding
/// it: on Android 13 and up it is a runtime grant, and without it
/// `startService` starts, reports success and Android draws nothing. The
/// failure is an absence rather than an error, which is exactly why it went
/// unnoticed. So the shade asks, once, at the point it is first needed —
/// starting a session — rather than on launch, where a permission dialog is
/// noise beside a splash screen. A refusal is not an error: the workout runs as
/// before, minus the shade, and nothing interrupts it to say so.
///
/// ## It holds no words of its own
///
/// Every string it posts arrives finished, in a [ShadeCopy] the caller built —
/// see [shadeCopy]. The class itself never sees an `AppLocalizations`, which is
/// the only arrangement that survives where this runs: the notification is
/// written by a foreground service whose task handler lives in an isolate of
/// its own, with no widget tree and so no `BuildContext` to look a catalogue up
/// from. The one place that pushes state in here — `workoutShadeSyncProvider` —
/// already watches the language, so it composes the text and the service posts
/// it.
class WorkoutShade {
  /// [platformSupported] and [requestPermission] both default to the real
  /// thing; a test overrides them because the runner is not Android and there
  /// is no dialog to answer.
  WorkoutShade({
    bool? platformSupported,
    Future<bool> Function()? requestPermission,
  }) : _platformSupported = platformSupported ?? _isAndroid,
       _requestPermission = requestPermission ?? _askAndroid;

  final bool _platformSupported;
  final Future<bool> Function() _requestPermission;

  /// Whether the grant has been asked for yet, and what came back. Null until
  /// the first ask — after that the answer stands for the life of the object:
  /// Android suppresses the dialog after a refusal anyway, and the way back on
  /// is the phone's settings rather than anything here.
  bool? _permitted;

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  static Future<bool> _askAndroid() async =>
      await FlutterForegroundTask.requestNotificationPermission() ==
      NotificationPermission.granted;

  static const _channelId = 'live_workout';

  /// The button ids, which are also what crosses the isolate boundary.
  static const doneAction = 'set_done';
  static const missedAction = 'set_missed';
  static const startAction = 'set_start';
  static const restAddAction = 'rest_add';
  static const restSubAction = 'rest_sub';
  static const restSkipAction = 'rest_skip';

  /// What **−15s** and **+15s** move a rest by — the screen's own step.
  static const restStepSeconds = 15;

  /// The actions that put the board in front of you as well as reaching the
  /// session — see the class comment on why that is routing rather than raising.
  static const bringsAppForward = {doneAction, missedAction, startAction};

  /// What crosses the port instead of a button id once the press has been
  /// written down: "there is something in the record for you". The press itself
  /// travels in [PendingShadeActions], so that a live isolate and one that has
  /// to be started first both apply it the same way — and neither can apply it
  /// twice. A bare id still means "apply this now", for the press the record
  /// would not take.
  static const drainPoke = 'drain_pending';

  bool _ready = false;
  bool _running = false;

  /// The channel labels [_init] last registered, so a language switch re-runs it
  /// and nothing else does.
  NotificationChannelCopy? _channelCopy;

  /// Android is the only platform this ships on, and the only one with a
  /// foreground service to put a workout in. See issue #33.
  bool get supported => _platformSupported;

  /// The last answer [_up] gave, for a caller with no `await` to spare — a test
  /// asserting that a refusal started nothing. Not what [show] and [hide]
  /// decide on; see [_up] for why.
  bool get running => _running;

  /// Whether Android has the service up, **asked of Android rather than
  /// remembered**.
  ///
  /// A remembered flag is wrong across the death of the app's own isolate. The
  /// service runs its handler in an engine of its own, so Android can tear down
  /// the UI — a swipe out of the recents list, a reclaim under memory pressure —
  /// and leave the service and its notification exactly where they were.
  /// Reopening the app builds a fresh `WorkoutShade`, and a fresh one that
  /// believes nothing is up gets both halves of its job wrong: [show] tries to
  /// start a second service, which the plugin refuses, so the shade never
  /// updates again; and [hide] returns without stopping the first, so it is
  /// never taken down. That is the stale shade — a rest counting down for a
  /// workout finished an hour ago, with a Skip button wired to nothing.
  ///
  /// The platform is the only thing that knows. If asking fails, the remembered
  /// flag is the best guess left.
  Future<bool> get _up async {
    try {
      return await FlutterForegroundTask.isRunningService;
    } catch (e) {
      debugPrint('WorkoutShade: could not ask whether the service is up ($e)');
      return _running;
    }
  }

  /// Registers the channel [copy] names. Re-run whenever the language changes:
  /// Android takes a channel's name and description from the last call, so a
  /// switch is what re-labels the row in the phone's notification settings.
  /// Its *sound* is fixed at creation, but this channel is silent anyway.
  void _init(ShadeCopy copy) {
    if (_ready && _channelCopy == copy.channel) return;
    if (!supported) return;
    _channelCopy = copy.channel;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: copy.channel.name,
        channelDescription: copy.channel.description,
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

  /// Puts [copy] in the shade, starting the service if it is not up yet.
  ///
  /// Safe to call on every change of the session: an update is cheap and the
  /// alternative is tracking what changed.
  Future<void> show(ShadeCopy copy) async {
    if (!supported) return;
    _init(copy);

    final title = copy.title;
    final text = copy.text;
    final buttons = copy.buttons;

    try {
      if (await _up) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
          notificationButtons: buttons,
        );
        _running = true;
        return;
      }
      // Before the service, never after: a service started without the grant
      // draws nothing and says it succeeded.
      _permitted ??= await _requestPermission();
      if (_permitted != true) return;
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
  ///
  /// Asks Android whether there is a service to stop rather than trusting this
  /// object's memory of one — see [_up]. A shade left up after Finish outlives
  /// the session it describes, and there is nothing on it that would ever
  /// correct itself.
  Future<void> hide() async {
    if (!supported) return;
    try {
      if (await _up) await FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint('WorkoutShade: could not stop the service ($e)');
    }
    _running = false;
  }
}

/// The presses the shade has taken and the session has not applied yet.
///
/// **A press is written down before it is announced.** The buttons are pressed
/// in the one place the app is least likely to be alive — a phone in a pocket,
/// backgrounded, with Android free to reclaim the isolate that holds the
/// session. `sendDataToMain` needs somebody listening; with the isolate gone the
/// press went nowhere, so Missed raised the app and logged nothing. Here the
/// press outlives the isolate: the service records it, and whichever isolate
/// next holds the session applies it out of the record — the one that was
/// already running, or the one the press itself started.
///
/// **The record is the only path**, which is what stops a press being applied
/// twice. [take] clears before it hands anything over, so two drains racing
/// cannot both claim the same press; the loser gets an empty list. A press the
/// record refuses to hold falls back to the port and is applied there — see
/// [WorkoutShade.drainPoke].
///
/// The store is the foreground-task plugin's, which is `SharedPreferences`
/// underneath and so is reachable from the service's isolate and the app's
/// alike. Both seams default to it; a test passes its own cell, because the
/// runner has no platform to store anything on.
class PendingShadeActions {
  PendingShadeActions({
    Future<String?> Function()? read,
    Future<void> Function(String?)? write,
  }) : _read = read ?? _readStore,
       _write = write ?? _writeStore;

  static const _key = 'pending_shade_actions';

  final Future<String?> Function() _read;
  final Future<void> Function(String?) _write;

  static Future<String?> _readStore() =>
      FlutterForegroundTask.getData<String>(key: _key);

  static Future<void> _writeStore(String? value) async {
    if (value == null) {
      await FlutterForegroundTask.removeData(key: _key);
    } else {
      await FlutterForegroundTask.saveData(key: _key, value: value);
    }
  }

  /// Writes [id] down behind whatever is already waiting. Returns whether it
  /// was taken: a false answer is the service's cue to announce the press the
  /// old way rather than lose it.
  Future<bool> add(String id) async {
    try {
      await _write(jsonEncode([...await _queued(), id]));
      return true;
    } catch (e) {
      debugPrint('PendingShadeActions: could not write down $id ($e)');
      return false;
    }
  }

  /// Claims everything waiting, oldest first, and empties the record.
  Future<List<String>> take() async {
    final queued = await _queued();
    if (queued.isEmpty) return const [];
    await clear();
    return queued;
  }

  /// Drops the lot — the session these presses were made in has ended, and a
  /// press applied to the next one would be a set logged in the wrong workout.
  Future<void> clear() async {
    try {
      await _write(null);
    } catch (e) {
      debugPrint('PendingShadeActions: could not clear the record ($e)');
    }
  }

  /// What is waiting, or nothing at all. An unreadable record is dropped rather
  /// than retried: it would fail the same way on every launch, and a workout is
  /// not worth interrupting over a notification button.
  Future<List<String>> _queued() async {
    try {
      final raw = await _read();
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw FormatException('not a list', raw);
      return decoded.whereType<String>().toList();
    } catch (e) {
      debugPrint('PendingShadeActions: could not read the record ($e)');
      await clear();
      return const [];
    }
  }
}

/// Where a press waits when there is no isolate to hear it.
///
/// Beside its class rather than in `providers.dart`, as `sessionMirrorProvider`
/// is: the live session reads it to clear the record when a workout ends, and it
/// cannot import the provider layer — the provider layer imports it.
final pendingShadeActionsProvider = Provider<PendingShadeActions>(
  (ref) => PendingShadeActions(),
);

// ---- What it says ----------------------------------------------------------
//
// Top-level and public: this is the part with judgement in it, it is the part
// that has to read right at a glance through a coat pocket, and it can be
// tested without a platform anywhere near it.

/// Everything the shade posts, already in the app's language.
///
/// The whole of [WorkoutShade]'s vocabulary in one value, so the service takes
/// finished text and nothing else — see the note on that class.
typedef ShadeCopy = ({
  NotificationChannelCopy channel,
  String title,
  String text,
  List<NotificationButton> buttons,
});

/// What the shade should say for [cue], or **null when there is nothing left to
/// say** — every set is logged, and the caller should take the notification
/// down rather than post an empty one.
ShadeCopy? shadeCopy(AppLocalizations l10n, WorkoutCue cue, String unit) {
  if (cue.kind == CueKind.finished) return null;
  return (
    channel: (
      name: l10n.shadeChannelName,
      description: l10n.shadeChannelDescription,
    ),
    title: shadeTitle(l10n, cue),
    text: shadeText(l10n, cue, unit),
    buttons: shadeButtons(l10n, cue),
  );
}

/// The bold line: what you are doing, or how long is left.
String shadeTitle(AppLocalizations l10n, WorkoutCue cue) => switch (cue.kind) {
  CueKind.resting => l10n.shadeRestTitle(fmtDuration(cue.restLeft ?? 0)),
  CueKind.hold || CueKind.lift => shadeWhere(l10n, cue),
  CueKind.finished => l10n.shadeWorkoutTitle,
};

/// Where in the session you are: the movement, whether this is its ramp, and
/// which set of how many.
///
/// The count is the part four identical sets of bench need — without it every
/// one of them reads the same from a pocket, and the only way to tell the first
/// from the last is to open the app the shade exists to save you opening.
///
/// Four whole sentences rather than three fragments glued together: a language
/// that puts the ramp's name after the movement, or that declines it, cannot be
/// built out of a prefix and a suffix.
String shadeWhere(AppLocalizations l10n, WorkoutCue cue) {
  final name = seededName(l10n, cue.exerciseSeedKey, cue.exercise);
  final counted = cue.setCount > 0;
  if (cue.warmup) {
    return counted
        ? l10n.shadeWhereWarmupSet(name, cue.setIndex + 1, cue.setCount)
        : l10n.shadeWhereWarmup(name);
  }
  return counted
      ? l10n.shadeWhereExerciseSet(name, cue.setIndex + 1, cue.setCount)
      : l10n.shadeWhereExercise(name);
}

/// The second line: the set itself, in enough detail to load a bar from.
String shadeText(AppLocalizations l10n, WorkoutCue cue, String unit) {
  final what = describeCue(l10n, cue, unit);
  if (cue.kind != CueKind.resting) return what;
  // While resting the bold line is the countdown, so this is the only line the
  // exercise can be named on — and "Next: 80 kg × 8" is a weight and a rep
  // count belonging to nothing. "Next" itself is the difference between a
  // countdown and an instruction, so it stays.
  return l10n.shadeNextLine(shadeWhere(l10n, cue), what);
}

/// The buttons: two to log a set with, or three to run the rest with.
List<NotificationButton> shadeButtons(AppLocalizations l10n, WorkoutCue cue) =>
    switch (cue.kind) {
      CueKind.finished => const [],
      // Nothing to log during a rest — but the rest itself is the thing you are
      // least likely to have the phone in your hand for. See issue #62.
      //
      // The same three words the rest bar uses, from the same three keys: the
      // two places a rest can be nudged from must not disagree about what the
      // nudge is called any more than about what it does.
      CueKind.resting => [
        NotificationButton(
          id: WorkoutShade.restSubAction,
          text: l10n.sessionRestMinus,
        ),
        NotificationButton(
          id: WorkoutShade.restAddAction,
          text: l10n.sessionRestPlus,
        ),
        NotificationButton(
          id: WorkoutShade.restSkipAction,
          text: l10n.sessionRestSkip,
        ),
      ],
      // A hold cannot be "done at the goal" from a pocket — how long you held
      // it is the whole measurement — so it gets one button that raises the app
      // at the stopwatch instead, and logs nothing on the way.
      CueKind.hold => [
        NotificationButton(
          id: WorkoutShade.startAction,
          text: l10n.shadeStart,
        ),
      ],
      CueKind.lift => [
        NotificationButton(id: WorkoutShade.doneAction, text: l10n.shadeDone),
        NotificationButton(
          id: WorkoutShade.missedAction,
          text: l10n.shadeMissed,
        ),
      ],
    };

/// One line describing a set: the load and the target.
///
/// Kept out of [WorkoutShade] so it can be read and tested without a platform
/// anywhere near it — "80 kg × 8", "45s", "Bodyweight × 12".
String describeCue(AppLocalizations l10n, WorkoutCue cue, String unit) {
  final weight = cue.weightKg == null
      ? null
      : l10n.unitWeightShort(
          fmtCueWeight(cue.weightKg!, unit), unitSuffix(l10n, unit));
  final seconds = cue.seconds;
  if (seconds != null) {
    return weight == null
        ? l10n.unitSecondsShort('$seconds')
        : l10n.shadeSetWeightSeconds(weight, seconds);
  }
  final reps = cue.reps ?? 0;
  return weight == null
      ? l10n.shadeSetBodyweightReps(reps)
      : l10n.shadeSetWeightReps(weight, reps);
}

/// A weight for the shade, converted to the display unit.
String fmtCueWeight(double kg, String unit) =>
    fmtWeight(toDisplayWeight(kg, unit));

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
    // **No `launchApp` here, and it is not an omission.** A button on this
    // notification is a broadcast `PendingIntent`, so raising the app from one
    // means a broadcast receiver starting an activity — which Android 12 forbade
    // outright (the notification-trampoline restriction) and Android 10 already
    // refused from a service. `FlutterForegroundTask.launchApp` says as much: it
    // wants SYSTEM_ALERT_WINDOW, the "display over other apps" grant, which is
    // far too much to ask for the convenience of a screen coming up by itself.
    // The refusal is silent, which is what made it look like a bug in the app.
    //
    // What the buttons do instead is send you to the board: the press reaches
    // the session, which routes to it — see `applyShadeAction` — so the board is
    // what you find when you next look at the phone. Tapping the notification
    // *body* raises the app properly, because that one is an activity intent;
    // see [onNotificationPressed].
    //
    // Written down, then announced — never the other way round. A poke that
    // arrives before the write would find an empty record and drop the press.
    // See [PendingShadeActions] for why the record rather than the port.
    PendingShadeActions().add(id).then((written) {
      FlutterForegroundTask.sendDataToMain(
        written ? WorkoutShade.drainPoke : id,
      );
    });
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp('/session');
}
