import { Controller } from "@hotwired/stimulus"

// 睡眠時間の「時間セレクト + 分テキスト入力」を hidden sleep_minutes フィールドと同期する
export default class extends Controller {
  static targets = ["hidden", "hours", "minutes"]

  connect() {
    this.initializeFromHidden()
  }

  initializeFromHidden() {
    const value = this.hiddenTarget.value
    if (value === "") return

    const total = parseInt(value, 10)
    const h = Math.min(Math.floor(total / 60), 12)
    this.hoursTarget.value = h
    this.minutesTarget.value = total - h * 60
  }

  update() {
    const h = parseInt(this.hoursTarget.value, 10) || 0
    const mRaw = this.minutesTarget.value
    if (mRaw === "") {
      this.hiddenTarget.value = h === 0 ? "" : h * 60
      return
    }

    const mParsed = parseInt(mRaw, 10) || 0
    const m = Math.min(Math.max(mParsed, 0), 59)
    if (m !== mParsed) this.minutesTarget.value = m

    this.hiddenTarget.value = h * 60 + m
  }
}
