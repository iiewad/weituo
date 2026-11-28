require "test_helper"

class GradeReportModelTest < ActiveSupport::TestCase
  setup do
    @campuse = campuses(:campuse_1)
    @grade_7 = grades(:grade_7)
    @previous = semesters(:semester_previous)
    @current = semesters(:semester_current)
    @next = semesters(:semester_next)
  end

  test "classifies new expand and continuing students for a semester grade row" do
    # 新增：只在当前学期入班
    students(:student_7_2).join_klass(semester_klasses(:sk_math_2))
    # 拓科：上学期学数学，当前学期数学+英语
    eng_klass = create_klass(semester: @current, subject: subjects(:eng), teacher: teachers(:eng_teacher_1), seq: 10)
    students(:student_7_3).join_klass(semester_klasses(:sk_math_1))
    students(:student_7_3).join_klass(semester_klasses(:sk_math_2))
    students(:student_7_3).join_klass(eng_klass)
    # 换科（上学期数学、当前学期只学英语）：同样算拓科
    students(:student_7_4).join_klass(semester_klasses(:sk_math_1))
    students(:student_7_4).join_klass(eng_klass)
    # student_7_1 由 fixtures 提供：上学期数学、当前学期数学 → 延续

    row = report_row(@current)

    assert_equal [ students(:student_7_2).identity_label ], row.new_students.map(&:name)
    assert_equal [ students(:student_7_3), students(:student_7_4) ].map(&:identity_label).sort, row.expand_students.map(&:name)
    assert_empty row.return_students
    # fixtures 的 student_7_1 是唯一的延续学员
    assert_equal 1, row.active_count - row.new_count - row.expand_count - row.return_count
    assert_includes row.expand_students.find { |entry| entry.name == students(:student_7_3).identity_label }.detail, "新增科目：英语"
    switched = row.expand_students.find { |entry| entry.name == students(:student_7_4).identity_label }.detail
    assert_includes switched, "新增科目：英语"
    assert_not_includes switched, "延续："
  end

  test "classifies returning students against the previous semester" do
    # 回流：上上学期入班、上学期未入班、本学期重新入班
    next_klass = create_klass(semester: @next, subject: subjects(:math), teacher: teachers(:math_teacher_1), seq: 10)
    students(:student_7_5).join_klass(semester_klasses(:sk_math_1))
    students(:student_7_5).join_klass(next_klass)

    row = report_row(@next)

    assert_equal [ students(:student_7_5).identity_label ], row.return_students.map(&:name)
    assert_includes row.return_students.first.detail, "最近入班：#{@previous.name}"
    # student_7_1 上学期在班 → 不是回流
    assert_not_includes row.return_students.map(&:name), students(:student_7_1).identity_label
  end

  test "returning counts after a gap of several semesters" do
    # 隔多个学期：上学期（seq 1）入班，中间隔了两个学期，第四个学期重新入班 → 仍是回流
    later = Semester.create!(campuse: @campuse, name: "later", seq: 4)
    later_klass = create_klass(semester: later, subject: subjects(:math), teacher: teachers(:math_teacher_1), seq: 10)
    students(:student_7_2).join_klass(semester_klasses(:sk_math_1))
    students(:student_7_2).join_klass(later_klass)

    row = report_row(later)

    assert_equal [ students(:student_7_2).identity_label ], row.return_students.map(&:name)
    assert_includes row.return_students.first.detail, "最近入班：#{@previous.name}"
  end

  test "counts and rates are internally consistent" do
    students(:student_7_2).join_klass(semester_klasses(:sk_math_2))

    GradeReport.new(campuse: @campuse, grade_ids: [ @grade_7.id ]).rows.each do |row|
      assert_operator row.new_count + row.expand_count + row.return_count, :<=, row.active_count
      assert_equal row.new_students.size, row.new_count
      assert_equal row.expand_students.size, row.expand_count
      assert_equal row.return_students.size, row.return_count
      if row.active_count.positive?
        assert_equal (row.new_count.to_f / row.active_count).round(2), row.new_rate
      end
    end
  end

  test "rows only cover allowed grades and the semester filter applies" do
    report = GradeReport.new(campuse: @campuse, grade_ids: [ grades(:grade_8).id ])
    assert_empty report.rows

    filtered = GradeReport.new(campuse: @campuse, grade_ids: [ @grade_7.id ], semester_id: @current.id)
    assert filtered.rows.all? { |row| row.semester.id == @current.id }
    assert_equal 1, filtered.semester_groups.size
  end

  test "computes every row with a fixed number of queries" do
    queries = 0
    test_thread = Thread.current
    # 测试可能并行执行，只统计当前线程发出的查询，避免其他用例的 SQL 混进来
    callback = ->(_name, _start, _finish, _id, payload) {
      if Thread.current == test_thread && !payload[:name].in?([ "SCHEMA", "TRANSACTION" ])
        queries += 1
      end
    }

    rows = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      GradeReport.new(campuse: @campuse, grade_ids: [ @grade_7.id ]).rows
    end

    assert_operator rows.size, :>, 0
    # 5 次为固定查询（学期、报名、年级、学员、科目），新增固定查询时同步调整
    assert_operator queries, :<=, 6, "报表应只做固定次数的查询，实际发出 #{queries} 次"
  end

  private
    def report_row(semester)
      GradeReport.new(campuse: @campuse, grade_ids: [ @grade_7.id ]).rows
        .find { |row| row.semester.id == semester.id && row.grade.id == @grade_7.id }
    end

    def create_klass(semester:, subject:, teacher:, seq:)
      SemesterKlass.create!(
        campuse: @campuse, semester:, subject:, teacher:,
        grade: @grade_7, genre: "TG", seq:, times: 2
      )
    end
end
