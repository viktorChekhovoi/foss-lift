import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/workout_cue.dart';
import '../util/units.dart';
import 'notification_ids.dart';
import 'notifications.dart';

/// The live workout in the notification shade.
///
/// Start a workout, put the phone in a pocket, and the session used to be
/// invisible until the app came back. This puts it where a straightforward set
/// needs no screen at all: what to lift, or how long is left of the rest, and
/// two buttons.
///
/// ## An ordinary notification, and no foreground service
///
/// It was a foreground service, and that was never about the notification — an
/// ordinary one draws the same thing. It was about the *process*: the live
/// session is deliberately in memory and never written to the database until
/// Finish, so a **Done** press has to reach the isolate that holds it, and
/// without a service Android is free to kill that isolate once the app is
/// backgrounded.
///
/// Play will not have a foreground service on those terms. Every
/// `FOREGROUND_SERVICE_*` type needs a console declaration and a video
/// demonstrating the feature, which is more than a rest timer is worth, and the
/// requirement is per type so there is no subtype to retreat to. So the shade is
/// a plain ongoing notification on a silent LOW channel, this app claims no
/// privilege to stay alive behind it, and the two things a dying isolate used to
/// take with it are held elsewhere instead:
///
///   * the session itself, by `SessionMirror`'s crash snapshot;
///   * the press, by [PendingShadeActions] — Android spawns an isolate of its
///     own to deliver a notification action, and that isolate writes the press
///     down where whichever isolate next holds the session can find it.
///
/// What is genuinely lost is that the text stops keeping up. The countdown stays
/// right because Android owns it (see [shadeRestEnd]), but the set named above it
/// is whatever was true when the app was last alive.
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
/// the front on Android 12 and up — see [shadeActionInBackground] for why, and
/// for what it would cost to change that. So the press routes the app to the
/// board rather than lighting the screen up: unlock the phone and the board is
/// what is there. The way to raise it deliberately is to tap the notification
/// itself, which does work, because that one is an activity intent.
///
/// Everything is gated on Android. On any other platform — the iOS port to
/// come, and the test runner — every method is a no-op rather than a crash, the
/// same shape `ReminderService` uses.
///
/// ## Asking to post notifications
///
/// Declaring `POST_NOTIFICATIONS` in the manifest is not the same as holding
/// it: on Android 13 and up it is a runtime grant, and without it the
/// notification is posted, reports success and is drawn nowhere. The failure is
/// an absence rather than an error, which is exactly why it went unnoticed. So
/// the shade asks, once, at the point it is first needed — starting a session —
/// rather than on launch, where a permission dialog is noise beside a splash
/// screen. A refusal is not an error: the workout runs as before, minus the
/// shade, and nothing interrupts it to say so.
class WorkoutShade {
  /// Every argument defaults to the real thing; a test overrides them because
  /// the runner is not Android and there is no dialog to answer.
  WorkoutShade({
    FlutterLocalNotificationsPlugin? plugin,
    bool? platformSupported,
    Future<bool> Function()? requestPermission,
    this.onTapped,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _platformSupported = platformSupported ?? _isAndroid,
       _requestPermission = requestPermission ?? _askAndroid;

  final FlutterLocalNotificationsPlugin _plugin;
  final bool _platformSupported;
  final Future<bool> Function() _requestPermission;

  /// What a tap on the notification body does — the board, and it is the provider
  /// layer that knows how to get there. Null in a test that does not care and
  /// everywhere off Android; the tap is then a plain raise of the app.
  final void Function()? onTapped;

  /// Whether the grant has been asked for yet, and what came back. Null until
  /// the first ask — after that the answer stands for the life of the object:
  /// Android suppresses the dialog after a refusal anyway, and the way back on
  /// is the phone's settings rather than anything here.
  bool? _permitted;

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  static const _channelId = 'live_workout';
  static const _channelName = 'Live workout';
  static const _channelDescription =
      'Shows the set you are on while a workout is running.';

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

  bool _ready = false;
  bool _running = false;

  /// Android is the only platform this ships on, and the only one with a shade
  /// to put a workout in. See issue #33.
  bool get supported => _platformSupported;

  /// Whether the last [show] got as far as posting anything — for a caller with
  /// no `await` to spare, and for a test asserting that a refusal drew nothing.
  /// Not what [show] and [hide] decide on: neither of them trusts it.
  bool get running => _running;

  /// Puts [cue] in the shade.
  ///
  /// Safe to call on every change of the session: re-posting the same id
  /// rewrites the one notification, and the alternative is tracking what
  /// changed.
  Future<void> show(WorkoutCue cue, {required String unit}) async {
    if (!supported) return;
    if (cue.kind == CueKind.finished) return hide();

    try {
      await _init();
      // Before posting, never after: a notification posted without the grant is
      // drawn nowhere and says it succeeded.
      _permitted ??= await _requestPermission();
      if (_permitted != true) return;
      await _plugin.show(
        id: kLiveWorkoutId,
        title: shadeTitle(cue),
        body: shadeText(cue, unit),
        notificationDetails: _details(cue),
      );
      _running = true;
    } catch (e) {
      // A refused permission, an OEM with opinions about ongoing notifications,
      // a platform channel that is not there. None of it is worth interrupting
      // a workout over — the app on screen is unaffected.
      debugPrint('WorkoutShade: could not show the live workout ($e)');
    }
  }

  /// Takes it down. Finishing and aborting both end here.
  ///
  /// **Cancels whether or not this object posted anything.** Android is free to
  /// reclaim the isolate mid-workout and leave the notification standing, so the
  /// shade the next launch builds has no memory of one that is still on screen.
  /// A shade left up outlives the session it describes, and there is nothing on
  /// it that would ever correct itself — a rest counting down for a workout that
  /// finished an hour ago, with a Skip button wired to nothing. Cancelling an id
  /// that is not there costs nothing.
  Future<void> hide() async {
    if (!supported) return;
    try {
      await _plugin.cancel(id: kLiveWorkoutId);
    } catch (e) {
      debugPrint('WorkoutShade: could not take the live workout down ($e)');
    }
    _running = false;
  }

  /// The real ask. Off the plugin singleton rather than this object's [_plugin],
  /// because an initializer list cannot reach a field it is still building —
  /// which costs nothing, since the two are the same instance anywhere the
  /// question can be asked, and a test overrides this whole function.
  static Future<bool> _askAndroid() async {
    final android = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Furniture rather than an alert, and a countdown Android runs itself.
  ///
  /// Silent, LOW and `onlyAlertOnce`: this notification is rewritten on every
  /// change of the session, and the one thing that should make a sound — the
  /// rest ending — is `RestAlarm`'s job on a channel of its own. `ongoing` with
  /// `autoCancel` off keeps a workout in progress from being swiped away or
  /// dismissed by a press on one of its own buttons.
  NotificationDetails _details(WorkoutCue cue) {
    final end = shadeRestEnd(cue, DateTime.now());
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        category: AndroidNotificationCategory.workout,
        playSound: false,
        enableVibration: false,
        silent: true,
        onlyAlertOnce: true,
        ongoing: true,
        autoCancel: false,
        // The countdown lives where Android draws a notification's timestamp,
        // as a chronometer running down to the instant the rest ends. There is
        // nothing to count down to otherwise, and a timestamp reading "now" on
        // a notification that has been up for half an hour is worse than none.
        showWhen: end != null,
        when: end?.millisecondsSinceEpoch,
        usesChronometer: end != null,
        chronometerCountDown: true,
        actions: shadeButtons(cue),
      ),
    );
  }

  Future<void> _init() async {
    if (_ready) return;
    // Both of the shade's ways back into the app are registered here, and
    // `initNotifications` is why neither is lost when one of the other two
    // notification services initializes the same plugin afterwards.
    await initNotifications(
      _plugin,
      onLiveWorkoutTap: onTapped,
      onBackgroundResponse: shadeActionInBackground,
    );
    // Created explicitly rather than left to the first post: a channel's
    // importance and sound are fixed when Android first creates it, and this one
    // has to be silent from the start.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
          ),
        );
    _ready = true;
  }
}

/// A button press, taken in the isolate Android starts to deliver it.
///
/// **No attempt to raise the app here, and it is not an omission.** A button on
/// this notification is a broadcast `PendingIntent`, so raising the app from one
/// means a broadcast receiver starting an activity — which Android 12 forbade
/// outright (the notification-trampoline restriction) and Android 10 already
/// refused from a service. Doing it anyway needs `SYSTEM_ALERT_WINDOW`, the
/// "display over other apps" grant, which is far too much to ask for the
/// convenience of a screen coming up by itself. The refusal is silent, which is
/// what made it look like a bug in the app.
///
/// What the buttons do instead is send you to the board: the press is written
/// down here, the session applies it out of the record — see `applyShadeAction`
/// — and the board is what you find when you next look at the phone. Tapping the
/// notification *body* raises the app properly, because that one is an activity
/// intent.
///
/// **The record is the only path.** This isolate is not the one holding the
/// session and cannot reach it: it is a second engine, started by the plugin's
/// `ActionBroadcastReceiver` for exactly as long as the press takes. So there is
/// nothing to announce a press *to*, which is also why nothing here has to
/// decide whether the app is alive.
@pragma('vm:entry-point')
void shadeActionInBackground(NotificationResponse response) {
  final id = response.actionId;
  if (id == null || response.id != kLiveWorkoutId) return;
  PendingShadeActions().add(id);
}

/// The presses the shade has taken and the session has not applied yet.
///
/// **A press is written down before it can be applied.** The buttons are pressed
/// in the one place the app is least likely to be alive — a phone in a pocket,
/// backgrounded, with Android free to reclaim the isolate that holds the
/// session. Here the press outlives that isolate: whichever isolate next holds
/// the session applies it out of the record — the one that was already running,
/// or the one the next launch restores from the snapshot.
///
/// **The record is also what stops a press being applied twice.** [take] clears
/// before it hands anything over, so two drains racing cannot both claim the
/// same press; the loser gets an empty list.
///
/// The store is `SharedPreferencesAsync`, and both halves of that matter.
/// Shared preferences because the isolate that writes and the isolate that reads
/// are different ones in the same process. *Async* because the other API caches
/// every value at the moment it is opened and reads out of that copy — which
/// would hide a press written by the other isolate for as long as the app lived.
///
/// Both seams default to it; a test passes its own cell, because the runner has
/// no platform to store anything on.
class PendingShadeActions {
  PendingShadeActions({
    Future<String?> Function()? read,
    Future<void> Function(String?)? write,
  }) : _read = read ?? _readStore,
       _write = write ?? _writeStore;

  static const _key = 'pending_shade_actions';

  final Future<String?> Function() _read;
  final Future<void> Function(String?) _write;

  static final _store = SharedPreferencesAsync();

  /// Android only, like everything else here — there is no shade to press a
  /// button on anywhere else, and a test runner has no store to reach for.
  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  static Future<String?> _readStore() async =>
      _isAndroid ? await _store.getString(_key) : null;

  static Future<void> _writeStore(String? value) async {
    if (!_isAndroid) return;
    if (value == null) {
      await _store.remove(_key);
    } else {
      await _store.setString(_key, value);
    }
  }

  /// Writes [id] down behind whatever is already waiting. Returns whether it was
  /// taken; a false answer means the press is lost, and there is nowhere else to
  /// put it.
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

/// Where a press waits until there is a session to apply it to.
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

/// The bold line: what you are doing, or that you are resting.
///
/// **No number while a rest runs.** The countdown is the chronometer's — see
/// [shadeRestEnd] — and a copy of it written into the title would have to be
/// rewritten every second by a process Android is free to freeze. A frozen
/// countdown is worse than no countdown, because it looks like a working one.
String shadeTitle(WorkoutCue cue) => switch (cue.kind) {
  CueKind.resting => 'Rest',
  CueKind.hold || CueKind.lift => shadeWhere(cue),
  CueKind.finished => 'Workout',
};

/// The instant a running rest ends, for Android to count down to — and null for
/// everything else, which has nothing to count down to.
DateTime? shadeRestEnd(WorkoutCue cue, DateTime now) =>
    cue.kind == CueKind.resting
    ? now.add(Duration(seconds: cue.restLeft ?? 0))
    : null;

/// Where in the session you are: the movement, whether this is its ramp, and
/// which set of how many.
///
/// The count is the part four identical sets of bench need — without it every
/// one of them reads the same from a pocket, and the only way to tell the first
/// from the last is to open the app the shade exists to save you opening.
String shadeWhere(WorkoutCue cue) {
  final warmup = cue.warmup ? 'Warm-up · ' : '';
  final of = cue.setCount > 0
      ? ' · Set ${cue.setIndex + 1}/${cue.setCount}'
      : '';
  return '$warmup${cue.exercise}$of';
}

/// The second line: the set itself, in enough detail to load a bar from.
String shadeText(WorkoutCue cue, String unit) {
  final what = describeCue(cue, unit);
  if (cue.kind != CueKind.resting) return what;
  // While resting the bold line is the countdown, so this is the only line the
  // exercise can be named on — and "Next: 80 kg × 8" is a weight and a rep
  // count belonging to nothing. "Next" itself is the difference between a
  // countdown and an instruction, so it stays.
  return 'Next: ${shadeWhere(cue)} · $what';
}

/// The buttons: two to log a set with, or three to run the rest with.
///
/// None of them dismisses the notification and none claims to open the app.
/// −15s twice in a row is the ordinary case, so a shade that went away on the
/// first press would take the rest's controls with it; and a button that says it
/// shows a user interface is a broadcast promising an activity it may not start
/// — see [shadeActionInBackground].
List<AndroidNotificationAction> shadeButtons(WorkoutCue cue) =>
    switch (cue.kind) {
      CueKind.finished => const [],
      // Nothing to log during a rest — but the rest itself is the thing you are
      // least likely to have the phone in your hand for. See issue #62.
      CueKind.resting => const [
        _ShadeButton(WorkoutShade.restSubAction, '−15s'),
        _ShadeButton(WorkoutShade.restAddAction, '+15s'),
        _ShadeButton(WorkoutShade.restSkipAction, 'Skip'),
      ],
      // A hold cannot be "done at the goal" from a pocket — how long you held
      // it is the whole measurement — so it gets one button that sends you to
      // the stopwatch instead, and logs nothing on the way.
      CueKind.hold => const [_ShadeButton(WorkoutShade.startAction, 'Start')],
      CueKind.lift => const [
        _ShadeButton(WorkoutShade.doneAction, 'Done'),
        _ShadeButton(WorkoutShade.missedAction, 'Missed'),
      ],
    };

/// An action with this app's two answers to the flags that matter already
/// filled in — see [shadeButtons] for why both are off.
class _ShadeButton extends AndroidNotificationAction {
  const _ShadeButton(super.id, super.title)
    : super(cancelNotification: false, showsUserInterface: false);
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
