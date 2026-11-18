import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="student-picker"
// 单个学员搜索选择器：远程按姓名搜索，选中后以标签展示，可清除。
export default class extends Controller {
  static targets = [ "input", "hidden", "results", "selected" ]
  static values = { optionsUrl: String, excludeId: String, selectedName: String, selectedGrade: String }

  connect() {
    this.requestId = 0
    this.handleOutsideClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    document.addEventListener("click", this.handleOutsideClick)
    this.renderSelected()
  }

  disconnect() {
    document.removeEventListener("click", this.handleOutsideClick)
    clearTimeout(this.timeout)
  }

  search() {
    clearTimeout(this.timeout)

    const query = this.inputTarget.value.trim()
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
    if (this.excludeIdValue) url.searchParams.set("exclude_id", this.excludeIdValue)

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
        button.className = "flex w-full items-center gap-2 rounded-box px-2.5 py-1.5 text-left text-xs hover:bg-base-200/60"

        const name = document.createElement("span")
        name.className = "font-medium"
        name.textContent = student.name

        const grade = document.createElement("span")
        grade.className = "ml-auto text-[10px] text-base-content/40"
        grade.textContent = student.grade || ""

        button.append(name, grade)
        button.addEventListener("click", () => this.select(student))
        this.resultsTarget.append(button)
      })
    }

    this.resultsTarget.classList.remove("hidden")
  }

  select(student) {
    this.hiddenTarget.value = student.id
    this.selectedNameValue = student.name
    this.selectedGradeValue = student.grade || ""
    this.inputTarget.value = ""
    this.renderSelected()
    this.close()
  }

  renderSelected() {
    this.selectedTarget.innerHTML = ""

    if (!this.hiddenTarget.value) {
      const hint = document.createElement("span")
      hint.className = "text-xs text-base-content/40"
      hint.textContent = "未选择推荐人"
      this.selectedTarget.append(hint)
      return
    }

    const chip = document.createElement("span")
    chip.className = "badge badge-ghost badge-sm gap-1"

    const name = document.createElement("span")
    name.textContent = [ this.selectedNameValue, this.selectedGradeValue ].filter(Boolean).join(" · ")

    const remove = document.createElement("button")
    remove.type = "button"
    remove.className = "text-base-content/40 hover:text-error"
    remove.textContent = "×"
    remove.setAttribute("aria-label", `移除 ${name.textContent}`)
    remove.addEventListener("click", () => this.clear())

    chip.append(name, remove)
    this.selectedTarget.append(chip)
  }

  clear(event) {
    event?.preventDefault()
    this.hiddenTarget.value = ""
    this.selectedNameValue = ""
    this.selectedGradeValue = ""
    this.inputTarget.value = ""
    this.renderSelected()
    this.close()
  }

  close() {
    this.resultsTarget.classList.add("hidden")
  }
}
