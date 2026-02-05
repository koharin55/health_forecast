import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "toggleButton", "statusText"]
  static values = {
    subscribed: Boolean
  }

  async connect() {
    await this.checkSubscriptionStatus()
  }

  async checkSubscriptionStatus() {
    if (!this.isPushSupported()) {
      this.setStatus("not-supported")
      return
    }

    // ブラウザの通知許可状態を確認
    const permission = Notification.permission
    if (permission === "denied") {
      this.setStatus("denied")
      return
    }

    const subscription = await window.PreCareSW?.getPushSubscription()
    this.subscribedValue = !!subscription
    this.setStatus(subscription ? "subscribed" : "unsubscribed")
  }

  async toggle() {
    // ブロック中の場合は案内を表示
    if (Notification.permission === "denied") {
      alert("通知がブロックされています。\n\nブラウザの設定から通知を許可してください。\n\n【手順】\nアドレスバー左のアイコン → サイトの設定 → 通知 → 許可")
      return
    }

    if (this.subscribedValue) {
      await this.unsubscribe()
    } else {
      await this.subscribe()
    }
  }

  async subscribe() {
    if (!this.isPushSupported()) {
      alert("このブラウザはプッシュ通知に対応していません")
      return
    }

    try {
      this.setStatus("loading")

      // 通知の許可を要求
      const permission = await Notification.requestPermission()
      if (permission !== "granted") {
        this.setStatus("denied")
        return
      }

      // VAPID公開鍵を取得
      const vapidResponse = await fetch("/api/v1/push_subscriptions/vapid_public_key")
      const { vapid_public_key } = await vapidResponse.json()

      // Service Workerでプッシュを購読
      const subscription = await window.PreCareSW.subscribeToPush(vapid_public_key)

      // サーバーに登録
      const response = await fetch("/api/v1/push_subscriptions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({
          push_subscription: {
            endpoint: subscription.endpoint,
            p256dh_key: this.arrayBufferToBase64(subscription.getKey("p256dh")),
            auth_key: this.arrayBufferToBase64(subscription.getKey("auth"))
          }
        })
      })

      if (response.ok) {
        this.subscribedValue = true
        this.setStatus("subscribed")
      } else {
        throw new Error("サーバーへの登録に失敗しました")
      }
    } catch (error) {
      console.error("[PushSubscription] Subscribe failed:", error)
      this.setStatus("error")
      alert("通知の登録に失敗しました: " + error.message)
    }
  }

  async unsubscribe() {
    try {
      this.setStatus("loading")

      const subscription = await window.PreCareSW?.getPushSubscription()
      if (subscription) {
        // サーバーから削除
        const encodedEndpoint = encodeURIComponent(subscription.endpoint)
        await fetch(`/api/v1/push_subscriptions?endpoint=${encodedEndpoint}`, {
          method: "DELETE",
          headers: {
            "X-CSRF-Token": this.csrfToken
          }
        })

        // ブラウザの購読を解除
        await window.PreCareSW.unsubscribeFromPush()
      }

      this.subscribedValue = false
      this.setStatus("unsubscribed")
    } catch (error) {
      console.error("[PushSubscription] Unsubscribe failed:", error)
      this.setStatus("error")
    }
  }

  setStatus(status) {
    if (this.hasStatusTarget) {
      this.statusTarget.dataset.status = status
    }

    // 統合ステータステキストを更新
    if (this.hasStatusTextTarget) {
      const browserPermission = ("Notification" in window) ? Notification.permission : "unsupported"
      const statusTextMap = {
        "loading": "確認中...",
        "subscribed": "オン（ブラウザ許可済み）",
        "unsubscribed": browserPermission === "granted"
          ? "オフ（ブラウザ許可済み）"
          : "オフ",
        "denied": "ブロック中（ブラウザ設定で許可してください）",
        "not-supported": "非対応",
        "error": "エラー"
      }
      this.statusTextTarget.textContent = statusTextMap[status] || status
    }

    // ボタンテキストを更新
    if (this.hasToggleButtonTarget) {
      const button = this.toggleButtonTarget
      const buttonLabels = {
        "loading": "処理中...",
        "subscribed": "通知をオフにする",
        "unsubscribed": "通知をオンにする",
        "denied": "ブラウザ設定を確認",
        "not-supported": "通知非対応",
        "error": "再試行"
      }
      button.textContent = buttonLabels[status] || status
      button.disabled = ["loading", "not-supported"].includes(status)
    }
  }

  isPushSupported() {
    return "serviceWorker" in navigator &&
           "PushManager" in window &&
           "Notification" in window
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  arrayBufferToBase64(buffer) {
    const bytes = new Uint8Array(buffer)
    let binary = ""
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i])
    }
    return btoa(binary)
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "")
  }
}
