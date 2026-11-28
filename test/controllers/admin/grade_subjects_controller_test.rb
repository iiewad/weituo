require "test_helper"

class Admin::GradeSubjectsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index renders the grade subject matrix for the current semester" do
    get admin_grade_subjects_path

    assert_response :success
    assert_select "h1", text: "年级科目管理"
    assert_select "input[type='checkbox'][name='combinations[]']", minimum: 1
    assert_select "input#combo_7_1[checked][disabled]"
    assert_select "input#combo_8_2[checked]"
    assert_select "input#combo_8_2:not([disabled])"
    assert_select "input[name='times[7-1]'][value='16']"
    assert_select "input[name='times[8-2]'][value='12']"
  end

  test "sync adds a new combination with a default times" do
    assert_difference -> { GradeSubject.count }, 1 do
      put sync_admin_grade_subjects_path, params: { combinations: [ "7-1", "8-2", "7-2" ] }
    end

    assert_redirected_to admin_grade_subjects_path
    added = campuses(:campuse_1).grade_subjects.find_by!(
      semester: semesters(:semester_current), grade_id: grades(:grade_7).id, subject_id: subjects(:eng).id
    )
    assert_equal 16, added.times
    assert_match "已更新 1 个", flash[:notice]
  end

  test "sync updates times for existing combinations" do
    put sync_admin_grade_subjects_path, params: {
      combinations: [ "7-1", "8-2" ],
      times: { "8-2" => "20" }
    }

    assert_equal 20, grade_subjects(:two).reload.times
    assert_equal 16, grade_subjects(:one).reload.times
  end

  test "sync removes an unused combination" do
    assert_difference -> { GradeSubject.count }, -1 do
      put sync_admin_grade_subjects_path, params: { combinations: [ "7-1" ] }
    end

    assert_not campuses(:campuse_1).grade_subjects.exists?(
      semester: semesters(:semester_current), grade_id: grades(:grade_8).id, subject_id: subjects(:eng).id
    )
  end

  test "sync keeps combinations that already have classes" do
    assert_no_difference -> { GradeSubject.count } do
      put sync_admin_grade_subjects_path, params: { combinations: [ "8-2" ] }
    end

    assert campuses(:campuse_1).grade_subjects.exists?(
      semester: semesters(:semester_current), grade_id: grades(:grade_7).id, subject_id: subjects(:math).id
    )
    assert_match "已有班级", flash[:notice]
  end

  test "sync ignores invalid combinations" do
    assert_no_difference -> { GradeSubject.count } do
      put sync_admin_grade_subjects_path, params: { combinations: [ "999-999", "7-1", "8-2" ] }
    end

    assert_not GradeSubject.exists?(grade_id: 999, subject_id: 999)
  end

  test "sync only changes the current campus and semester" do
    other_campuse = Campuse.create!(name: "其他校区", school: schools(:school_1))
    other_grade = other_campuse.grades.create!(name: "七年级", level: 7)
    other_subject = other_campuse.subjects.create!(name: "英语", code: "ENG")
    other_semester = other_campuse.semesters.create!(name: "其他学期", seq: 1)
    other = other_campuse.grade_subjects.create!(
      semester: other_semester, grade: other_grade, subject: other_subject, times: 12
    )
    next_semester = campuses(:campuse_1).grade_subjects.create!(
      semester: semesters(:semester_next), grade: grades(:grade_9), subject: subjects(:math), times: 10
    )

    put sync_admin_grade_subjects_path, params: { combinations: [ "7-1", "8-2" ] }

    assert GradeSubject.exists?(other.id)
    assert GradeSubject.exists?(next_semester.id)
  end

  test "managers cannot access grade subject management" do
    sign_in_as users(:two)

    get admin_grade_subjects_path

    assert_redirected_to root_path
    assert_match "超级管理员", flash[:alert]
  end
end
