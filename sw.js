// Kudos service worker — minimal, just enough to be an installable PWA with an
// offline fallback. Network-first on same-origin app-shell assets only; never
// touches Supabase / fonts / any cross-origin (so no private data is cached).
const CACHE = 'kudos-shell-v1';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));

self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  if (url.origin !== location.origin) return;   // leave Supabase/fonts alone
  e.respondWith(
    fetch(e.request)
      .then(res => {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(e.request, copy)).catch(() => {});
        return res;
      })
      .catch(() => caches.match(e.request))       // offline: serve last-cached shell
  );
});
