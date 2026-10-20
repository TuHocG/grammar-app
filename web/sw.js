// Service worker of the web app (docs/07 §12): keeps the app shell (the HTML, the compiled app,
// CanvasKit, fonts, assets) so the app opens offline once it was loaded. The lesson data and the
// pictures (data/, img/) are not touched here: the app keeps them itself in Cache Storage.
//
// Registered as sw.js?v=<build version> by flutter_bootstrap.js; the shell cache is named after
// that version, so a new build gets a fresh cache and the old one is deleted on activation. The
// list of shell files comes from shell.json, written by tool/web/build_web.py after the build.
const VERSION = new URL(self.location).searchParams.get('v') || 'dev';
const SHELL = `shell-${VERSION}`;
const scopePath = (rel) => new URL(rel, self.registration.scope).pathname;
const DATA = scopePath('data/');
const IMG = scopePath('img/');

// Fresh when the network answers in time, the cached copy otherwise.
const NETWORK_FIRST_MS = 4000;

self.addEventListener('install', (event) => {
  // Take over from the previous build's worker as soon as the shell is cached (not awaited: the
  // promotion itself only happens after install completes).
  self.skipWaiting();
  event.waitUntil(
    (async () => {
      const cache = await caches.open(SHELL);
      const r = await fetch(`shell.json?v=${VERSION}`, { cache: 'no-cache' });
      if (!r.ok) throw new Error(`shell.json: HTTP ${r.status} (build with tool/web/build_web.py)`);
      await cache.addAll(await r.json());
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((names) => Promise.all(names.filter((n) => n.startsWith('shell-') && n !== SHELL).map((n) => caches.delete(n))))
      .then(() => self.clients.claim()),
  );
});

// The entry points carry the build version: they must be seen fresh, or no new build ever lands.
const isEntry = (url) => {
  const name = url.pathname.slice(url.pathname.lastIndexOf('/') + 1);
  return name === '' || ['index.html', 'flutter_bootstrap.js', 'manifest.json', 'version.json'].includes(name);
};

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin) return;
  if (url.pathname.startsWith(DATA) || url.pathname.startsWith(IMG)) return; // the app's own caches
  if (event.request.mode === 'navigate' || isEntry(url)) {
    event.respondWith(networkFirst(event.request));
    return;
  }
  // Everything else of the shell is content-hashed or precached: cache first, filled from the
  // network on first use.
  event.respondWith(caches.match(event.request, { ignoreSearch: true }).then((hit) => hit || fetch(event.request).then((r) => keep(event.request, r))));
});

async function networkFirst(request) {
  const timeout = new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), NETWORK_FIRST_MS));
  try {
    return keep(request, await Promise.race([fetch(request), timeout]));
  } catch (_) {
    // Offline: the page itself comes from the precached root ("./"), never a redirected copy.
    const hit = await caches.match(request.mode === 'navigate' ? './' : request, { ignoreSearch: true });
    return hit || Response.error();
  }
}

function keep(request, response) {
  if (response.ok && !response.redirected) {
    const copy = response.clone();
    caches.open(SHELL).then((cache) => cache.put(request, copy));
  }
  return response;
}
