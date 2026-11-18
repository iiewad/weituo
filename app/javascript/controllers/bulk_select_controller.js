import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bulk-select"
// 学员列表批量操作：全选当前页、统计已选人数并控制提交按钮。
export default class extends Controller {
  static targets = ["item", "all", "count", "submit"]

  connect() {
    this.update()
  }

  toggleAll() {
    const checked = this.allTarget.checked
    this.itemTargets.forEach((item) => { item.checked = checked })
    this.update()
  }

  update() {
    const selected = this.itemTargets.filter((item) => item.checked).length
    this.countTarget.textContent = selected
    this.submitTarget.disabled = selected === 0

    if (this.hasAllTarget) {
      this.allTarget.checked = selected > 0 && selected === this.itemTargets.length
      this.allTarget.indeterminate = selected > 0 && selected < this.itemTargets.length
    }
  }
}
