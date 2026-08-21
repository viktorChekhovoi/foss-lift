/// Platform-specific leave guard; the web implementation uses `beforeunload` and native builds provide a no-op.

library;

export 'leave_guard_native.dart'
    if (dart.library.js_interop) 'leave_guard_web.dart';
