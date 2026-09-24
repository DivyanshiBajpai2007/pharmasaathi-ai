// Network-first service worker: users always get the latest deployed app when online,
// and the last-seen copy of the app shell when offline.
// It only ever touches same-origin requests, so API calls (Supabase) and CDN scripts
// are never cached — nothing personal or health-related is stored by this worker.
const CACHE = 'pharmasaathi-v8';

self.addEventListener('install', function(){ self.skipWaiting(); });

self.addEventListener('activate', function(e){
  e.waitUntil(
    caches.keys()
      .then(function(keys){ return Promise.all(keys.filter(function(k){ return k !== CACHE; }).map(function(k){ return caches.delete(k); })); })
      .then(function(){ return self.clients.claim(); })
  );
});

self.addEventListener('fetch', function(e){
  var req = e.request;
  if (req.method !== 'GET') return;
  var url = new URL(req.url);
  if (url.origin !== self.location.origin) return;
  e.respondWith(
    fetch(req).then(function(res){
      if (res && res.ok){
        var copy = res.clone();
        caches.open(CACHE).then(function(c){ c.put(req, copy); });
      }
      return res;
    }).catch(function(){ return caches.match(req); })
  );
});
