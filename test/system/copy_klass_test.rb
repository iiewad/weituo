require "application_system_test_case"

class CopyKlassTest < ApplicationSystemTestCase
  test "查看历史班级详情" do
    sign_in
    visit copy_admin_semester_klasses_path

    source = semester_klasses(:sk_math_1)
    row = find("tr", text: source.name)
    within(row) { find("label.btn", text: "详情").click }

    drawer = find("#drawer-cp-detail-#{source.id}", visible: :all).ancestor(".drawer-end")
    within(drawer) do
      assert_text "历史班级详情"
      assert_text "#{source.grade.name} · #{source.subject.name} · #{source.teacher.name} 老师"
      assert_text "共 16 课次"
      assert_text "7_学生1"
    end
  end

  test "额外加入学员支持按姓名搜索" do
    sign_in
    visit copy_admin_semester_klasses_path

    source = semester_klasses(:sk_math_1)
    row = find("tr", text: source.name)
    within(row) { find("label.btn", text: "复制").click }

    drawer = find("#drawer-cp-klass-#{source.id}", visible: :all).ancestor(".drawer-end")
    within(drawer) do
      find("[data-student-multiselect-target='input']").set("7_学生2")

      assert_selector "#copy_#{source.id}_student_#{students(:student_7_2).id}", visible: true
      assert_no_selector "#copy_#{source.id}_student_#{students(:student_7_3).id}", visible: true

      find("#copy_#{source.id}_student_#{students(:student_7_2).id}").check
      assert_selector "[data-student-multiselect-target='selected']", text: students(:student_7_2).name

      find("[data-student-multiselect-target='input']").set("不存在的学员")
      assert_text "没有匹配的学员"
    end
  end

  test "从历史班级复制到当前学期并跳到新班级" do
    sign_in
    visit admin_semester_klasses_path
    first(:link, "复制班级").click

    assert_current_path copy_admin_semester_klasses_path
    assert_text "目标学期"

    source = semester_klasses(:sk_math_1)
    row = find("tr", text: source.name)
    within(row) { find("label.btn", text: "复制").click }

    drawer = find("#drawer-cp-klass-#{source.id}", visible: :all).ancestor(".drawer-end")
    within(drawer) do
      assert_text source.semester.name
      assert_field "班级序号", with: source.seq.to_s
      find("input[type=submit]").click
    end

    assert_text "复制成功"
    assert_current_path admin_semester_klass_path(SemesterKlass.order(:id).last)
    assert_text students(:student_7_1).name
  end
end
