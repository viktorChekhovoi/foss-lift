/// Where the database file lives, chosen when the app is compiled.
///
/// `AppDatabase` calls [openAppDatabase] and knows nothing else about it. The
/// two implementations behind this export have nothing in common: one opens a
/// file through `path_provider` and drift's native executor, the other loads
/// sqlite3 compiled to WebAssembly and lets drift pick a browser storage API.
///
/// **The split has to be an import, not an `if (kIsWeb)`.** A branch would
/// still leave `package:drift/native.dart` — and through it `dart:ffi` — in the
/// web build's import graph, and `dart:ffi` is the one import that genuinely
/// fails to compile for the web. Conditional export keeps the losing side out
/// of the build entirely.
///
/// The condition tests `dart.library.js_interop` rather than the absence of
/// `dart.library.io`, because `dart:io` *is* present on the web: it compiles
/// and then throws from every call. See `docs/web-build.md`.
library;

export 'db_open_native.dart'
    if (dart.library.js_interop) 'db_open_web.dart';
