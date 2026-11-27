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

  # 预留表只列出当前所选学期的预留；切换学期后其它学期的预留才会出现
  def switch_to_semester(semester)
    get switch_thread_semester_admin_school_semester_path(schools(:school_1), semester)
  end

  test "index lists reservations targeting the selected semester" do
    reserve(@student, genre: "JY")
    reserve(@other, genre: "TG", source: semester_klasses(:sk_math_1))
    switch_to_semester(semesters(:semester_next))

    get admin_reservations_path

    assert_response :success
    assert_select "th", text: "源学期"
    assert_select "th", text: "预留目标学期", count: 0
    assert_select "tbody tr", count: 2
    assert_select "td", text: /#{@student.identity_label}/
    assert_select "td", text: /#{@other.identity_label}/
    assert_select "td", text: "精英班 一期"
    assert_select "td", text: "八年级"
    # 首列为勾选框：第 2 列学员，第 3 列源学期
    assert_select "tbody tr td:nth-child(3)", text: semesters(:semester_previous).name
    assert_select "td", text: /待分班/, count: 2
    assert_select "form[action^='#{generate_admin_reservations_path}']", count: 2
  end

  test "index only shows reservations targeting the current semester" do
    reserve(@student, genre: "JY")
    reserve(@other, genre: "TG", semester: semesters(:semester_current), source: semester_klasses(:sk_math_1))

    get admin_reservations_path

    assert_select "tbody tr", count: 1
    assert_select "td", text: /#{@other.identity_label}/
    assert_select "td", text: /#{@student.identity_label}/, count: 0
  end

  test "index filters by reservation content" do
    reserve(@student, genre: "JY")
    reserve(@other, genre: "TG")
    switch_to_semester(semesters(:semester_next))

    get admin_reservations_path(q: { genre_eq: "JY" })

    assert_select "tbody tr", count: 1
    assert_select "td", text: /#{@student.identity_label}/

    get admin_reservations_path(q: { genre_eq: "XQ" })

    assert_select "tbody tr", count: 0

    get admin_reservations_path(q: { student_name_cont: @other.name.last(2) }, status: "pending")

    assert_select "tbody tr", count: 1
    assert_select "td", text: /#{@other.identity_label}/
  end

  test "index filters out generated reservations unless asked" do
    reserve(@student, genre: "JY")
    Reservation.last.update!(semester_klass: semester_klasses(:sk_math_1))
    switch_to_semester(semesters(:semester_next))

    get admin_reservations_path(status: "pending")

    assert_select "tbody tr", count: 0

    get admin_reservations_path(status: "generated")

    assert_select "tbody tr", count: 1
    assert_select "td", text: /已生成 · #{semester_klasses(:sk_math_1).name}/
    assert_select "form[action^='#{generate_admin_reservations_path}']", count: 0
  end

  test "generate creates a next semester class and enrolls the reserved students" do
    # 学员年级与班级年级一致才可进班：须先升级到目标年级（八年级）
    @student.update!(grade: grades(:grade_8))
    @other.update!(grade: grades(:grade_8))
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
    # 分班不改动学员年级
    assert_equal grades(:grade_8), @student.reload.grade

    # 已生成的分组不再重复生成
    assert_no_difference -> { SemesterKlass.count } do
      post generate_admin_reservations_path, params: group_params("JY")
    end
    assert_match "没有待分班的预留学员", flash[:alert]
  end

  test "generate refuses when no student has been promoted to the target grade" do
    reserve(@student, genre: "JY") # 七年级学员，目标八年级，未升级

    assert_no_difference -> { SemesterKlass.count } do
      post generate_admin_reservations_path, params: group_params("JY")
    end

    assert_redirected_to admin_reservations_path
    assert_match "尚未升级", flash[:alert]
    assert Reservation.pending.exists?(student: @student)
  end

  test "generate enrolls promoted students and skips those not yet promoted" do
    @student.update!(grade: grades(:grade_8)) # 已升级
    reserve(@student, genre: "JY")
    reserve(@other, genre: "JY") # 仍为七年级

    assert_difference -> { SemesterKlass.where(semester: semesters(:semester_next)).count }, 1 do
      post generate_admin_reservations_path, params: group_params("JY")
    end

    klass = SemesterKlass.where(semester: semesters(:semester_next)).order(:id).last
    assert_equal [ @student.id ], klass.klass_students.pluck(:student_id)
    assert_match "加入 1 名预留学员", flash[:notice]
    assert_match "1 名未升级", flash[:notice]
    # 未升级学员的预留保持待分班，升级后可再次生成
    assert Reservation.pending.exists?(student: @other)
  end

  test "generate keeps the list filters" do
    @student.update!(grade: grades(:grade_8))
    reserve(@student, genre: "JY")

    post generate_admin_reservations_path, params: group_params("JY").merge(q: { genre_eq: "JY" }, status: "pending")

    assert_redirected_to admin_reservations_path(q: { genre_eq: "JY" }, status: "pending")
  end

  test "generate only moves its own group" do
    @student.update!(grade: grades(:grade_8))
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
    @student.update!(grade: grades(:grade_8))
    @other.update!(grade: grades(:grade_8))
    reserve(@student, genre: "JY", teacher: nil)
    reserve(@other, genre: "JY", teacher: nil)
    switch_to_semester(semesters(:semester_next))

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

    switch_to_semester(semesters(:semester_next))
    get admin_reservations_path

    assert_select "tbody tr", count: 1
    assert_select "td", text: /#{@student.identity_label}/

    # 升级到目标年级后才能生成进班
    @student.update!(grade: grades(:grade_8))
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

  test "index renders batch selection and shows every filter" do
    pending = reserve(@student, genre: "JY")
    generated = reserve(@other, genre: "TG")
    generated.update!(semester_klass: semester_klasses(:sk_math_1))

    switch_to_semester(semesters(:semester_next))
    get admin_reservations_path

    assert_select "input[data-reservation-select-target='rowCheckbox'][value='#{pending.id}'][data-group-key]"
    assert_select "input[data-reservation-select-target='rowCheckbox'][value='#{generated.id}']", count: 0
    assert_select "dialog#batch-enroll-modal form[action='#{batch_enroll_admin_reservations_path}']"
    assert_select "form details", count: 0
    assert_select "form select[name='q[grade_id_eq]']"
    assert_select "form select[name='q[subject_id_eq]']"
    assert_select "form select[name='q[genre_eq]']"
    assert_select "form select[name='q[teacher_id_eq]']"
    assert_select "form select[name='q[source_semester_id_eq]']", count: 0
  end

  test "index paginates reservations and keeps filters in page links" do
    26.times do |i|
      student = Student.create!(campuse: campuses(:campuse_1), name: "分页学员#{i}", grade: grades(:grade_8))
      reserve(student, genre: "JY")
    end
    switch_to_semester(semesters(:semester_next))

    get admin_reservations_path

    assert_select "nav[aria-label='预留分页']"
    assert_select "nav[aria-label='预留分页'] a[href*='page=2']"
    assert_select "tbody tr", count: 25

    get admin_reservations_path(page: 2)

    assert_select "tbody tr", count: 1
  end

  test "index renders into a turbo frame and keeps filters inside it" do
    reserve(@student, genre: "JY")
    switch_to_semester(semesters(:semester_next))

    get admin_reservations_path, headers: { "Turbo-Frame" => "reservations_content" }

    assert_response :success
    assert_select "body > turbo-frame#reservations_content", count: 1
    assert_select "turbo-frame#reservations_content form select[name='q[grade_id_eq]']"
    assert_select "turbo-frame#reservations_content input[data-reservation-select-target='rowCheckbox']"
  end

  test "batch_enroll generates one class per group and enrolls only selected students" do
    @student.update!(grade: grades(:grade_8))
    @other.update!(grade: grades(:grade_8))
    first = reserve(@student, genre: "JY")
    second = reserve(@other, genre: "JY")
    reserve(students(:student_7_3), genre: "JY")

    assert_difference -> { SemesterKlass.where(semester: semesters(:semester_next)).count }, 1 do
      post batch_enroll_admin_reservations_path, params: { mode: "generate", reservation_ids: [ first.id, second.id ] }
    end

    assert_redirected_to admin_reservations_path
    assert_match "已生成 1 个班级", flash[:notice]

    klass = SemesterKlass.where(semester: semesters(:semester_next)).order(:id).last
    assert_equal teachers(:math_teacher_1), klass.teacher
    assert_equal [ @student.id, @other.id ].sort, klass.klass_students.pluck(:student_id).sort
    assert first.reload.generated?
    assert second.reload.generated?
    assert Reservation.pending.exists?(student: students(:student_7_3))
  end

  test "batch_enroll picks a teacher for groups without one" do
    @student.update!(grade: grades(:grade_8))
    reservation = reserve(@student, genre: "JY", teacher: nil)
    key = reservation.group_key_string

    post batch_enroll_admin_reservations_path, params: {
      mode: "generate", reservation_ids: [ reservation.id ],
      groups: { key => { teacher_id: teachers(:math_teacher_2).id } }
    }

    klass = SemesterKlass.where(semester: semesters(:semester_next)).order(:id).last
    assert_equal teachers(:math_teacher_2), klass.teacher
    assert_equal teachers(:math_teacher_2), reservation.reload.teacher
  end

  test "batch_enroll applies customized class info per group" do
    reservation = reserve(@student, genre: "JY", teacher: nil)
    key = reservation.group_key_string

    post batch_enroll_admin_reservations_path, params: {
      mode: "generate", reservation_ids: [ reservation.id ],
      groups: { key => {
        grade_id: grades(:grade_7).id, genre: "TG", phase: 2,
        teacher_id: teachers(:math_teacher_2).id, times: 8
      } }
    }

    assert_redirected_to admin_reservations_path
    klass = SemesterKlass.where(semester: semesters(:semester_next)).order(:id).last
    assert_equal grades(:grade_7), klass.grade
    assert_equal "TG", klass.genre
    assert_equal 2, klass.phase
    assert_equal teachers(:math_teacher_2), klass.teacher
    assert_equal 8, klass.times
    assert_equal 8, klass.courses.count
    assert reservation.reload.generated?
  end

  test "batch_enroll refuses groups without a teacher" do
    reservation = reserve(@student, genre: "JY", teacher: nil)

    assert_no_difference -> { SemesterKlass.count } do
      post batch_enroll_admin_reservations_path, params: { mode: "generate", reservation_ids: [ reservation.id ] }
    end

    assert_match "部分分组未选择本科目的在任教师", flash[:alert]
    assert Reservation.pending.exists?(id: reservation.id)
  end

  test "batch_enroll skips a group whose students are not promoted and creates no empty class" do
    reservation = reserve(@student, genre: "JY") # 七年级，目标八年级，未升级

    assert_no_difference -> { SemesterKlass.count } do
      post batch_enroll_admin_reservations_path, params: { mode: "generate", reservation_ids: [ reservation.id ] }
    end

    assert_match "尚未升级到目标年级", flash[:alert]
    assert Reservation.pending.exists?(id: reservation.id)
  end

  test "batch_enroll joins an existing class when semester and subject match" do
    @student.update!(grade: grades(:grade_8))
    reservation = reserve(@student, genre: "JY")
    target = SemesterKlass.create!(
      campuse: campuses(:campuse_1), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      seq: 40, genre: "JY", grade: grades(:grade_8), semester: semesters(:semester_next), times: 1
    )

    post batch_enroll_admin_reservations_path, params: { mode: "join", reservation_ids: [ reservation.id ], klass_id: target.id }

    assert_redirected_to admin_reservations_path
    assert_match "已将 1 名学员加入班级", flash[:notice]
    assert_equal [ @student.id ], target.klass_students.pluck(:student_id)
    assert_equal target, reservation.reload.semester_klass
  end

  test "batch_enroll refuses to join a class whose grade differs from the reservation target" do
    reservation = reserve(@student, genre: "JY") # 目标八年级
    target = SemesterKlass.create!(
      campuse: campuses(:campuse_1), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      seq: 42, genre: "JY", grade: grades(:grade_7), semester: semesters(:semester_next), times: 1
    )

    assert_no_difference -> { KlassStudent.count } do
      post batch_enroll_admin_reservations_path, params: { mode: "join", reservation_ids: [ reservation.id ], klass_id: target.id }
    end

    assert_match "同一目标学期、科目与年级", flash[:alert]
    assert_nil reservation.reload.semester_klass
  end

  test "batch_enroll skips a student not yet promoted even when the class grade matches the target" do
    reservation = reserve(@student, genre: "JY") # 目标八年级，学员仍七年级未升级
    target = SemesterKlass.create!(
      campuse: campuses(:campuse_1), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      seq: 43, genre: "JY", grade: grades(:grade_8), semester: semesters(:semester_next), times: 1
    )

    assert_no_difference -> { KlassStudent.count } do
      post batch_enroll_admin_reservations_path, params: { mode: "join", reservation_ids: [ reservation.id ], klass_id: target.id }
    end

    assert_match "已将 0 名学员加入班级", flash[:notice]
    assert_match "1 名年级与班级不符", flash[:notice]
    assert Reservation.pending.exists?(id: reservation.id)
  end

  test "batch_enroll rejects joining a class from another semester" do
    reservation = reserve(@student, genre: "JY")
    target = SemesterKlass.create!(
      campuse: campuses(:campuse_1), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      seq: 41, genre: "TG", grade: grades(:grade_7), semester: semesters(:semester_current), times: 1
    )

    assert_no_difference -> { KlassStudent.count } do
      post batch_enroll_admin_reservations_path, params: { mode: "join", reservation_ids: [ reservation.id ], klass_id: target.id }
    end

    assert_match "同一目标学期、科目与年级", flash[:alert]
    assert_nil reservation.reload.semester_klass
  end

  test "batch_enroll ignores reservations outside the manager's grades" do
    sign_in_as users(:two)
    hidden = SemesterKlass.create!(
      campuse: campuses(:campuse_1), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      seq: 93, genre: "TG", grade: grades(:grade_7), semester: semesters(:semester_current), times: 1
    )
    reservation = Reservation.create!(
      student: @other, semester: semesters(:semester_next), subject: subjects(:math), grade: grades(:grade_7),
      teacher: teachers(:math_teacher_1), genre: "JY", source_semester: hidden.semester, source_semester_klass: hidden
    )

    assert_no_difference -> { SemesterKlass.where(semester: semesters(:semester_next)).count } do
      post batch_enroll_admin_reservations_path, params: { mode: "generate", reservation_ids: [ reservation.id ] }
    end

    assert_match "请先选择待分班的预留学员", flash[:alert]
    assert Reservation.pending.exists?(id: reservation.id)
  end
end
