require "test_helper"
require "stringio"
require "zip"

class StatementReportTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    # 本用例只校验预留口径，把出勤门槛设为 0
    campuses(:campuse_1).update!(reserve_min_attendances: 0)
  end

  test "跨学期数据计算预留率" do
    current = semester_klasses(:sk_math_2)
    next_semester = semesters(:semester_next)
    # fixtures 里当前班级已有一名在班学员，先退班，保证下面的场景数据可控。
    klass_students(:ks_2).update!(status: "out")

    # 当前学期数学班：2/3/6
    [ students(:student_7_2), students(:student_7_3), students(:student_7_6) ].each do |student|
      student.join_klass(current)
    end

    # 下学期数学班：3/6（构成预留学员）
    next_math = SemesterKlass.create!(
      campuse: campuses(:campuse_1), subject: subjects(:math),
      teacher: teachers(:math_teacher_1), semester: next_semester,
      grade: grades(:grade_7), genre: "TG", seq: 9, times: 2
    )
    [ students(:student_7_3), students(:student_7_6) ].each { |student| student.join_klass(next_math) }

    row = StatementReport.new(SemesterKlass.where(id: current.id), campuse: campuses(:campuse_1)).rows.first
    assert_equal 3, row.active_count
    assert_equal 2, row.reserve_count
    assert_equal 1, row.unreserved_count

    get statement_admin_semester_klasses_path
    assert_response :success
    # 抽屉里能看到预留学员的下学期班级来源
    assert_match "下学期（", response.body
    assert_match next_math.name, response.body

    # 在班名单会标注该生的预留 / 未预留身份
    assert_select ".roster-chip", text: /#{students(:student_7_3).name}\s*预留/
    assert_select ".roster-chip", text: /#{students(:student_7_2).name}\s*未预留/
    assert_match "下学期（#{next_semester.name}）未报同科目", response.body

    # 未预留学员在名单中优先展示
    assert_includes row.active_students.first.tags, "未预留"

    get export_statement_admin_semester_klasses_path
    assert_response :success
    workbook = Zip::File.open_buffer(StringIO.new(response.body))
    strings = workbook.read("xl/sharedStrings.xml").force_encoding("UTF-8")
    assert_includes strings, "学员明细"
    assert_includes strings, "下学期（"
    assert_includes strings, next_math.name
  end
end
