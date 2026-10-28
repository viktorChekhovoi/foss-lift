const MAX_BACKUP = 1024 * 1024;
const SESSION_COOKIE = '__Host-fl-session';
const LOGIN_COOKIE = '__Host-fl-login';
const LINK_LIFETIME = 15 * 60;
const SESSION_LIFETIME = 30 * 24 * 60 * 60;
const encoder = new TextEncoder();
const headers = {
  'Content-Type': 'application/json; charset=utf-8',
  'Cache-Control': 'no-store',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  'Cross-Origin-Resource-Policy': 'same-origin',
};
const json = (body, status = 200, extra = {}) =>
  new Response(JSON.stringify(body), { status, headers: { ...headers, ...extra } });
const cookie = (name, value, age) =>
  `${name}=${value}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${age}`;
const randomToken = () => [...crypto.getRandomValues(new Uint8Array(32))]
  .map((v) => v.toString(16).padStart(2, '0')).join('');
const hash = async (value) => [...new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(value)))]
  .map((v) => v.toString(16).padStart(2, '0')).join('');
const tokenCookie = (request, name) => {
  const value = (request.headers.get('Cookie') || '').split(';')
    .map((v) => v.trim()).find((v) => v.startsWith(`${name}=`))?.slice(name.length + 1);
  return /^[a-f0-9]{64}$/.test(value || '') ? value : null;
};
class Refusal extends Error {
  constructor(code, status) { super(code); this.status = status; }
}
async function readBody(request, limit) {
  if (Number(request.headers.get('Content-Length') || 0) > limit) throw new Refusal('too_large', 413);
  const reader = request.body?.getReader();
  if (!reader) throw new Refusal('invalid_request', 400);
  const parts = [];
  let length = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > limit) throw new Refusal('too_large', 413);
      parts.push(value);
    }
  } finally { await reader.cancel(); }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const part of parts) { bytes.set(part, offset); offset += part.length; }
  return new TextDecoder('utf-8', { fatal: true }).decode(bytes);
}
async function bodyJson(request, limit) {
  if (!request.headers.get('Content-Type')?.startsWith('application/json')) throw new Refusal('invalid_request', 415);
  const raw = await readBody(request, limit);
  try { return { raw, value: JSON.parse(raw) }; }
  catch { throw new Refusal('invalid_request', 400); }
}
async function session(request, db, now) {
  const token = tokenCookie(request, SESSION_COOKIE);
  if (!token) return null;
  return db.prepare(`SELECT u.id, u.email, s.token_hash, b.revision, b.updated_at
    FROM auth_sessions s JOIN users u ON u.id = s.user_id
    LEFT JOIN snapshots b ON b.user_id = u.id
    WHERE s.token_hash = ? AND s.expires_at > ?`).bind(await hash(token), now).first();
}
async function cleanup(db, now) {
  await db.batch([
    db.prepare('DELETE FROM magic_links WHERE expires_at <= ?').bind(now),
    db.prepare('DELETE FROM auth_sessions WHERE expires_at <= ?').bind(now),
    db.prepare('DELETE FROM rate_limits WHERE expires_at <= ?').bind(now),
  ]);
}

export async function handleRequest(request, env) {
  try {
    const url = new URL(request.url);
    // Preview deployments cannot use production cookies, database, or login links.
    const available = Boolean(env.DB && env.RESEND_API_KEY && env.EMAIL_FROM && env.APP_ORIGIN === url.origin);
    if (url.pathname === '/api/session' && request.method === 'GET' && !available) {
      return json({ available: false, email: null, revision: 0 });
    }
    if (!available) return json({ error: 'not_configured' }, 503);
    if (!['GET', 'POST', 'PUT', 'DELETE'].includes(request.method)) return json({ error: 'method_not_allowed' }, 405);
    if (request.method !== 'GET' && request.headers.get('Origin') !== env.APP_ORIGIN) {
      return json({ error: 'wrong_origin' }, 403);
    }
    const db = env.DB;
    const now = Math.floor(Date.now() / 1000);
    if (url.pathname === '/api/auth/request' && request.method === 'POST') {
      const { value } = await bodyJson(request, 2048);
      const email = typeof value?.email === 'string' ? value.email.trim().toLowerCase() : '';
      if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return json({ error: 'invalid_email' }, 400);
      const ip = request.headers.get('CF-Connecting-IP') || 'local';
      const window = Math.floor(now / LINK_LIFETIME);
      const buckets = [
        { key: `email:${await hash(email)}:${window}`, limit: 3, expiry: now + LINK_LIFETIME },
        { key: `ip:${await hash(ip)}:${window}`, limit: 10, expiry: now + LINK_LIFETIME },
        { key: `mail:${Math.floor(now / 86400)}`, limit: 90, expiry: now + 86400 },
      ];
      await cleanup(db, now);
      const counts = await db.batch(buckets.map((b) => db.prepare(`INSERT INTO rate_limits(bucket, attempts, expires_at)
        VALUES (?, 1, ?) ON CONFLICT(bucket) DO UPDATE SET attempts = attempts + 1 RETURNING attempts`).bind(b.key, b.expiry)));
      const browser = randomToken();
      const accepted = () => json({ ok: true }, 202, { 'Set-Cookie': cookie(LOGIN_COOKIE, browser, LINK_LIFETIME) });
      if (counts.some((row, i) => row.results[0].attempts > buckets[i].limit)) return accepted();
      const token = randomToken();
      const tokenHash = await hash(token);
      await db.prepare('INSERT INTO magic_links(token_hash, browser_hash, email, expires_at) VALUES (?, ?, ?, ?)')
        .bind(tokenHash, await hash(browser), email, now + LINK_LIFETIME).run();
      const link = `${env.APP_ORIGIN}/auth/#token=${token}`;
      const mail = new Request('https://api.resend.com/emails', {
        method: 'POST',
        headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ from: env.EMAIL_FROM, to: [email], subject: 'Sign in to Foss Lift',
          text: `Sign in to Foss Lift:\n\n${link}\n\nThis link expires in 15 minutes and works only in the browser where you requested it. Open the page and press Continue. If you did not request it, ignore this email.` }),
      });
      let sent = false;
      try { sent = (await (env.MAILER ? env.MAILER.fetch(mail) : fetch(mail))).ok; }
      finally {
        if (!sent) await db.prepare('DELETE FROM magic_links WHERE token_hash = ?').bind(tokenHash).run();
      }
      if (!sent) return json({ error: 'email_unavailable' }, 503);
      return accepted();
    }
    if (url.pathname === '/api/auth/consume' && request.method === 'POST') {
      const { value } = await bodyJson(request, 2048);
      const browser = tokenCookie(request, LOGIN_COOKIE);
      if (!browser || !/^[a-f0-9]{64}$/.test(value?.token || '')) return json({ error: 'invalid_link' }, 400);
      const link = await db.prepare(`DELETE FROM magic_links
        WHERE token_hash = ? AND browser_hash = ? AND expires_at > ? RETURNING email`)
        .bind(await hash(value.token), await hash(browser), now).first();
      if (!link) return json({ error: 'invalid_link' }, 400);
      const user = await db.prepare(`INSERT INTO users(id, email, created_at) VALUES (?, ?, ?)
        ON CONFLICT(email) DO UPDATE SET email = excluded.email RETURNING id`)
        .bind(crypto.randomUUID(), link.email, now).first();
      const token = randomToken();
      await db.prepare('INSERT INTO auth_sessions(token_hash, user_id, expires_at) VALUES (?, ?, ?)')
        .bind(await hash(token), user.id, now + SESSION_LIFETIME).run();
      const result = json({ ok: true });
      result.headers.append('Set-Cookie', cookie(SESSION_COOKIE, token, SESSION_LIFETIME));
      result.headers.append('Set-Cookie', cookie(LOGIN_COOKIE, '', 0));
      return result;
    }
    const user = await session(request, db, now);
    if (url.pathname === '/api/session' && request.method === 'GET') {
      return json({ available: true, email: user?.email || null, revision: user?.revision || 0, updatedAt: user?.updated_at || null });
    }
    if (!user) return json({ error: 'sign_in_required' }, 401);
    if (url.pathname === '/api/auth/logout' && request.method === 'POST') {
      await db.prepare('DELETE FROM auth_sessions WHERE token_hash = ?').bind(user.token_hash).run();
      return json({ ok: true }, 200, { 'Set-Cookie': cookie(SESSION_COOKIE, '', 0) });
    }
    if (url.pathname === '/api/account' && request.method === 'DELETE') {
      await db.batch([
        db.prepare('DELETE FROM magic_links WHERE email = ?').bind(user.email),
        db.prepare('DELETE FROM users WHERE id = ?').bind(user.id),
      ]);
      return json({ ok: true }, 200, { 'Set-Cookie': cookie(SESSION_COOKIE, '', 0) });
    }
    if (url.pathname === '/api/backup' && request.method === 'GET') {
      const row = await db.prepare('SELECT payload, revision FROM snapshots WHERE user_id = ?').bind(user.id).first();
      if (!row) return json({ error: 'no_backup' }, 404);
      return new Response(row.payload, { headers: { ...headers, ETag: `"${row.revision}"` } });
    }
    if (url.pathname === '/api/backup' && request.method === 'PUT') {
      const match = /^"(0|[1-9][0-9]{0,9})"$/.exec(request.headers.get('If-Match') || '');
      if (!match) return json({ error: 'revision_required' }, 428);
      const { raw, value } = await bodyJson(request, MAX_BACKUP);
      if (value?.format !== 'foss-lift-cloud-1' || !Number.isSafeInteger(value.schema) || value.schema < 1 ||
          !value.tables || typeof value.tables !== 'object' || Array.isArray(value.tables) ||
          Object.hasOwn(value.tables, 'live_sessions') || Object.values(value.tables).some((v) => !Array.isArray(v))) {
        return json({ error: 'invalid_backup' }, 400);
      }
      const revision = Number(match[1]);
      const row = revision === 0
        ? await db.prepare(`INSERT INTO snapshots(user_id, payload, revision, updated_at) VALUES (?, ?, 1, ?)
            ON CONFLICT(user_id) DO NOTHING RETURNING revision`).bind(user.id, raw, now).first()
        : await db.prepare(`UPDATE snapshots SET payload = ?, revision = revision + 1, updated_at = ?
            WHERE user_id = ? AND revision = ? RETURNING revision`).bind(raw, now, user.id, revision).first();
      if (!row) return json({ error: 'backup_changed' }, 409);
      return json({ revision: row.revision, updatedAt: now });
    }
    return json({ error: 'not_found' }, 404);
  } catch (error) {
    if (error instanceof Refusal) return json({ error: error.message }, error.status);
    // Do not put email addresses, tokens, or backup contents in Worker logs.
    return json({ error: 'service_unavailable' }, 503);
  }
}
