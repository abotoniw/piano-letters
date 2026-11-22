/* Offline copy of the app. The version changes with every build, which is how an update is noticed. */
const V = '2026-11-22-d96e73', DV = 'db2f44a7a4', SHELL = 'pls-shell-' + V, DATA = 'pls-data';
const CORE = ['./', 'index.html', 'manifest.webmanifest', 'icon-180.png', 'icon-192.png', 'icon-512.png'];
self.addEventListener('install', e => e.waitUntil(caches.open(SHELL).then(c => c.addAll(CORE.map(u => new Request(u, { cache: 'reload' }))))));
self.addEventListener('activate', e => e.waitUntil((async () => {
  for (const k of await caches.keys()) if (k.startsWith('pls-shell-') && k !== SHELL) await caches.delete(k);
  const m = await caches.open('pls-meta'), old = await m.match('dv'), v = old ? await old.text() : '';
  if (v !== DV) { await caches.delete(DATA); await m.put('dv', new Response(DV)); } // the scores changed
  await self.clients.claim();
})()));
self.addEventListener('message', e => { if (e.data === 'go') self.skipWaiting(); });
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== location.origin) return;
  if (u.pathname.endsWith('/my-sheets.json')) return; // always from the network
  if (u.pathname.includes('/data/')) { e.respondWith(caches.open(DATA).then(async c => { const key = u.pathname, hit = await c.match(key); if (hit) return hit; const r = await fetch(e.request, { cache: 'no-cache' }); if (r.ok) await c.put(key, r.clone()); return r; })); return; }
  if (e.request.mode === 'navigate') { e.respondWith(caches.open(SHELL).then(async c => (await c.match('index.html')) || fetch(e.request))); return; }
  e.respondWith(caches.open(SHELL).then(async c => (await c.match(e.request, { ignoreSearch: true })) || fetch(e.request)));
});
