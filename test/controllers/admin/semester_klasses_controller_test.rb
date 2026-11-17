require "test_helper"

class Admin::SemesterKlassesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index lists current semester classes grouped by grade" do
    get admin_semester_klasses_path

    assert_response :success
    assert_select "h1", text: "班级管理"
    assert_select "h2", text: "七年级"
    assert_select "a[href='#{admin_semester_klass_path(semester_klasses(:sk_math_2))}']", count: 1
    assert_select "a[href='#{admin_semester_klass_path(semester_klasses(:sk_math_1))}']", count: 0
  end

  test "statement" do
    get statement_admin_semester_klasses_path
    assert_response :success
  end

  test "show renders the class menu with the current class active" do
    sk = semester_klasses(:sk_math_2)
    get admin_semester_klass_path(sk)

    assert_response :success
    assert_select "a.menu-active[aria-current='page']", text: /#{sk.name}/
    assert_select "summary", text: /七年级/
    assert_select "summary", text: /数学/
    # 同年级同科目下的其他班级也出现在菜单里，便于切换
    assert_select "a[href='#{admin_semester_klass_path(semester_klasses(:sk_math_3))}']"
  end

  test "copy lists historical classes with their source details" do
    get copy_admin_semester_klasses_path

    assert_response :success
    assert_select "h1", text: "复制历史班级"
    assert_select "tbody tr", count: 2
    assert_select "td", text: /#{semester_klasses(:sk_math_1).name}/
    assert_select "th", text: "在读"
    assert_select "td", text: "1 人", minimum: 1
    assert_select "label.btn", text: "复制", count: 2
    # 复制表单应带上历史班级的班型与年级，而不是留空
    assert_select "select[name='semester_klass[genre]'] option[selected][value='TG']", count: 2
    assert_select "select[name='semester_klass[grade_id]'] option[selected][value='7']", count: 2
    assert_select "textarea[name='semester_klass[students_text]']", count: 2
  end

  test "create" do
    assert_difference -> { SemesterKlass.count }, 1 do
      post admin_semester_klasses_path, params: { semester_klass: {
        semester_id: semesters(:semester_current).id,
        grade_id: grades(:grade_7).id,
        teacher_id: teachers(:math_teacher_1).id,
        campuse_id: campuses(:campuse_1).id,
        genre: "JY", seq: 99, times: 3, students_text: ""
      } }
    end
    sk = SemesterKlass.last
    assert_redirected_to admin_semester_klass_path(sk)
    assert_equal 3, sk.courses.count
    assert_equal [ 1, 2, 3 ], sk.courses.order(:seq).pluck(:seq)
  end

  test "create with a duplicate class redirects with an alert" do
    sk = semester_klasses(:sk_math_1)

    assert_no_difference -> { SemesterKlass.count } do
      post admin_semester_klasses_path, params: { semester_klass: {
        semester_id: sk.semester_id, grade_id: sk.grade_id,
        teacher_id: sk.teacher_id, campuse_id: sk.campuse_id,
        genre: sk.genre, seq: sk.seq, times: 3, students_text: ""
      } }
    end

    assert_redirected_to admin_semester_klasses_path
    assert_match "失败", flash[:alert]
  end

  test "update" do
    sk = semester_klasses(:sk_math_1)

    put admin_semester_klass_path(sk), params: { semester_klass: {
      genre: "JY", seq: 42, times: 5,
      teacher_id: teachers(:math_teacher_1).id, students_text: ""
    } }

    assert_redirected_to admin_semester_klass_path(sk)
    assert_equal "JY", sk.reload.genre
    assert_equal 42, sk.seq
  end

  test "copy_create copies a class into the current semester" do
    assert_difference -> { SemesterKlass.count }, 1 do
      post copy_create_admin_semester_klasses_path, params: { semester_klass: {
        grade_id: grades(:grade_7).id,
        teacher_id: teachers(:math_teacher_1).id,
        genre: "JY", seq: 88, times: 2, students_text: ""
      } }
    end

    sk = SemesterKlass.last
    assert_redirected_to admin_semester_klass_path(sk)
    assert_equal Thread.current[:semester].id, sk.semester_id
    assert_equal Thread.current[:campuse].id, sk.campuse_id
    assert_equal subjects(:math).id, sk.subject_id
    assert_equal 2, sk.courses.count
  end
end
