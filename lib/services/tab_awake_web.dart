/// The keepalive in a browser: a tone below hearing, held for the length of a
/// workout.
///
/// Reached through `tab_awake.dart` — never imported directly, and see there
/// for why this exists and what it costs.
library;

import 'package:web/web.dart' as web;

/// How loud the inaudible tone is.
///
/// Not zero: the throttling exemption is for *audible* output and the browser
/// judges it by level, so digital silence would be ignored and the whole thing
/// would buy nothing. This is roughly -60 dB relative to full scale — below the
/// noise floor of any real output, and above whatever the browser's threshold
/// is.
const double _kInaudibleGain = 0.001;

/// The pitch it sits at.
///
/// Low, and deliberately not near the rest tone: if a browser ever does make
/// this faintly audible on some output, a low hum is less objectionable than
/// something in the range the ear is most sensitive to — and it cannot be
/// mistaken for the tone that means a rest is over.
const double _kHz = 60;

class TabAwake {
  web.AudioContext? _context;
  web.OscillatorNode? _oscillator;

  /// Whether this build has anything to hold.
  static bool get supported => true;

  bool get held => _oscillator != null;

  /// Starts the tone, if it is not already going.
  ///
  /// Never throws. A browser that refuses to build an `AudioContext`, or one
  /// that has not been interacted with yet, simply leaves the tab throttleable
  /// — which is where it was anyway. The clocks are correct either way; this
  /// only changes how promptly a rest announces itself.
  void hold() {
    if (held) return;
    try {
      final context = _context ??= web.AudioContext();
      // Autoplay policy: a context built before the page was interacted with
      // starts suspended. Starting a workout is a tap, so this normally
      // resolves at once — and where it does not, the oscillator below simply
      // makes no sound and nothing else is affected.
      context.resume();
      final gain = context.createGain();
      gain.gain.value = _kInaudibleGain;
      gain.connect(context.destination);
      final oscillator = context.createOscillator();
      oscillator.frequency.value = _kHz;
      oscillator.connect(gain);
      oscillator.start();
      _oscillator = oscillator;
    } catch (_) {
      _oscillator = null;
    }
  }

  /// Stops it. Idempotent, and never throws for the same reasons as [hold].
  ///
  /// The `AudioContext` itself is kept rather than closed: a session is
  /// followed by another session often enough, and building one is the
  /// expensive half. It holds no audio focus once the oscillator is stopped.
  void release() {
    final oscillator = _oscillator;
    _oscillator = null;
    if (oscillator == null) return;
    try {
      oscillator.stop();
      oscillator.disconnect();
    } catch (_) {
      // Already stopped, or the context went away with the page. Either way
      // there is nothing left to hold.
    }
  }

  void dispose() {
    release();
    try {
      _context?.close();
    } catch (_) {}
    _context = null;
  }
}
