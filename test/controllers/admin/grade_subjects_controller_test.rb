require "test_helper"

class Admin::GradeSubjectsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index renders the grade subject matrix for the current school" do
    get admin_grade_subjects_path

    assert_response :success
    assert_select "h1", text: "年级科目管理"
    assert_select "input[type='checkbox'][name='combinations[]']", minimum: 1
    assert_select "input#combo_7_1[checked][disabled]"
    assert_select "input#combo_8_2[checked]"
    assert_select "input#combo_8_2:not([disabled])"
  end

  test "sync adds a new combination" do
    assert_difference -> { GradeSubject.count }, 1 do
      put sync_admin_grade_subjects_path, params: { combinations: [ "7-1", "8-2", "7-2" ] }
    end

    assert_redirected_to admin_grade_subjects_path
    assert schools(:school_1).grade_subjects.exists?(grade_id: grades(:grade_7).id, subject_id: subjects(:eng).id)
    assert_match "已更新 1 个", flash[:notice]
  end

  test "sync removes an unused combination" do
    assert_difference -> { GradeSubject.count }, -1 do
      put sync_admin_grade_subjects_path, params: { combinations: [ "7-1" ] }
    end

    assert_not schools(:school_1).grade_subjects.exists?(grade_id: grades(:grade_8).id, subject_id: subjects(:eng).id)
  end

  test "sync keeps combinations that already have classes" do
    assert_no_difference -> { GradeSubject.count } do
      put sync_admin_grade_subjects_path, params: { combinations: [ "8-2" ] }
    end

    assert schools(:school_1).grade_subjects.exists?(grade_id: grades(:grade_7).id, subject_id: subjects(:math).id)
    assert_match "已有班级", flash[:notice]
  end

  test "sync ignores invalid combinations" do
    assert_no_difference -> { GradeSubject.count } do
      put sync_admin_grade_subjects_path, params: { combinations: [ "999-999", "7-1", "8-2" ] }
    end

    assert_not GradeSubject.exists?(grade_id: 999, subject_id: 999)
  end

  test "sync only changes the current school" do
    other_school = School.create!(name: "其他学校")
    other = other_school.grade_subjects.create!(grade: grades(:grade_7), subject: subjects(:eng))

    put sync_admin_grade_subjects_path, params: { combinations: [ "7-1", "8-2" ] }

    assert GradeSubject.exists?(other.id)
  end

  test "managers cannot access grade subject management" do
    sign_in_as users(:two)

    get admin_grade_subjects_path

    assert_redirected_to root_path
    assert_match "超级管理员", flash[:alert]
  end
end
