require "test_helper"

class CampuseIsolationTest < ActionDispatch::IntegrationTest
  setup do
    @other = Campuse.create!(name: "隔离校区", school: schools(:school_1))
    @other_grade = @other.grades.create!(level: 7, name: "隔离七年级")
    UserCampuse.create!(user: users(:one), school: schools(:school_1), campuse: @other,
      role: "admin", grade_ids: [ @other_grade.id ])
    @other_subject = @other.subjects.create!(code: "IMATH", name: "隔离数学")
    @other_current = @other.semesters.create!(name: "隔离当前学期", seq: 1)
    @other.semesters.create!(name: "隔离未来学期", seq: 2)
    @other_student = @other.students.create!(name: "隔离学员", grade: @other_grade)
    sign_in_as users(:one)
  end

  test "学期与年级科目字典只展示当前校区的数据" do
    get admin_semesters_path
    assert_response :success
    assert_match semesters(:semester_current).name, response.body
    assert_no_match "隔离当前学期", response.body

    get admin_grade_subjects_path
    assert_response :success
    assert_match grades(:grade_7).name, response.body
    assert_no_match "隔离七年级", response.body
    assert_no_match "隔离数学", response.body
  end

  test "不能切换或修改另一校区的学期" do
    get switch_thread_semester_admin_semester_path(@other_current), headers: { "HTTP_REFERER" => root_path }
    assert_response :not_found

    put admin_semester_path(@other_current), params: { semester: { name: "篡改" } }
    assert_response :not_found
    assert_equal "隔离当前学期", @other_current.reload.name
  end

  test "切换校区后学期回退到该校区当前学期且学员按校区隔离" do
    get switch_thread_campuse_admin_school_campuse_path(schools(:school_1), @other),
      headers: { "HTTP_REFERER" => admin_students_path }

    get admin_students_path
    assert_response :success
    assert_match "隔离当前学期", response.body
    assert_match "隔离学员", response.body
    assert_no_match students(:student_7_1).name, response.body
  end

  test "无学期的校区被引导去学期管理，创建学期后放行" do
    bare = Campuse.create!(name: "空白校区", school: schools(:school_1))
    UserCampuse.create!(user: users(:one), school: schools(:school_1), campuse: bare, role: "admin", grade_ids: [])
    get switch_thread_campuse_admin_school_campuse_path(schools(:school_1), bare),
      headers: { "HTTP_REFERER" => root_path }

    # 看板仍可打开（新手引导指向学期管理）
    get root_path
    assert_response :success

    get admin_students_path
    assert_redirected_to admin_semesters_path
    assert_match "还没有学期", flash[:alert]

    get admin_grade_subjects_path
    assert_redirected_to admin_semesters_path

    get admin_semesters_path
    assert_response :success

    post admin_semesters_path, params: { semester: { name: "首个学期", seq: 1 } }
    assert_redirected_to admin_semesters_path
    assert_equal "首个学期", bare.semesters.sole.name
    assert bare.semesters.sole.current?

    get admin_students_path
    assert_response :success
  end
end
