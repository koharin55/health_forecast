import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "overlay"]

  connect() {
    // Close menu on Turbo navigation
    document.addEventListener("turbo:load", () => this.close())
  }

  toggle() {
    this.menuTarget.classList.toggle("active")
    this.overlayTarget.classList.toggle("active")
  }

  close() {
    this.menuTarget.classList.remove("active")
    this.overlayTarget.classList.remove("active")
  }
}
