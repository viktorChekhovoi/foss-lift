# The browser build

Foss Lift builds for the web from the same source as the Android app. The
database is real SQLite — sqlite3 compiled to WebAssembly, stored in the
browser's own origin-private file system or IndexedDB — so the schema, the
queries and the first-run seed are the ones the phone uses, not a reimplementation.

Nothing is uploaded and there is no account. The cost is that "your data" now
means "your data in this browser on this machine", which is a weaker promise
than a file in app storage. That trade, and everything else a web user gives up,
is set out below.

```bash
flutter build web --no-web-resources-cdn      # output in build/web
```

The flag is not optional — see [The engine has to be local](#the-engine-has-to-be-local).

## What works

Everything except the four things in [What a web user loses](#what-a-web-user-loses).
The routine builder, the live board, the plate maths, progression, layoff
deloads, warm-up ramps, history and charts, themes, text scaling and all five
languages are the same widgets compiled for a different target.

Verified on the built output in headless Chrome: the app boots, seeds a fresh
database with 87 exercises, 2 demo routines and 12 bars, and round-trips a
write through the WebAssembly executor.

## Where the data lives

`lib/data/db_open_web.dart` calls `WasmDatabase.open`, which probes the browser
and picks the best storage it can actually use. In descending preference:

| Implementation | Mechanism | Needs |
|---|---|---|
| `opfsShared` | OPFS inside a shared worker | a shared worker that can spawn a dedicated worker — **Firefox only** |
| `opfsLocks` | OPFS, two dedicated workers per tab, `Atomics.wait` | **cross-origin isolation** (COOP/COEP) |
| `sharedIndexedDb` | IndexedDB in a shared worker | a shared worker |
| `unsafeIndexedDb` | IndexedDB, no worker | nothing — but cannot prevent races between tabs |
| `inMemory` | nothing persisted | nothing |

Shared workers and cross-origin isolation are **independent** requirements, which
is why the headers matter for some browsers and not others. Measured here:

- Chrome **without** COOP/COEP → `sharedIndexedDb`. Durable, safe across tabs, slower.
- Chrome **with** COOP/COEP → `opfsLocks`. The fast path.
- Firefox reaches `opfsShared` either way.

So the headers are an optimisation, not a requirement. Nothing fails without
them. The one genuinely bad outcome is `inMemory`, which needs a browser with
neither workers nor IndexedDB; `lastWebStorage` records what was chosen.

If a database already exists, drift keeps using the storage API it is already
in rather than the best available one, so a browser update cannot strand the
training log. `moveExistingIndexedDbToOpfs` is enabled so an IndexedDB database
migrates up when OPFS becomes reachable.

### Durability, honestly

Both OPFS and IndexedDB live in the origin's storage bucket. **Clearing site
data deletes the training log**, and eviction under storage pressure takes the
whole bucket at once. A private window starts empty every time. drift's docs do
not address eviction; `navigator.storage.persist()` is the standard mitigation
and nothing here calls it yet.

This is the honest cost of having no server, and it is why the Android build is
the one to actually train off. The browser build is for trying the app, and for
a desktop machine at a laptop.

## What a web user loses

Four things, each because the browser cannot do it — not because the port is
incomplete. `lib/util/capabilities.dart` states them once; the screens ask it,
so every affected control is *absent* rather than present and broken.

| Gone | Why | What is left |
|---|---|---|
| **Reminders** | a reminder is a scheduled local notification | the weekday schedule still edits and still travels in a share code |
| **Set videos** | filming writes a file into app storage; `path_provider` has no web implementation | history and progression never needed a clip |
| **QR scanning** | the scanner reads camera frames one at a time (`startImageStream`), unsupported on web | pasting a code, and *showing* a QR, both work |
| **The workout shade** | a foreground service, and the rest ding that depends on it | the session is in memory and survives being collapsed, exactly as on a phone |

The rest tone is also silent: `RestTone.supported` was already false off
Android and iOS, so a rest on the web is a timer you watch. `audioplayers` does
support the web, so this is a decision that could be revisited rather than a
wall.

Deep links (`fosslift://`) do not apply in a browser. `app_links` delivers only
an initial link on web and a custom scheme is not something a browser routes,
so import happens by paste.

## What had to change, and why

Three things, all in `lib/`:

1. **The database opener is a conditional import** — `db_open.dart` exports
   `db_open_native.dart` or `db_open_web.dart`. It cannot be an `if (kIsWeb)`:
   a branch still leaves `package:drift/native.dart` in the web build's import
   graph, and through it `dart:ffi`, which is the **one** import that genuinely
   fails to compile for the web. Before the split, `flutter build web` produced
   ~3,300 errors, all of them from `sqlite3`'s FFI bindings.

2. **The routine share code compresses with pure Dart.** `RoutineCode` used
   `dart:io`'s `ZLibCodec`. See the trap below.

3. **Platform services are gated on capabilities**, and `ReminderService.supported`
   gained a `kIsWeb` check — `Platform.isAndroid` does not return false in a
   browser, it throws.

### The dart:io trap

**`dart:io` compiles for the web and then throws from everything.** It is not a
compile error, which makes it worse than one: nothing warns you, and the failure
arrives at runtime in whatever code path first touches it. Measured under dart2js:

```
ZLibCodec(...).encode(...)  → UnsupportedError: _newZLibDeflateFilter
Platform.isAndroid          → UnsupportedError: Platform._operatingSystem
File('/tmp/x')              → constructs fine; every operation on it throws
```

This is why `lib/data/routine_code.dart` now uses `package:archive`'s pure-Dart
`Deflate`/`Inflate` on **both** platforms rather than conditionally. The output
is ordinary raw deflate: byte-identical in length to `dart:io`'s at level 9 in
testing, and each decodes the other's, so `FLR1` means one thing everywhere and
a code does not carry which build wrote it.

The same trap explains why several files still import `dart:io` and are fine:
they are behind a capability gate that is false on the web, so the throwing call
is never reached. `SetVideoStore._clipFiles` is the one that mattered — the
orphan sweep runs unprompted on every launch.

### Dependencies

No dependency had to be removed. Every plugin without a web implementation is
simply omitted from the generated web plugin registrant; the build succeeds and
calling into it would throw `MissingPluginException`, which the capability gates
prevent. `sqlite3_flutter_libs` at `0.6.0+eol` does nothing at all any more and
could be dropped in a later tidy-up.

## The engine has to be local

Since Flutter 3.22, `flutter build web` points CanvasKit at `gstatic.com` by
default. `--no-web-resources-cdn` copies it into `build/web/canvaskit/` instead.
Two reasons, both requirements:

- **"No network" has to stay true of the running app.** A CDN fetch on every
  cold load is exactly the third-party request this app promises not to make.
- **A cross-origin subresource is blocked outright under `COEP: require-corp`.**
  With the headers on and the engine remote, the page does not load at all.

`web/index.html` names no remote origin and
`test/feature_19_web_build_test.dart` keeps it that way. The build flag is not
something a test can enforce — that one is on you.

Verified: a load of the built output requests `index.html`, `flutter_bootstrap.js`,
`main.dart.js`, `canvaskit/`, the fonts, `drift_worker.js` and `sqlite3.wasm`,
and nothing else. No request leaves the origin.

## The two checked-in binaries

`web/sqlite3.wasm` and `web/drift_worker.js` are prebuilt and are not outputs of
anything in this repository. They come from the drift release matching the
pinned package version:

```
https://github.com/simolus3/drift/releases/download/drift-2.34.3/sqlite3.wasm
https://github.com/simolus3/drift/releases/download/drift-2.34.3/drift_worker.js
```

```
41cf968998241465d8b1dfffb1eb60dd10c35de5022a3647e14174ea3af84143  sqlite3.wasm
4db0469de8ceabad8d5cd3d920614486ba587e100e39523f36f704a3aec5f26c  drift_worker.js
```

**Re-download both when `drift` moves in `pubspec.lock`.** Compatibility is
one-directional: the Dart packages may be newer than these files, never older. A
`sqlite3.wasm` built for a later `package:sqlite3` than the one resolved fails at
runtime, inside the worker, where the error is easy to miss.

`sqlite3.wasm` must be served as `Content-Type: application/wasm` or the browser
refuses the module. Every host below does this by extension.

## Hosting

**Recommendation: Cloudflare Pages.**

- Unlimited bandwidth on the free tier, with no suspension cliff. Netlify hard-suspends
  a free site for the rest of the month at 100 GB.
- SPA fallback with no configuration: Pages treats a project with no top-level
  `404.html` as a single-page app, and `flutter build web` emits none.
- `_headers` in the published directory gives COOP/COEP for free — already
  checked in at `web/_headers`, which the build copies to `build/web/_headers`.
- Default caching (`max-age=0, must-revalidate` with ETag revalidation) is
  already right for a Flutter SPA. The risk on Pages is *adding* a long
  `max-age` over `index.html`, not the absence of one.
- No non-commercial clause. Vercel's Hobby tier is personal-use-only and that
  covers donation links, which a FOSS app plausibly wants.

Deploy: point Pages at the repo, build command `flutter build web --no-web-resources-cdn`,
output directory `build/web`. Or build locally and upload `build/web`.

### The others

**Netlify** reads the same `web/_headers` file, and needs an SPA redirect:

```
/*  /index.html  200
```

**Vercel** ignores `_headers`. It needs a `vercel.json` at the repository root:

```json
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "Cross-Origin-Opener-Policy", "value": "same-origin" },
        { "key": "Cross-Origin-Embedder-Policy", "value": "require-corp" }
      ]
    }
  ],
  "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }]
}
```

**GitHub Pages cannot set response headers at all** — no `_headers`, no
`.htaccess`, no config, and a `<meta http-equiv>` does not work for COOP/COEP.
The site still runs (drift falls back to IndexedDB), but it can never reach OPFS,
and its deep-link fallback returns HTTP 404 with the page body. Usable, not
recommended.

### Serving it locally

`flutter run -d chrome` works. To test the isolated path:

```bash
flutter run -d chrome \
  --web-header=Cross-Origin-Opener-Policy=same-origin \
  --web-header=Cross-Origin-Embedder-Policy=require-corp
```

## Not done

- **`flutter build web --wasm`.** The dry run passes, so it is probably a flag
  away, but it is untested here and skwasm's threading is the thing COOP/COEP
  really buys.
- **Offline.** Flutter no longer generates a service worker with useful caching
  by default. The app is offline-capable in the sense that it makes no network
  calls once loaded; it is not installable-and-works-on-a-plane without a
  service worker written by hand.
- **`navigator.storage.persist()`.** Worth calling on first run to ask the
  browser not to evict the database.
- **Warning on `inMemory`.** `lastWebStorage` records the choice but no screen
  reads it. A browser that lands there loses everything on reload and should be
  told so.
