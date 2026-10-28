# Browser build and startup

Build with the pinned Flutter SDK used by CI:

```sh
dart tool/l10n.dart
flutter pub get
flutter gen-l10n
npm ci
flutter build web --release --wasm --optimization-level=4 --no-web-resources-cdn
npm run prepare:web
```

The standalone translation merge must run before `flutter pub get`: Flutter generates translations automatically, and the merged ARB inputs are deliberately ignored by Git. Running dependency setup first broke fresh-checkout CI.

`--wasm` produces a Skwasm build and a JavaScript/CanvasKit fallback. Both are shipped and checked in a real browser. `--no-web-resources-cdn` is required: the engine, fonts, Drift worker and SQLite module are hosted at this origin. The app's `COOP` and `COEP` headers allow cross-origin isolation and faster OPFS storage where supported. Browsers without it fall back to IndexedDB. The database name remains `foss_lift`, preserving existing browser data.

`tool/prepare-web.mjs` moves compiled code, fonts/assets and the rendering engine into separate directories under `_app/`, each named by its content hash. `_headers` gives these files a one-year immutable browser cache. The small HTML page and loader revalidate. Changing app code does not invalidate the unchanged rendering engine. The loader query also bypasses an old generated Flutter worker's cached bootstrap. Existing Flutter workers retire and remove only their known static caches; OPFS and IndexedDB are not cleared.

The build also compresses WebAssembly modules with Brotli's maximum setting. Generated, exact-path `Content-Encoding: br` headers describe those modules and `no-transform` prevents an edge recompression from enlarging them. This applies to the browser binaries only; source `web/sqlite3.wasm` and the database files remain unchanged. The local verification server understands the same encoding manifest and checks that both browser renderers and SQLite still load.

The HTML shell appears immediately and stays until stored settings have loaded and the usable Flutter frame has painted. It gives progress, an error state, and Reload. The readiness signal measures the usable app rather than Flutter's initial blank holding frame. A first visit still downloads a rendering engine: this preserves the complete native app's behavior, including existing training data and share formats. Repeat visits use the browser's asset cache.

SQLite's `sqlite3.wasm` and `drift_worker.js` are committed under `web/`. Keep them compatible with the locked Drift/sqlite3 packages when upgrading dependencies; [Drift documents the required matching releases](https://drift.simonbinder.eu/platforms/web/). Do not change the database name or storage backend to bypass a startup problem: that can strand existing users' data.

## Verify the built app

```sh
npx playwright install chromium
npm run test:web
SLOW_NETWORK=1 npm run test:web
```

Set `CHROME_PATH` to a local Chrome executable when using an already installed browser. The test server applies the same storage-isolation and caching headers as production and compresses responses. It tests both Wasm and the fallback by simulating a browser without WasmGC, verifies there are no outside-origin requests or JavaScript errors, and reloads the same browser profile to check persistent settings and HTTP caching. Screenshots and resource measurements are written to `build/web-verification/`. The slow profile uses 200,000 bytes/second download bandwidth and 150 ms latency. Production measurements may differ because Cloudflare uses its own compression and edge routing.

The GitHub workflow runs analysis, the Flutter suite, the feature check, the dual-target build, and the browser checks before deploying static files to the existing Cloudflare Pages project. It retains the browser report as an artifact. There are no Functions, database bindings, account endpoints, email secrets, or infrastructure-provisioning commands. The only Cloudflare credentials needed are the existing Pages deployment token and account ID.
