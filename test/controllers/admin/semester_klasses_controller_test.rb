require "test_helper"
require "stringio"
require "zip"

class Admin::SemesterKlassesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index lists current semester classes grouped by grade" do
    get admin_semester_klasses_path

    assert_response :success
    assert_select "h1", text: "班级管理"
    assert_select "h2", text: "七年级"
    assert_select "a[href='#{admin_semester_klass_path(semester_klasses(:sk_math_2))}']", count: 1
    assert_select "a[href='#{export_attendances_admin_semester_klasses_path}']", text: /导出考勤/
    assert_select "a[href='#{admin_semester_klass_path(semester_klasses(:sk_math_1))}']", count: 0
  end

  test "statement renders summary cards and per-class rates" do
    get statement_admin_semester_klasses_path

    assert_response :success
    assert_select "h1", text: "班级报表"
    assert_select "th", text: "新增率"
    assert_select "th", text: "拓科率"
    assert_select "th", text: "预留率"
    assert_select "tbody tr", count: SemesterKlass.where(campuse_id: campuses(:campuse_1).id).count
    assert_select "h3", text: /学员构成/, count: SemesterKlass.where(campuse_id: campuses(:campuse_1).id).count
    assert_select "a[href*='export_statement']", text: /导出报表/
  end

  test "show queries do not scale with students and courses" do
    sk = semester_klasses(:sk_math_2)
    course = sk.courses.find_by!(seq: 1)
    course.update!(start_date: Date.current)
    sk.klass_students.each { |klass_student| course.attendances.create!(klass_student: klass_student, status: "normal") }

    baseline = count_queries { get admin_semester_klass_path(sk) }
    assert_response :success

    [ students(:student_7_2), students(:student_7_3) ].each do |student|
      KlassStudent.create!(semester_klass: sk, student: student, status: "in")
    end

    3.times do |index|
      extra_course = sk.courses.create!(seq: index + 17, start_date: Date.current)
      sk.klass_students.reload.each do |klass_student|
        extra_course.attendances.create!(klass_student: klass_student, status: "normal")
      end
    end

    expanded = count_queries { get admin_semester_klass_path(sk) }
    assert_response :success
    assert_operator expanded - baseline, :<=, 4, "新增学员或课次不应带来按行查询"
  end

  test "show renders the attendance status actions in a single row" do
    sk = semester_klasses(:sk_math_2)
    course = sk.courses.find_by!(seq: 1)
    course.update!(start_date: Date.current)
    course.attendances.create!(klass_student: klass_students(:ks_2), status: "normal")

    get admin_semester_klass_path(sk)

    assert_response :success
    # 缺课 / 事假 / 病假 三项排在同一行，退课 / 转出仍为两列
    assert_select "[data-floating-card-target='card'] .grid.grid-cols-3", count: 1
    assert_select "[data-floating-card-target='card'] .grid.grid-cols-2", count: 1
    card = Nokogiri::HTML(response.body).at_css("[data-floating-card-target='card']")
    assert_includes card.text, "正常"
    assert_includes card.text, "缺课"
    assert_includes card.text, "事假"
    assert_includes card.text, "病假"
    assert_includes card.text, "转出"
    assert_select "[data-action='transfer-drawer#open']", text: "转出"
    assert_select "#drawer-transfer"
    assert_select "input[type='radio'][name='target_semester_klass_id'][value='#{semester_klasses(:sk_math_3).id}']"
    assert_select "[data-controller='student-multiselect'] input[data-student-multiselect-target='input']", minimum: 1
    assert_select "input#insert_#{course.id}_student_#{students(:student_7_2).id}"
  end

  test "transfer drawer exposes enrolled class ids and filters" do
    sk = semester_klasses(:sk_math_2)
    target = semester_klasses(:sk_math_3)
    KlassStudent.create!(semester_klass: target, student: students(:student_7_1), status: "in")
    course = sk.courses.find_by!(seq: 1)
    course.update!(start_date: Date.current)
    course.attendances.create!(klass_student: klass_students(:ks_2), status: "normal")

    get admin_semester_klass_path(sk)

    assert_response :success
    button = Nokogiri::HTML(response.body).at_css("button[data-transfer-url]")
    assert_includes button["data-transfer-class-ids"].split(","), target.id.to_s
    assert_equal sk.subject_id.to_s, button["data-transfer-subject-id"]
    assert_select "select#transfer_subject_filter"
    assert_select "select#transfer_genre_filter"
    assert_select "label[data-transfer-drawer-target='option'][data-class-id='#{target.id}'][data-subject-id='#{target.subject_id}']"
  end

  test "show lets a student on leave still quit or transfer" do
    sk = semester_klasses(:sk_math_2)
    course = sk.courses.find_by!(seq: 1)
    course.update!(start_date: Date.current)
    course.attendances.create!(klass_student: klass_students(:ks_2), status: "personal_leave")

    get admin_semester_klass_path(sk)

    assert_response :success
    card = Nokogiri::HTML(response.body).at_css("[data-floating-card-target='card']")
    assert_includes card.text, "补课销假"
    assert_includes card.text, "退课"
    assert_includes card.text, "转出"
  end

  test "statement keeps the filter selections after searching" do
    get statement_admin_semester_klasses_path(q: {
      semester_id_eq: semesters(:semester_previous).id,
      grade_id_eq: grades(:grade_7).id,
      subject_id_eq: subjects(:math).id,
      teacher_id_eq: teachers(:math_teacher_1).id,
      genre_eq: "TG"
    })

    assert_response :success
    assert_select "select[name='q[semester_id_eq]'] option[selected][value='#{semesters(:semester_previous).id}']"
    assert_select "select[name='q[grade_id_eq]'] option[selected][value='#{grades(:grade_7).id}']"
    assert_select "select[name='q[subject_id_eq]'] option[selected][value='#{subjects(:math).id}']"
    assert_select "select[name='q[teacher_id_eq]'] option[selected][value='#{teachers(:math_teacher_1).id}']"
    assert_select "select[name='q[genre_eq]'] option[selected][value='TG']"
    assert_select "a[href*='export_statement'][href*='grade_id_eq']"
  end

  test "copy keeps the semester filter after searching" do
    get copy_admin_semester_klasses_path(q: { semester_id_eq: semesters(:semester_previous).id })

    assert_response :success
    assert_select "select[name='q[semester_id_eq]'] option[selected][value='#{semesters(:semester_previous).id}']"
  end

  test "exports the statement as xlsx" do
    get export_statement_admin_semester_klasses_path

    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])

    workbook = Zip::File.open_buffer(StringIO.new(response.body))
    strings = workbook.read("xl/sharedStrings.xml").force_encoding("UTF-8")
    assert_includes strings, "班级报表"
    assert_includes strings, "新增率(%)"
    assert_includes strings, "拓科率(%)"
    assert_includes strings, "预留率(%)"
    assert_includes strings, semester_klasses(:sk_math_2).name
    assert_includes strings, "筛选条件：全部班级"
    assert_includes strings, "学员明细"
    assert_includes strings, "类型"
    assert_includes strings, "说明"
  end

  test "exports only the filtered classes" do
    grade_8_klass = SemesterKlass.create!(
      campuse: campuses(:campuse_1),
      semester: semesters(:semester_current),
      grade: grades(:grade_8),
      subject: subjects(:math),
      teacher: teachers(:math_teacher_1),
      genre: "TG",
      seq: 1,
      times: 2
    )

    get export_statement_admin_semester_klasses_path(q: { grade_id_eq: grades(:grade_7).id })

    assert_response :success
    workbook = Zip::File.open_buffer(StringIO.new(response.body))
    strings = workbook.read("xl/sharedStrings.xml").force_encoding("UTF-8")
    assert_includes strings, "年级：七年级"
    assert_not_includes strings, grade_8_klass.name
  end

  test "show renders the class menu with the current class active" do
    sk = semester_klasses(:sk_math_2)
    get admin_semester_klass_path(sk)

    assert_response :success
    assert_select "a.menu-active[aria-current='page']", text: /#{sk.name}/
    assert_select "a[href='#{export_attendance_admin_semester_klass_path(sk)}']", text: /导出考勤/
    assert_select "[data-turbo-confirm*='历史考勤会保留']"
    assert_select "summary", text: /七年级/
    assert_select "summary", text: /数学/
    # 同年级同科目下的其他班级也出现在菜单里，便于切换
    assert_select "a[href='#{admin_semester_klass_path(semester_klasses(:sk_math_3))}']"
  end

  test "exports one attendance sheet per class in a single workbook" do
    grade_8_klass = SemesterKlass.create!(
      campuse: campuses(:campuse_1),
      semester: semesters(:semester_current),
      grade: grades(:grade_8),
      subject: subjects(:math),
      teacher: teachers(:math_teacher_1),
      genre: "TG",
      seq: 1,
      times: 2
    )

    get export_attendances_admin_semester_klasses_path

    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert response.body.start_with?("PK")

    workbook = Zip::File.open_buffer(StringIO.new(response.body))
    sheets = workbook.read("xl/workbook.xml").force_encoding("UTF-8")
    assert_includes sheets, "七年级-#{semester_klasses(:sk_math_2).name}"
    assert_includes sheets, "八年级-#{grade_8_klass.name}"

    strings = workbook.read("xl/sharedStrings.xml").force_encoding("UTF-8")
    assert_includes strings, "学员"
    assert_includes strings, semester_klasses(:sk_math_2).klass_students.first.student.name
  end

  test "exports the attendance sheet as xlsx" do
    sk = semester_klasses(:sk_math_2)
    get export_attendance_admin_semester_klass_path(sk)

    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert response.body.start_with?("PK")

    workbook = Zip::File.open_buffer(StringIO.new(response.body))
    strings = workbook.read("xl/sharedStrings.xml").force_encoding("UTF-8")
    assert_includes strings, sk.name
    assert_includes strings, sk.klass_students.first.student.name
    assert_includes strings, "学员"
  end

  test "cannot export a class outside the current semester" do
    get export_attendance_admin_semester_klass_path(semester_klasses(:sk_math_1))

    assert_response :not_found
  end

  test "copy lists historical classes with their source details" do
    get copy_admin_semester_klasses_path

    assert_response :success
    assert_select "h1", text: "复制班级"
    assert_select "tbody tr", count: 2
    assert_select "a[href*='target_semester_id=#{semesters(:semester_next).id}']", text: /复制到/
    assert_select "td", text: /#{semester_klasses(:sk_math_1).name}/
    assert_select "th", text: "在读"
    assert_select "td", text: "1 人", minimum: 1
    assert_select "label.btn", text: "详情", count: 2
    assert_select "h3", text: "历史班级详情", count: 2
    assert_select "label.btn", text: "复制", count: 2
    # 复制表单应带上历史班级的班型与年级，而不是留空
    assert_select "select[name='semester_klass[genre]'] option[selected][value='TG']", count: 2
    assert_select "select[name='semester_klass[grade_id]'] option[selected][value='7']", count: 2
    assert_select "input[type='checkbox'][name='student_ids[]']", minimum: 1
    assert_select "input[name='student_ids[]'][checked][value='#{students(:student_7_1).id}']"
    assert_select "[data-controller='student-multiselect'] input[data-student-multiselect-target='input']", minimum: 1
    assert_select "input#copy_#{semester_klasses(:sk_math_1).id}_student_#{students(:student_7_2).id}"
  end

  test "copy can target a future semester and includes current classes" do
    next_semester = semesters(:semester_next)
    get copy_admin_semester_klasses_path(target_semester_id: next_semester.id, q: { genre_eq: "TG" })

    assert_response :success
    assert_select "tbody tr", count: 4
    assert_select "td", text: /#{semester_klasses(:sk_math_2).name}/
    assert_select "input[name='target_semester_id'][value='#{next_semester.id}']"
    assert_select "select[name='q[genre_eq]'] option[selected][value='TG']"
    assert_select "span.badge", text: next_semester.name, minimum: 1
  end

  test "copy_create can copy a class into a future semester" do
    next_semester = semesters(:semester_next)

    assert_difference -> { SemesterKlass.count }, 1 do
      post copy_create_admin_semester_klasses_path, params: {
        target_semester_id: next_semester.id,
        student_ids: [ students(:student_7_2).id ],
        semester_klass: {
          grade_id: grades(:grade_7).id,
          teacher_id: teachers(:math_teacher_1).id,
          genre: "JY", seq: 88, times: 2
        }
      }
    end

    sk = SemesterKlass.order(:id).last
    assert_equal next_semester.id, sk.semester_id
    assert sk.klass_students.exists?(student_id: students(:student_7_2).id)
    assert_redirected_to copy_admin_semester_klasses_path(target_semester_id: next_semester.id)
  end

  private
    def count_queries
      queries = 0
      test_thread = Thread.current
      callback = ->(_name, _start, _finish, _id, payload) {
        if Thread.current == test_thread && !payload[:name].in?([ "SCHEMA", "TRANSACTION" ])
          queries += 1
        end
      }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
      queries
    end

  public

  test "create adds selected students from the chosen lesson" do
    assert_difference -> { KlassStudent.count }, 1 do
      post admin_semester_klasses_path, params: {
        student_ids: [ students(:student_7_4).id ],
        join_course_seq: 2,
        semester_klass: {
          semester_id: semesters(:semester_current).id,
          grade_id: grades(:grade_7).id,
          teacher_id: teachers(:math_teacher_1).id,
          campuse_id: campuses(:campuse_1).id,
          genre: "JY", seq: 55, times: 3
        }
      }
    end

    sk = SemesterKlass.order(:id).last
    ks = sk.klass_students.find_by!(student_id: students(:student_7_4).id)
    assert_equal "absent", sk.courses.find_by!(seq: 1).attendances.find_by!(klass_student: ks).status
  end

  test "index renders the student picker for the new class form" do
    get admin_semester_klasses_path

    assert_response :success
    assert_select "[data-controller='student-multiselect'][data-student-multiselect-grade-selector-value='#klass_new_grade_id']"
    assert_select "input[type='search'][data-student-multiselect-target='input']"
    assert_select "input[name='join_course_seq'][value='1']"
    assert_select "input#klass_new_student_#{students(:student_7_4).id}"
    assert_select "textarea[name='semester_klass[students_text]']", count: 0
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

  test "create always uses the current campus and semester" do
    other_campuse = Campuse.create!(name: "其他校区", school: schools(:school_1))
    other_semester = School.find(schools(:school_1).id).semesters.create!(
      name: "其他学期", start_date: Date.current + 1.year, end_date: Date.current + 1.year + 1.month, seq: 88
    )

    assert_difference -> { SemesterKlass.count }, 1 do
      post admin_semester_klasses_path, params: { semester_klass: {
        semester_id: other_semester.id,
        campuse_id: other_campuse.id,
        grade_id: grades(:grade_7).id,
        teacher_id: teachers(:math_teacher_1).id,
        genre: "JY", seq: 98, times: 1, students_text: ""
      } }
    end

    created = SemesterKlass.find_by!(genre: "JY", seq: 98)
    assert_equal campuses(:campuse_1), created.campuse
    assert_equal semesters(:semester_current), created.semester
  end

  test "manager only sees classes in authorized grades" do
    sign_in_as users(:two)

    get admin_semester_klasses_path
    assert_response :success
    assert_select "a[href='#{admin_semester_klass_path(semester_klasses(:sk_math_2))}']", count: 0

    get admin_semester_klass_path(semester_klasses(:sk_math_2))
    assert_response :not_found
  end

  test "manager cannot create a class in an unauthorized grade" do
    sign_in_as users(:two)

    assert_no_difference -> { SemesterKlass.count } do
      post admin_semester_klasses_path, params: { semester_klass: {
        grade_id: grades(:grade_7).id,
        teacher_id: teachers(:math_teacher_1).id,
        genre: "JY", seq: 97, times: 1, students_text: ""
      } }
    end

    assert_redirected_to admin_semester_klasses_path
    assert_match "无权操作该年级", flash[:alert]
  end

  test "cannot view a class from another campus" do
    other_campuse = Campuse.create!(name: "其他校区", school: schools(:school_1))
    sk = SemesterKlass.create!(
      campuse: other_campuse, semester: semesters(:semester_current),
      grade: grades(:grade_7), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      genre: "TG", seq: 9, times: 1
    )

    get admin_semester_klass_path(sk)

    assert_response :not_found
  end

  test "create with a duplicate class redirects with an alert" do
    sk = semester_klasses(:sk_math_2)

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

  test "update adds selected students from the chosen lesson" do
    sk = semester_klasses(:sk_math_2)

    assert_difference -> { sk.klass_students.count }, 1 do
      put admin_semester_klass_path(sk), params: {
        student_ids: [ students(:student_7_3).id ],
        join_course_seq: 1,
        semester_klass: { genre: sk.genre, seq: sk.seq, times: sk.times, teacher_id: sk.teacher_id, students_text: "" }
      }
    end

    assert sk.klass_students.exists?(student_id: students(:student_7_3).id)
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
      post copy_create_admin_semester_klasses_path, params: {
        student_ids: [ students(:student_7_1).id ],
        semester_klass: {
          grade_id: grades(:grade_7).id,
          teacher_id: teachers(:math_teacher_1).id,
          genre: "JY", seq: 88, times: 2
        }
      }
    end

    sk = SemesterKlass.last
    assert_redirected_to admin_semester_klass_path(sk)
    assert_equal semesters(:semester_current).id, sk.semester_id
    assert_equal campuses(:campuse_1).id, sk.campuse_id
    assert_equal subjects(:math).id, sk.subject_id
    assert_equal 2, sk.courses.count
  end
end
