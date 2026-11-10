import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "wt-sidebar-collapsed"

export default class extends Controller {
  static targets = ["drawerToggle"]

  connect() {
    this.sync()
  }

  toggle() {
    const collapsed = document.documentElement.classList.toggle("wt-sidebar-collapsed")
    localStorage.setItem(STORAGE_KEY, String(collapsed))
    this.sync()
  }

  sync() {
    const collapsed = document.documentElement.classList.contains("wt-sidebar-collapsed")
    if (this.hasDrawerToggleTarget) this.drawerToggleTarget.checked = false

    this.element.querySelectorAll("[data-sidebar-toggle]").forEach((button) => {
      button.setAttribute("aria-expanded", String(!collapsed))
      button.setAttribute("aria-label", collapsed ? "显示侧边栏" : "隐藏侧边栏")
    })
  }
}
