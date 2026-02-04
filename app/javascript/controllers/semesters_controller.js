import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="semesters"
export default class extends Controller {
  static targets = ["tbody", "template"];

  connect() {
    console.log("Semesters controller connected");
  }

  addRow() {
    const tbody = this.tbodyTarget;
    const template = this.templateTarget;
    const newRow = template.content.cloneNode(true);
    
    const timestamp = Date.now();
    const rowId = `new-semester-${timestamp}`;
    const row = newRow.querySelector("tr");
    row.id = rowId;
    
    const inputs = newRow.querySelectorAll("input");
    inputs.forEach(input => {
      if (input.name.includes("new_semester")) {
        const newName = input.name.replace("new_semester", timestamp);
        input.name = newName;
        if (input.id) {
          input.id = input.id.replace("new_semester", timestamp);
        }
      }
    });
    
    tbody.appendChild(newRow);
  }

  deleteRow(event) {
    const rowElement = event.target.closest("tr");
    const destroyField = rowElement.querySelector(`input[name*="semesters_attributes"][name*="_destroy"]`);
    
    if (destroyField) {
      if (rowElement.id.startsWith("semester-") && !rowElement.id.includes("new")) {
        destroyField.value = "true";
        rowElement.style.opacity = "0.5";
        rowElement.classList.add("line-through");
        
        const inputsToDisable = rowElement.querySelectorAll('input:not([name*="_destroy"]):not([name*="id"])');
        const deleteBtn = rowElement.querySelector("button");
        
        inputsToDisable.forEach(input => input.disabled = true);
        if (deleteBtn) deleteBtn.disabled = true;
        
        destroyField.disabled = false;
        const idField = rowElement.querySelector(`input[name*="semesters_attributes"][name*="id"]`);
        if (idField) idField.disabled = false;
      } else {
        rowElement.remove();
      }
    }
  }
}