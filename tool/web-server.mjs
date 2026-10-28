// A local production-like static server for compiled-browser verification.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { brotliCompressSync, brotliDecompressSync, constants } from 'node:zlib';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export async function serveWeb(port = 0) {
  const root = path.resolve('build/web');
  const encoded = JSON.parse(await readFile(path.join(root, '_encodings.json'), 'utf8').catch(() => '{}'));
  const cache = new Map();
  const types = { '.js': 'application/javascript', '.mjs': 'application/javascript', '.wasm': 'application/wasm', '.html': 'text/html; charset=utf-8', '.json': 'application/json', '.ttf': 'font/ttf', '.otf': 'font/otf', '.png': 'image/png' };
  const server = createServer(async (request, response) => {
    try {
      let route = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
      if (route.startsWith('/api/')) {
        response.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
        response.end(JSON.stringify({ available: false, email: null, revision: 0 }));
        return;
      }
      if (route.endsWith('/')) route += 'index.html';
      const absolute = path.resolve(root, `.${route}`);
      if (!absolute.startsWith(root + path.sep)) { response.writeHead(403); response.end(); return; }
      let file = cache.get(absolute);
      if (!file) {
        const bytes = await readFile(absolute);
        const raw = encoded[route.slice(1)] ? brotliDecompressSync(bytes) : bytes;
        const br = encoded[route.slice(1)] ? bytes : brotliCompressSync(raw, { params: { [constants.BROTLI_PARAM_QUALITY]: 5 } });
        file = { raw, br, etag: `"${createHash('sha256').update(bytes).digest('hex')}"` };
        cache.set(absolute, file);
      }
      const headers = {
        'Content-Type': types[path.extname(absolute)] || 'application/octet-stream',
        'Cache-Control': route.startsWith('/_app/') ? 'public, max-age=31536000, immutable' : 'no-cache',
        'Cross-Origin-Opener-Policy': 'same-origin',
        'Cross-Origin-Embedder-Policy': 'require-corp',
        'Referrer-Policy': 'no-referrer',
        'X-Content-Type-Options': 'nosniff',
        ETag: file.etag,
        Vary: 'Accept-Encoding',
      };
      if (request.headers['if-none-match'] === file.etag) { response.writeHead(304, headers); response.end(); return; }
      const compressed = /\bbr\b/.test(request.headers['accept-encoding'] || '');
      const body = compressed ? file.br : file.raw;
      if (compressed) headers['Content-Encoding'] = 'br';
      headers['Content-Length'] = body.length;
      response.writeHead(200, headers); response.end(body);
    } catch (_) { response.writeHead(404); response.end('Not found'); }
  });
  await new Promise((resolve) => server.listen(port, '127.0.0.1', resolve));
  return { url: `http://127.0.0.1:${server.address().port}`, close: () => new Promise((resolve) => { server.close(resolve); server.closeAllConnections(); }) };
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const server = await serveWeb(Number(process.argv[2]) || 8789);
  console.log(`Serving compiled web app: ${server.url}`);
}
