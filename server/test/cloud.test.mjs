// HTTP + real D1 integration coverage for catalogue section 24.
import { afterEach, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';

const origin = 'https://foss.example';
let runtime, db, messages, mailStatus;
beforeEach(async () => {
  messages = [];
  mailStatus = 200;
  runtime = new Miniflare(convertV4MiniflareOptions({
    modules: true,
    scriptPath: 'build/cloud-test/worker.js',
    compatibilityDate: '2026-10-01',
    d1Databases: ['DB'],
    bindings: { APP_ORIGIN: origin, EMAIL_FROM: 'Foss Lift <login@example.com>', RESEND_API_KEY: 'test-key' },
    serviceBindings: {
      MAILER: async (request) => {
        messages.push(await request.json());
        return Response.json({ id: 'test-message' }, { status: mailStatus });
      },
    },
  }));
  db = await runtime.getD1Database('DB');
  for (const sql of (await readFile('migrations/0001_cloud.sql', 'utf8')).split(';').filter((s) => s.trim())) {
    await db.prepare(sql).run();
  }
});
afterEach(async () => { await runtime?.dispose(); });

function request(route, { method = 'GET', body, cookie, headers = {} } = {}) {
  return runtime.dispatchFetch(`${origin}${route}`, {
    method,
    headers: { ...(method !== 'GET' ? { Origin: origin } : {}),
      ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
      ...(cookie ? { Cookie: cookie } : {}), ...headers },
    ...(body !== undefined ? { body: typeof body === 'string' ? body : JSON.stringify(body) } : {}),
  });
}
function cookieFrom(response, name) {
  return response.headers.getSetCookie().find((c) => c.startsWith(`${name}=`))?.split(';')[0];
}
async function ask(email = 'alice@example.com') {
  const response = await request('/api/auth/request', { method: 'POST', body: { email } });
  assert.equal(response.status, 202);
  const browser = cookieFrom(response, '__Host-fl-login');
  const token = messages.at(-1).text.match(/#token=([a-f0-9]{64})/)[1];
  return { browser, token, response };
}
async function signIn(email = 'alice@example.com') {
  const { token, browser } = await ask(email);
  const response = await request('/api/auth/consume', { method: 'POST', body: { token }, cookie: browser });
  assert.equal(response.status, 200);
  return { cookie: cookieFrom(response, '__Host-fl-session'), response };
}
const backup = (name) => ({ format: 'foss-lift-cloud-1', schema: 18, tables: { routines: [{ name }] } });
const save = (cookie, revision, name) => request('/api/backup', {
  method: 'PUT', cookie, body: backup(name), headers: { 'If-Match': `"${revision}"` },
});

test('offline visitors need no account; unconfigured and preview deployments fail closed', async () => {
  assert.deepEqual(await (await request('/api/session')).json(), { available: true, email: null, revision: 0, updatedAt: null });
  assert.equal((await request('/api/backup')).status, 401);
  const preview = await runtime.dispatchFetch('https://preview.example/api/session');
  assert.equal((await preview.json()).available, false);
  assert.equal((await runtime.dispatchFetch('https://preview.example/api/backup')).status, 503);
});

test('email links are hashed, browser-bound, single use, and use secure cookies', async () => {
  const { token, browser, response } = await ask('Alice@Example.com');
  assert.equal((await response.json()).token, undefined);
  const stored = await db.prepare('SELECT * FROM magic_links').first();
  assert.notEqual(stored.token_hash, token);
  assert.equal(stored.email, 'alice@example.com');
  assert.ok(stored.expires_at <= Date.now() / 1000 + 901);
  // A scanner's GET and another browser cannot consume the link.
  assert.notEqual((await request(`/api/auth/consume?token=${token}`)).status, 200);
  assert.equal((await request('/api/auth/consume', { method: 'POST', body: { token } })).status, 400);
  const results = await Promise.all([0, 1].map(() => request('/api/auth/consume', { method: 'POST', body: { token }, cookie: browser })));
  assert.deepEqual(results.map((r) => r.status).sort(), [200, 400]);
  const success = results.find((r) => r.status === 200);
  const setCookie = success.headers.getSetCookie().find((v) => v.startsWith('__Host-fl-session='));
  for (const attribute of ['HttpOnly', 'Secure', 'SameSite=Lax', 'Path=/', 'Max-Age=2592000']) assert.ok(setCookie.includes(attribute));
  const cookie = cookieFrom(success, '__Host-fl-session');
  assert.equal((await (await request('/api/session', { cookie })).json()).email, 'alice@example.com');
});

test('expired links and expired sessions do not authenticate', async () => {
  const { browser, token } = await ask();
  await db.prepare('UPDATE magic_links SET expires_at = 0').run();
  assert.equal((await request('/api/auth/consume', { method: 'POST', body: { token }, cookie: browser })).status, 400);
  const { cookie } = await signIn('bob@example.com');
  await db.prepare('UPDATE auth_sessions SET expires_at = 0').run();
  assert.equal((await request('/api/backup', { cookie })).status, 401);
});

test('save and restore isolate users and prevent concurrent backup overwrites', async () => {
  const alice = (await signIn()).cookie;
  const bob = (await signIn('bob@example.com')).cookie;
  assert.equal((await save(alice, 0, 'First')).status, 200);
  assert.equal((await request('/api/backup', { cookie: bob })).status, 404);
  const updates = await Promise.all([save(alice, 1, 'Second'), save(alice, 1, 'Third')]);
  assert.deepEqual(updates.map((r) => r.status).sort(), [200, 409]);
  const restored = await request('/api/backup', { cookie: alice });
  assert.equal(restored.headers.get('ETag'), '"2"');
  assert.equal(restored.headers.get('Cache-Control'), 'no-store');
  assert.ok(['Second', 'Third'].includes((await restored.json()).tables.routines[0].name));
  assert.equal((await save(alice, 0, 'Stale device')).status, 409);
});

test('writes reject cross-origin requests, missing revisions, malformed and oversized backups', async () => {
  const { cookie } = await signIn();
  assert.equal((await request('/api/account', { method: 'DELETE', cookie, headers: { Origin: 'https://attacker.example' } })).status, 403);
  assert.equal((await request('/api/account', { method: 'DELETE', cookie, headers: { Origin: '' } })).status, 403);
  assert.equal((await request('/api/backup', { method: 'PUT', cookie, body: backup('No revision') })).status, 428);
  assert.equal((await request('/api/backup', { method: 'PUT', cookie, body: '{', headers: { 'If-Match': '"0"' } })).status, 400);
  assert.equal((await request('/api/backup', { method: 'PUT', cookie, body: { ...backup('No live state'), tables: { live_sessions: [] } }, headers: { 'If-Match': '"0"' } })).status, 400);
  assert.equal((await request('/api/backup', { method: 'PUT', cookie, body: ' '.repeat(1024 * 1024 + 1), headers: { 'If-Match': '"0"' } })).status, 413);
  assert.equal((await request('/api/backup', { cookie })).status, 404);
});

test('rate-limited email requests return the same response and do not send more mail', async () => {
  for (let i = 0; i < 5; i++) {
    const result = await request('/api/auth/request', { method: 'POST', body: { email: 'alice@example.com' } });
    assert.equal(result.status, 202);
    assert.deepEqual(await result.json(), { ok: true });
  }
  assert.equal(messages.length, 3);
});

test('provider failure removes the unusable link', async () => {
  mailStatus = 503;
  const response = await request('/api/auth/request', { method: 'POST', body: { email: 'alice@example.com' } });
  assert.equal(response.status, 503);
  assert.equal((await db.prepare('SELECT COUNT(*) AS n FROM magic_links').first()).n, 0);
});

test('sign out revokes its session and account deletion removes server data only for that user', async () => {
  const alice = (await signIn()).cookie;
  const aliceOther = (await signIn()).cookie;
  const bob = (await signIn('bob@example.com')).cookie;
  await save(alice, 0, 'Alice');
  await save(bob, 0, 'Bob');
  assert.equal((await request('/api/auth/logout', { method: 'POST', cookie: alice })).status, 200);
  assert.equal((await request('/api/backup', { cookie: alice })).status, 401);
  await ask();
  assert.equal((await request('/api/account', { method: 'DELETE', cookie: aliceOther })).status, 200);
  assert.equal((await request('/api/backup', { cookie: aliceOther })).status, 401);
  assert.equal((await db.prepare('SELECT COUNT(*) AS n FROM magic_links WHERE email = ?').bind('alice@example.com').first()).n, 0);
  assert.equal((await db.prepare('SELECT COUNT(*) AS n FROM snapshots').first()).n, 1);
  assert.equal((await (await request('/api/backup', { cookie: bob })).json()).tables.routines[0].name, 'Bob');
});
