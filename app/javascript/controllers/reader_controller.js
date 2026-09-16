import { Controller } from "@hotwired/stimulus"

// Marks posts as read once they have actually been read: an IntersectionObserver
// watches each unread item, and a post counts as read when it has been mostly
// on screen for a moment, rather than the instant it scrolls into view.
//
// Requests are fire-and-forget. If one fails the post stays unread, which is
// the right way round to be wrong.
export default class extends Controller {
  static targets = ["item", "marker"]
  static values = {
    dwell: { type: Number, default: 800 },
    threshold: { type: Number, default: 0.6 }
  }

  connect() {
    if (!("IntersectionObserver" in window)) return

    this.timers = new Map()
    this.observer = new IntersectionObserver(this.#onIntersect.bind(this), {
      threshold: this.thresholdValue
    })

    this.itemTargets.filter((item) => item.dataset.feedItemUrl).forEach((item) => this.observer.observe(item))
  }

  disconnect() {
    this.observer?.disconnect()
    this.timers?.forEach((timer) => clearTimeout(timer))
    this.timers?.clear()
  }

  itemTargetConnected(item) {
    if (this.observer && item.dataset.feedItemUrl) this.observer.observe(item)
  }

  #onIntersect(entries) {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        this.#scheduleRead(entry.target)
      } else {
        this.#cancelRead(entry.target)
      }
    }
  }

  #scheduleRead(item) {
    if (this.timers.has(item)) return

    this.timers.set(item, setTimeout(() => this.#markRead(item), this.dwellValue))
  }

  #cancelRead(item) {
    clearTimeout(this.timers.get(item))
    this.timers.delete(item)
  }

  async #markRead(item) {
    const url = item.dataset.feedItemUrl
    if (!url) return

    // Clear it locally first: the dot going away is the feedback, and a failed
    // request just means it is still unread next time.
    delete item.dataset.feedItemUrl
    this.observer.unobserve(item)
    item.classList.remove("kith-unread")
    item.querySelector("[data-reader-target='marker']")?.remove()

    try {
      await fetch(url, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content,
          "Accept": "application/json"
        },
        credentials: "same-origin"
      })
    } catch {
      // Left unread on the server. It will be marked next time it is seen.
    }
  }
}
