require "application_system_test_case"

class CopyKlassTest < ApplicationSystemTestCase
  test "从历史班级复制到当前学期并跳到新班级" do
    sign_in
    visit admin_semester_klasses_path
    first(:link, "复制历史班级").click

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
  end
end
