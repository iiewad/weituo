import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="guide-wizard"
// 新手引导弹窗：单步展示、前后切换，完成或跳过后记录状态。
export default class extends Controller {
  static targets = [ "step", "progress", "prev", "next", "finish" ]
  static values = { autoOpen: Boolean, completeUrl: String, csrf: String }

  connect() {
    this.index = 0
    this.render()
    if (this.autoOpenValue && !this.element.open) this.element.showModal()
  }

  next() {
    if (this.index >= this.stepTargets.length - 1) return
    this.index += 1
    this.render()
  }

  prev() {
    if (this.index === 0) return
    this.index -= 1
    this.render()
  }

  finish() {
    this.complete()
    this.element.close()
  }

  skip() {
    this.complete()
    this.element.close()
  }

  complete() {
    fetch(this.completeUrlValue, {
      method: "POST",
      headers: { "Accept": "application/json", "X-CSRF-Token": this.csrfValue }
    }).catch(() => {})
  }

  render() {
    this.stepTargets.forEach((step, index) => step.classList.toggle("hidden", index !== this.index))
    this.progressTarget.textContent = `第 ${this.index + 1} / ${this.stepTargets.length} 步`

    const last = this.index === this.stepTargets.length - 1
    this.prevTarget.disabled = this.index === 0
    this.nextTarget.classList.toggle("hidden", last)
    this.finishTarget.classList.toggle("hidden", !last)
  }
}
