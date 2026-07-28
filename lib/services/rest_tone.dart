import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The sound the rest timer makes when it runs out.
///
/// A rest that ends silently is a rest you overrun with the phone in your
/// pocket, which is most of what the timer is for.
///
/// **What it plays.** One asset, `assets/sound/rest_done.wav` — two notes a
/// fifth apart, about six-tenths of a second. It is *synthesised*, not sourced,
/// so there is no licence attached to it and nothing to attribute. The
/// generator is recorded in the commit that added it.
///
/// **What it respects.** The audio is declared as an *alarm* on Android, which
/// is what puts it on the alarm stream rather than the media one: it follows
/// the phone's own silent and Do-Not-Disturb behaviour instead of overriding
/// it, and it does not duck or stop whatever music is already playing —
/// `AudioContextAndroid.audioFocus` is `gain` for the length of the tone and
/// nothing more. Wanting a rest timer is not wanting your album interrupted.
///
/// **What it does not do.** It plays while the app is running. Firing with the
/// screen off and the app in the background is a notification's job, not a
/// media player's, and belongs with the notification-shade work — see issue
/// #37. Nothing here needs a network permission, and `audioplayers` is MIT.
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
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );
}
