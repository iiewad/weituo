import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="row-actions"
// 行内操作默认隐藏，鼠标移入行时显示，移出后恢复隐藏。
export default class extends Controller {
  static targets = [ "actions" ]

  show() {
    this.actionsTarget.classList.remove("opacity-0", "pointer-events-none")
  }

  hide() {
    this.actionsTarget.classList.add("opacity-0", "pointer-events-none")
  }
}
