require "test_helper"

class RequestContextTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "切换学期后班级列表按当前学期过滤" do
    get admin_semester_klasses_path
    assert_response :success
    assert_match semester_klasses(:sk_math_2).name, response.body
    assert_no_match semester_klasses(:sk_math_1).name, response.body

    switch_to_semester(semesters(:semester_previous))

    get admin_semester_klasses_path
    assert_response :success
    assert_match semester_klasses(:sk_math_1).name, response.body
    assert_no_match semester_klasses(:sk_math_2).name, response.body
  end

  test "切换学期后可打开该学期的班级详情" do
    switch_to_semester(semesters(:semester_previous))

    get admin_semester_klass_path(semester_klasses(:sk_math_1))

    assert_response :success
  end

  test "切换校区后班级列表按校区过滤" do
    other = Campuse.create!(name: "第二校区", school: schools(:school_1))
    UserCampuse.create!(user: users(:one), school: schools(:school_1), campuse: other, role: "admin", grade_ids: [ "7" ])
    other_sk = SemesterKlass.create!(
      campuse: other, subject: subjects(:math), teacher: teachers(:math_teacher_2),
      semester: semesters(:semester_current), grade: grades(:grade_7), genre: "JY", seq: 55, times: 2
    )

    get switch_thread_campuse_admin_school_campuse_path(schools(:school_1), other), headers: { "HTTP_REFERER" => root_path }
    assert_redirected_to root_path

    get admin_semester_klasses_path
    assert_response :success
    assert_match other_sk.name, response.body
    assert_no_match semester_klasses(:sk_math_2).name, response.body
  end

  private
    def switch_to_semester(semester)
      get switch_thread_semester_admin_school_semester_path(schools(:school_1), semester), headers: { "HTTP_REFERER" => root_path }
      assert_redirected_to root_path
    end
end

class ManagerScopeTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:two) }

  test "管理员只能看到授权年级的学员" do
    get admin_students_path

    assert_response :success
    assert_match students(:student_8_1).name, response.body
    assert_no_match students(:student_7_1).name, response.body
  end
end
