import { createHash } from 'node:crypto';
import { readdir, readFile, mkdir, rename, writeFile, stat, rm, cp } from 'node:fs/promises';
import path from 'node:path';
import { brotliCompress, constants } from 'node:zlib';
import { promisify } from 'node:util';
import { writePrivacyPage } from './privacy-page.mjs';

const output = path.resolve(process.argv[2] || 'build/web');
async function digest(hash, relative) {
  const absolute = path.join(output, relative);
  const info = await stat(absolute);
  if (info.isDirectory()) {
    for (const name of (await readdir(absolute)).sort()) await digest(hash, path.join(relative, name));
  } else {
    hash.update(relative).update(await readFile(absolute));
  }
}
const bootstrapPath = path.join(output, 'flutter_bootstrap.js');
let bootstrap = await readFile(bootstrapPath, 'utf8');
if (!bootstrap.includes('__FOSS_LIFT_ASSET_ROOT__')) throw new Error('Custom web loader missing');
for (const name of ['assets', 'canvaskit', 'main.dart.js', 'main.dart.wasm', 'main.dart.mjs']) await stat(path.join(output, name));
await rm(path.join(output, '_app'), { recursive: true, force: true });
// Spend compression CPU once during the build instead of transferring the
// larger default edge encoding on every first visit. Supported Flutter browsers
// all decode Brotli. Explicit headers and no-transform preserve these bytes.
const wasm = [];
async function findWasm(relative) {
  const info = await stat(path.join(output, relative));
  if (info.isDirectory()) {
    for (const name of await readdir(path.join(output, relative))) await findWasm(path.join(relative, name));
  } else if (relative.endsWith('.wasm')) wasm.push(relative);
}
for (const name of ['main.dart.wasm', 'sqlite3.wasm', 'canvaskit']) await findWasm(name);
const compress = promisify(brotliCompress);
const encodings = {};
await Promise.all(wasm.map(async (name) => {
  const file = path.join(output, name);
  const raw = await readFile(file);
  const encoded = await compress(raw, { params: { [constants.BROTLI_PARAM_QUALITY]: 11 } });
  await writeFile(file, encoded);
  encodings[name] = { rawBytes: raw.length, bytes: encoded.length };
}));
// Cache the engine separately: changing app code must not download Skia again.
for (const [group, names] of [
  ['APP', ['main.dart.js', 'main.dart.wasm', 'main.dart.mjs']],
  ['ASSET', ['assets']],
  ['ENGINE', ['canvaskit']],
]) {
  const hash = createHash('sha256');
  for (const name of names) await digest(hash, name);
  const prefix = `_app/${hash.digest('hex').slice(0, 20)}/`;
  await mkdir(path.join(output, prefix), { recursive: true });
  for (const name of names) {
    // Open tabs from the previous release still refer to root assets (notably
    // the rest tone). Keep that compatibility path until those tabs close.
    if (name === 'assets') await cp(path.join(output, name), path.join(output, prefix, name), { recursive: true });
    else await rename(path.join(output, name), path.join(output, prefix, name));
  }
  for (const name of Object.keys(encodings)) {
    if (names.some((root) => name === root || name.startsWith(root + '/'))) {
      encodings[prefix + name] = encodings[name];
      delete encodings[name];
    }
  }
  bootstrap = bootstrap.replace(`__FOSS_LIFT_${group}_ROOT__`, prefix);
  console.log(`Versioned ${group.toLowerCase()}: ${prefix}`);
}
await writeFile(bootstrapPath, bootstrap);
const indexFile = path.join(output, 'index.html');
const release = createHash('sha256').update(bootstrap).digest('hex').slice(0, 20);
await writeFile(indexFile, (await readFile(indexFile, 'utf8')).replace('__FOSS_LIFT_BOOT_VERSION__', release));
await writeFile(path.join(output, 'flutter_service_worker.js'), await readFile('web/retire-service-worker.js'));
await writePrivacyPage(output);
const encodingRules = Object.keys(encodings).sort().map((name) =>
  `/${name}\n  Content-Encoding: br\n  Content-Type: application/wasm\n  Cache-Control: ${name.startsWith('_app/') ? 'no-transform' : 'no-cache, no-transform'}\n`).join('\n');
await writeFile(path.join(output, '_headers'), (await readFile(path.join(output, '_headers'), 'utf8')) + '\n' + encodingRules);
await writeFile(path.join(output, '_encodings.json'), JSON.stringify(encodings, null, 2) + '\n');
console.log(`Brotli-compressed ${wasm.length} WebAssembly modules at build time`);
