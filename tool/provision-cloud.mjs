// Additive free-tier provisioning. The standard root Wrangler configuration is
// the source of truth; database IDs and sender addresses are not secrets.
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import path from 'node:path';

const config = JSON.parse(await readFile('wrangler.jsonc', 'utf8'));
config.vars.EMAIL_FROM = process.env.CLOUD_EMAIL_FROM || config.vars.EMAIL_FROM;
await mkdir('build', { recursive: true });
const local = process.argv.includes('--local');
const optional = process.argv.includes('--optional');
const account = process.env.CLOUDFLARE_ACCOUNT_ID;
const token = process.env.CLOUDFLARE_API_TOKEN;

if (local) {
  // Only D1 migration commands use this alternate file; Pages uses its standard
  // root config with explicit local bindings and an isolated persistence path.
  config.d1_databases = [{ binding: 'DB', database_name: 'foss-lift-local', database_id: 'DB', migrations_dir: path.resolve('migrations') }];
  config.pages_build_output_dir = path.resolve('build/web');
  await writeFile('build/wrangler.local.json', JSON.stringify(config, null, 2) + '\n');
  console.log('Local D1 configuration: build/wrangler.local.json');
} else {
  async function api(route, options = {}) {
    const response = await fetch(`https://api.cloudflare.com/client/v4/accounts/${account}${route}`, {
      ...options,
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      signal: AbortSignal.timeout(30000),
    });
    const body = await response.json();
    if (!response.ok || !body.success) {
      throw new Error(`Cloudflare returned HTTP ${response.status}; the API token needs account D1:Edit and Pages:Edit permissions.`);
    }
    return body;
  }
  let database;
  if (!process.argv.includes('--static')) {
    try {
      if (!account || !token) throw new Error('Set CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN.');
      for (let page = 1; ; page++) {
        const result = await api(`/d1/database?per_page=100&page=${page}`);
        database = result.result.find((item) => item.name === 'foss-lift-users');
        if (database || result.result.length < 100) break;
      }
      if (!database) database = (await api('/d1/database', {
        method: 'POST', body: JSON.stringify({ name: 'foss-lift-users', primary_location_hint: 'enam' }),
      })).result;
      config.d1_databases = [{ binding: 'DB', database_name: 'foss-lift-users', database_id: database.uuid, migrations_dir: 'migrations' }];
    } catch (error) {
      if (!optional) throw error;
      // Keep any already-declared binding. Losing permission must not silently
      // remove a previously configured database from a deployment.
      console.log(`::warning::Cloud storage was not configured: ${error.message}`);
    }
  }
  await writeFile('wrangler.jsonc', JSON.stringify(config, null, 2) + '\n');
  if (database) {
    const result = spawnSync(path.resolve('node_modules/.bin/wrangler'),
      ['d1', 'migrations', 'apply', 'DB', '--remote'],
      { stdio: 'inherit', env: { ...process.env, CI: 'true' } });
    if (result.error) throw result.error;
    if (result.status !== 0) process.exit(result.status || 1);
    console.log(`D1 configured: ${database.name} (${database.uuid}). Email delivery also requires its key and sender.`);
  }
  console.log('Deployment configuration: wrangler.jsonc');
}
