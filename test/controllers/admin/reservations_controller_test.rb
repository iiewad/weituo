require "test_helper"

class Admin::ReservationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @sk = semester_klasses(:sk_math_2)
    @student = students(:student_7_1)
    @other = students(:student_7_2)
  end

  def reserve(student, genre:, grade: grades(:grade_8), semester: semesters(:semester_next),
      teacher: teachers(:math_teacher_1), source: @sk)
    Reservation.create!(
      student: student, semester: semester, subject: subjects(:math), grade: grade,
      teacher: teacher, genre: genre, source_semester: source.semester, source_semester_klass: source
    )
  end

  def group_params(genre)
    {
      semester_id: semesters(:semester_next).id, grade_id: grades(:grade_8).id, subject_id: subjects(:math).id,
      genre: genre, phase: 1, group_teacher_id: teachers(:math_teacher_1).id, teacher_id: teachers(:math_teacher_1).id
    }
  end

  test "index lists every reserved student of every semester with the target" do
    reserve(@student, genre: "JY")
    reserve(@other, genre: "TG", semester: semesters(:semester_current), source: semester_klasses(:sk_math_1))

    get admin_reservations_path

    assert_response :success
    assert_select "th", text: "源学期"
    assert_select "th", text: "预留目标学期"
    assert_select "tbody tr", count: 2
    assert_select "td", text: /#{@student.identity_label}/
    assert_select "td", text: /#{@other.identity_label}/
    assert_select "td", text: "精英班 一期"
    assert_select "td", text: "八年级"
    # 来源班级所在学期 与 预留目标学期
    assert_select "tbody tr td:nth-child(2)", text: semesters(:semester_previous).name
    assert_select "tbody tr td:nth-child(3)", text: semesters(:semester_current).name
    assert_select "td", text: /待分班/, count: 2
    assert_select "form[action^='#{generate_admin_reservations_path}']", count: 2
  end

  test "index filters by reservation content" do
    reserve(@student, genre: "JY")
    reserve(@other, genre: "TG")

    get admin_reservations_path(q: { genre_eq: "JY" })

    assert_select "tbody tr", count: 1
    assert_select "td", text: /#{@student.identity_label}/

    get admin_reservations_path(q: { semester_id_eq: semesters(:semester_current).id })

    assert_select "tbody tr", count: 0

    get admin_reservations_path(q: { source_semester_id_eq: semesters(:semester_current).id })

    assert_select "tbody tr", count: 2

    get admin_reservations_path(q: { source_semester_id_eq: semesters(:semester_previous).id })

    assert_select "tbody tr", count: 0

    get admin_reservations_path(q: { student_name_cont: @other.name.last(2) }, status: "pending")

    assert_select "tbody tr", count: 1
    assert_select "td", text: /#{@other.identity_label}/
  end

  test "index filters out generated reservations unless asked" do
    reserve(@student, genre: "JY")
    Reservation.last.update!(semester_klass: semester_klasses(:sk_math_1))

    get admin_reservations_path(status: "pending")

    assert_select "tbody tr", count: 0

    get admin_reservations_path(status: "generated")

    assert_select "tbody tr", count: 1
    assert_select "td", text: /已生成 · #{semester_klasses(:sk_math_1).name}/
    assert_select "form[action^='#{generate_admin_reservations_path}']", count: 0
  end

  test "generate creates a next semester class and enrolls the reserved students" do
    reserve(@student, genre: "JY")
    reserve(@other, genre: "JY")

    assert_difference -> { SemesterKlass.where(semester: semesters(:semester_next)).count }, 1 do
      post generate_admin_reservations_path, params: group_params("JY")
    end

    assert_redirected_to admin_reservations_path
    assert_match "加入 2 名预留学员", flash[:notice]

    klass = SemesterKlass.where(semester: semesters(:semester_next)).order(:id).last
    assert_equal grades(:grade_8), klass.grade
    assert_equal "JY", klass.genre
    assert_equal teachers(:math_teacher_1), klass.teacher
    assert_equal [ @student.id, @other.id ].sort, klass.klass_students.pluck(:student_id).sort
    assert Reservation.where(student: [ @student, @other ]).all? { |reservation| reservation.semester_klass == klass }
    # 分班不修改学员现年级
    assert_equal grades(:grade_7), @student.reload.grade

    # 已生成的分组不再重复生成
    assert_no_difference -> { SemesterKlass.count } do
      post generate_admin_reservations_path, params: group_params("JY")
    end
    assert_match "没有待分班的预留学员", flash[:alert]
  end

  test "generate keeps the list filters" do
    reserve(@student, genre: "JY")

    post generate_admin_reservations_path, params: group_params("JY").merge(q: { genre_eq: "JY" }, status: "pending")

    assert_redirected_to admin_reservations_path(q: { genre_eq: "JY" }, status: "pending")
  end

  test "generate only moves its own group" do
    reserve(@student, genre: "JY")
    reserve(@other, genre: "TG")

    post generate_admin_reservations_path, params: group_params("JY")

    assert_equal [ @student.id ], SemesterKlass.where(semester: semesters(:semester_next)).last.klass_students.pluck(:student_id)
    assert Reservation.pending.exists?(student: @other)
  end

  test "generate with incomplete params creates nothing" do
    reserve(@student, genre: "JY")

    assert_no_difference -> { SemesterKlass.count } do
      post generate_admin_reservations_path, params: group_params("JY").except(:subject_id)
    end

    assert_redirected_to admin_reservations_path
    assert_match "预留信息不完整", flash[:alert]
  end

  test "reservations without a teacher pick it when generating" do
    reserve(@student, genre: "JY", teacher: nil)
    reserve(@other, genre: "JY", teacher: nil)

    get admin_reservations_path

    assert_select "td", text: "待定", count: 2
    assert_select "select[name='teacher_id']", count: 2

    assert_no_difference -> { SemesterKlass.count } do
      post generate_admin_reservations_path, params: group_params("JY").except(:teacher_id).merge(group_teacher_id: "")
    end
    assert_match "请选择本科目的在任教师", flash[:alert]

    assert_difference -> { SemesterKlass.where(semester: semesters(:semester_next)).count }, 1 do
      post generate_admin_reservations_path, params: group_params("JY").except(:group_teacher_id).merge(group_teacher_id: "", teacher_id: teachers(:math_teacher_2).id)
    end

    klass = SemesterKlass.where(semester: semesters(:semester_next)).order(:id).last
    assert_equal teachers(:math_teacher_2), klass.teacher
    assert_equal [ @student.id, @other.id ].sort, klass.klass_students.pluck(:student_id).sort
    assert_equal teachers(:math_teacher_2), Reservation.find_by!(student: @other).teacher
  end

  test "manager sees reservations from their own grade into the grade above" do
    sign_in_as users(:two)
    reserve(@student, genre: "JY")
    # 目标年级与来源班级都不在授权年级（八、九年级）内
    hidden = SemesterKlass.create!(
      campuse: campuses(:campuse_1), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      seq: 91, genre: "TG", grade: grades(:grade_7), semester: semesters(:semester_current), times: 1
    )
    Reservation.create!(
      student: @other, semester: semesters(:semester_next), subject: subjects(:math), grade: grades(:grade_7),
      teacher: teachers(:math_teacher_1), genre: "JY", source_semester: hidden.semester, source_semester_klass: hidden
    )

    get admin_reservations_path

    assert_select "tbody tr", count: 1
    assert_select "td", text: /#{@student.identity_label}/

    assert_difference -> { SemesterKlass.where(semester: semesters(:semester_next)).count }, 1 do
      post generate_admin_reservations_path, params: group_params("JY")
    end
  end

  test "update changes the reservation target" do
    reservation = reserve(@student, genre: "JY")

    patch admin_reservation_path(reservation), params: {
      grade_id: grades(:grade_7).id, genre: "TG", teacher_id: teachers(:math_teacher_2).id
    }

    assert_redirected_to admin_reservations_path
    reservation.reload
    assert_equal grades(:grade_7), reservation.grade
    assert_equal "TG", reservation.genre
    assert_equal teachers(:math_teacher_2), reservation.teacher
  end

  test "update can clear the teacher" do
    reservation = reserve(@student, genre: "JY")

    patch admin_reservation_path(reservation), params: { grade_id: reservation.grade_id, genre: reservation.genre, teacher_id: "" }

    assert_nil reservation.reload.teacher
  end

  test "update rejects a teacher from another subject" do
    reservation = reserve(@student, genre: "JY")

    patch admin_reservation_path(reservation), params: {
      grade_id: reservation.grade_id, genre: reservation.genre, teacher_id: teachers(:eng_teacher_1).id
    }

    assert_match "所选教师不是本科目的在任教师", flash[:alert]
    assert_equal teachers(:math_teacher_1), reservation.reload.teacher
  end

  test "generated reservations cannot be updated or cancelled" do
    reservation = reserve(@student, genre: "JY")
    reservation.update!(semester_klass: semester_klasses(:sk_math_1))

    patch admin_reservation_path(reservation), params: { grade_id: grades(:grade_7).id, genre: "TG" }

    assert_match "已生成班级的预留不能修改", flash[:alert]
    assert_equal "JY", reservation.reload.genre

    assert_no_difference -> { Reservation.count } do
      delete admin_reservation_path(reservation)
    end
    assert_match "已生成班级的预留不能取消", flash[:alert]
  end

  test "destroy cancels a pending reservation" do
    reservation = reserve(@student, genre: "JY")

    assert_difference -> { Reservation.count }, -1 do
      delete admin_reservation_path(reservation)
    end
    assert_match "已取消", flash[:notice]
  end

  test "manager cannot update or cancel reservations outside their grades" do
    sign_in_as users(:two)
    hidden = SemesterKlass.create!(
      campuse: campuses(:campuse_1), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      seq: 92, genre: "TG", grade: grades(:grade_7), semester: semesters(:semester_current), times: 1
    )
    reservation = Reservation.create!(
      student: @other, semester: semesters(:semester_next), subject: subjects(:math), grade: grades(:grade_7),
      teacher: teachers(:math_teacher_1), genre: "JY", source_semester: hidden.semester, source_semester_klass: hidden
    )

    patch admin_reservation_path(reservation), params: { grade_id: grades(:grade_7).id, genre: "TG" }
    assert_response :not_found

    assert_no_difference -> { Reservation.count } do
      delete admin_reservation_path(reservation)
    end
    assert_response :not_found
  end
end
