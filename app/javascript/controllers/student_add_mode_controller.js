import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="student-add-mode"
// 班级学员录入方式二选一：勾选已有学员 / 粘贴名单。
export default class extends Controller {
  static targets = [ "picked", "text" ]

  connect() {
    this.apply()
  }

  apply() {
    const mode = this.element.querySelector("input[type='radio']:checked")?.value || "pick"
    this.pickedTarget.classList.toggle("hidden", mode !== "pick")
    this.textTarget.classList.toggle("hidden", mode !== "text")
    // 只提交当前方式的内容：勾选模式下禁用粘贴框，避免两种输入同时提交
    this.textTarget.querySelectorAll("textarea").forEach((field) => {
      field.disabled = mode !== "text"
    })
  }
}
