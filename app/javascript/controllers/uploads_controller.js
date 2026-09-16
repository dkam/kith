import { Controller } from "@hotwired/stimulus"

// Drag-and-drop photos onto the post form, with previews and upload progress.
//
// The file input stays the source of truth: dropping files assigns them to it,
// so the form submits exactly as it would have without any of this, and works
// with JavaScript off.
export default class extends Controller {
  static targets = ["dropzone", "input", "list", "status", "submit"]

  connect() {
    this.dragDepth = 0
    this.defaultStatus = this.hasStatusTarget ? this.statusTarget.textContent : ""
  }

  // --- Drag and drop ---

  dragover(event) {
    event.preventDefault()
  }

  dragenter(event) {
    event.preventDefault()
    this.dragDepth++
    this.#highlight(true)
  }

  dragleave() {
    this.dragDepth--
    if (this.dragDepth <= 0) this.#highlight(false)
  }

  drop(event) {
    event.preventDefault()
    this.dragDepth = 0
    this.#highlight(false)

    const files = Array.from(event.dataTransfer.files).filter((file) => file.type.startsWith("image/"))
    if (files.length === 0) return

    const transfer = new DataTransfer()
    for (const file of [...this.inputTarget.files, ...files]) transfer.items.add(file)
    this.inputTarget.files = transfer.files

    this.preview()
  }

  // --- Previews ---

  preview() {
    if (!this.hasListTarget) return

    this.listTarget.replaceChildren()

    for (const file of this.inputTarget.files) {
      const item = document.createElement("li")
      item.className = "relative"

      const image = document.createElement("img")
      image.className = "aspect-square w-full rounded-md border border-rule object-cover"
      image.alt = ""
      image.src = URL.createObjectURL(file)
      image.addEventListener("load", () => URL.revokeObjectURL(image.src), { once: true })

      item.append(image)
      this.listTarget.append(item)
    }

    this.#status(this.inputTarget.files.length > 0
      ? `${this.inputTarget.files.length} photo${this.inputTarget.files.length === 1 ? "" : "s"} ready.`
      : this.defaultStatus)
  }

  // --- Direct upload progress ---
  //
  // Active Storage fires these on the form while it uploads each file.

  uploadStart() {
    if (this.hasSubmitTarget) this.submitTarget.disabled = true
  }

  uploadProgress(event) {
    this.#status(`Uploading… ${Math.round(event.detail.progress)}%`)
  }

  uploadError(event) {
    event.preventDefault()
    this.#status("That photo wouldn't upload. Try again?")
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
  }

  uploadEnd() {
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
  }

  // --- Private ---

  #highlight(on) {
    if (!this.hasDropzoneTarget) return

    const classes = (this.dropzoneTarget.dataset.dragClass || "").split(" ").filter(Boolean)
    this.dropzoneTarget.classList.toggle("border-dashed", !on)
    classes.forEach((name) => this.dropzoneTarget.classList.toggle(name, on))
  }

  #status(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }
}
