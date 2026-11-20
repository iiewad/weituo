require "test_helper"
require "stringio"
require "zip"

class StatementReportTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "跨学期数据计算新增率、拓科率与预留率" do
    current = semester_klasses(:sk_math_2)
    previous = semesters(:semester_previous)
    next_semester = semesters(:semester_next)
    # fixtures 里当前班级已有一名在班学员，先退班，保证下面的场景数据可控。
    klass_students(:ks_2).update!(status: "out")

    # 历史学期：数学班已有 1/2/3，英语班引入 5（构成拓科学员）
    [ students(:student_7_1), students(:student_7_2), students(:student_7_3) ].each do |student|
      student.join_klass(semester_klasses(:sk_math_1))
    end
    history_eng = SemesterKlass.create!(
      campuse: campuses(:campuse_1), subject: subjects(:eng),
      teacher: teachers(:eng_teacher_1), semester: previous,
      grade: grades(:grade_7), genre: "TG", seq: 8, times: 2
    )
    students(:student_7_5).join_klass(history_eng)

    # 当前学期数学班：2/3/5/6，其中 6 是新生、5 是拓科
    [ students(:student_7_2), students(:student_7_3), students(:student_7_5), students(:student_7_6) ].each do |student|
      student.join_klass(current)
    end

    # 下学期数学班：3/6（构成预留学员）
    next_math = SemesterKlass.create!(
      campuse: campuses(:campuse_1), subject: subjects(:math),
      teacher: teachers(:math_teacher_1), semester: next_semester,
      grade: grades(:grade_7), genre: "TG", seq: 9, times: 2
    )
    [ students(:student_7_3), students(:student_7_6) ].each { |student| student.join_klass(next_math) }

    assert_equal 4, current.current_active_students.count
    assert_equal 0.25, current.new_rate
    assert_equal 0.25, current.expand_rate
    assert_equal 0.5, current.reserve_rate

    get statement_admin_semester_klasses_path
    assert_response :success
    assert_match "25.0%", response.body
    assert_match "50.0%", response.body
    # 抽屉里能看到每个学员的具体来源：新生、拓科科目、下学期班级
    assert_match "历史学期无记录", response.body
    assert_match "上学期（", response.body
    assert_match "下学期（", response.body
    assert_match next_math.name, response.body

    # 在班名单会标注该生的新增/拓科/预留身份
    assert_select ".roster-chip", text: /#{students(:student_7_6).name}\s*新增/
    assert_select ".roster-chip", text: /#{students(:student_7_5).name}\s*拓科/
    assert_select ".roster-chip", text: /#{students(:student_7_3).name}\s*预留/
    # 未预留的学员在名单里直接标出，并有对应的详情
    assert_select ".roster-chip", text: /#{students(:student_7_5).name}\s*拓科\s*未预留/
    assert_select ".roster-chip", text: /#{students(:student_7_2).name}\s*未预留/
    assert_match "未预留", response.body
    assert_match "下学期（#{next_semester.name}）未报同科目", response.body

    # 未预留学员在名单中优先展示
    row = StatementReport.new(SemesterKlass.where(id: current.id), campuse: campuses(:campuse_1)).rows.first
    assert_includes row.active_students.first.tags, "未预留"

    get export_statement_admin_semester_klasses_path
    assert_response :success
    workbook = Zip::File.open_buffer(StringIO.new(response.body))
    strings = workbook.read("xl/sharedStrings.xml").force_encoding("UTF-8")
    assert_includes strings, "学员明细"
    assert_includes strings, "历史学期无记录"
    assert_includes strings, "上学期（"
    assert_includes strings, "下学期（"
    assert_includes strings, next_math.name
  end
end
