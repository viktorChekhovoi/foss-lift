/// The browser's "are you sure you want to leave" dialog, armed and disarmed.
///
/// A conditional export rather than a `kIsWeb` branch, for the same reason
/// `db_open.dart` is one: a branch leaves the web-only import in the native
/// build's import graph. The browser interop libraries would survive that, but
/// the shape is the one this codebase already uses for a per-platform
/// implementation and it keeps them out of the Android build entirely.
///
/// See `leave_guard_web.dart` for what a browser can and cannot be asked here —
/// the message is not ours to write, and the dialog cannot be raised over a
/// page nobody has touched.
library;

export 'leave_guard_native.dart'
    if (dart.library.js_interop) 'leave_guard_web.dart';
