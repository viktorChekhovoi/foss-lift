# Optional server backups on Cloudflare Free

Cloudflare Free supports this setup without Terraform or a paid infrastructure plan: Pages hosts the static app, Pages Functions handles `/api/*`, and D1 stores accounts, login-link hashes, session hashes, and one backup per account. [Wrangler configuration](https://developers.cloudflare.com/pages/functions/wrangler-configuration/) declares the project, compatibility date, variables, and database binding; the numbered SQL files under `migrations/` declare the database schema. The provisioning command creates the database if it is absent and applies only pending migrations.

The [D1 free allowance](https://developers.cloudflare.com/d1/platform/pricing/) is 5 million rows read and 100,000 rows written per day, with 5 GB across the account. A [single free database is limited to 500 MB](https://developers.cloudflare.com/d1/platform/limits/). API traffic also uses the Workers Free request and CPU allowance; static asset requests do not run the Function because `web/_routes.json` includes only `/api/*`. Exceeding a free limit stops the affected operation rather than requiring this app to upgrade the plan.

## Email delivery is separate

[Cloudflare's arbitrary-recipient email sending requires Workers Paid](https://developers.cloudflare.com/email-service/). Free Email Routing is not an outbound login-email service for the public. The implementation instead supports Resend over HTTPS. Resend currently offers [3,000 transactional emails per month, with a 100/day free limit](https://resend.com/pricing). A verified sending domain and a Resend sending API key are required. The app additionally caps requests at 90 delivered login links per UTC day across the installation, plus per-email and per-IP limits. This is an intentional small-installation free-tier limit.

The app remains fully usable offline without an account. Until both D1 and email delivery are configured, **Profile → Cloud backup** reports that server backups are unavailable. There is no development login bypass in production and no logging of raw login tokens.

## Set up production

1. Create or update a Cloudflare API token with account **Cloudflare Pages: Edit** and **D1: Edit** permissions, scoped to the account hosting Foss Lift. The existing GitHub deployment secrets are `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`. A Pages-only token can deploy the static app but cannot provision D1.
2. Verify a sending domain in Resend. Set the repository variable `CLOUD_EMAIL_FROM` to a sender such as `Foss Lift <login@your-domain.example>`, or edit `vars.EMAIL_FROM` in `wrangler.jsonc`. Do not use an address on `pages.dev`; you do not control its email DNS.
3. Add the Resend key as a Cloudflare Pages production secret: `npx wrangler pages secret put RESEND_API_KEY --project-name=foss-lift`. Enter the key at the prompt. Keep it out of Git, build flags, browser code, and command history.
4. With the Cloudflare token and account ID in your environment, run `npm ci` and `npm run setup:cloud`. This creates `foss-lift-users`, applies `migrations/`, and writes the real database binding into the standard root `wrangler.jsonc`. It never creates a paid subscription. GitHub's web push workflow performs the same provisioning step when its token allows it.
5. Run the web build described in [web-build.md](web-build.md), then deploy with `npx wrangler pages deploy build/web --project-name=foss-lift --branch=main`, or push the verified change to `main` to use the workflow. Re-run provisioning after a clean checkout; the database name is stable and the command reuses it.
6. On `https://foss-lift.pages.dev`, open **Profile → Cloud backup**, request your own link, and open it in the same browser within 15 minutes. Press **Continue**. Save a backup, change a harmless local setting, and restore the backup to check the complete path. Test a second account to confirm isolation.

If provisioning reports a permission error, update the Cloudflare token and rerun it. The optional CI provisioning step keeps static hosting deployable and leaves sign-in disabled when the token lacks D1 permission. It does not delete an existing database. Production migrations fail the deployment if they cannot be applied; they are not silently skipped.

Preview deployments cannot authenticate against the production origin. The API compares its configured origin with the request origin, and refuses requests from a preview address. Local tests use isolated D1 storage and an injected email service; they send no actual email.

## Security and data behavior

Magic links are adequate for this account model when the email account itself is secure. Links contain 256 random bits, expire after 15 minutes, are bound to the requesting browser, and are consumed by one atomic delete on an explicit POST. Their token is in the URL fragment, so it is not sent in access logs or referrers. A scanner opening the email page cannot consume the link. Only token hashes are persisted.

Sessions expire after 30 days and use `__Host-` cookies with `HttpOnly`, `Secure`, `SameSite=Lax`, and `/` scope. The application never stores credentials in localStorage. Mutating endpoints require an exact same-origin `Origin` header and structured JSON where a body is expected. Sign out revokes the current session; deleting the account revokes every session and deletes the active server backup and outstanding login links.

Backups include routines, exercises, completed sessions and sets, preferences, custom themes, and bars. They exclude unfinished sessions and video bytes. They have a 1 MB limit so they fit within D1's per-row limit. Saving requires the revision last observed by the browser; a concurrent save from another device returns a conflict rather than overwriting its data. Restore asks before replacing the local database, checks the schema and row shape, and runs all writes in one SQLite transaction. Restore is blocked during a live workout. Local and server copies are never automatically merged.

This is server backup, not end-to-end encrypted storage. The service operator and infrastructure provider can access the stored backup. Cloudflare's recovery retention also applies after active records are deleted. The public policy is served at `/privacy/` and its source is [PRIVACY.md](../PRIVACY.md).

## Local verification

`npm run test:cloud` runs real Workers/D1 integration tests with Miniflare and a fake email provider. `flutter test test/feature_24_cloud_backup_test.dart` exercises a real SQLite backup round trip, failed-restore rollback, UI confirmation, and explicit saving. `npm run dev:cloud` generates an isolated local binding, applies migrations locally, and serves the compiled app on `http://localhost:8788`. To test real email delivery, copy `.dev.vars.example` to the ignored `.dev.vars` and configure a sending key and sender. Wrangler reads this ignored file from the repository root. Automated tests use a fake mailer instead. Never point a local test at the production database.
