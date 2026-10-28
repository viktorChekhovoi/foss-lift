# Performance, iOS, and cloud review — 28 October 2026

The changes keep the existing training model and local database. The web release now ships WebAssembly with a JavaScript fallback, caches unchanged assets across visits, and removes serial database work from startup and common actions. iOS now has a compiling native project and macOS build workflow. Optional server backups and email sign-in are implemented; production authentication stays disabled until its database and email credentials are configured.

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

The old production deployment was compared with the compressed Cloudflare release candidate `5020e09` (`4db0c802.foss-lift.pages.dev`). The slow profile uses 200,000 bytes/second download bandwidth, 100,000 bytes/second upload bandwidth, and 150 ms latency. The normal profile adds no artificial network limit.

| Connection and visit | Old median | New median | Reduction |
| --- | ---: | ---: | ---: |
| Normal connection, first visit | 2.77 s | 1.27 s | 54% |
| Normal connection, repeat visit | 1.11 s | 0.96 s | 14% |
| Slow connection, first visit | 23.26 s | 17.55 s | 25% |
| Slow connection, repeat visit | 1.95 s | 1.19 s | 39% |

The normal-connection repeat measurements ranged from 0.45 to 0.96 seconds, so that result has more variation than the cold measurements. The final capability guards also remove queries for unsupported startup services; they were added after this candidate comparison. Production checks confirm the deployed build separately.

Resource Timing on the page omits downloads initiated inside workers, so its byte sum must not be treated as the complete download size. Screenshots and raw measurements are kept locally under `dist/performance/`; CI also retains `web-verification` artifacts.

A first visit still needs Flutter's rendering engine. This release retains the complete training application rather than introducing a second, partial browser implementation. Cold loading on a slow connection remains limited by that download. The loader, cache separation, and database batching address different parts of the delay.

## Data preservation and verification

- Flutter analysis is clean. The complete Flutter suite passes **1,749 tests**, with **18 existing skips**. The added cloud screen also passes the shared language and text-size sweeps.
- Eight HTTP/Workers integration tests use real local D1 through Miniflare and a fake email provider. They cover browser-bound single-use tokens, expiry, secure cookies, account isolation, concurrent saves, malformed/oversized requests, rate limits, sign-out, and account deletion. They send no real email.
- Browser checks run the compiled Wasm and JavaScript renderers, reload a saved GZCLP routine, and reject script errors and third-party resource requests. The persistence assertion uses Flutter's combined accessible routine group after reload.
- A restore test first failed against the unguarded replacement, then passed after checking the shared database's unfinished-workout record inside the restore transaction. Local routines and that record survive a refused restore; restore succeeds after the workout is cleared.
- An upgrade check loads the old deployed app, saves a GZCLP routine, verifies it after reload, installs a representative legacy Flutter cache worker, then switches the same origin to the new deployment. The routine survives, the worker unregisters, and the old static caches disappear. IndexedDB and OPFS are left intact. The database remains named `foss_lift`, and the local schema remains version 18.
- macOS CI successfully builds both a simulator app and an unsigned release device app using Xcode 26. Physical-device camera, file-backup, and workout/background behavior still need the checks listed in [ios-testflight.md](ios-testflight.md).

## Cloudflare and authentication

Cloudflare Free supports the required [Wrangler configuration](https://developers.cloudflare.com/pages/functions/wrangler-configuration/) and [D1 allowance](https://developers.cloudflare.com/d1/platform/pricing/). `wrangler.jsonc`, SQL migrations, and `npm run setup:cloud` define and provision the infrastructure. Only `/api/*` invokes Functions; static downloads do not consume Function requests.

The existing GitHub token can deploy Pages, but D1 provisioning returned HTTP 401. The local Wrangler login is also expired, so there is no second authenticated provisioning route available in this environment. No database was silently substituted, no paid plan was enabled, and sign-in reports unavailable until the required bindings exist.

To activate backups, give the deployment token **D1: Edit**, configure a verified Resend sender and `RESEND_API_KEY`, and rerun provisioning/deployment. [cloud-backup.md](cloud-backup.md) contains the exact commands and limits. Cloudflare's public-recipient email service requires Workers Paid; the Resend adapter keeps this small installation compatible with a free email allowance instead.

Email links are suitable for this optional backup account model when the mailbox is secure. This is single-factor email authentication. Token handling follows the random, expiring, single-use URL-token practices described by [OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html): 256 random bits, a 15-minute lifetime, hash-only storage, and an explicit POST to consume a browser-bound link. Session cookies are secure and HttpOnly, mutations require the configured origin, and saves use revision checks to prevent another device's backup being overwritten.

Backups are explicit save/restore operations, currently available in the browser. They are not automatic cross-device synchronization. Each account keeps one backup up to 1 MB; videos and unfinished sessions are excluded. Restore validates the payload and commits atomically. Server backups are not end-to-end encrypted. The public policy is at `/privacy/`.

## iOS distribution

The compiled device app uses `com.fosslift.fosslift`, version 0.5.10, and minimum iOS 14. It is unsigned and cannot be uploaded directly to TestFlight. Signing requires the owner's paid Apple Developer team. The console steps, signing command, and private external-testing group setup are in [ios-testflight.md](ios-testflight.md).

iOS supports local training, camera scanning, silent set videos, and file backups. Android notification-shade controls, scheduled reminders, and background rest alerts are hidden. Native cloud sign-in is not included in this release.

## Feature catalogue changes

Existing entry IDs are preserved. The catalogue check passes with 25 sections and 569 entries.

- Section 13: updated `makes-no-network-connections-collects` and the section tagline to describe offline training with optional browser backups accurately.
- Section 19: updated `browser-holds-database`; added `startup-shows-progress-and-retry`, `wasm-with-browser-fallback`, and `repeat-loads-reuse-versioned-assets`.
- New section 24: `cloud-backup-is-opt-in`, `email-link-sign-in`, `sessions-stay-in-secure-cookies`, `one-versioned-server-backup`, and `restore-validates-before-replacing`.
- New section 25: `ios-keeps-local-training` and `ios-builds-on-macos`.
- Added the `cloud.backup` and `cloud.auth` concepts and the cloud-backup screen mapping.
