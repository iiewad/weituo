import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="drawer-lazy"
// 打开抽屉时才请求 Turbo Frame，避免列表页提前渲染所有详情/表单。
export default class extends Controller {
  static targets = [ "toggle", "frame" ]
  static values = { src: String }

  connect() {
    this.load()
  }

  load() {
    if (!this.toggleTarget.checked || !this.hasFrameTarget) return
    if (this.frameTarget.getAttribute("src")) return

    this.frameTarget.setAttribute("src", this.srcValue)
  }
}
