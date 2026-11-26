import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="attendance-search"
// 按学员姓名过滤考勤矩阵的行，支持序号与 Esc 清空。
export default class extends Controller {
  static targets = [ "input", "row", "count", "empty" ]

  connect() {
    this.apply()
  }

  apply() {
    const query = this.inputTarget.value.trim().toLowerCase()
    let matched = 0

    this.rowTargets.forEach((row) => {
      const hit = query.length === 0 || (row.dataset.searchText || "").toLowerCase().includes(query)
      row.classList.toggle("hidden", !hit)
      if (hit) matched += 1
    })

    this.countTarget.textContent = query.length > 0 ? `匹配 ${matched} 人` : ""
    if (this.hasEmptyTarget) {
      this.emptyTarget.classList.toggle("hidden", query.length === 0 || matched > 0)
    }
  }

  clear() {
    this.inputTarget.value = ""
    this.apply()
  }
}
