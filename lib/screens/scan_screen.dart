import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/routine_code.dart';
import '../l10n/app_localizations.dart';
import '../services/deep_links.dart';
import '../services/qr_decoder.dart';
import '../theme/app_theme.dart';

/// Points the camera at a Foss Lift QR code and hands what it finds to the
/// matching import screen.
///
/// One scanner for everything shareable — [host] says which: `theme`, `routine`.
/// Nothing is applied here — a scan navigates to the confirmation, which is the
/// only place a shared anything is ever adopted.
///
/// On Android the system camera can already open a `fosslift://` link, so this
/// is a convenience. It would not be on iOS: Apple's Camera app is unreliable
/// about offering to open third-party URL schemes, and this path bypasses OS
/// URL routing entirely by decoding the string itself.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.host});

  /// What is being scanned for, as the link host: `theme` or `routine`. It is
  /// also what picks the wording: every sentence on this screen exists once per
  /// kind of code rather than once with the noun spliced in, because a language
  /// that inflects the noun cannot be handed it as a substituted word.
  final String host;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

/// What stopped the scanner, held as a value rather than as a finished
/// sentence: the camera fails in [initState], where there is nothing to read
/// the string catalogue with, and the wording is chosen in [build].
enum _ScanProblem { noCamera, denied, failed }

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _camera;
  _ScanProblem? _problem;
  bool _busy = false;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _problem = _ScanProblem.noCamera);
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        // Low resolution on purpose: a QR held up to the lens decodes fine at
        // this size, and every extra pixel is one more to walk per frame.
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
      await controller.startImageStream(_onFrame);
    } on CameraException catch (e) {
      // Overwhelmingly this is a declined permission, which is a choice rather
      // than a fault — say what it means and offer the way round it.
      setState(() => _problem = e.code == 'CameraAccessDenied'
          ? _ScanProblem.denied
          : _ScanProblem.failed);
    } catch (_) {
      setState(() => _problem = _ScanProblem.failed);
    }
  }

  /// Called for every frame. Cheap rejections first: the vast majority of
  /// frames have no code in them, and this runs at the camera's frame rate.
  void _onFrame(CameraImage image) {
    if (_busy || _handled) return;
    _busy = true;
    try {
      final luma = QrDecoder.lumaFromPlane(
        image.planes.first.bytes,
        image.width,
        image.height,
        image.planes.first.bytesPerRow,
      );
      if (luma == null) return;
      final text = QrDecoder.decodeLuminance(luma, image.width, image.height);
      if (text == null) return;
      _found(text);
    } finally {
      _busy = false;
    }
  }

  void _found(String text) {
    // Only act on something that actually reads as what we are scanning for;
    // pointing the phone at a Wi-Fi QR on a café wall should not yank you into
    // an import screen.
    if (!readsAsShare(widget.host, text)) return;
    final route = importRoute(widget.host, text);
    if (route == null) return;
    _handled = true;
    _camera?.stopImageStream();
    if (!mounted) return;
    context.pushReplacement(route);
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final camera = _camera;
    final routine = widget.host == RoutineCode.host;
    final problem = _problem;
    return Scaffold(
      appBar: AppBar(
          title: Text(routine ? l10n.scanRoutineTitle : l10n.scanThemeTitle)),
      body: SafeArea(
        child: problem != null
            ? _message(l10n, switch (problem) {
                _ScanProblem.noCamera => l10n.commonNoCamera,
                _ScanProblem.denied =>
                  routine ? l10n.scanRoutineDenied : l10n.scanThemeDenied,
                _ScanProblem.failed => l10n.commonCameraFailed,
              })
            : camera == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(child: Center(child: CameraPreview(camera))),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          routine ? l10n.scanRoutineHint : l10n.scanThemeHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.muted, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _message(AppLocalizations l10n, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography_outlined,
                  size: 40, color: AppColors.muted),
              const SizedBox(height: 14),
              Text(text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.text, fontSize: 15, height: 1.5)),
              const SizedBox(height: 22),
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(l10n.commonBack),
              ),
            ],
          ),
        ),
      );
}
