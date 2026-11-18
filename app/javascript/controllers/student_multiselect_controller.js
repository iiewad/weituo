import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="student-multiselect"
// 搜索多选：勾选后以标签展示，可逐个移除或一键清空；可选按外部年级下拉联动过滤。
export default class extends Controller {
  static targets = ["input", "option", "panel", "empty", "selected", "count"]
  static values = { gradeSelector: String }

  connect() {
    this.handleOutsideClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    this.handleGradeChange = () => this.filter()

    document.addEventListener("click", this.handleOutsideClick)
    if (this.hasGradeSelectorValue && this.gradeSelectorValue) {
      this.gradeElement = document.querySelector(this.gradeSelectorValue)
      this.gradeElement?.addEventListener("change", this.handleGradeChange)
    }

    this.filter()
  }

  disconnect() {
    document.removeEventListener("click", this.handleOutsideClick)
    this.gradeElement?.removeEventListener("change", this.handleGradeChange)
  }

  open() {
    this.panelTarget.classList.remove("hidden")
  }

  close() {
    this.panelTarget.classList.add("hidden")
  }

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase()
    const gradeId = this.gradeElement?.value || ""
    let visible = 0

    this.optionTargets.forEach((option) => {
      const matchedText = option.dataset.searchText.toLowerCase().includes(query)
      const matchedGrade = !gradeId || option.dataset.gradeId === gradeId
      const matched = matchedText && matchedGrade

      option.classList.toggle("hidden", !matched)
      if (!matchedGrade) {
        const checkbox = option.querySelector("input[type='checkbox']")
        if (checkbox) checkbox.checked = false
      }
      if (matched) visible += 1
    })

    this.emptyTarget.classList.toggle("hidden", visible > 0)
    this.sync()
  }

  sync() {
    const checked = this.optionTargets
      .map((option) => ({ option, checkbox: option.querySelector("input[type='checkbox']") }))
      .filter(({ checkbox }) => checkbox?.checked)

    this.countTarget.textContent = checked.length
    this.selectedTarget.innerHTML = ""

    if (checked.length === 0) {
      const hint = document.createElement("span")
      hint.className = "text-xs text-base-content/40"
      hint.textContent = "尚未选择学员"
      this.selectedTarget.append(hint)
      return
    }

    checked.forEach(({ option, checkbox }) => {
      const chip = document.createElement("span")
      chip.className = "badge badge-ghost badge-sm gap-1"

      const name = document.createElement("span")
      name.textContent = option.dataset.searchText

      const remove = document.createElement("button")
      remove.type = "button"
      remove.className = "text-base-content/40 hover:text-error"
      remove.textContent = "×"
      remove.setAttribute("aria-label", `移除 ${name.textContent}`)
      remove.addEventListener("click", () => {
        checkbox.checked = false
        this.sync()
      })

      chip.append(name, remove)
      this.selectedTarget.append(chip)
    })
  }

  clear(event) {
    event.preventDefault()
    this.optionTargets.forEach((option) => {
      const checkbox = option.querySelector("input[type='checkbox']")
      if (checkbox) checkbox.checked = false
    })
    this.inputTarget.value = ""
    this.filter()
    this.sync()
  }
}
