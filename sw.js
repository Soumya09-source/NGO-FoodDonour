// Caches the app so it opens even without internet
const CACHE = "akshaya-ahar-v2";
const FILES = ["./", "./index.html", "./manifest.json", "./config.js", "./icon-192.png", "./icon-512.png"];
self.addEventListener("install", e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES))); self.skipWaiting(); });
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))));
  self.clients.claim();
});
self.addEventListener("fetch", e => {
  if (e.request.method !== "GET" || !e.request.url.startsWith(self.location.origin)) {
    return;
  }
  e.respondWith(caches.match(e.request).then(r => r || fetch(e.request).then(res => {
    if (res.status === 200) {
      const copy = res.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)).catch(() => {});
    }
    return res;
  }).catch(() => caches.match("./index.html"))));
});
