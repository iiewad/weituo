import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="list-filter"
// 在额外学员列表中按姓名即时过滤，不提交表单。
export default class extends Controller {
  static targets = ["input", "item", "empty"]

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase()
    let visible = 0

    this.itemTargets.forEach((item) => {
      const matched = item.dataset.searchText.toLowerCase().includes(query)
      item.classList.toggle("hidden", !matched)
      if (matched) visible += 1
    })

    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("hidden", visible > 0)
  }
}
