import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="quick-day-school-trigger"
// 学员表单里「日校」旁的快速添加入口，把目标下拉框交给页面上的日校弹窗。
export default class extends Controller {
  static values = { select: String }

  open() {
    document.dispatchEvent(new CustomEvent("quick-day-school:open", {
      detail: { select: this.selectValue }
    }))
  }
}
