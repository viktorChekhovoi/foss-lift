// This replaces the deprecated generated Flutter worker on existing installs.
// Only its known static caches are removed. Training storage is never touched.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil((async () => {
  await Promise.all(['flutter-app-cache', 'flutter-temp-cache', 'flutter-app-manifest'].map((name) => caches.delete(name)));
  await self.clients.claim();
  await self.registration.unregister();
})()));
