import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="quick-student"
// 快速创建学员并插入对应班级表单的学员多选列表。
export default class extends Controller {
  static targets = [ "form", "name", "grade", "prefix", "error" ]
  static values = { createUrl: String, csrf: String }

  connect() {
    this.handleOpen = (event) => this.open(event.detail)
    document.addEventListener("quick-student:open", this.handleOpen)
  }

  disconnect() {
    document.removeEventListener("quick-student:open", this.handleOpen)
  }

  open({ prefix, gradeSelector }) {
    this.prefixTarget.value = prefix || ""
    this.nameTarget.value = ""
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")

    const gradeSelect = gradeSelector ? document.querySelector(gradeSelector) : null
    this.gradeTarget.value = gradeSelect?.value || ""

    if (!this.element.open) this.element.showModal()
    setTimeout(() => this.nameTarget.focus(), 50)
  }

  close() {
    this.element.close()
  }

  async submit(event) {
    event.preventDefault()

    let response
    try {
      response = await fetch(this.createUrlValue, {
        method: "POST",
        headers: { "Accept": "application/json", "X-CSRF-Token": this.csrfValue },
        body: new FormData(this.formTarget)
      })
    } catch {
      this.showError("网络异常，请稍后重试")
      return
    }

    const data = await response.json().catch(() => ({}))
    if (!response.ok) {
      this.showError((data.errors || [ "创建失败，请稍后重试" ]).join("；"))
      return
    }

    this.appendStudent(data, this.prefixTarget.value)
    this.element.close()
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  appendStudent(student, prefix) {
    const container = document.getElementById(`${prefix}_student_options`)
    if (!container) return

    const label = document.createElement("label")
    label.className = "flex items-center gap-2 rounded-box px-2.5 py-1.5 text-xs hover:bg-base-200/60"
    label.setAttribute("data-student-multiselect-target", "option")
    label.dataset.searchText = student.name
    label.dataset.displayText = student.identity_label
    label.dataset.gradeId = student.grade_id

    const checkbox = document.createElement("input")
    checkbox.type = "checkbox"
    checkbox.name = "student_ids[]"
    checkbox.value = student.id
    checkbox.id = `${prefix}_student_${student.id}`
    checkbox.className = "checkbox checkbox-xs"
    checkbox.checked = true

    const name = document.createElement("span")
    name.className = "font-medium"
    name.textContent = student.name
    label.append(checkbox, name)

    if (student.identity_suffix) {
      const suffix = document.createElement("span")
      suffix.className = "text-[10px] text-base-content/40"
      suffix.textContent = student.identity_suffix
      label.append(suffix)
    }

    const grade = document.createElement("span")
    grade.className = "ml-auto text-[10px] text-base-content/40"
    grade.textContent = student.grade_name || ""
    label.append(grade)

    container.append(label)

    const root = container.closest("[data-controller='student-multiselect']")
    const controller = root ? this.application.getControllerForElementAndIdentifier(root, "student-multiselect") : null
    if (controller) {
      controller.inputTarget.value = ""
      controller.filter()
    }
  }
}
