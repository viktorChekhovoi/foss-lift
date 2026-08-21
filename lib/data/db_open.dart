/// Selects the native or WebAssembly database opener at compile time.
/// Conditional export keeps `dart:ffi` out of web builds.
library;

export 'db_open_native.dart'
    if (dart.library.js_interop) 'db_open_web.dart';
