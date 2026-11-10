// HordeSurvival 3D — Service Worker
// Transparently caches the Godot Web payload (wasm, pck, js) in Cache Storage
// so subsequent visits load in seconds without re-downloading large files.
const CACHE_NAME = 'hs3d-v4';

const CACHE_ASSETS = [
  'index.wasm',
  'index.wasm.gz',
  'index.pck',
  'index.js',
  'index.html',
  'index.offline.html',
  'index.icon.png',
  'index.apple-touch-icon.png'
];

self.addEventListener('install', (event) => {
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
  if (url.origin !== self.location.origin) return;

  const path = url.pathname;
  const file = path.substring(path.lastIndexOf('/') + 1);

  // Audio worklets must stay strictly in sync with index.js — never cache them.
  if (file === 'index.audio.worklet.js' || file === 'index.audio.position.worklet.js') {
    event.respondWith(fetch(event.request, { cache: 'no-store' }));
    return;
  }

  // HTML shell: network-first with offline cache fallback
  if (path.endsWith('/') || path.endsWith('/index.html')) {
    event.respondWith(networkFirst(event.request));
    return;
  }

  // Engine files & assets: cache-first with network fallback & background cache population
  if (CACHE_ASSETS.includes(file)) {
    event.respondWith(cacheFirst(event.request));
    return;
  }
});

async function cacheFirst(request) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request, { ignoreSearch: true });
  if (cached) {
    return cached;
  }
  const response = await fetch(request);
  if (response && response.status === 200) {
    try {
      cache.put(request, response.clone());
    } catch (e) {
      console.warn('SW cache.put error:', e);
    }
  }
  return response;
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
    if (hit) return hit;
    const offlineHit = await cache.match('index.offline.html');
    if (offlineHit) return offlineHit;
    throw e;
  }
}
