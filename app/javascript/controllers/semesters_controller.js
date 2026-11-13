import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="semesters"
export default class extends Controller {
  static targets = ["tbody", "template"];

  addRow() {
    const newRow = this.templateTarget.content.cloneNode(true);
    const timestamp = Date.now();
    newRow.querySelector("tr").id = `new-semester-${timestamp}`;
    newRow.querySelectorAll("input, select").forEach((input) => {
      if (input.name.includes("new_semester")) {
        input.name = input.name.replace("new_semester", timestamp);
        if (input.id) input.id = input.id.replace("new_semester", timestamp);
      }
    });
    this.tbodyTarget.appendChild(newRow);
  }

  deleteRow(event) {
    const row = event.currentTarget.closest("tr");
    const id = row.querySelector('input[name$="[id]"]');
    const destroy = row.querySelector('input[name$="[_destroy]"]');
    if (!destroy || !id || !id.value) {
      row.remove();
    } else {
      destroy.value = "true";
      row.style.display = "none";
    }
  }
}
