import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    // Close menu on Turbo navigation
    document.addEventListener("turbo:load", () => this.close())
  }

  toggle() {
    const menu = this.menuTarget
    if (menu.style.display === "none" || menu.style.display === "") {
      menu.style.display = "block"
    } else {
      menu.style.display = "none"
    }
  }

  close() {
    if (this.hasMenuTarget) {
      this.menuTarget.style.display = "none"
    }
  }
}
