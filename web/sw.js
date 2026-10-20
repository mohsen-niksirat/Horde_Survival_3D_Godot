// HordeSurvival 3D — Service Worker
// Cache-first for the versioned engine payload (wasm/pck/js), network-first
// for the HTML shell. Audio worklets are deliberately never cached: mixing a
// worklet from one Godot export with index.js from another causes
// `GodotAudio.sampleNodes is null` during startup.
const CACHE_NAME = 'hs3d-v3';

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
  // Cache the network response before resolving respondWith; Godot's engine
  // fetches stream large files and a clone() before the body finishes can
  // leave the promise pending forever in some browsers.
  const res = await fetch(request);
  if (res && res.ok) {
    const copy = res.clone();
    copy.arrayBuffer().then(buf =>
      cache.put(request, new Response(buf, {
        status: res.status,
        statusText: res.statusText,
        headers: res.headers,
      }))
    ).catch(() => {});
  }
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
