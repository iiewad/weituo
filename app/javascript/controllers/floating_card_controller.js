import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="floating-card"
// 用 fixed 定位把操作卡挂到视口坐标，避免被表格的 overflow 容器裁切。
export default class extends Controller {
  static targets = ["trigger", "card"]
  static values = { closeDelay: { type: Number, default: 160 } }

  connect() {
    this.closeTimer = null
    this.handleScrollOrResize = this.close.bind(this)
    // capture 同时监听表格内部的横向/纵向滚动
    window.addEventListener("scroll", this.handleScrollOrResize, true)
    window.addEventListener("resize", this.handleScrollOrResize)
  }

  disconnect() {
    clearTimeout(this.closeTimer)
    window.removeEventListener("scroll", this.handleScrollOrResize, true)
    window.removeEventListener("resize", this.handleScrollOrResize)
  }

  open() {
    clearTimeout(this.closeTimer)
    this.cardTarget.classList.remove("hidden")
    this.cardTarget.classList.add("flex")
    this.position()
  }

  keepOpen() {
    clearTimeout(this.closeTimer)
  }

  scheduleClose() {
    clearTimeout(this.closeTimer)
    this.closeTimer = setTimeout(() => this.close(), this.closeDelayValue)
  }

  close() {
    clearTimeout(this.closeTimer)
    this.cardTarget.classList.add("hidden")
    this.cardTarget.classList.remove("flex")
  }

  position() {
    const trigger = this.triggerTarget.getBoundingClientRect()
    const card = this.cardTarget
    const margin = 8
    const gap = 6
    const width = card.offsetWidth
    const height = card.offsetHeight

    const left = Math.max(margin, Math.min(trigger.right - width, window.innerWidth - width - margin))
    let top = trigger.bottom + gap
    if (top + height > window.innerHeight - margin) top = trigger.top - height - gap

    card.style.left = `${left}px`
    card.style.top = `${Math.max(margin, top)}px`
  }
}
