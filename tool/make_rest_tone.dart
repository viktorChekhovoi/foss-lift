// Generates `assets/sound/rest_done.wav` — the sound the rest timer makes when
// it runs out.
//
// Run it from the repository root:
//
//     dart run tool/make_rest_tone.dart
//
// It overwrites the asset in place and prints what it wrote. There is nothing
// random in here, so re-running it reproduces the same file byte for byte; a
// diff on the wav that is not preceded by a diff on this script is a mistake.
//
// **Why the generator is committed.** The tone is synthesised rather than
// sourced, which is what keeps it free of any licence and of anything to
// attribute — but a wav is a binary nobody can review, and the pitch, the
// envelope and the length *are* the design. They belong somewhere they can be
// read and argued with. It is deliberately not built in CI either: an asset
// that only exists in a release is one no developer has ever heard and no test
// can play.
//
// **Why one note.** The first version of this was two notes a fifth apart,
// which reads as "da-dong". A little melody is a thing you notice having heard;
// a rest ending is one event you act on, so it gets one strike. The octave
// underneath the fundamental is not a second note — it shares the single
// envelope and is there to keep the tone from sounding like a test tone.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// 44.1 kHz, the rate every phone resamples to anyway.
const _sampleRate = 44100;

/// A5. High enough to carry over a gym without being shrill, and well inside
/// the range a phone speaker can actually produce at volume.
const _fundamental = 880.0;

/// A quiet octave over the fundamental. Under the same envelope, so it is
/// brightness rather than a second voice.
const _harmonicGain = 0.22;

/// The whole thing, attack and decay together.
///
/// Longer than it first was. A tone that is over in a quarter of a second is
/// one you can miss between two clangs of somebody else's barbell, and the
/// complaint about this ding was that it is too quiet — half of which is
/// duration, not amplitude.
const _seconds = 0.45;

/// How quickly it reaches full volume. Long enough not to click, short enough
/// to read as a strike rather than a swell.
const _attackSeconds = 0.004;

/// How fast the decay falls away, in time constants over the tone's length. A
/// bigger number is a shorter, drier ding. Slower than it was, so the strike
/// rings out rather than being a tick.
const _decayRate = 3.5;

/// Peak amplitude, of a possible 1.0. Effectively the ceiling: the two partials
/// are normalised below, so this cannot clip, and there is no reason to leave
/// headroom on a sound whose whole job is to be heard across a gym.
const _peak = 0.99;

void main() {
  final samples = _render();
  final wav = _wav(samples);
  // One copy, and the app plays it itself. There used to be a second — an
  // Android raw resource, because a notification channel will only sound
  // something Android owns and cannot point at a Flutter asset. The rest
  // notification no longer makes a sound (see `services/rest_alarm.dart`), so
  // the raw resource had nothing left naming it.
  final targets = [File('assets/sound/rest_done.wav')];
  if (!targets.first.parent.existsSync()) {
    stderr.writeln('Run this from the repository root — ${targets.first.path} '
        'is not somewhere I can write.');
    exitCode = 1;
    return;
  }
  for (final file in targets) {
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(wav);
    stdout.writeln('Wrote ${file.path}: '
        '${samples.length} samples, '
        '${(samples.length / _sampleRate * 1000).round()} ms, '
        '${wav.length} bytes.');
  }
}

/// The tone itself, as 16-bit signed samples.
Int16List _render() {
  final count = (_sampleRate * _seconds).round();
  final raw = Float64List(count);
  final attack = (_sampleRate * _attackSeconds).round();
  var loudest = 0.0;
  for (var i = 0; i < count; i++) {
    final t = i / _sampleRate;
    // Rise, then fall away — never rising again, which is the difference
    // between one note and two.
    final rise = i < attack ? i / attack : 1.0;
    final fall = math.exp(-_decayRate * (t / _seconds));
    // The last few milliseconds are taken to exactly zero. An exponential never
    // quite arrives, and a wav that stops on a non-zero sample clicks.
    final tail = math.min(1.0, (count - i) / (_sampleRate * 0.004));
    final wave = math.sin(2 * math.pi * _fundamental * t) +
        _harmonicGain * math.sin(4 * math.pi * _fundamental * t);
    raw[i] = rise * fall * tail * wave;
    loudest = math.max(loudest, raw[i].abs());
  }
  // Scaled by what the waveform actually reached, not by what its two gains sum
  // to. The partials do not peak together, so dividing by 1 + the harmonic gain
  // left the ding a good 15% below the ceiling it was aiming at — which is
  // audible, and was half of "the ding is too quiet".
  final scale = _peak / loudest * 32767;
  final out = Int16List(count);
  for (var i = 0; i < count; i++) {
    out[i] = (raw[i] * scale).round();
  }
  return out;
}

/// A canonical 44-byte RIFF header and the samples after it: mono, 16-bit PCM.
Uint8List _wav(Int16List samples) {
  final data = samples.buffer.asUint8List();
  final out = BytesBuilder();
  void ascii(String s) => out.add(s.codeUnits);
  void u32(int v) => out.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) => out.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

  ascii('RIFF');
  u32(36 + data.length); // everything after this field
  ascii('WAVE');
  ascii('fmt ');
  u32(16); // the size of this chunk
  u16(1); // uncompressed PCM
  u16(1); // one channel
  u32(_sampleRate);
  u32(_sampleRate * 2); // bytes per second: one channel, two bytes a sample
  u16(2); // bytes per frame
  u16(16); // bits per sample
  ascii('data');
  u32(data.length);
  out.add(data);
  return out.toBytes();
}
