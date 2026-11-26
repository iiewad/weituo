import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="floating-card"
// 点击考勤徽章展开操作卡；再次点击、点击外部或按 Esc 关闭。用 fixed 定位挂到视口坐标，避免被表格容器裁切。
export default class extends Controller {
  static targets = [ "trigger", "card" ]

  connect() {
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

  open() {
    this.cardTarget.classList.remove("hidden")
    this.cardTarget.classList.add("flex")
    this.position()
  }

  close() {
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
