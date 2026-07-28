import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../services/set_video_recorder.dart';
import '../theme/app_theme.dart';

/// Films one set of the live workout, and hands the clip to that set.
///
/// The camera is opened when this screen opens and released when it closes —
/// never held between takes. Recording is the only way a clip gets into the
/// app: there is no import from the gallery, which would mean read access to
/// shared storage for a path nobody asked for.
class SetVideoScreen extends ConsumerStatefulWidget {
  const SetVideoScreen({
    super.key,
    required this.exerciseIndex,
    required this.setIndex,
  });

  final int exerciseIndex;
  final int setIndex;

  @override
  ConsumerState<SetVideoScreen> createState() => _SetVideoScreenState();
}

class _SetVideoScreenState extends ConsumerState<SetVideoScreen> {
  SetVideoRecorder? _recorder;
  RecorderProblem? _problem;
  bool _recording = false;
  bool _saving = false;
  int _elapsed = 0;
  int _max = kDefaultVideoSeconds;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final setting = ref.read(videoSettingProvider).value;
    _max = resolveVideoMaxSeconds(setting?.maxSeconds);
    final recorder = ref.read(setVideoRecorderProvider);
    try {
      await recorder.open(resolveVideoHeight(setting?.height));
      if (!mounted) {
        await recorder.close();
        return;
      }
      setState(() => _recorder = recorder);
    } on RecorderException catch (e) {
      if (mounted) setState(() => _problem = e.problem);
    } catch (_) {
      if (mounted) setState(() => _problem = RecorderProblem.failed);
    }
  }

  Future<void> _startRecording() async {
    final recorder = _recorder;
    if (recorder == null || _recording) return;
    await recorder.start();
    if (!mounted) return;
    setState(() {
      _recording = true;
      _elapsed = 0;
    });
    // The hard stop. A recording nobody stopped is what fills a phone — you
    // rack the bar, walk off, and the app films the ceiling.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (recordingExpired((elapsed: _elapsed, max: _max))) _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    final recorder = _recorder;
    if (recorder == null || !_recording || _saving) return;
    _tick?.cancel();
    _tick = null;
    setState(() {
      _recording = false;
      _saving = true;
    });

    final recorded = await recorder.stop();
    await recorder.close();
    _recorder = null;
    if (recorded == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    // File first, then the pointer. The live session holds the path in memory
    // until Finish, so nothing is written to the database here at all — see
    // SetEntry.videoPath.
    final relative = await ref.read(setVideoStoreProvider).adopt(recorded);
    await ref
        .read(activeWorkoutProvider.notifier)
        .attachVideo(widget.exerciseIndex, widget.setIndex, relative);
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _tick?.cancel();
    // Fire and forget: the screen is going either way, and the camera must not
    // be left open behind it.
    unawaited(_recorder?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clock = (elapsed: _elapsed, max: _max);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Record this set'),
        backgroundColor: Colors.black,
      ),
      body: SafeArea(
        child: _problem != null
            ? _message(_problem!)
            : Column(
                children: [
                  Expanded(
                    child: Center(
                      child: _recorder?.preview() ??
                          const CircularProgressIndicator(),
                    ),
                  ),
                  if (_recording) _clock(clock),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: _shutter(),
                  ),
                ],
              ),
      ),
    );
  }

  /// Seconds left, and only shouting about it at the end. A countdown running
  /// the whole time is a stopwatch nobody asked for; a stop that arrives with
  /// no warning is worse.
  Widget _clock(RecordingClock clock) {
    final left = recordingRemaining(clock);
    final closing = recordingCountingDown(clock);
    return Text(
      closing ? 'Stopping in $left' : '$left s left',
      style: kMono.copyWith(
        fontSize: closing ? 20 : 14,
        fontWeight: FontWeight.w700,
        color: closing ? AppColors.gold : Colors.white70,
      ),
    );
  }

  Widget _shutter() {
    if (_saving) return const CircularProgressIndicator();
    final ready = _recorder != null;
    return GestureDetector(
      onTap: !ready
          ? null
          : _recording
              ? _stopRecording
              : _startRecording,
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          color: _recording ? Colors.red : Colors.transparent,
        ),
        child: _recording
            ? const Icon(Icons.stop_rounded, color: Colors.white, size: 32)
            : null,
      ),
    );
  }

  Widget _message(RecorderProblem problem) {
    final text = switch (problem) {
      RecorderProblem.noCamera => 'This device has no camera.',
      RecorderProblem.denied =>
        'Foss Lift needs the camera to film a set. Clips stay on this phone.',
      RecorderProblem.failed => 'The camera could not be started.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined,
                size: 40, color: Colors.white70),
            const SizedBox(height: 14),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, height: 1.5)),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
