import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'set_video_store.dart';

/// Why a recording could not start. Separated from the message so the screen
/// can say something useful about a declined permission — which is a choice,
/// not a fault — without string-matching a plugin's error codes.
enum RecorderProblem { noCamera, denied, failed }

/// Filming one set.
///
/// An interface rather than the camera plugin directly, for one reason: none of
/// this can run in a widget test. A fake implementation is what lets the rules
/// around recording — the hard stop, the clip landing on the right set, a
/// discarded take deleting its file — be tested at all, and those rules are
/// where the bugs live. The camera itself is the one part a device has to
/// check.
abstract class SetVideoRecorder {
  /// Opens the camera at [height], **without audio**.
  ///
  /// Never with audio: a gym is full of other people's conversations, the track
  /// is worth nothing for checking bar path, and leaving it off avoids the
  /// microphone permission prompt on both platforms.
  Future<void> open(int height);

  /// The viewfinder. Only valid between [open] and [close].
  Widget preview();

  Future<void> start();

  /// Stops, and returns the absolute path of the file written — or null if
  /// nothing was recorded.
  Future<String?> stop();

  /// Releases the camera. Called the moment recording is over: the camera is
  /// opened only while actively filming, never held.
  Future<void> close();
}

/// Thrown by [SetVideoRecorder.open] when the camera will not come up.
class RecorderException implements Exception {
  RecorderException(this.problem);
  final RecorderProblem problem;
}

/// The real one, over the `camera` plugin.
class CameraSetVideoRecorder implements SetVideoRecorder {
  CameraController? _controller;

  @override
  Future<void> open(int height) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw RecorderException(RecorderProblem.noCamera);
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        height >= 720 ? ResolutionPreset.high : ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      _controller = controller;
    } on CameraException catch (e) {
      throw RecorderException(e.code == 'CameraAccessDenied'
          ? RecorderProblem.denied
          : RecorderProblem.failed);
    }
  }

  @override
  Widget preview() {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return CameraPreview(controller);
  }

  @override
  Future<void> start() async => _controller?.startVideoRecording();

  @override
  Future<String?> stop() async {
    final controller = _controller;
    if (controller == null || !controller.value.isRecordingVideo) return null;
    final file = await controller.stopVideoRecording();
    return file.path;
  }

  @override
  Future<void> close() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}

/// The recorder the app films with. Overridden in tests with a fake that writes
/// a file and returns its path — see the note on [SetVideoRecorder].
final setVideoRecorderProvider =
    Provider<SetVideoRecorder>((ref) => CameraSetVideoRecorder());

/// How long a recording has been running, and how long it may run.
///
/// Pure so the hard stop can be tested without a camera: [remaining] is what
/// the countdown shows, and [expired] is what ends the recording. See
/// `Settings.videoMaxSeconds` for why there is a stop at all.
typedef RecordingClock = ({int elapsed, int max});

int recordingRemaining(RecordingClock clock) =>
    (clock.max - clock.elapsed).clamp(0, clock.max);

bool recordingExpired(RecordingClock clock) => clock.elapsed >= clock.max;

/// Whether the countdown should be on screen: the last five seconds, so a stop
/// that is about to happen is never a surprise.
bool recordingCountingDown(RecordingClock clock) =>
    recordingRemaining(clock) <= 5;

/// The seconds a clip may run, clamped to something the app offers. A stored
/// value from nowhere resolves to the default rather than to no limit at all.
int resolveVideoMaxSeconds(int? stored) =>
    kVideoMaxSeconds.contains(stored) ? stored! : kDefaultVideoSeconds;

/// The same for the height it is filmed at.
int resolveVideoHeight(int? stored) =>
    kVideoHeights.contains(stored) ? stored! : kDefaultVideoHeight;
