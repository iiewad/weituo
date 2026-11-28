import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="course-date"
// 考勤表表头的已开课日期可点击修改：默认只改本课，
// 勾选「后续已开课课次按间隔顺延」后把后面已开课的课次按新日期逐课累加，抽屉里实时预览结果。
export default class extends Controller {
  static targets = [
    "toggle", "form", "title", "current", "date", "interval",
    "cascade", "cascadeRow", "cascadeEmpty", "preview"
  ]

  open(event) {
    const data = event.currentTarget.dataset

    this.seq = data.courseDateSeq
    this.laterSeqs = (data.courseDateLaterSeqs || "").split(",").filter(Boolean).map(Number)

    this.formTarget.action = data.courseDateUrl
    this.titleTarget.textContent = `第 ${this.seq} 课`
    this.currentTarget.textContent = `原开课日期 ${data.courseDateCurrentLabel}`
    this.dateTarget.value = data.courseDateCurrent
    this.intervalTarget.value = 7
    this.cascadeTarget.checked = false

    const hasLater = this.laterSeqs.length > 0
    this.cascadeRowTarget.classList.toggle("hidden", !hasLater)
    this.cascadeEmptyTarget.classList.toggle("hidden", hasLater)

    this.updatePreview()
    this.toggleTarget.checked = true
  }

  updatePreview() {
    if (this.laterSeqs.length === 0) {
      this.previewTarget.textContent = ""
      return
    }

    const first = this.laterSeqs[0]
    const last = this.laterSeqs[this.laterSeqs.length - 1]
    const range = first === last
      ? `第 ${first} 课`
      : `第 ${first}–${last} 课（共 ${this.laterSeqs.length} 次）`

    if (!this.cascadeTarget.checked) {
      this.previewTarget.textContent = `只改第 ${this.seq} 课，${range}保持原日期。`
      return
    }

    const base = parseDate(this.dateTarget.value)
    if (!base) {
      this.previewTarget.textContent = "选择开课日期后会在这里预览顺延结果。"
      return
    }

    const interval = parseInterval(this.intervalTarget.value)
    const end = addDays(base, interval * this.laterSeqs.length)
    this.previewTarget.textContent =
      `${range}从 ${mmdd(addDays(base, interval))} 起按 ${interval} 天顺延，至 ${mmdd(end)}。`
  }
}

function parseDate(value) {
  const matched = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value || "")
  if (!matched) return null

  return new Date(Date.UTC(Number(matched[1]), Number(matched[2]) - 1, Number(matched[3])))
}

function parseInterval(value) {
  const interval = parseInt(value, 10)
  if (Number.isNaN(interval)) return 7

  return Math.min(Math.max(interval, 0), 365)
}

function addDays(date, days) {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000)
}

function mmdd(date) {
  const month = String(date.getUTCMonth() + 1).padStart(2, "0")
  const day = String(date.getUTCDate()).padStart(2, "0")

  return `${month}-${day}`
}
