import { Controller } from "@hotwired/stimulus"

// How far a direct upload has got. A Strava export can be hundreds of
// megabytes, and it uploads only once Import is pressed, so without this the
// page sits still for minutes and looks broken.
export default class extends Controller {
  static targets = ["status"]

  progress(event) {
    this.statusTarget.textContent = `Uploading: ${Math.round(event.detail.progress)}%`
  }

  end() {
    this.statusTarget.textContent = "Uploaded. Starting the import."
  }
}
