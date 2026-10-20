// HordeSurvival 3D — Service Worker
// Network-first for the Godot engine payload and HTML shell. Large wasm/pck
// responses are intentionally not intercepted by Cache Storage: on some
// browsers a service-worker response stays pending and blocks startGame.
const CACHE_NAME = 'hs3d-v4';

// Engine payload — fingerprinted by Godot export; safe to cache forever
// until CACHE_NAME changes (files are content-stable between builds).
const ENGINE_FILES = [
  'index.wasm',
  'index.pck',
  'index.js',
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
    // Worklets must stay in lockstep with index.js. Bypass both SW and the
    // browser HTTP cache so a previous deployment cannot be mixed in.
    if (file === 'index.audio.worklet.js' || file === 'index.audio.position.worklet.js') {
      event.respondWith(fetch(event.request, { cache: 'no-store' }));
      return;
    }
    if (ENGINE_FILES.includes(file)) {
      // Let the browser fetch the large payload directly. Do not call
      // respondWith/cacheFirst for wasm or pck.
      return;
    }
  }
  if (path.endsWith('/') || path.endsWith('/index.html')) {
    event.respondWith(networkFirst(event.request));
  }
});

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
