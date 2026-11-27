import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="reservation-select"
// 预留表勾选学员后，工具栏「批量进班」把勾选学员带入弹窗，按分组生成新班级或加入已有班级。
export default class extends Controller {
  static targets = [
    "rowCheckbox", "selectAll", "count", "batchButton", "modal",
    "idList", "modalCount", "groupRow", "groupCount", "generatePane", "joinPane", "generateEmpty"
  ]

  connect() {
    this.refresh()
  }

  refresh() {
    const selected = this.selected()

    if (this.hasCountTarget) {
      this.countTarget.textContent = selected.length > 0 ? `已选 ${selected.length} 人` : ""
    }
    if (this.hasBatchButtonTarget) {
      this.batchButtonTarget.disabled = selected.length === 0
    }
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = this.rowCheckboxTargets.length > 0 &&
        this.rowCheckboxTargets.every((checkbox) => checkbox.checked)
    }
  }

  toggleAll() {
    const checked = this.selectAllTarget.checked
    this.rowCheckboxTargets.forEach((checkbox) => { checkbox.checked = checked })
    this.refresh()
  }

  openBatch() {
    if (!this.hasModalTarget) return

    const selected = this.selected()
    if (selected.length === 0) return

    this.idListTarget.replaceChildren()
    selected.forEach((checkbox) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "reservation_ids[]"
      input.value = checkbox.value
      this.idListTarget.append(input)
    })

    if (this.hasModalCountTarget) this.modalCountTarget.textContent = selected.length

    const counts = new Map()
    selected.forEach((checkbox) => {
      const key = checkbox.dataset.groupKey
      counts.set(key, (counts.get(key) || 0) + 1)
    })

    this.groupRowTargets.forEach((row) => {
      const count = counts.get(row.dataset.batchGroup) || 0
      row.dataset.selectedCount = count
      const label = row.querySelector('[data-reservation-select-target="groupCount"]')
      if (label) label.textContent = count > 0 ? `选中 ${count} 人` : ""
    })

    this.applyMode()
    this.modalTarget.showModal()
  }

  switchMode() {
    this.applyMode()
  }

  applyMode() {
    const generate = this.currentMode() === "generate"

    if (this.hasGeneratePaneTarget) this.generatePaneTarget.classList.toggle("hidden", !generate)
    if (this.hasJoinPaneTarget) this.joinPaneTarget.classList.toggle("hidden", generate)

    let visibleGroups = 0
    this.groupRowTargets.forEach((row) => {
      const active = generate && row.dataset.selectedCount !== "0"
      row.classList.toggle("hidden", !active)
      if (active) visibleGroups += 1
      row.querySelectorAll("select, input").forEach((field) => { field.disabled = !active })
    })

    if (this.hasJoinPaneTarget) {
      this.joinPaneTarget.querySelectorAll("select, input").forEach((el) => { el.disabled = generate })
    }
    if (this.hasGenerateEmptyTarget) {
      this.generateEmptyTarget.classList.toggle("hidden", !(generate && visibleGroups === 0))
    }
  }

  currentMode() {
    const checked = this.element.querySelector("input[name='mode']:checked")
    return checked ? checked.value : "generate"
  }

  selected() {
    return this.rowCheckboxTargets.filter((checkbox) => checkbox.checked)
  }
}