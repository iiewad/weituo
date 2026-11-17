import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="user-campuses"
export default class extends Controller {
  static targets = ["container", "template", "empty", "count"]

  connect() {
    this.rows().forEach((row) => this.filterRow(row))
    this.refreshEmpty()
  }

  add(event) {
    event.preventDefault()
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, Date.now())
    this.containerTarget.insertAdjacentHTML("beforeend", content)
    this.filterRow(this.rows().at(-1))
    this.refreshEmpty()
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
    this.refreshEmpty()
  }

  filterGrades(event) {
    this.filterRow(event.currentTarget.closest(".nested-fields"))
  }

  // 校区决定可选年级：只保留该校所属学校开设的年级
  filterRow(row) {
    if (!row) return
    const campus = row.querySelector('[data-user-campuses-target="campuse"]')
    const grades = row.querySelector('[data-user-campuses-target="grades"]')
    if (!campus || !grades) return

    const schoolId = campus.selectedOptions[0]?.dataset.schoolId
    grades.querySelectorAll("[data-grade-option]").forEach((chip) => {
      const checkbox = chip.querySelector("input[type='checkbox']")
      const schoolIds = (checkbox.dataset.schoolIds || "").split(",")
      const allowed = !schoolId || schoolIds.includes(schoolId)

      checkbox.disabled = !allowed
      if (!allowed) checkbox.checked = false
      chip.classList.toggle("opacity-40", !allowed)
    })
  }

  rows() {
    return Array.from(this.containerTarget.querySelectorAll(".nested-fields"))
      .filter((row) => row.style.display !== "none")
  }

  refreshEmpty() {
    const count = this.rows().length
    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("hidden", count > 0)
    if (this.hasCountTarget) this.countTarget.textContent = count
  }
}
