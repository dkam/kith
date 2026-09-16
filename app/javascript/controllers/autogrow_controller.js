import { Controller } from "@hotwired/stimulus"

// Grows a reply box to fit what is being written, so a long thought doesn't
// have to be composed through a two-line window.
export default class extends Controller {
  connect() {
    this.resize()
  }

  resize() {
    this.element.style.height = "auto"
    this.element.style.height = `${this.element.scrollHeight}px`
  }
}
