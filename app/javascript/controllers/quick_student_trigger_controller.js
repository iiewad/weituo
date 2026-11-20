import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="quick-student-trigger"
// 多选列表搜索无结果时，由按钮把当前表单的上下文发给页面上的快速添加弹窗。
export default class extends Controller {
  static values = { prefix: String, gradeSelector: String }

  open() {
    document.dispatchEvent(new CustomEvent("quick-student:open", {
      detail: { prefix: this.prefixValue, gradeSelector: this.gradeSelectorValue }
    }))
  }
}
