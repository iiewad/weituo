import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="klass-times"
// 开班时按「年级 + 教师科目」带出该学期在年级科目管理中配置的默认课次。
export default class extends Controller {
  static targets = [ "grade", "teacher", "times" ]
  static values = { times: Object, subjects: Object }

  apply() {
    // 年级是一组单选按钮，取当前勾选的那个
    const grade = this.gradeTargets.find((radio) => radio.checked)?.value
    const subject = this.subjectsValue[this.teacherTarget.value]
    const times = grade && subject ? this.timesValue[`${grade}-${subject}`] : null

    // 没有配置时清空，避免保留上一个组合的课次
    this.timesTarget.value = times || ""
  }
}
