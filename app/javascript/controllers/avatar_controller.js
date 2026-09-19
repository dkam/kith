import { Controller } from "@hotwired/stimulus"

// Paste a photo straight onto the settings page.
//
// The file input stays the source of truth: a pasted image is assigned to it,
// so the form submits exactly as it would have had the file been chosen by
// hand — direct upload, EXIF stripping and all — and the page still works with
// JavaScript off.
//
// The paste is listened for on the document rather than on the input, because
// nobody thinks to focus a file button before pressing paste. Text pastes are
// left alone: a clipboard carrying no image file is somebody filling in their
// name, and the event has to reach the field they are typing into.
export default class extends Controller {
  static targets = ["input", "preview", "status"]

  paste(event) {
    const file = Array.from(event.clipboardData?.files ?? []).find((file) => this.#permitted(file))
    if (!file) return

    event.preventDefault()

    const transfer = new DataTransfer()
    transfer.items.add(file)
    this.inputTarget.files = transfer.files

    this.show(file)
  }

  // Also runs when a file is chosen by hand, so both routes show the same thing.
  show(file = this.inputTarget.files[0]) {
    if (!file || !this.hasPreviewTarget) return

    const image = document.createElement("img")
    image.className = this.previewTarget.dataset.avatarClass
    image.alt = ""
    image.src = URL.createObjectURL(file)
    image.addEventListener("load", () => URL.revokeObjectURL(image.src), { once: true })

    this.previewTarget.replaceChildren(image)
    this.#status("New photo ready. Save to keep it.")
  }

  // --- Private ---

  // The same list the file input accepts, so there is one answer to what a
  // photo is and the input holds it.
  #permitted(file) {
    return (this.inputTarget.accept || "")
      .split(",")
      .map((type) => type.trim())
      .includes(file.type)
  }

  #status(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }
}
