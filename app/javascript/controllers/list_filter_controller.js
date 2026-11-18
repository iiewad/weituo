import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="list-filter"
// 在额外学员列表中按姓名即时过滤，不提交表单。
export default class extends Controller {
  static targets = ["input", "item", "empty", "grade"]

  connect() {
    if (this.hasInputTarget) this.filter()
  }

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase()
    const gradeId = this.hasGradeTarget ? this.gradeTarget.value : ""
    let visible = 0

    this.itemTargets.forEach((item) => {
      const matchedText = item.dataset.searchText.toLowerCase().includes(query)
      const matchedGrade = !gradeId || item.dataset.gradeId === gradeId
      const matched = matchedText && matchedGrade
      item.classList.toggle("hidden", !matched)
      if (!matchedGrade) {
        const checkbox = item.querySelector("input[type='checkbox']")
        if (checkbox) checkbox.checked = false
      }
      if (matched) visible += 1
    })

    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("hidden", visible > 0)
  }
}
