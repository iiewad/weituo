import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="campuses"
export default class extends Controller {
  static targets = ["tbody", "template"];

  connect() {
    console.log("Campuses controller connected");
  }

  // 添加新校区行
  addRow() {
    const tbody = this.tbodyTarget;
    const template = this.templateTarget;
    const newRow = template.content.cloneNode(true);
    
    // 生成唯一ID
    const timestamp = Date.now();
    const rowId = `new-campus-${timestamp}`;
    const row = newRow.querySelector("tr");
    row.id = rowId;
    
    // 更新表单元素的名称和ID，使用动态索引
    const inputs = newRow.querySelectorAll("input");
    inputs.forEach(input => {
      if (input.name.includes("new_campus")) {
        const newName = input.name.replace("new_campus", timestamp);
        input.name = newName;
        if (input.id) {
          input.id = input.id.replace("new_campus", timestamp);
        }
      }
    });
    
    tbody.appendChild(newRow);
  }

  // 删除校区行
  deleteRow(event) {
    // 获取当前点击的行元素
    const rowElement = event.target.closest("tr");
    
    // 查找_destroy字段并设置为1
    const destroyField = rowElement.querySelector('input[name$="[_destroy]"]');
    
    if (destroyField) {
      // 如果是现有校区，标记为删除
      if (rowElement.id.startsWith("campus_") && rowElement.id !== "campus_new") {
        destroyField.value = "1";
        
        // 视觉反馈
        rowElement.style.opacity = "0.5";
        rowElement.classList.add("line-through");
        
        // 禁用编辑
        const nameInput = rowElement.querySelector('input[name$="[name]"]');
        const deleteBtn = rowElement.querySelector("button");
        if (nameInput) nameInput.disabled = true;
        if (deleteBtn) deleteBtn.disabled = true;
      } else {
        // 如果是新添加的校区，直接删除
        rowElement.remove();
      }
    } else {
      // 作为后备方案，直接删除行
      rowElement.remove();
    }
  }
}