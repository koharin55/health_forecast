import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "installButton"]

  connect() {
    this.deferredPrompt = null
    this.setupInstallPrompt()
    this.checkIfInstalled()
  }

  setupInstallPrompt() {
    window.addEventListener("beforeinstallprompt", (event) => {
      // デフォルトのプロンプトを防止
      event.preventDefault()
      // イベントを保存
      this.deferredPrompt = event
      // インストールボタンを表示
      this.showInstallButton()
    })

    window.addEventListener("appinstalled", () => {
      // インストール完了
      this.deferredPrompt = null
      this.hideInstallButton()
    })
  }

  checkIfInstalled() {
    // スタンドアロンモードで実行中かチェック
    if (window.matchMedia("(display-mode: standalone)").matches ||
        window.navigator.standalone === true) {
      this.hideInstallButton()
    }
  }

  async install() {
    if (!this.deferredPrompt) return

    // インストールプロンプトを表示
    this.deferredPrompt.prompt()

    // ユーザーの選択を待つ
    const { outcome } = await this.deferredPrompt.userChoice

    if (outcome === "accepted") {
      console.log("[Install] User accepted the install prompt")
    } else {
      console.log("[Install] User dismissed the install prompt")
    }

    this.deferredPrompt = null
  }

  showInstallButton() {
    if (this.hasContainerTarget) {
      this.containerTarget.classList.remove("hidden")
    }
  }

  hideInstallButton() {
    if (this.hasContainerTarget) {
      this.containerTarget.classList.add("hidden")
    }
  }
}
