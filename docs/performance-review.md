# Performance and iOS review — 28 October 2026

The performance improvements and iOS project are retained. The web release ships WebAssembly with a JavaScript fallback, caches unchanged assets across visits, and removes serial database work from startup and common actions. The app has no accounts, server backups, or account API. Cloudflare Pages serves static files through the existing deployment workflow; there is no infrastructure provisioning.

## Findings addressed

| Finding | Change and effect |
| --- | --- |
| The first browser visit downloaded a large JavaScript app and CanvasKit engine; a blank Flutter frame appeared before the database was usable. | Build Wasm/Skwasm where supported, retain CanvasKit fallback, precompress Wasm with Brotli, and show a small loading page until stored settings are ready. The page includes failure and retry states. |
| Root app and engine URLs revalidated on repeat visits, and an app update could invalidate unrelated engine files. | Hash app code, assets, and engine separately; give those paths immutable one-year caching. Keep HTML and the loader revalidated. |
| Flutter's default font fallback contacted Google at startup. | Bundle the UI fonts and their licenses; compiled-browser checks reject outside-origin requests. |
| A native backup-screen import pulled FFI into the browser build. | Use conditional screen exports so the same router compiles for both platforms. |
| First-run seeding awaited roughly 145 separate bar/exercise inserts. Session completion also awaited every set insert separately. | Batch the writes, reducing worker messages and individual database operations. Keep each action's transaction and existing data semantics. |
| Browser startup loaded reminder data and scanned clip references even though those platform services do nothing there. | Gate those startup providers before their database reads. Web skips the clip scan and reminder queries; iOS also skips Android-only notification work. |
| Adding a starter routine queried the exercise table separately for every slot. | Read the library once, resolve names in memory, and batch the workout items. |
| The live board recomputed the same plate search on timer updates. | Cache small searches by complete rack values and target limit. Keep at most eight entries; leave searches with more than 2,048 reachable states or 32 plate sizes uncached to bound retained memory. A 5,000-call benchmark returned identical results and improved from 90.9 ms to 20.2 ms, about 4.5×. This is the plate calculation, not a claim that the whole app became 4.5× faster. |
| History could wait indefinitely for a count to catch up with a page fetched before a concurrent deletion or reset. | Read the first history page and count in one database transaction, removing the unbounded stream predicate. |
| Fresh-checkout CI ran dependency setup before generating ignored translation inputs. | Generate the translation catalogues before `flutter pub get` in web, Android, and iOS build workflows. |

## Browser measurements

Measurements use the actual Cloudflare deployment, desktop Chrome with a 390 × 844 viewport, and a new browser context for each cold visit. A repeat visit reuses that context and its HTTP/database storage. Readiness means the initial tutorial can be dismissed and the **Ready-made routines** control is available, rather than Flutter's first blank frame. Three runs per version provide a median. These are controlled comparisons, not field telemetry or a promise for every device.

These historical measurements compare the old production deployment with optimized release `428587e` at `https://foss-lift.pages.dev/` (deployment `ceffc457`), before the requested removal of the server feature. All performance changes remain in the static release. The slow profile uses 200,000 bytes/second download bandwidth, 100,000 bytes/second upload bandwidth, and 150 ms latency. The normal profile adds no artificial network limit. The individual samples and profile settings are in [performance-measurements.json](performance-measurements.json).

| Connection and visit | Old median | New median | Reduction |
| --- | ---: | ---: | ---: |
| Normal connection, first visit | 2.77 s | 1.29 s | 54% |
| Normal connection, repeat visit | 1.11 s | 0.53 s | 52% |
| Slow connection, first visit | 23.26 s | 17.46 s | 25% |
| Slow connection, repeat visit | 1.95 s | 1.19 s | 39% |

The normal-connection repeat measurements ranged from 0.43 to 1.00 seconds, so that result has more variation than the cold measurements. The production checks also confirm Brotli response encoding, immutable asset caching, cross-origin isolation, and the public privacy-policy page.

Resource Timing on the page omits downloads initiated inside workers, so its byte sum must not be treated as the complete download size. Screenshots and raw measurements are kept locally under `dist/performance/`; CI also retains `web-verification` artifacts.

A first visit still needs Flutter's rendering engine. This release retains the complete training application rather than introducing a second, partial browser implementation. Cold loading on a slow connection remains limited by that download. The loader, cache separation, and database batching address different parts of the delay.

## Data preservation and verification

- After removing the server feature, Flutter analysis is clean and the complete Flutter suite passes **1,739 tests**, with **18 existing skips**. The language and text-size sweeps continue to cover the retained screens.
- Browser checks run the compiled Wasm and JavaScript renderers, reload a saved GZCLP routine, and reject script errors and third-party resource requests. The persistence assertion uses Flutter's combined accessible routine group after reload.
- An upgrade check loads the old deployed app, saves a GZCLP routine, verifies it after reload, installs a representative legacy Flutter cache worker, then switches the same origin to the new deployment. The routine survives, the worker unregisters, and the old static caches disappear. IndexedDB and OPFS are left intact. The database remains named `foss_lift`, and the local schema remains version 18.
- macOS CI successfully builds both a simulator app and an unsigned release device app using Xcode 26. Physical-device camera, file-backup, and workout/background behavior still need the checks listed in [ios-testflight.md](ios-testflight.md).

The final [web deployment workflow](https://github.com/viktorChekhovoi/foss-lift/actions/runs/40644209036) and [iOS build workflow](https://github.com/viktorChekhovoi/foss-lift/actions/runs/40644208956) both passed. The local `dist/ios-final/` directory holds the downloaded device and simulator ZIPs from that iOS run.

## Static hosting and removed server feature

The requested rollback removes the Wrangler IaC configuration, D1 migrations, Pages Functions, email provider integration, server provisioning, backup/auth clients and UI, and cloud-only tests and translations. The deployment retains the original Pages token and account ID for static hosting. No database was provisioned or live user backup stored: D1 access had returned HTTP 401.

The public privacy policy and About copy describe local storage again. The native file-backup format, browser database name and schema are unchanged. Browser verification checks Profile without an account tile and rejects account/API requests. The web compression, versioned asset caching, loading UI, startup query guards, history fix, and plate optimization remain.

## iOS distribution

The compiled device app uses `com.fosslift.fosslift`, version 0.5.10, and minimum iOS 14. It is unsigned and cannot be uploaded directly to TestFlight. Signing requires the owner's paid Apple Developer team. The console steps, signing command, and private external-testing group setup are in [ios-testflight.md](ios-testflight.md).

iOS supports local training, camera scanning, silent set videos, and file backups. Android notification-shade controls, scheduled reminders, and background rest alerts are hidden.

## Feature catalogue changes

The retained entry IDs are preserved. The catalogue check passes with 24 sections, 564 entries and 119 concepts. Section 25 remains the iOS section; it is not renumbered after removing section 24.

- Section 13: reworded `makes-no-network-connections-collects` and the section tagline to restore the local-only, no-account contract.
- Section 19: reworded `browser-holds-database` to remove server uploads. Retained `startup-shows-progress-and-retry`, `wasm-with-browser-fallback`, and `repeat-loads-reuse-versioned-assets`.
- Removed section 24 and its entries: `cloud-backup-is-opt-in`, `email-link-sign-in`, `sessions-stay-in-secure-cookies`, `one-versioned-server-backup`, and `restore-validates-before-replacing`.
- New section 25: `ios-keeps-local-training` and `ios-builds-on-macos`.
- Removed the `cloud.backup` and `cloud.auth` concepts and the cloud-backup screen mapping.
