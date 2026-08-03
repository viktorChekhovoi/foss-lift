import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The sound the rest timer makes when it runs out.
///
/// A rest that ends silently is a rest you overrun with the phone in your
/// pocket, which is most of what the timer is for.
///
/// **What it plays.** One asset, `assets/sound/rest_done.wav` — one note,
/// struck and fading, under half a second. It was two notes a fifth
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
/// **It plays with the phone in a pocket too**, which it did not always. The
/// off-screen ding used to be a notification channel's own sound, posted
/// whenever Android got round to it. Both cases take this route now, so the
/// same asset sounds the same way wherever the phone is.
///
/// **How loud it is is not this app's business.** The alarm stream already has
/// a slider on it, on every phone, reachable with the hardware keys; a gain of
/// the app's own stacked on top would be a second number to get wrong for one
/// question.
///
/// Three things have to hold for that, and all three do. The countdown is a
/// timer in the app's own isolate, so the end of a rest is reached here rather
/// than in the foreground service's isolate. The live session runs behind that
/// foreground service, so the process is still alive to reach it — and Android
/// permits background audio to an app running a foreground service that is not
/// `SHORT_SERVICE`, which `specialUse` is not. And `audioplayers` holds only the
/// *application* context, so nothing here depends on an activity being up.
///
/// What is still silent is the rest that ends with the app not running at all —
/// a force-stop, or a reclaim the service did not prevent. Nothing is handed to
/// Android in advance to cover that; see [RestAlarm].
///
/// Nothing here needs a network permission, and `audioplayers` is MIT.
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
