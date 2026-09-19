// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()

// The composer. Lexxy takes over Action Text's form helpers, so importing it
// is nearly the whole of the wiring.
//
// Configuration has to run synchronously after the import — editor elements
// register once this call stack unwinds, and anything set later is ignored.
import * as Lexxy from "lexxy"

Lexxy.configure({
  default: {
    // Photographs, not files. Kith knows how to strip EXIF from an image and
    // how to serve it through MediaController; it has nothing to say about a
    // spreadsheet, so the general upload button goes.
    toolbar: { upload: "image" },

    // Lexxy's highlighter offers nine text colours and nine grounds. The
    // design system permits exactly one hue, so the pen is loaded with it:
    // the control still works, it just cannot introduce a second colour. The
    // `permit` lists stay empty, so no colour survives a paste either.
    highlight: {
      buttons: {
        color: [ "var(--accent)" ],
        "background-color": [ "var(--accent-quiet)" ]
      }
    }
  }
})

// The installable app. Registering is all the page has to do; the worker keeps
// the stylesheet, the fonts and the JavaScript on the device and passes
// everything else straight through to the network. See app/views/pwa.
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
