import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="transfer-drawer"
// 考勤卡上的「转出」按钮会带上本次考勤的地址、学员信息和该学员已加入的班级，
// 打开抽屉后按学员隐藏已在班级，并支持按科目 / 班型筛选目标班。
export default class extends Controller {
  static targets = [
    "toggle", "form", "summary", "option",
    "subjectFilter", "genreFilter", "empty", "submit"
  ]

  connect() {
    this.enrolledIds = new Set()
  }

  open(event) {
    const {
      transferUrl, transferStudent, transferSource, transferCourse,
      transferClassIds, transferSubjectId
    } = event.currentTarget.dataset

    this.enrolledIds = new Set((transferClassIds || "").split(",").filter(Boolean))
    this.formTarget.action = transferUrl
    this.summaryTarget.textContent = `将 ${transferStudent} 从 ${transferSource}（${transferCourse}）转出，请选择要转入的班级。`
    this.resetFilters()
    // 默认按当前班级科目筛选；若目标班没有该科目，select 会自动回落到「全部科目」
    if (this.hasSubjectFilterTarget && transferSubjectId) {
      this.subjectFilterTarget.value = transferSubjectId
    }
    this.applyFilters()
    this.toggleTarget.checked = true
  }

  applyFilters() {
    const subject = this.hasSubjectFilterTarget ? this.subjectFilterTarget.value : ""
    const genre = this.hasGenreFilterTarget ? this.genreFilterTarget.value : ""
    let visibleCount = 0

    this.optionTargets.forEach((option) => {
      const matched = !this.enrolledIds.has(option.dataset.classId) &&
        (!subject || option.dataset.subjectId === subject) &&
        (!genre || option.dataset.genre === genre)

      option.classList.toggle("hidden", !matched)

      if (matched) {
        visibleCount += 1
      } else {
        const radio = option.querySelector("input[type='radio']")
        if (radio?.checked) radio.checked = false
      }
    })

    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("hidden", visibleCount > 0)
    if (this.hasSubmitTarget) this.submitTarget.disabled = visibleCount === 0
  }

  resetFilters() {
    if (this.hasSubjectFilterTarget) this.subjectFilterTarget.value = ""
    if (this.hasGenreFilterTarget) this.genreFilterTarget.value = ""
  }
}
