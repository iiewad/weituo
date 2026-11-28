import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="student-multiselect"
// 搜索多选：勾选后以标签展示，可逐个移除或一键清空；可选按外部年级控件联动过滤。
export default class extends Controller {
  static targets = ["input", "option", "panel", "empty", "selected", "count", "quickAdd", "quickAddError"]
  static values = { gradeSelector: String, quickAddUrl: String, optionsId: String, csrf: String }

  connect() {
    this.handleOutsideClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    this.handleGradeChange = () => this.filter()

    document.addEventListener("click", this.handleOutsideClick)
    if (this.hasGradeSelectorValue && this.gradeSelectorValue) {
      // 年级控件可以是一个 select，也可以是包着一组单选按钮的容器
      this.gradeElement = document.querySelector(this.gradeSelectorValue)
      this.gradeElement?.addEventListener("change", this.handleGradeChange)
    }

    this.filter()
  }

  disconnect() {
    document.removeEventListener("click", this.handleOutsideClick)
    this.gradeElement?.removeEventListener("change", this.handleGradeChange)
  }

  gradeValue() {
    const element = this.gradeElement
    if (!element) return ""
    return element.matches("select, input") ? element.value : element.querySelector("input:checked")?.value || ""
  }

  open() {
    this.panelTarget.classList.remove("hidden")
  }

  close() {
    this.panelTarget.classList.add("hidden")
  }

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase()
    const gradeId = this.gradeValue()
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
    if (this.hasQuickAddTarget) {
      const name = this.inputTarget.value.trim()
      this.quickAddTarget.disabled = name.length === 0
      this.quickAddTarget.title = name.length === 0 ? "请先输入学员姓名" : `以「${name}」建档并加入`
    }
    this.sync()
  }

  // 直接以搜索框里的姓名和当前班级年级建档，创建后自动勾选，不再弹窗
  async quickAdd() {
    const name = this.inputTarget.value.trim()
    if (!name) {
      this.inputTarget.focus()
      return
    }

    const gradeId = this.gradeValue()
    if (!gradeId) {
      this.gradeElement?.querySelector?.("input, select")?.reportValidity()
      return
    }

    this.hideQuickAddError()
    this.quickAddTarget.disabled = true

    const body = new FormData()
    body.append("student[name]", name)
    body.append("student[grade_id]", gradeId)

    let response
    try {
      response = await fetch(this.quickAddUrlValue, {
        method: "POST",
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfValue },
        body
      })
    } catch {
      this.showQuickAddError("网络异常，请稍后重试")
      return
    } finally {
      this.quickAddTarget.disabled = false
    }

    const data = await response.json().catch(() => ({}))
    if (!response.ok) {
      this.showQuickAddError((data.errors || [ "创建失败，请稍后重试" ]).join("；"))
      return
    }

    this.appendOption(data)
    this.inputTarget.value = ""
    this.filter()
  }

  appendOption(student) {
    const container = document.getElementById(this.optionsIdValue)
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
    checkbox.id = `quick_student_${student.id}`
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
  }

  showQuickAddError(message) {
    if (!this.hasQuickAddErrorTarget) return

    this.quickAddErrorTarget.textContent = message
    this.quickAddErrorTarget.classList.remove("hidden")
  }

  hideQuickAddError() {
    if (!this.hasQuickAddErrorTarget) return

    this.quickAddErrorTarget.textContent = ""
    this.quickAddErrorTarget.classList.add("hidden")
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
      name.textContent = option.dataset.displayText || option.dataset.searchText

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
