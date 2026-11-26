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

  test "index shows the reserve rate on class cards" do
    sk = semester_klasses(:sk_math_2)
    next_klass = SemesterKlass.create!(
      semester: semesters(:semester_next), campuse: campuses(:campuse_1),
      grade: grades(:grade_7), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      genre: "TG", seq: 9, times: 1
    )
    students(:student_7_1).join_klass(next_klass)

    get admin_semester_klasses_path

    assert_response :success
    assert_select "a[href='#{admin_semester_klass_path(sk)}']", text: /预留率\s*100\.0%/
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
  end

  test "reserve enrolls selected students into an existing next semester class" do
    sk = semester_klasses(:sk_math_2)
    student = students(:student_7_1)
    target = SemesterKlass.create!(
      semester: semesters(:semester_next), campuse: campuses(:campuse_1),
      grade: grades(:grade_7), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      genre: "JY", seq: 1, times: 2
    )

    assert_difference -> { KlassStudent.count }, 1 do
      post reserve_admin_semester_klass_path(sk), params: {
        target_semester_klass_id: target.id, student_ids: [ student.id ]
      }
    end

    assert_redirected_to admin_semester_klass_path(sk)
    assert_match "已预留 1 名", flash[:notice]
    assert target.klass_students.exists?(student_id: student.id)
  end

  test "reserve creates a new next semester class when requested" do
    sk = semester_klasses(:sk_math_2)
    student = students(:student_7_1)

    assert_difference -> { SemesterKlass.where(semester: semesters(:semester_next)).count }, 1 do
      post reserve_admin_semester_klass_path(sk), params: {
        target_semester_klass_id: "", student_ids: [ student.id ],
        new_grade_id: grades(:grade_7).id, new_genre: "JY",
        new_teacher_id: teachers(:math_teacher_1).id, new_times: 8
      }
    end

    created = SemesterKlass.where(semester: semesters(:semester_next)).order(:id).last
    assert_equal grades(:grade_7), created.grade
    assert_equal "JY", created.genre
    assert_equal 8, created.times
    assert created.klass_students.exists?(student_id: student.id)
    assert_redirected_to admin_semester_klass_path(sk)
  end

  test "reserve can target the next grade without changing the student grade" do
    sk = semester_klasses(:sk_math_2)
    student = students(:student_7_1)
    target = SemesterKlass.create!(
      semester: semesters(:semester_next), campuse: campuses(:campuse_1),
      grade: grades(:grade_8), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      genre: "JY", seq: 1, times: 2
    )

    post reserve_admin_semester_klass_path(sk), params: {
      target_semester_klass_id: target.id, student_ids: [ student.id ]
    }

    assert_equal grades(:grade_7), student.reload.grade
    assert target.klass_students.exists?(student_id: student.id)
    assert_match "已预留 1 名", flash[:notice]
  end

  test "reserve requires selected students and does not create a target" do
    sk = semester_klasses(:sk_math_2)

    assert_no_difference -> { SemesterKlass.count } do
      post reserve_admin_semester_klass_path(sk), params: {
        target_semester_klass_id: "", student_ids: [ "" ],
        new_grade_id: grades(:grade_7).id, new_genre: "JY",
        new_teacher_id: teachers(:math_teacher_1).id, new_times: 8
      }
    end

    assert_redirected_to admin_semester_klass_path(sk)
    assert_match "请选择要预留的学员", flash[:alert]
  end

  test "reserve requires a next semester" do
    sk = SemesterKlass.create!(
      semester: semesters(:semester_next), campuse: campuses(:campuse_1),
      grade: grades(:grade_7), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      genre: "TG", seq: 7, times: 1
    )
    KlassStudent.create!(semester_klass: sk, student: students(:student_7_1), status: "in")
    # 班级属于下学期，先切到该学期再操作
    get switch_thread_semester_admin_school_semester_path(schools(:school_1), semesters(:semester_next))

    post reserve_admin_semester_klass_path(sk), params: { student_ids: [ students(:student_7_1).id ] }

    assert_redirected_to admin_semester_klass_path(sk)
    assert_match "下学期尚未创建", flash[:alert]
  end

  test "reserve ignores a target from another subject" do
    sk = semester_klasses(:sk_math_2)
    student = students(:student_7_1)
    target = SemesterKlass.create!(
      semester: semesters(:semester_next), campuse: campuses(:campuse_1),
      grade: grades(:grade_7), subject: subjects(:eng), teacher: teachers(:eng_teacher_1),
      genre: "TG", seq: 1, times: 1
    )

    post reserve_admin_semester_klass_path(sk), params: {
      target_semester_klass_id: target.id, student_ids: [ student.id ]
    }

    assert_redirected_to admin_semester_klass_path(sk)
    assert_match "请选择目标班级", flash[:alert]
    assert_not target.klass_students.exists?(student_id: student.id)
  end

  test "show renders the reserve drawer with next semester targets" do
    sk = semester_klasses(:sk_math_2)
    target = SemesterKlass.create!(
      semester: semesters(:semester_next), campuse: campuses(:campuse_1),
      grade: grades(:grade_7), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      genre: "JY", seq: 1, times: 2
    )

    get admin_semester_klass_path(sk)

    assert_response :success
    assert_select "input#drawer-reserve"
    assert_select "form[action='#{reserve_admin_semester_klass_path(sk)}']"
    assert_select "input[type='radio'][name='target_semester_klass_id'][value='#{target.id}']"
    assert_select "input[type='radio'][name='target_semester_klass_id'][value='']"
    assert_select "input[type='checkbox'][name='student_ids[]']"
    assert_select "select[name='new_grade_id']"
    assert_select "select[name='new_genre']"
    assert_select "select[name='new_teacher_id']"
    assert_select "input[name='new_times']"
  end

  test "show offers the copy drawer targeting the next semester" do
    sk = semester_klasses(:sk_math_2)
    next_semester = semesters(:semester_next)

    get admin_semester_klass_path(sk)

    assert_response :success
    assert_select "input#drawer-copy"
    assert_select "form[action='#{copy_create_admin_semester_klasses_path}'] input[name='target_semester_id'][value='#{next_semester.id}']"
    assert_select "form[action='#{copy_create_admin_semester_klasses_path}'] input[name='return_klass_id'][value='#{sk.id}']"
    assert_select "select[name='semester_klass[genre]'] option[selected][value='#{sk.genre}']"
    assert_select "input[type='checkbox'][name='student_ids[]'][checked][value='#{students(:student_7_1).id}']"
  end

  test "copy_create returns to the source class when requested" do
    source = semester_klasses(:sk_math_2)
    next_semester = semesters(:semester_next)

    assert_difference -> { SemesterKlass.count }, 1 do
      post copy_create_admin_semester_klasses_path, params: {
        target_semester_id: next_semester.id,
        return_klass_id: source.id,
        student_ids: [ students(:student_7_1).id ],
        semester_klass: {
          grade_id: grades(:grade_7).id,
          teacher_id: teachers(:math_teacher_1).id,
          genre: "JY", seq: 88, times: 2
        }
      }
    end

    assert_redirected_to admin_semester_klass_path(source)
  end

  test "class form only lists teachers from the current campus" do
    other_campuse = Campuse.create!(name: "其他校区", school: schools(:school_1))
    other_teacher = Teacher.create!(name: "外校老师", campuse: other_campuse, subject: subjects(:math))

    get admin_semester_klasses_path

    assert_response :success
    assert_select "select[data-klass-times-target='teacher'] option[value='#{other_teacher.id}']", count: 0
    assert_select "select[data-klass-times-target='teacher'] option[value='#{teachers(:math_teacher_1).id}']"
  end

  test "show keeps the student removal action inside the name column" do
    sk = semester_klasses(:sk_math_2)
    ks = klass_students(:ks_2)

    get admin_semester_klass_path(sk)

    assert_response :success
    assert_select "thead th", text: "操作", count: 0
    assert_select "tbody tr th .student-row-actions form[action='#{admin_semester_klass_klass_student_path(sk, ks)}']"
    assert_select ".student-row-actions.opacity-0", count: 0
  end

  test "class form quick adds students inline without a modal" do
    get admin_semester_klasses_path

    assert_response :success
    assert_select "[data-controller='student-multiselect'][data-student-multiselect-quick-add-url-value='#{quick_create_admin_students_path}']"
    assert_select "[data-student-multiselect-target='quickAdd']", text: "快速添加学员"
    assert_select "dialog#quick-student-modal", count: 0
  end

  test "class form exposes grade subject times for auto-fill" do
    get admin_semester_klasses_path

    assert_response :success
    assert_select "form[data-controller='klass-times']"
    assert_select "select[data-klass-times-target='grade'][data-action='change->klass-times#apply']"
    assert_select "select[name='semester_klass[phase]'] option[selected][value='1']", text: "第一阶段"
    assert_select "select[data-klass-times-target='teacher'][data-action='change->klass-times#apply']"
    assert_select "input[data-klass-times-target='times']"

    form = Nokogiri::HTML(response.body).at_css("form[data-controller='klass-times']")
    times = JSON.parse(form["data-klass-times-times-value"])
    assert_equal 16, times["7-1"]
  end

  test "show only offers the first unstarted course to start" do
    sk = semester_klasses(:sk_math_2)
    first = sk.courses.find_by!(seq: 1)
    second = sk.courses.find_by!(seq: 2)

    get admin_semester_klass_path(sk)

    assert_response :success
    assert_select "form[action='#{start_admin_semester_klass_course_path(sk, first)}'] button", text: "开第 1 课"
    assert_select "form[action='#{start_admin_semester_klass_course_path(sk, second)}'] button", count: 0
    assert_select "thead th", text: /未开课/, minimum: 1
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

  test "show lists quit and transferred students with a reinstate action" do
    sk = semester_klasses(:sk_math_2)
    ks = klass_students(:ks_2)
    course = sk.courses.find_by!(seq: 1)
    course.update!(start_date: Date.current)
    attendance = course.attendances.create!(klass_student: ks, status: "normal")
    attendance.mark_quit!

    get admin_semester_klass_path(sk)

    assert_response :success
    assert_select "summary", text: /转出 \/ 退课学员 1 人/
    assert_select "li", text: /第 1 课起/
    assert_select "form[action='#{reinstate_admin_semester_klass_klass_student_path(sk, ks)}'] button", text: "撤销"
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

  test "show disables transfer when the class has no target class" do
    sk = SemesterKlass.create!(
      semester: semesters(:semester_current), campuse: campuses(:campuse_1),
      grade: grades(:grade_9), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      genre: "TG", seq: 9, times: 1
    )
    ks = KlassStudent.create!(semester_klass: sk, student: students(:student_9_1), status: "in")
    course = sk.courses.find_by!(seq: 1)
    course.update!(start_date: Date.current)
    course.attendances.create!(klass_student: ks, status: "normal")

    get admin_semester_klass_path(sk)

    assert_response :success
    assert_select "button[disabled][title*='暂无可转入的班级']", text: "转出"
    assert_select "form[action*='status=transfer']", count: 0
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

  test "show offers an open class entry next to the class actions" do
    sk = semester_klasses(:sk_math_2)

    get admin_semester_klass_path(sk)

    assert_response :success
    assert_select "label[for='drawer-klass-new'].drawer-button", text: "开班"
    assert_select "#drawer-klass-new"
    assert_select "form[action='#{admin_semester_klasses_path}'][method='post'] select[name='semester_klass[phase]']"
  end

  test "show offers a delete button until the class starts courses" do
    sk = semester_klasses(:sk_math_3)

    get admin_semester_klass_path(sk)

    assert_response :success
    assert_select "a[href='#{export_attendance_admin_semester_klass_path(sk)}']", text: /导出考勤/
    assert_select "form[action='#{admin_semester_klass_path(sk)}'] input[name='_method'][value='delete']"
    assert_select "button[data-turbo-confirm*='确定删除班级']", text: "删除班级"
  end

  test "show disables delete once a course has started" do
    sk = semester_klasses(:sk_math_2)
    sk.courses.find_by!(seq: 1).start!

    get admin_semester_klass_path(sk)

    assert_response :success
    assert_select "span.btn-disabled[title*='不能删除']", text: "删除班级"
    assert_select "form[action='#{admin_semester_klass_path(sk)}'] input[name='_method'][value='delete']", count: 0
  end

  test "destroy removes an unstarted class together with its enrollments" do
    sk = semester_klasses(:sk_math_2)
    assert sk.all_klass_students.exists?

    assert_difference -> { SemesterKlass.count }, -1 do
      assert_difference -> { KlassStudent.unscoped.count }, -1 do
        delete admin_semester_klass_path(sk)
      end
    end

    assert_redirected_to admin_semester_klasses_path
    assert_match "已删除班级", flash[:notice]
    assert_equal 0, Course.where(semester_klass_id: sk.id).count
  end

  test "destroy refuses a class that already has started courses" do
    sk = semester_klasses(:sk_math_2)
    sk.courses.find_by!(seq: 1).start!

    assert_no_difference -> { SemesterKlass.count } do
      delete admin_semester_klass_path(sk)
    end

    assert_redirected_to admin_semester_klass_path(sk)
    assert_match "不能删除", flash[:alert]
  end

  test "transfer drawer orders target classes by phase, genre and seq" do
    sk = semester_klasses(:sk_math_2)
    SemesterKlass.create!(
      semester: sk.semester, campuse: sk.campuse, grade: sk.grade, subject: sk.subject,
      teacher: sk.teacher, genre: "JY", seq: 1, times: 2, phase: 1
    )
    SemesterKlass.create!(
      semester: sk.semester, campuse: sk.campuse, grade: sk.grade, subject: sk.subject,
      teacher: sk.teacher, genre: "JY", seq: 1, times: 2, phase: 2
    )

    get admin_semester_klass_path(sk)

    assert_response :success
    names = Nokogiri::HTML(response.body)
      .css("label[data-transfer-drawer-target='option'] > span > span:first-child")
      .map { |span| span.text.strip }
    # 一期：提高班在前、精英班在后；二期整体排在一期之后
    assert_equal [ "一期7数提3", "一期7数精1", "二期7数精1" ], names.select { |name| name.match?(/\A(一期|二期)7数/) }
  end

  test "class menu orders classes by phase, genre and seq" do
    sk = semester_klasses(:sk_math_2)
    SemesterKlass.create!(
      semester: sk.semester, campuse: sk.campuse, grade: sk.grade, subject: sk.subject,
      teacher: sk.teacher, genre: "JY", seq: 1, times: 2, phase: 2
    )

    get admin_semester_klass_path(sk)

    assert_response :success
    names = Nokogiri::HTML(response.body).css("ul.menu a > span:first-child").map { |span| span.text.strip }
    assert_equal [ "一期7数提2", "一期7数提3", "二期7数精1" ], names.select { |name| name.match?(/\A(一期|二期)7数/) }
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
    assert_select "[data-controller='student-multiselect'][data-student-multiselect-grade-selector-value='#klass_new_semester_klass_grade_id']"
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
        genre: "JY", seq: 99, times: 3
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
        genre: "JY", seq: 98, times: 1
      } }
    end

    created = SemesterKlass.order(:id).last
    assert_equal "JY", created.genre
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
        genre: "JY", seq: 97, times: 1
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

  test "create falls back to the configured times when blank" do
    grade_subjects(:one).update!(times: 20)

    post admin_semester_klasses_path, params: { semester_klass: {
      semester_id: semesters(:semester_current).id,
      grade_id: grades(:grade_7).id,
      teacher_id: teachers(:math_teacher_1).id,
      campuse_id: campuses(:campuse_1).id,
      genre: "JY", seq: 1, times: ""
    } }

    assert_equal 20, SemesterKlass.order(:id).last.times
  end

  test "create assigns the next seq when the combo already exists" do
    sk = semester_klasses(:sk_math_2)

    assert_difference -> { SemesterKlass.count }, 1 do
      post admin_semester_klasses_path, params: { semester_klass: {
        semester_id: sk.semester_id, grade_id: sk.grade_id,
        teacher_id: sk.teacher_id, campuse_id: sk.campuse_id,
        genre: sk.genre, seq: sk.seq, times: 3
      } }
    end

    created = SemesterKlass.order(:id).last
    assert_equal 5, created.seq
    assert_equal "一期7数提5", created.name
    assert_redirected_to admin_semester_klass_path(created)
  end

  test "create allows the same class combination in the other phase" do
    source = semester_klasses(:sk_math_2)

    assert_difference -> { SemesterKlass.count }, 1 do
      post admin_semester_klasses_path, params: { semester_klass: {
        semester_id: source.semester_id, grade_id: source.grade_id,
        teacher_id: source.teacher_id, campuse_id: source.campuse_id,
        genre: source.genre, times: 3, phase: 2
      } }
    end

    created = SemesterKlass.order(:id).last
    assert_equal 2, created.phase
    assert_equal "二期7数提1", created.name
    assert_redirected_to admin_semester_klass_path(created)
  end

  test "update adds selected students from the chosen lesson" do
    sk = semester_klasses(:sk_math_2)

    assert_difference -> { sk.klass_students.count }, 1 do
      put admin_semester_klass_path(sk), params: {
        student_ids: [ students(:student_7_3).id ],
        join_course_seq: 4,
        semester_klass: { genre: sk.genre, seq: sk.seq, times: sk.times, teacher_id: sk.teacher_id }
      }
    end

    ks = sk.klass_students.find_by!(student_id: students(:student_7_3).id)
    # 第 4 课入班：之前的课次补记缺课，第 4 课尚未开课不生成考勤
    assert_equal "absent", sk.courses.find_by!(seq: 1).attendances.find_by!(klass_student_id: ks.id).status
    assert_nil sk.courses.find_by!(seq: 4).attendances.find_by(klass_student_id: ks.id)
  end

  test "update" do
    sk = semester_klasses(:sk_math_2)

    put admin_semester_klass_path(sk), params: { semester_klass: {
      genre: "JY", seq: 42, times: 5,
      teacher_id: teachers(:math_teacher_1).id
    } }

    assert_redirected_to admin_semester_klass_path(sk)
    assert_equal "JY", sk.reload.genre
    assert_equal 42, sk.seq
  end

  test "update syncs courses when times changes" do
    sk = semester_klasses(:sk_math_2)

    assert_difference -> { sk.courses.count }, 2 do
      put admin_semester_klass_path(sk), params: { semester_klass: {
        genre: sk.genre, teacher_id: sk.teacher_id, times: 18
      } }
    end

    assert_redirected_to admin_semester_klass_path(sk)
    assert_equal (1..18).to_a, sk.courses.order(:seq).pluck(:seq)
  end

  test "update rejects a grade change once students are enrolled" do
    sk = semester_klasses(:sk_math_2)

    put admin_semester_klass_path(sk), params: { semester_klass: {
      grade_id: grades(:grade_8).id, genre: sk.genre, teacher_id: sk.teacher_id,
      times: sk.times
    } }

    assert_redirected_to admin_semester_klasses_path
    assert_match "不能修改年级", flash[:alert]
    assert_equal grades(:grade_7), sk.reload.grade
  end

  test "create joins students from pasted text and creates missing ones" do
    assert_difference -> { SemesterKlass.count }, 1 do
      assert_difference -> { Student.count }, 1 do
        post admin_semester_klasses_path, params: {
          students_text: "7_学生2,2\n7_学生3\n粘贴新生",
          join_course_seq: 1,
          semester_klass: {
            semester_id: semesters(:semester_current).id,
            grade_id: grades(:grade_7).id,
            teacher_id: teachers(:math_teacher_1).id,
            campuse_id: campuses(:campuse_1).id,
            genre: "JY", seq: 76, times: 3
          }
        }
      end
    end

    sk = SemesterKlass.order(:id).last
    assert_redirected_to admin_semester_klass_path(sk)
    assert_match "已加入 3 名学员", flash[:notice]
    assert_match "新建 1 名学员", flash[:notice]

    newcomer = Student.find_by!(name: "粘贴新生")
    assert_equal grades(:grade_7), newcomer.grade
    assert sk.klass_students.exists?(student: newcomer)

    late = sk.klass_students.find_by!(student_id: students(:student_7_2).id)
    first = sk.klass_students.find_by!(student_id: students(:student_7_3).id)
    # 第 2 课入班：第 1 课补记缺课；默认第 1 课入班则不生成缺课
    assert_equal "absent", sk.courses.find_by!(seq: 1).attendances.find_by!(klass_student_id: late.id).status
    assert_nil sk.courses.find_by!(seq: 1).attendances.find_by(klass_student_id: first.id)
  end

  test "update creates missing students from pasted text and skips those already in class" do
    sk = semester_klasses(:sk_math_2)

    assert_difference -> { Student.count }, 1 do
      assert_difference -> { sk.klass_students.count }, 1 do
        put admin_semester_klass_path(sk), params: {
          students_text: "粘贴新增,1\n#{students(:student_7_1).name},1",
          join_course_seq: 1,
          semester_klass: { genre: sk.genre, seq: sk.seq, times: sk.times, teacher_id: sk.teacher_id }
        }
      end
    end

    assert_redirected_to admin_semester_klass_path(sk)
    newcomer = Student.find_by!(name: "粘贴新增")
    assert_equal sk.grade, newcomer.grade
    assert sk.klass_students.exists?(student: newcomer)
    assert_match "新建 1 名", flash[:notice]
    assert_match "跳过 1 行", flash[:notice]
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
