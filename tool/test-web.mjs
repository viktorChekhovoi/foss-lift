// Exercises the compiled release, including real browser SQLite storage.
import assert from 'node:assert/strict';
import { mkdir, writeFile } from 'node:fs/promises';
import { chromium } from 'playwright';
import { serveWeb } from './web-server.mjs';

const server = await serveWeb();
const browser = await chromium.launch({
  ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}),
  args: ['--no-sandbox'],
});
const results = [];
try {
  for (const fallback of [false, true]) {
    const context = await browser.newContext({ viewport: { width: 390, height: 844 }, locale: 'en-US' });
    const page = await context.newPage();
    const errors = [];
    const outside = [];
    const backendRequests = [];
    page.on('pageerror', (error) => errors.push(error.message));
    page.on('request', (request) => { if (!request.url().startsWith(server.url) && !request.url().startsWith('blob:')) outside.push(request.url()); });
    page.on('request', (request) => { if (/^\/(api|auth)(\/|$)/.test(new URL(request.url()).pathname)) backendRequests.push(request.url()); });
    // Simulate a browser without WasmGC. Routing/intercepting requests would
    // disable Chromium's HTTP cache and invalidate the repeat-visit measurement.
    if (fallback) await page.addInitScript(() => { WebAssembly.validate = () => false; });
    if (process.env.SLOW_NETWORK) {
      const session = await context.newCDPSession(page);
      await session.send('Network.emulateNetworkConditions', { offline: false, downloadThroughput: 200000, uploadThroughput: 100000, latency: 150 });
    }
    for (const visit of ['cold', 'repeat']) {
      await page.goto(server.url, { waitUntil: 'domcontentloaded' });
      await page.waitForFunction(() => document.getElementById('boot')?.hidden, { timeout: 60000 });
      await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
      if (visit === 'cold') await page.getByRole('button', { name: 'Not now', exact: true }).click({ timeout: 10000 });
      await page.getByRole('button', { name: 'Ready-made routines', exact: true }).waitFor({ timeout: 10000 });
      await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      const report = await page.evaluate(() => ({
        readyMs: Math.round(performance.getEntriesByName('fosslift-ready')[0].startTime),
        resources: performance.getEntriesByType('resource').map((entry) => ({
          path: new URL(entry.name).pathname, bytes: entry.transferSize, decoded: entry.decodedBodySize,
        })),
      }));
      assert.ok(report.resources.some((r) => r.path.endsWith(fallback ? 'main.dart.js' : 'main.dart.wasm')));
      assert.equal(errors.length, 0, errors.join('\n'));
      assert.deepEqual(outside, [], 'The app must load its engine and fonts from its own origin');
      const result = { target: fallback ? 'javascript' : 'wasm', visit, ...report };
      results.push(result);
      console.log(`${result.target} ${visit}: ready ${result.readyMs} ms; transferred ${report.resources.reduce((n, r) => n + r.bytes, 0)} bytes`);
      await mkdir('build/web-verification', { recursive: true });
      // Skwasm presents from a worker after Flutter updates its semantics.
      // Allow that frame to arrive for the screenshot, after recording timing.
      await page.waitForTimeout(250);
      await page.screenshot({ path: `build/web-verification/${result.target}-${visit}.png` });
    }
    // A real program must survive a reload of the compiled app's browser store.
    await page.goto(`${server.url}/#/routines/library/gzclp`);
    await page.getByRole('button', { name: 'Add to my routines', exact: true }).click();
    await page.waitForFunction(() => location.hash === '#/routines');
    await page.getByRole('group', { name: /^GZCLP\b/ }).waitFor();
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.waitForFunction(() => document.getElementById('boot')?.hidden);
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.getByRole('group', { name: /^GZCLP\b/ }).waitFor();
    await page.getByRole('tab', { name: 'Profile', exact: true }).click();
    await page.getByRole('button', { name: 'About Foss Lift', exact: true }).waitFor();
    assert.equal(await page.getByRole('button', { name: 'Cloud backup', exact: true }).count(), 0);
    await page.waitForTimeout(250);
    await page.screenshot({ path: `build/web-verification/${fallback ? 'javascript' : 'wasm'}-profile.png` });
    assert.deepEqual(backendRequests, [], 'Training and Profile must not contact an account or backup API');
    assert.deepEqual(outside, []);
    assert.deepEqual(errors, []);
    await context.close();
  }
  await writeFile('build/web-verification/measurements.json', JSON.stringify(results, null, 2) + '\n');
} finally { await browser.close(); await server.close(); }
