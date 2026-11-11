require "test_helper"

class Admin::SemesterKlassesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index" do
    get admin_semester_klasses_path
    assert_response :success
  end

  test "statement" do
    get statement_admin_semester_klasses_path
    assert_response :success
  end

  test "show" do
    get admin_semester_klass_path(semester_klasses(:sk_math_2))
    assert_response :success
  end

  test "copy" do
    get copy_admin_semester_klasses_path
    assert_response :success
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
    assert_response :redirect
    assert_equal Thread.current[:semester].id, sk.semester_id
    assert_equal Thread.current[:campuse].id, sk.campuse_id
    assert_equal subjects(:math).id, sk.subject_id
    assert_equal 2, sk.courses.count
  end
end
