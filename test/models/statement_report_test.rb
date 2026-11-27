require "test_helper"

class StatementReportModelTest < ActiveSupport::TestCase
  setup do
    @campuse = campuses(:campuse_1)
    # 这些用例只校验结构一致性，默认把门槛设为 0，避免出勤数据干扰
    @campuse.update!(reserve_min_attendances: 0)
  end

  test "row counts and rates are internally consistent" do
    report = StatementReport.new(SemesterKlass.where(campuse_id: @campuse.id), campuse: @campuse)

    report.rows.each do |row|
      sk = row.semester_klass

      assert_equal sk.current_active_students.count, row.active_count
      assert_equal sk.reserve_students.size, row.reserve_count
      assert_equal row.reserve_count + row.unreserved_count, row.active_count
      assert_equal row.unreserved_students.size, row.unreserved_count

      if row.active_count.positive?
        assert_equal (row.reserve_count.to_f / row.active_count).round(2), row.reserve_rate
      end
    end
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
      StatementReport.new(SemesterKlass.where(campuse_id: @campuse.id), campuse: @campuse).rows
    end

    assert_equal SemesterKlass.where(campuse_id: @campuse.id).count, rows.size
    # 10 次为固定查询（学期、班级、报名、学员、出勤、预留表等），新增固定查询时同步调整
    assert_operator queries, :<=, 11, "报表应只做固定次数的查询，实际发出 #{queries} 次"
  end

  test "reserve requires enough attendance in the next semester subject class" do
    @campuse.update!(reserve_min_attendances: 2)
    current = semester_klasses(:sk_math_2)
    next_class = SemesterKlass.create!(
      campuse: @campuse, subject: subjects(:math), teacher: teachers(:math_teacher_1),
      semester: semesters(:semester_next), grade: grades(:grade_7), genre: "TG", seq: 9, times: 3
    )
    attendee = students(:student_7_1)
    short = students(:student_7_2)
    [ attendee, short ].each { |student| student.join_klass(current) }
    [ attendee, short ].each { |student| student.join_klass(next_class) }

    next_class.courses.order(:seq).limit(2).each(&:start!)
    # 第二位学员只保留 1 次出勤，达不到 2 次门槛
    short_ks = next_class.klass_students.find_by!(student_id: short.id)
    next_class.courses.find_by!(seq: 2).attendances.find_by!(klass_student_id: short_ks.id).destroy!

    row = StatementReport.new(SemesterKlass.where(id: current.id), campuse: @campuse).rows.first

    assert_equal 2, row.active_count
    assert_equal 1, row.reserve_count
    assert_equal 1, row.unreserved_count
    assert_equal [ attendee.identity_label ], row.reserve_students.map(&:name)
    assert_includes row.unreserved_students.map(&:detail).join(" "), "已上 1 次，未达 2 次"
  end

  test "unreserved detail tells a pending reservation apart from not enrolled" do
    current = semester_klasses(:sk_math_2)
    Reservation.create!(
      student: students(:student_7_1), semester: semesters(:semester_next), subject: subjects(:math),
      grade: grades(:grade_8), teacher: teachers(:math_teacher_1), genre: "JY", source_semester_klass: current
    )

    row = StatementReport.new(SemesterKlass.where(id: current.id), campuse: @campuse).rows.first

    assert_not_includes row.reserve_students.map(&:name), students(:student_7_1).identity_label
    unreserved = row.unreserved_students.to_h { |entry| [ entry.name, entry.detail ] }
    assert_equal "已登记预留，待分班", unreserved[students(:student_7_1).identity_label]
  end

  test "summary aggregates counts and average rates" do
    report = StatementReport.new(SemesterKlass.where(campuse_id: @campuse.id), campuse: @campuse)
    summary = report.summary

    assert_equal report.rows.size, summary[:class_count]
    assert_equal report.rows.sum(&:active_count), summary[:active_count]
    assert_kind_of Float, summary[:reserve_rate]
  end
end
