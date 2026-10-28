import 'package:web/web.dart' as web;

bool _announced = false;

void appReady() {
  if (_announced) return;
  _announced = true;
  web.window.dispatchEvent(web.Event('fosslift-ready'));
}

void startupFailed() => web.window.dispatchEvent(web.Event('fosslift-failed'));
