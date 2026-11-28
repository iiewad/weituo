require "test_helper"

class Admin::GradesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "create adds a grade" do
    assert_difference -> { Grade.count }, 1 do
      post admin_grades_path, params: { grade: { level: 10, name: "十年级" } }
    end

    assert_redirected_to admin_grade_subjects_path
    assert_match "年级已添加", flash[:notice]
  end

  test "create grants the new grade to campus admins" do
    post admin_grades_path, params: { grade: { level: 10, name: "十年级" } }

    grade = Grade.find_by!(name: "十年级")
    user_campuse = UserCampuse.find_by!(user: users(:one), campuse: campuses(:campuse_1))
    assert_includes user_campuse.reload.grade_ids, grade.id
  end

  test "create rejects duplicate level" do
    assert_no_difference -> { Grade.count } do
      post admin_grades_path, params: { grade: { level: grades(:grade_7).level, name: "重复年级" } }
    end

    assert_match "添加失败", flash[:alert]
  end

  test "update changes a grade" do
    grade = grades(:grade_9)

    patch admin_grade_path(grade), params: { grade: { level: grade.level, name: "高三" } }

    assert_redirected_to admin_grade_subjects_path
    assert_equal "高三", grade.reload.name
  end

  test "cannot delete a grade used by students" do
    grade = grades(:grade_7)
    assert Student.exists?(grade_id: grade.id)

    assert_no_difference -> { Grade.count } do
      delete admin_grade_path(grade)
    end

    assert_match "学员", flash[:alert]
  end

  test "cannot delete a grade used by user authorization" do
    grade = Grade.create!(level: 11, name: "十一年级", campuse: campuses(:campuse_1))
    user_campuse = UserCampuse.find_by!(user: users(:one), campuse: campuses(:campuse_1))
    user_campuse.update!(grade_ids: [ grade.id ])

    assert_no_difference -> { Grade.count } do
      delete admin_grade_path(grade)
    end

    assert_match "用户授权", flash[:alert]
  end

  test "deletes an unused grade" do
    grade = Grade.create!(level: 12, name: "十二年级", campuse: campuses(:campuse_1))

    assert_difference -> { Grade.count }, -1 do
      delete admin_grade_path(grade)
    end

    assert_match "年级已删除", flash[:notice]
  end

  test "managers cannot maintain grades" do
    sign_in_as users(:two)

    post admin_grades_path, params: { grade: { level: 13, name: "十三年级" } }

    assert_redirected_to root_path
    assert_match "超级管理员", flash[:alert]
  end
end
