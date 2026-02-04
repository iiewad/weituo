import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="grade-subjects"
export default class extends Controller {
  static targets = ["tbody", "template"];

  connect() {
    console.log("GradeSubjects controller connected");
  }

  // 添加新的年级科目关联行
  addRow() {
    const tbody = this.tbodyTarget;
    const template = this.templateTarget;
    const newRow = template.content.cloneNode(true);
    
    // 生成唯一ID
    const timestamp = Date.now();
    const rowId = `new-grade-subject-${timestamp}`;
    const row = newRow.querySelector("tr");
    row.id = rowId;
    
    // 更新表单元素的名称和ID，使用动态索引
    const inputs = newRow.querySelectorAll("input, select");
    inputs.forEach(input => {
      if (input.name.includes("new_grade_subject")) {
        const newName = input.name.replace("new_grade_subject", timestamp);
        input.name = newName;
        if (input.id) {
          input.id = input.id.replace("new_grade_subject", timestamp);
        }
      }
    });
    
    tbody.appendChild(newRow);
  }

  // 删除年级科目关联行
  deleteRow(event) {
    // 获取当前点击的行元素
    const rowElement = event.target.closest("tr");
    console.log("Deleting row:", rowElement.id);
    
    // 直接通过表单字段名称查找_destroy字段
    // 使用更精确的选择器
    const destroyField = rowElement.querySelector(`input[name*="grade_subjects_attributes"][name*="_destroy"]`); 
    
    if (destroyField) {
      console.log("Found destroy field:", destroyField.name, "Current value:", destroyField.value);
      
      // 如果是现有关联，标记为删除
      if (rowElement.id.startsWith("grade-subject-") && !rowElement.id.includes("new")) {
        // 使用Rails预期的true/false字符串值
        destroyField.value = "true";
        console.log("Set destroy field value to:", destroyField.value);
        
        // 视觉反馈
        rowElement.style.opacity = "0.5";
        rowElement.classList.add("line-through");
        
        // 禁用编辑，但保留_destroy字段可用
        const inputsToDisable = rowElement.querySelectorAll('input:not([name*="_destroy"]):not([name*="id"]), select');
        const deleteBtn = rowElement.querySelector("button");
        
        inputsToDisable.forEach(input => {
          input.disabled = true;
          console.log("Disabled input:", input.name);
        });
        
        if (deleteBtn) deleteBtn.disabled = true;
        
        // 确保_destroy字段和id字段始终可用
        destroyField.disabled = false;
        const idField = rowElement.querySelector(`input[name*="grade_subjects_attributes"][name*="id"]`);
        if (idField) idField.disabled = false;
        
        // 额外的调试信息：检查所有字段的状态
        const allFields = rowElement.querySelectorAll('input, select');
        allFields.forEach(field => {
          console.log(`Field: ${field.name}, Value: ${field.value}, Disabled: ${field.disabled}`);
        });
      } else {
        // 如果是新添加的关联，直接删除
        rowElement.remove();
        console.log("Removed new row");
      }
    } else {
      console.error("_destroy field not found. Checking all inputs:");
      const allInputs = rowElement.querySelectorAll('input, select');
      allInputs.forEach(input => {
        console.log(`Input: ${input.name}, Type: ${input.type}, Value: ${input.value}`);
      });
    }
  }
}