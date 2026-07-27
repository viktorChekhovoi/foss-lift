import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/qr_decoder.dart';
import '../theme/app_theme.dart';
import '../theme/theme_code.dart';

/// Points the camera at a theme QR code and hands what it finds to the import
/// screen.
///
/// Nothing is applied here — a scan navigates to the confirmation, which is the
/// only place a theme is ever adopted.
///
/// On Android the system camera can already open a `fosslift://` link, so this
/// is a convenience. It would not be on iOS: Apple's Camera app is unreliable
/// about offering to open third-party URL schemes, and this path bypasses OS
/// URL routing entirely by decoding the string itself.
class ThemeScanScreen extends StatefulWidget {
  const ThemeScanScreen({super.key});

  @override
  State<ThemeScanScreen> createState() => _ThemeScanScreenState();
}

class _ThemeScanScreenState extends State<ThemeScanScreen> {
  CameraController? _camera;
  String? _problem;
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
        setState(() => _problem = 'This device has no camera.');
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
          ? 'Foss Lift needs the camera to scan a code. You can still paste a '
              'theme code instead.'
          : 'The camera could not be started.');
    } catch (_) {
      setState(() => _problem = 'The camera could not be started.');
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
    // Only act on something that actually reads as a theme; pointing the phone
    // at a Wi-Fi QR on a café wall should not yank you into an import screen.
    if (ThemeCode.decode(text) is! ThemeCodeOk) return;
    _handled = true;
    _camera?.stopImageStream();
    if (!mounted) return;
    context.pushReplacement(
        '/settings/theme/import?code=${Uri.encodeQueryComponent(text)}');
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a theme')),
      body: SafeArea(
        child: _problem != null
            ? _message(_problem!)
            : camera == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(child: Center(child: CameraPreview(camera))),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Point the camera at a Foss Lift theme QR code.',
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

  Widget _message(String text) => Center(
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
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
}
