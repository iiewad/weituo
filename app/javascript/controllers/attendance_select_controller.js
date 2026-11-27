import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="attendance-select"
// 考勤表勾选学员后，工具栏「预留」/「移出」把勾选学员带入对应弹窗确认。
export default class extends Controller {
  static targets = [
    "rowCheckbox", "selectAll", "count", "reserveButton", "removeButton",
    "reserveModal", "removeModal", "reserveList", "reserveEmpty", "reserveSubmit", "reserveSkipped",
    "removeList", "removeSubmit"
  ]

  connect() {
    this.afterStreamRender = () => requestAnimationFrame(() => this.refresh())
    document.addEventListener("turbo:before-stream-render", this.afterStreamRender)
    this.refresh()
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.afterStreamRender)
  }

  toggleAll() {
    const checked = this.selectAllTarget.checked
    this.visibleCheckboxes().forEach((checkbox) => { checkbox.checked = checked })
    this.refresh()
  }

  refresh() {
    const selected = this.selected()
    if (this.hasCountTarget) {
      this.countTarget.textContent = selected.length > 0 ? `已选 ${selected.length} 人` : ""
    }
    if (this.hasReserveButtonTarget) {
      this.reserveButtonTarget.disabled = !selected.some((checkbox) => checkbox.dataset.reserveEligible === "true")
    }
    if (this.hasRemoveButtonTarget) this.removeButtonTarget.disabled = selected.length === 0
    if (this.hasSelectAllTarget) {
      const visible = this.visibleCheckboxes()
      this.selectAllTarget.checked = visible.length > 0 && visible.every((checkbox) => checkbox.checked)
    }
  }

  openReserve() {
    const selected = this.selected()
    const eligible = selected.filter((checkbox) => checkbox.dataset.reserveEligible === "true")
    this.renderList(this.reserveListTarget, eligible)
    if (this.hasReserveEmptyTarget) this.reserveEmptyTarget.classList.toggle("hidden", eligible.length > 0)
    if (this.hasReserveSubmitTarget) this.reserveSubmitTarget.disabled = eligible.length === 0
    if (this.hasReserveSkippedTarget) {
      const skipped = selected.length - eligible.length
      this.reserveSkippedTarget.textContent = skipped > 0 ? `另有 ${skipped} 名已预留或不在班学员未列入。` : ""
    }
    this.reserveModalTarget.showModal()
  }

  openRemove() {
    const selected = this.selected()
    this.renderList(this.removeListTarget, selected)
    if (this.hasRemoveSubmitTarget) this.removeSubmitTarget.disabled = selected.length === 0
    this.removeModalTarget.showModal()
  }

  renderList(list, selected) {
    list.replaceChildren()
    selected.forEach((checkbox) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = list.dataset.inputName
      input.value = list.dataset.valueKey === "ks" ? checkbox.dataset.ksId : checkbox.value
      const badge = document.createElement("span")
      badge.className = "badge badge-ghost badge-sm"
      badge.textContent = checkbox.dataset.studentName
      list.append(input, badge)
    })
  }

  selected() {
    return this.rowCheckboxTargets.filter((checkbox) => checkbox.checked)
  }

  visibleCheckboxes() {
    return this.rowCheckboxTargets.filter((checkbox) => !checkbox.closest("tr").classList.contains("hidden"))
  }
}