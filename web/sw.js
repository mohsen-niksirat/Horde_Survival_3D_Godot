// HordeSurvival 3D — Service Worker
// Cache-first for the engine payload (wasm/pck/js/audio), network-first for
// the HTML shell so new deploys are picked up immediately. Bump CACHE_NAME
// on any asset change to invalidate stale caches across installs.
const CACHE_NAME = 'hs3d-v1';

// Engine payload — fingerprinted by Godot export; safe to cache forever
// until CACHE_NAME changes (files are content-stable between builds).
const ENGINE_FILES = [
  'index.wasm',
  'index.pck',
  'index.js',
  'index.audio.worklet.js',
  'index.audio.position.worklet.js',
  'index.offline.html',
];

self.addEventListener('install', (event) => {
  // Activate immediately — don't wait for all tabs to close.
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  const path = url.pathname;

  // Only handle same-origin requests under this Pages deployment.
  if (url.origin !== self.location.origin) return;
  if (!path.endsWith('/')) {
    const file = path.substring(path.lastIndexOf('/') + 1);
    if (ENGINE_FILES.includes(file)) {
      event.respondWith(cacheFirst(event.request));
      return;
    }
  }
  if (path.endsWith('/') || path.endsWith('/index.html')) {
    event.respondWith(networkFirst(event.request));
  }
});

async function cacheFirst(request) {
  const cache = await caches.open(CACHE_NAME);
  const hit = await cache.match(request, { ignoreSearch: true });
  if (hit) return hit;
  const res = await fetch(request);
  if (res && res.ok) cache.put(request, res.clone());
  return res;
}

async function networkFirst(request) {
  try {
    const res = await fetch(request);
    const cache = await caches.open(CACHE_NAME);
    if (res && res.ok) cache.put(request, res.clone());
    return res;
  } catch (e) {
    const cache = await caches.open(CACHE_NAME);
    const hit = await cache.match(request, { ignoreSearch: true });
    return hit || Response.error();
  }
}
