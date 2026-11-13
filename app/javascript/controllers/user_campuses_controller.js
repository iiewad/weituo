import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="user-campuses"
export default class extends Controller {
  static targets = ["container", "template"]

  add(event) {
    event.preventDefault()
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, Date.now())
    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    event.preventDefault()
    const row = event.currentTarget.closest(".nested-fields")
    const destroy = row.querySelector('input[name$="[_destroy]"]')
    // 新增行（data-new-record=true）直接移除；已有行标记 _destroy，由 Rails 在提交时删除
    if (row.dataset.newRecord === "true" || !destroy) {
      row.remove()
    } else {
      destroy.value = "true"
      row.style.display = "none"
    }
  }
}
