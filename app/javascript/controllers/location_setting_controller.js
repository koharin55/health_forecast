import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["prefectureSection", "zipcodeSection", "prefectureRadio", "zipcodeRadio", "zipcodeInput", "zipcodeResult", "form"]

  connect() {
    this.toggleType()
  }

  toggleType() {
    const isPrefecture = this.prefectureRadioTarget.checked

    if (isPrefecture) {
      this.prefectureSectionTarget.style.display = "block"
      this.zipcodeSectionTarget.style.display = "none"
    } else {
      this.prefectureSectionTarget.style.display = "none"
      this.zipcodeSectionTarget.style.display = "block"
    }
  }

  async searchZipcode(event) {
    event.preventDefault()
    const zipcode = this.zipcodeInputTarget.value.trim()

    if (!zipcode) {
      this.showResult("郵便番号を入力してください", "error")
      return
    }

    this.showResult("検索中...", "loading")

    try {
      const response = await fetch("/mypage/search_zipcode", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ zipcode: zipcode })
      })

      const data = await response.json()

      if (data.success) {
        this.showResult(`<span class="text-emerald-700 font-medium">${data.address}</span>`, "success")
      } else {
        this.showResult(data.error || "郵便番号が見つかりませんでした", "error")
      }
    } catch (error) {
      this.showResult("検索中にエラーが発生しました", "error")
    }
  }

  showResult(message, type) {
    const resultElement = this.zipcodeResultTarget
    let className = "p-3 rounded-xl text-sm "

    switch (type) {
      case "success":
        className += "bg-emerald-50 border border-emerald-200"
        break
      case "error":
        className += "bg-red-50 border border-red-200 text-red-700"
        break
      case "loading":
        className += "bg-slate-50 border border-slate-200 text-slate-600"
        break
    }

    resultElement.innerHTML = `<div class="${className}">${message}</div>`
  }

  clearResult() {
    this.zipcodeResultTarget.innerHTML = ""
  }
}
