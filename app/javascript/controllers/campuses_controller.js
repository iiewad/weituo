import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="campuses"
export default class extends Controller {
  static targets = ["tbody", "template"];

  addRow() {
    const newRow = this.templateTarget.content.cloneNode(true);
    const timestamp = Date.now();
    newRow.querySelector("tr").id = `new-campus-${timestamp}`;
    newRow.querySelectorAll("input, select").forEach((input) => {
      if (input.name.includes("new_campus")) {
        input.name = input.name.replace("new_campus", timestamp);
        if (input.id) input.id = input.id.replace("new_campus", timestamp);
      }
    });
    this.tbodyTarget.appendChild(newRow);
  }

  deleteRow(event) {
    const row = event.currentTarget.closest("tr");
    const id = row.querySelector('input[name$="[id]"]');
    const destroy = row.querySelector('input[name$="[_destroy]"]');
    // 新增行（id 为空）直接移除；已有行标记 _destroy，由 Rails 在提交时删除
    if (!destroy || !id || !id.value) {
      row.remove();
    } else {
      destroy.value = "true";
      row.style.display = "none";
    }
  }
}
