import { Controller } from "@hotwired/stimulus"

// How far a direct upload has got. A Strava export can be hundreds of
// megabytes, and it uploads only once Import is pressed, so without this the
// page sits still for minutes and looks broken.
export default class extends Controller {
  static targets = ["status"]

  start() {
    this.failed = false
    this.statusTarget.textContent = "Uploading."
  }

  progress(event) {
    this.statusTarget.textContent = `Uploading: ${Math.round(event.detail.progress)}%`
  }

  // Active Storage sends end after error as well, so it must not undo it.
  end() {
    if (!this.failed) this.statusTarget.textContent = "Uploaded. Starting the import."
  }

  // Active Storage alerts the error unless this is prevented, and a large
  // upload cut off by a proxy would end in a browser dialog. The error itself
  // says nothing a member can act on, so it is not shown.
  error(event) {
    event.preventDefault()
    this.failed = true
    this.statusTarget.textContent = "The upload didn't finish. Try again."
  }
}
