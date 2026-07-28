import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The sound the rest timer makes when it runs out.
///
/// A rest that ends silently is a rest you overrun with the phone in your
/// pocket, which is most of what the timer is for.
///
/// **What it plays.** One asset, `assets/sound/rest_done.wav` — one note,
/// struck and fading, under three-tenths of a second. It was two notes a fifth
/// apart to begin with, which reads as "da-dong": a little melody is a thing
/// you notice having heard, and a rest ending is one event you act on.
///
/// It is *synthesised*, not sourced, so there is no licence attached to it and
/// nothing to attribute. The generator lives in `tool/make_rest_tone.dart` —
/// beside the asset rather than in a commit message, because a wav is a binary
/// nobody can review and the pitch, the envelope and the length are the design.
///
/// **What it respects.** The audio is declared as an *alarm* on Android, which
/// is what puts it on the alarm stream rather than the media one: it follows
/// the phone's own silent and Do-Not-Disturb behaviour instead of overriding
/// it. It takes *transient* focus for the length of the tone, which pauses
/// music for a fraction of a second and hands it straight back — the first
/// version merely asked whatever was playing to duck if it felt like it, and
/// the answer to that on most players is no, which is half of why this was
/// reported as too quiet.
///
/// **What it does not do.** It plays while the app is on screen, and only then
/// — with the phone in a pocket the ding is a notification's job, which is
/// [RestAlarm]'s. The two are picked between in
/// `ActiveWorkoutController.stopRest`. Nothing here needs a network permission,
/// and `audioplayers` is MIT.
class RestTone {
  RestTone({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  bool _ready = false;

  /// Whether this platform has audio to play through at all.
  ///
  /// Note this is a *platform* check, not an environment one: a widget test
  /// reports Android, so it says true there and the call goes on to fail
  /// harmlessly against a channel that is not registered. That is why [play]
  /// swallows rather than relying on this to stay out of trouble.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Plays the tone once. Silent when [enabled] is false — the user's own
  /// switch, which the phone's silent mode outranks either way.
  ///
  /// Never throws: a device with no audio route, a locked player, an asset that
  /// failed to decode — none of that is worth interrupting a workout over, and
  /// the alternative to a tone is the timer people already read off the screen.
  Future<void> play({required bool enabled}) async {
    if (!enabled || !supported) return;
    try {
      if (!_ready) {
        await _player.setAudioContext(_context);
        await _player.setReleaseMode(ReleaseMode.stop);
        // Full scale. The stream's own volume is the user's to set; quieting
        // the app's one sound underneath it is not a decision to make here.
        await _player.setVolume(1.0);
        _ready = true;
      }
      await _player.stop();
      await _player.play(AssetSource('sound/rest_done.wav'));
    } catch (_) {
      // Deliberately swallowed. See above.
    }
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }

  /// The alarm stream on Android, and a category on iOS that mixes rather than
  /// taking the session over.
  static final AudioContext _context = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.alarm,
      audioFocus: AndroidAudioFocus.gainTransient,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );
}
