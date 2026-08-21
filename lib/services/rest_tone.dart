import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays the synthesized rest-complete tone through the platform alarm stream; failures are ignored so audio problems never interrupt a workout.

bool restToneSupportedOn({
  required bool isWeb,
  required TargetPlatform platform,
}) =>
    isWeb ||
    platform == TargetPlatform.android ||
    platform == TargetPlatform.iOS;

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
      restToneSupportedOn(isWeb: kIsWeb, platform: defaultTargetPlatform);

  /// Plays the tone once, at whatever the phone's alarm stream is set to.
  ///
  /// Never throws: a device with no audio route, a locked player, an asset that
  /// failed to decode — none of that is worth interrupting a workout over, and
  /// the alternative to a tone is the timer people already read off the screen.
  Future<void> play() async {
    if (!supported) return;
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
      // A partial wake lock for the length of the tone. The foreground service
      // already holds one, so this is belt and braces — but the sound that most
      // needs to arrive is the one with the screen off, and half a second of CPU
      // is not worth being clever about. `WAKE_LOCK` is already in the manifest.
      stayAwake: true,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.alarm,
      audioFocus: AndroidAudioFocus.gainTransient,
    ),
    // `ambient` already mixes, and asking for `mixWithOthers` on top of it is
    // an error the package asserts on — which in a debug build meant this whole
    // context threw on construction and `play` swallowed it, so the tone never
    // sounded at all. The category is the thing that was wanted; the option was
    // the same wish stated twice.
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );
}
