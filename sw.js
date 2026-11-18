/* MaraPass – Service Worker: app shell + Leaflet + tiles do mapa em cache (uso offline). */
const V = 'marapass-v1';
const SHELL = V + '-shell';
const TILES = V + '-tiles';
const LIB = [
  'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css',
  'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js'
];
const MAX_TILES = 1500;
const isTile = u => /(^|\.)arcgisonline\.com$/.test(u.hostname) || /(^|\.)basemaps\.cartocdn\.com$/.test(u.hostname);

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(SHELL)
      .then(c => Promise.all(LIB.map(u => c.add(new Request(u, { mode: 'cors' })).catch(() => {}))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(ks => Promise.all(ks.filter(k => !k.startsWith(V)).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// Subdomínios a-d do CARTO viram "a" para o mesmo tile não ser guardado 4 vezes.
const tileKey = u => u.replace(/^https:\/\/[a-d]\.basemaps\.cartocdn\.com/, 'https://a.basemaps.cartocdn.com');

async function trim(cache) {
  const ks = await cache.keys();
  if (ks.length > MAX_TILES) await Promise.all(ks.slice(0, ks.length - MAX_TILES).map(k => cache.delete(k)));
}

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  // Tiles: cache primeiro; se não tiver, rede (e guarda). Sem internet e sem cache: tile vazio.
  if (isTile(url)) {
    e.respondWith((async () => {
      const cache = await caches.open(TILES);
      const key = tileKey(req.url);
      const hit = await cache.match(key);
      if (hit) return hit;
      try {
        // mode:cors evita respostas "opacas" (que ocupam muita cota de armazenamento).
        const res = await fetch(req.url, { mode: 'cors' });
        if (res.ok) { cache.put(key, res.clone()); trim(cache); }
        return res;
      } catch (_) {
        return new Response('', { status: 504 });
      }
    })());
    return;
  }

  // Leaflet (CDN): cache primeiro.
  if (LIB.includes(req.url)) {
    e.respondWith(caches.match(req.url).then(r => r || fetch(req)));
    return;
  }

  // Página: rede primeiro, cai para o cache quando offline.
  if (req.mode === 'navigate' || (url.origin === location.origin && /\/(index\.html)?$/.test(url.pathname))) {
    e.respondWith(
      fetch(req).then(res => {
        if (res.ok) caches.open(SHELL).then(c => c.put('./', res.clone()));
        return res;
      }).catch(() => caches.match('./').then(r => r || caches.match(req)))
    );
  }
});
