// The installable app. Registering is all the page has to do; the worker keeps
// the stylesheet, the fonts and the JavaScript on the device and passes
// everything else straight through to the network. See app/views/pwa.
//
// This module is loaded by layouts/_pwa, which the phone apps' layout does not
// render — a service worker inside a WKWebView is a second cache with opinions
// about a device that already has a native one, and nothing wants that.
//
// It is registered at the root so its scope is the whole app, and failure is
// not worth a word to the member: a browser that will not take a service
// worker (Safari in a private window, an http:// origin in development) still
// runs Kith perfectly, it just cannot be installed to a home screen.
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker", { scope: "/" })
      .catch(() => {})
  })
}
