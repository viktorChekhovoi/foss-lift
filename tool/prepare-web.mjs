import { createHash } from 'node:crypto';
import { readdir, readFile, mkdir, rename, writeFile, stat, rm } from 'node:fs/promises';
import path from 'node:path';
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
  for (const name of names) await rename(path.join(output, name), path.join(output, prefix, name));
  bootstrap = bootstrap.replace(`__FOSS_LIFT_${group}_ROOT__`, prefix);
  console.log(`Versioned ${group.toLowerCase()}: ${prefix}`);
}
await writeFile(bootstrapPath, bootstrap);
const indexFile = path.join(output, 'index.html');
const release = createHash('sha256').update(bootstrap).digest('hex').slice(0, 20);
await writeFile(indexFile, (await readFile(indexFile, 'utf8')).replace('__FOSS_LIFT_BOOT_VERSION__', release));
await writeFile(path.join(output, 'flutter_service_worker.js'), await readFile('web/retire-service-worker.js'));
await writePrivacyPage(output);
