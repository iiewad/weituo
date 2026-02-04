import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  connect() {
    console.log("UserCampuses controller connected")
  }

  add(event) {
    event.preventDefault()
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime())
    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    event.preventDefault()
    const wrapper = event.target.closest(".nested-fields")
    if (wrapper.dataset.newRecord === "true") {
      // 如果是新记录，直接从DOM中移除
      wrapper.remove()
    } else {
      // 如果是现有记录，标记为删除
      const input = wrapper.querySelector("input[name*='_destroy']")
      if (input) {
        input.value = "true"
        input.disabled = false // 确保字段不被禁用
        wrapper.style.display = "none"
      }
    }
  }
}