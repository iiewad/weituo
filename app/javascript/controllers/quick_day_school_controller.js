import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="quick-day-school"
// 快速新增日校并填入当前学员表单的日校下拉框。
export default class extends Controller {
  static targets = [ "name", "error" ]
  static values = { createUrl: String, csrf: String }

  connect() {
    this.handleOpen = (event) => this.open(event.detail.select)
    document.addEventListener("quick-day-school:open", this.handleOpen)
  }

  disconnect() {
    document.removeEventListener("quick-day-school:open", this.handleOpen)
  }

  open(selector) {
    this.selectElement = selector ? document.querySelector(selector) : null
    this.nameTarget.value = ""
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")

    if (!this.element.open) this.element.showModal()
    setTimeout(() => this.nameTarget.focus(), 50)
  }

  close() {
    this.element.close()
  }

  async submit() {
    const name = this.nameTarget.value.trim()
    if (!name) {
      this.showError("请填写日校名称")
      return
    }

    let response
    try {
      response = await fetch(this.createUrlValue, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfValue
        },
        body: JSON.stringify({ day_school: { name } })
      })
    } catch {
      this.showError("网络异常，请稍后重试")
      return
    }

    const data = await response.json().catch(() => ({}))
    if (!response.ok) {
      this.showError((data.errors || [ "添加失败，请稍后重试" ]).join("；"))
      return
    }

    this.appendOption(data)
    this.element.close()
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  appendOption(daySchool) {
    if (!this.selectElement) return

    const option = document.createElement("option")
    option.value = daySchool.id
    option.textContent = daySchool.name
    this.selectElement.append(option)
    this.selectElement.value = String(daySchool.id)
  }
}
