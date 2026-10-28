import { readFile, mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

// PRIVACY.md is the single source for the policy in Git and on the public site.
export async function writePrivacyPage(output) {
  const escape = (value) => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
  const inline = (value) => escape(value).replace(/\[([^\]]+)\]\((https:\/\/[^)]+)\)/g, '<a href="$2">$1</a>');
  const content = (await readFile('PRIVACY.md', 'utf8')).trim().split(/\n\n+/).map((paragraph) => {
    if (paragraph.startsWith('# ')) return `<h1>${inline(paragraph.slice(2))}</h1>`;
    if (paragraph.startsWith('## ')) return `<h2>${inline(paragraph.slice(3))}</h2>`;
    return `<p>${inline(paragraph.replaceAll('\n', ' '))}</p>`;
  }).join('\n');
  await mkdir(path.join(output, 'privacy'), { recursive: true });
  await writeFile(path.join(output, 'privacy/index.html'), `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Privacy · Foss Lift</title><style>
body{margin:0;background:#0e1117;color:#e8edf4;font:16px/1.65 system-ui,sans-serif}main{max-width:760px;margin:auto;padding:32px 24px 64px}h1{font-size:32px;line-height:1.2}h2{font-size:22px;margin-top:32px}a{color:#ff996d}
</style></head><body><main><a href="/">← Foss Lift</a>${content}</main></body></html>\n`);
}
