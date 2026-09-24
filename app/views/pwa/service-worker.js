// Kith's service worker.
//
// It exists for two reasons and has no third: a browser will not offer to
// install an app that has no fetch handler, and the stylesheet, the fonts and
// the importmapped JavaScript are worth keeping on the device so a cold launch
// on a bad train does not render in Times.
//
// It deliberately caches **nothing that anybody wrote**. No documents, no
// /media/, no JSON. A phone is shared, lent and lost, and the Cache API is a
// plain readable store that outlives the session cookie and that nothing in
// `Visibility` gets a say over — a followers-only photograph sitting in it is
// the whole privacy model failing quietly, months later, on a device that is
// signed out. Assets are safe because they are the same for everyone and
// contain nothing a member typed.

const VERSION = "kith-assets-v1"

// Propshaft serves digested, immutable files under /assets/. Anything else —
// every page, every photograph, every form post — goes straight to the network.
function isImmutableAsset(request) {
  if (request.method !== "GET") return false

  const url = new URL(request.url)
  if (url.origin !== self.location.origin) return false

  return url.pathname.startsWith("/assets/")
}

self.addEventListener("install", (event) => {
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== VERSION).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", (event) => {
  if (!isImmutableAsset(event.request)) return

  event.respondWith(
    caches.match(event.request).then((hit) => {
      if (hit) return hit

      return fetch(event.request).then((response) => {
        // Only a clean, complete, same-origin response is worth keeping.
        if (response.ok && response.type === "basic") {
          const copy = response.clone()
          caches.open(VERSION).then((cache) => cache.put(event.request, copy))
        }

        return response
      })
    })
  )
})

// Web Push goes here when it lands — a `push` handler that draws the
// notification and a `notificationclick` that focuses the right page. It needs
// VAPID keys and a subscriptions table first, and the payload has to answer to
// `Visibility` like every other side channel: a lock screen is a surface a
// signed-out stranger can read.
