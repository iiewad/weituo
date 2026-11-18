require "test_helper"

class Admin::StudentsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index" do
    get admin_students_path
    assert_response :success
  end

  test "index supports changing page size and keeps filters" do
    get admin_students_path(q: { name_cont: "7_学生1" }, filter: "in_class", per_page: 50)

    assert_response :success
    assert_select "select#students-per-page option[selected][value='50']"
    assert_select "input[name='per_page'][value='50']"
    assert_select "a[href*='per_page=50'][href*='filter=in_class']", minimum: 1
  end

  test "index falls back to the default page size" do
    get admin_students_path(per_page: 999)

    assert_response :success
    assert_select "select#students-per-page option[selected][value='30']"
  end

  test "index keeps the filter and quick filter state after searching" do
    get admin_students_path(q: { name_cont: "7_学生1", grade_id_eq: grades(:grade_7).id }, filter: "in_class")

    assert_response :success
    assert_select "input[name='q[name_cont]'][value='7_学生1']"
    assert_select "select[name='q[grade_id_eq]'] option[selected][value='#{grades(:grade_7).id}']"
    assert_select "input[name='filter'][value='in_class']"
  end

  test "index renders a detail drawer with the student's class history" do
    student = students(:student_7_1)
    student.update!(remark: "家长要求每节课反馈")
    klass_student = klass_students(:ks_1)
    Attendance.create!(
      course: semester_klasses(:sk_math_1).courses.first,
      klass_student:,
      status: "normal"
    )
    get admin_students_path

    assert_response :success
    assert_select "tr#student-row-#{student.id}"
    assert_select "label.btn", text: "详情", minimum: 1

    drawer = Nokogiri::HTML(response.body).at_css("#drawer-student-detail-#{student.id}").parent
    assert_includes drawer.text, "历史班级"
    assert_includes drawer.text, semester_klasses(:sk_math_1).name
    assert_includes drawer.text, semester_klasses(:sk_math_2).name
    assert_includes drawer.text, "在班"
    assert_includes drawer.text, "当前学期"
    assert_includes drawer.text, "考勤 1 次 · 出勤 1"
    assert_includes drawer.text, "家长要求每节课反馈"
    assert_includes drawer.text, "9_学生1"
  end

  %w[in_class not_in_class out_class].each do |filter|
    test "index with #{filter} filter" do
      get admin_students_path(filter: filter)
      assert_response :success
    end
  end

  test "create" do
    assert_difference -> { Student.count }, 1 do
      post admin_students_path, params: { student: { name: "新学员", campuse_id: campuses(:campuse_1).id, grade_id: grades(:grade_7).id, remark: "需要关注" } }
    end
    assert_redirected_to admin_students_path
    assert_equal "需要关注", Student.find_by!(name: "新学员").remark
  end

  test "create saves the referrer" do
    referrer = students(:student_9_2)

    assert_difference -> { StudentReferral.count }, 1 do
      post admin_students_path, params: { student: { name: "推荐新生", grade_id: grades(:grade_7).id, referrer_id: referrer.id } }
    end

    assert_equal referrer, Student.find_by!(name: "推荐新生").referrer
  end

  test "options returns matching students and excludes the given id" do
    excluded = students(:student_8_1)

    get options_admin_students_path(q: "8_学生1", exclude_id: excluded.id)

    assert_response :success
    payload = JSON.parse(response.body)
    assert payload.any?
    assert_not_includes payload.map { |student| student["id"] }, excluded.id
    assert payload.all? { |student| student["name"].include?("8_学生1") }
    assert payload.all? { |student| student["detail"].present? }
  end

  test "options requires a search query" do
    get options_admin_students_path

    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end

  test "options searches across grades for managers with limited grade access" do
    sign_in_as users(:two)

    get options_admin_students_path(q: "7_学生1")

    assert_response :success
    assert_includes JSON.parse(response.body).map { |student| student["name"] }, "7_学生1"
  end

  test "create always uses the current campus" do
    other = Campuse.create!(name: "第二校区", school: schools(:school_1))

    assert_difference -> { Student.count }, 1 do
      post admin_students_path, params: { student: { name: "新学员", grade_id: grades(:grade_7).id, campuse_id: other.id } }
    end

    assert_equal campuses(:campuse_1).id, Student.find_by!(name: "新学员").campuse_id
  end

  test "import creates students from pasted csv text" do
    text = [
      "导入甲,男,2000-01-01,7,1,2026-01-01,三中,家长甲,13800000001,父亲",
      "导入乙,女,2000-01-01,7,1,2026-01-01,三中",
      "坏日校,男,2000-01-01,7,1,2026-01-01,不存在"
    ].join("\n")

    assert_difference -> { Student.count }, 2 do
      assert_difference -> { Guardian.count }, 1 do
        post import_admin_students_path, params: { students_text: text }
      end
    end

    assert_redirected_to admin_students_path
    assert_match "新增 2 名学员", flash[:notice]
    assert_match "跳过 1 行", flash[:notice]
  end

  test "import without text redirects with an alert" do
    assert_no_difference -> { Student.count } do
      post import_admin_students_path, params: { students_text: "  " }
    end

    assert_redirected_to admin_students_path
    assert_match "请粘贴", flash[:alert]
  end

  test "promote moves selected students to the next grade" do
    selected = [ students(:student_7_1), students(:student_7_2) ]

    post promote_admin_students_path, params: { student_ids: selected.map(&:id) }

    assert_redirected_to admin_students_path
    selected.each { |student| assert_equal grades(:grade_8), student.reload.grade }
    assert_match "已为 2 名学员升年级", flash[:notice]
  end

  test "promote skips students without an authorized next grade" do
    student = students(:student_9_1)

    post promote_admin_students_path, params: { student_ids: [ student.id ] }

    assert_redirected_to admin_students_path
    assert_equal grades(:grade_9), student.reload.grade
    assert_match "没有可升的年级", flash[:alert]
  end

  test "promote requires a selection" do
    post promote_admin_students_path, params: { student_ids: [ "" ] }

    assert_redirected_to admin_students_path
    assert_match "请先勾选", flash[:alert]
  end

  test "update" do
    student = students(:student_7_1)
    referrer = students(:student_9_2)
    put admin_student_path(student), params: { student: { name: "改名", remark: "已更新备注", referrer_id: referrer.id } }
    assert_redirected_to admin_students_path
    assert_equal "改名", student.reload.name
    assert_equal "已更新备注", student.remark
    assert_equal referrer, student.referrer
  end
end
