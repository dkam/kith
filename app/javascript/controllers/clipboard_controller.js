import { Controller } from "@hotwired/stimulus"

// Copies a read-only field — the MCP endpoint — to the clipboard. There are no
// toasts in Kith, so the button says what happened and then goes back to
// saying what it does.
//
// The clipboard API only exists on a secure origin. Where it doesn't, the text
// is still selected, which leaves the member one keystroke away.
export default class extends Controller {
  static targets = ["source", "button"]
  static values = { label: String, copiedLabel: String }

  copy() {
    this.sourceTarget.select()

    navigator.clipboard?.writeText(this.sourceTarget.value).then(() => this.confirm())
  }

  confirm() {
    clearTimeout(this.restore)
    this.buttonTarget.textContent = this.copiedLabelValue
    this.restore = setTimeout(() => { this.buttonTarget.textContent = this.labelValue }, 1600)
  }

  disconnect() {
    clearTimeout(this.restore)
  }
}
