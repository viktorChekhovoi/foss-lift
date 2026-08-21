/// Keeps browser timers responsive during a live workout by holding a nearly inaudible audio stream. The implementation is a no-op on native platforms.

library;

export 'tab_awake_native.dart'
    if (dart.library.js_interop) 'tab_awake_web.dart';
