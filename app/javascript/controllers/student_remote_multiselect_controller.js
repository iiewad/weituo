import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="student-remote-multiselect"
// 远程搜索多选：不预渲染候选列表，输入姓名后才请求；已选学员以隐藏字段提交。
export default class extends Controller {
  static targets = [ "input", "results", "selected", "count", "fields" ]
  static values = { optionsUrl: String, gradeSelector: String, gradeId: String, selected: Array }

  connect() {
    this.selected = new Map(this.selectedValue.map((student) => [ student.id, student ]))
    this.requestId = 0
    this.handleOutsideClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    this.handleGradeChange = () => this.clear()

    document.addEventListener("click", this.handleOutsideClick)
    this.gradeElement = this.hasGradeSelectorValue ? document.querySelector(this.gradeSelectorValue) : null
    this.gradeElement?.addEventListener("change", this.handleGradeChange)
    this.renderSelected()
  }

  disconnect() {
    document.removeEventListener("click", this.handleOutsideClick)
    this.gradeElement?.removeEventListener("change", this.handleGradeChange)
    clearTimeout(this.timeout)
  }

  currentGradeId() {
    if (this.gradeElement) return this.gradeElement.value
    if (this.hasGradeIdValue) return this.gradeIdValue
    return ""
  }

  search() {
    clearTimeout(this.timeout)

    const query = this.inputTarget.value.trim()
    if (!this.currentGradeId()) {
      this.requestId += 1
      this.resultsTarget.innerHTML = '<p class="px-3 py-2 text-xs text-base-content/40">请先选择年级</p>'
      this.resultsTarget.classList.remove("hidden")
      return
    }

    if (!query) {
      this.requestId += 1
      this.close()
      this.resultsTarget.innerHTML = ""
      return
    }

    this.timeout = setTimeout(() => this.fetchOptions(query), 180)
  }

  async fetchOptions(query) {
    const requestId = ++this.requestId
    const url = new URL(this.optionsUrlValue, window.location.origin)
    url.searchParams.set("q", query)
    url.searchParams.set("grade_id", this.currentGradeId())

    try {
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      if (!response.ok || requestId !== this.requestId) return

      this.renderResults(await response.json())
    } catch {
      this.close()
    }
  }

  renderResults(students) {
    this.resultsTarget.innerHTML = ""

    if (students.length === 0) {
      const empty = document.createElement("p")
      empty.className = "px-3 py-2 text-xs text-base-content/40"
      empty.textContent = "没有匹配的学员"
      this.resultsTarget.append(empty)
    } else {
      students.forEach((student) => {
        const button = document.createElement("button")
        button.type = "button"
        button.className = "flex w-full flex-col rounded-box px-2.5 py-1.5 text-left text-xs hover:bg-base-200/60"
        button.disabled = this.selected.has(student.id)

        const name = document.createElement("span")
        name.className = "font-medium"
        name.textContent = student.name

        const detail = document.createElement("span")
        detail.className = "text-[10px] text-base-content/40"
        detail.textContent = student.detail || ""

        button.append(name, detail)
        button.addEventListener("click", () => this.select(student))
        this.resultsTarget.append(button)
      })
    }

    this.resultsTarget.classList.remove("hidden")
  }

  select(student) {
    if (this.selected.has(student.id)) return

    this.selected.set(student.id, student)
    this.addHiddenField(student.id)

    this.renderSelected()
    this.inputTarget.value = ""
    this.close()
  }

  addHiddenField(id) {
    if (this.fieldsTarget.querySelector(`input[value="${id}"]`)) return

    const hidden = document.createElement("input")
    hidden.type = "hidden"
    hidden.name = "student_ids[]"
    hidden.value = id
    this.fieldsTarget.append(hidden)
  }

  renderSelected() {
    this.selectedTarget.innerHTML = ""

    if (this.selected.size === 0) {
      const hint = document.createElement("span")
      hint.className = "text-xs text-base-content/40"
      hint.textContent = "尚未选择学员"
      this.selectedTarget.append(hint)
    } else {
      this.selected.forEach((student) => {
        const chip = document.createElement("span")
        chip.className = "badge badge-ghost badge-sm gap-1"

        const label = document.createElement("span")
        label.textContent = [ student.name, student.detail ].filter(Boolean).join(" · ")

        const remove = document.createElement("button")
        remove.type = "button"
        remove.className = "text-base-content/40 hover:text-error"
        remove.textContent = "×"
        remove.setAttribute("aria-label", `移除 ${student.name}`)
        remove.addEventListener("click", () => this.remove(student.id))

        chip.append(label, remove)
        this.selectedTarget.append(chip)
      })
    }

    this.countTarget.textContent = this.selected.size
  }

  remove(id) {
    this.selected.delete(id)
    this.fieldsTarget.querySelector(`input[value="${id}"]`)?.remove()
    this.renderSelected()
  }

  clear(event) {
    event?.preventDefault()
    this.selected.clear()
    this.fieldsTarget.innerHTML = ""
    this.inputTarget.value = ""
    this.renderSelected()
    this.close()
  }

  close() {
    this.resultsTarget.classList.add("hidden")
  }
}
