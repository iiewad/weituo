import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="floating-card"
// 点击考勤徽章展开操作卡；再次点击、点击外部或按 Esc 关闭。用 fixed 定位挂到视口坐标，避免被表格容器裁切。
// 也支持 hover 触发（hoverOpen/scheduleClose）：移入展开、移出延迟关闭；卡片内一旦点击或聚焦则钉住，
// 避免操作下拉框时鼠标移出导致卡片消失，钉住后仅点击外部 / Esc / 滚动关闭。
export default class extends Controller {
  static targets = [ "trigger", "card" ]

  connect() {
    this.pinned = false
    this.closeTimer = null
    this.handleDocumentClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    this.handleDocumentKeydown = (event) => {
      if (event.key === "Escape") this.close()
    }
    this.handleViewportChange = () => this.close()

    document.addEventListener("click", this.handleDocumentClick)
    document.addEventListener("keydown", this.handleDocumentKeydown)
    // capture 同时监听表格内部的横向/纵向滚动
    window.addEventListener("scroll", this.handleViewportChange, true)
    window.addEventListener("resize", this.handleViewportChange)
  }

  disconnect() {
    this.cancelClose()
    document.removeEventListener("click", this.handleDocumentClick)
    document.removeEventListener("keydown", this.handleDocumentKeydown)
    window.removeEventListener("scroll", this.handleViewportChange, true)
    window.removeEventListener("resize", this.handleViewportChange)
  }

  toggle(event) {
    event.preventDefault()
    if (this.cardTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  handleTriggerKey(event) {
    if (event.key !== "Enter" && event.key !== " ") return

    event.preventDefault()
    this.toggle(event)
  }

  hoverOpen(event) {
    event?.preventDefault()
    this.cancelClose()
    this.open()
  }

  scheduleClose() {
    if (this.pinned) return
    this.cancelClose()
    this.closeTimer = setTimeout(() => this.close(), 150)
  }

  cancelClose() {
    if (this.closeTimer) {
      clearTimeout(this.closeTimer)
      this.closeTimer = null
    }
  }

  pin() {
    this.pinned = true
    this.cancelClose()
  }

  open() {
    this.cardTarget.classList.remove("hidden")
    this.cardTarget.classList.add("flex")
    this.position()
  }

  close() {
    this.pinned = false
    this.cancelClose()
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
