require "test_helper"

class Admin::SemestersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index lists semesters of the current campuse" do
    get admin_semesters_path

    assert_response :success
    assert_select "td", text: semesters(:semester_current).name
    assert_select "td", text: semesters(:semester_next).name
    assert_select ".badge", text: "当前学期"
  end

  test "index does not list semesters from another campuse" do
    other_campuse = Campuse.create!(name: "其他校区", school: schools(:school_1))
    other_campuse.semesters.create!(name: "其他校区学期", seq: 1)

    get admin_semesters_path

    assert_response :success
    assert_select "td", text: "其他校区学期", count: 0
  end

  test "create adds a semester to the current campuse" do
    assert_difference -> { Semester.count }, 1 do
      post admin_semesters_path, params: { semester: { name: "新学期", seq: 4 } }
    end

    assert_redirected_to admin_semesters_path
    assert_match "学期已添加", flash[:notice]
    semester = Semester.find_by(name: "新学期")
    assert_equal campuses(:campuse_1), semester.campuse
    assert_not semester.current
  end

  test "create rejects a duplicate seq in the same campuse" do
    assert_no_difference -> { Semester.count } do
      post admin_semesters_path, params: { semester: { name: "重复序号", seq: semesters(:semester_next).seq } }
    end

    assert_redirected_to admin_semesters_path
    assert_match "学期添加失败", flash[:alert]
  end

  test "update renames a semester" do
    put admin_semester_path(semesters(:semester_next)), params: { semester: { name: "改名学期" } }

    assert_redirected_to admin_semesters_path
    assert_match "学期已更新", flash[:notice]
    assert_equal "改名学期", semesters(:semester_next).reload.name
  end

  test "update can flag the current semester and unsets the previous flag" do
    put admin_semester_path(semesters(:semester_next)), params: { semester: { current: "1" } }

    assert_redirected_to admin_semesters_path
    assert semesters(:semester_next).reload.current
    assert_not semesters(:semester_current).reload.current
  end

  test "destroy cascades the semester with its classes" do
    semester = semesters(:semester_next)
    klass_count = semester.semester_klasses.count

    assert_difference -> { Semester.count }, -1 do
      assert_difference -> { SemesterKlass.count }, -klass_count do
        delete admin_semester_path(semester)
      end
    end

    assert_redirected_to admin_semesters_path
    assert_match "已删除", flash[:notice]
  end

  test "destroying the current semester falls back to the smallest seq" do
    delete admin_semester_path(semesters(:semester_current))

    assert_redirected_to admin_semesters_path
    assert_equal semesters(:semester_previous), campuses(:campuse_1).reload.current_semester
  end

  test "cannot manage a semester from another campuse" do
    other_campuse = Campuse.create!(name: "其他校区", school: schools(:school_1))
    other_semester = other_campuse.semesters.create!(name: "其他学期", seq: 1)

    put admin_semester_path(other_semester), params: { semester: { name: "篡改" } }
    assert_response :not_found

    delete admin_semester_path(other_semester)
    assert_response :not_found
    assert Semester.exists?(other_semester.id)
  end

  test "managers cannot manage semesters" do
    sign_in_as users(:two)

    get admin_semesters_path

    assert_redirected_to root_path
    assert_match "超级管理员", flash[:alert]
  end

  test "managers can still switch the thread semester" do
    sign_in_as users(:two)

    get switch_thread_semester_admin_semester_path(semesters(:semester_next)), headers: { "HTTP_REFERER" => root_path }

    assert_redirected_to root_path
    assert_equal semesters(:semester_next).id, session[:current_semester_id]
  end

  test "switch thread semester" do
    get switch_thread_semester_admin_semester_path(semesters(:semester_next)), headers: { "HTTP_REFERER" => root_path }
    assert_redirected_to root_path
    assert_equal semesters(:semester_next).id, session[:current_semester_id]
  end

  test "switching from a class detail page lands on the class list" do
    sk = semester_klasses(:sk_math_2)

    get switch_thread_semester_admin_semester_path(semesters(:semester_next)),
      headers: { "HTTP_REFERER" => admin_semester_klass_path(sk) }

    assert_redirected_to admin_semester_klasses_path
    assert_equal semesters(:semester_next).id, session[:current_semester_id]
  end

  test "switching from a class edit page lands on the class list" do
    sk = semester_klasses(:sk_math_2)

    get switch_thread_semester_admin_semester_path(semesters(:semester_next)),
      headers: { "HTTP_REFERER" => edit_admin_semester_klass_path(sk) }

    assert_redirected_to admin_semester_klasses_path
    assert_equal semesters(:semester_next).id, session[:current_semester_id]
  end

  test "switching from a collection report returns to that report" do
    get switch_thread_semester_admin_semester_path(semesters(:semester_next)),
      headers: { "HTTP_REFERER" => statement_admin_semester_klasses_path }

    assert_redirected_to statement_admin_semester_klasses_path
    assert_equal semesters(:semester_next).id, session[:current_semester_id]
  end

  test "cannot switch to a semester from another campuse" do
    other_campuse = Campuse.create!(name: "其他校区", school: schools(:school_1))
    other_semester = other_campuse.semesters.create!(
      name: "其他学期", seq: 1
    )

    get switch_thread_semester_admin_semester_path(other_semester)

    assert_response :not_found
  end
end
