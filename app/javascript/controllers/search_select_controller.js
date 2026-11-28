import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="search-select"
// 可搜索下拉：把页面上的 <select> 换成「输入框 + 浮层候选」。输入关键字按选项文字或分组名（如科目）过滤，
// 选中后写回 <select> 并触发 change，原有依赖 <select> 的联动（如按教师带出课次）不用改。
export default class extends Controller {
  static targets = [ "input", "results", "select" ]

  connect() {
    this.highlighted = -1
    this.selectTarget.classList.add("hidden")
    this.syncInput()
  }

  open() {
    this.render(this.inputTarget.value)
  }

  filter() {
    this.render(this.inputTarget.value)
  }

  // 输入框失焦即收起候选，并把输入框还原成已选项的文字（未选则清空），不会留下选不中的自由文本
  close() {
    this.resultsTarget.classList.add("hidden")
    this.syncInput()
  }

  // 候选项按 pointerdown 选中：先于输入框失焦触发，鼠标和触屏都可靠
  pick(event) {
    const button = event.target.closest("button[data-value]")
    if (!button) return

    event.preventDefault()
    this.choose(button.dataset.value)
  }

  keydown(event) {
    const buttons = Array.from(this.resultsTarget.querySelectorAll("button[data-value]"))

    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
      return
    }
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      if (!this.isOpen()) { this.render(this.inputTarget.value); return }
      const step = event.key === "ArrowDown" ? 1 : -1
      this.highlight(buttons, (this.highlighted + step + buttons.length) % buttons.length)
      return
    }
    if (event.key === "Enter") {
      event.preventDefault()
      if (!this.isOpen()) { this.render(this.inputTarget.value); return }
      // 没有用方向键选中时，只有候选恰好一项才回车选中，避免回车选到非预期的项
      const index = this.highlighted >= 0 ? this.highlighted : (buttons.length === 1 ? 0 : -1)
      if (index >= 0) this.choose(buttons[index].dataset.value)
    }
  }

  choose(value) {
    this.selectTarget.value = value
    this.selectTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.close()
  }

  isOpen() {
    return !this.resultsTarget.classList.contains("hidden")
  }

  // 输入框始终显示已选项的文字；未选时为空
  syncInput() {
    const option = this.selectTarget.selectedOptions[0]
    this.inputTarget.value = option && option.value ? option.text : ""
  }

  // 从 <select> 读取分组（optgroup）与选项，忽略空值占位项
  groups() {
    const select = this.selectTarget
    const groups = Array.from(select.querySelectorAll("optgroup")).map((group) => ({
      name: group.label,
      options: Array.from(group.querySelectorAll("option")).filter((option) => option.value).map((option) => ({ value: option.value, label: option.text }))
    }))
    const loose = Array.from(select.options).filter((option) => option.value && !option.parentElement.closest("optgroup"))
    return groups.concat(loose.length ? [ { name: "", options: loose.map((option) => ({ value: option.value, label: option.text })) } ] : [])
  }

  render(query) {
    const keyword = query.trim().toLowerCase()
    const selectedValue = this.selectTarget.value
    const matches = this.groups()
      .map((group) => {
        // 关键字命中分组名（如输入「数学」）时，该组全部选项都算匹配
        const groupMatched = keyword && group.name.toLowerCase().includes(keyword)
        const options = group.options.filter((option) => !keyword || groupMatched || option.label.toLowerCase().includes(keyword))
        return { name: group.name, options }
      })
      .filter((group) => group.options.length > 0)

    this.resultsTarget.innerHTML = ""
    this.highlighted = -1

    if (matches.length === 0) {
      this.resultsTarget.append(this.node("p", "px-3 py-2 text-xs text-base-content/40", "没有匹配的选项"))
    }

    matches.forEach((group) => {
      if (group.name) {
        this.resultsTarget.append(this.node("p", "px-2.5 pt-1.5 text-[10px] text-base-content/40", group.name))
      }
      group.options.forEach((option) => {
        const button = this.node("button", "flex w-full rounded-box px-2.5 py-1.5 text-left text-xs hover:bg-base-200/60", option.label)
        button.type = "button"
        button.dataset.value = option.value
        if (option.value === selectedValue) {
          button.classList.add("bg-base-200", "font-medium")
        }
        this.resultsTarget.append(button)
      })
    })

    this.resultsTarget.classList.remove("hidden")
  }

  highlight(buttons, index) {
    buttons[this.highlighted]?.classList.remove("bg-base-200/60")
    this.highlighted = index
    const button = buttons[index]
    button.classList.add("bg-base-200/60")
    button.scrollIntoView({ block: "nearest" })
  }

  node(tag, className, text) {
    const element = document.createElement(tag)
    element.className = className
    element.textContent = text
    return element
  }
}
