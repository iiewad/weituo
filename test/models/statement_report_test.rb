require "test_helper"

class StatementReportModelTest < ActiveSupport::TestCase
  setup do
    @campuse = campuses(:campuse_1)
  end

  test "row counts and rates are internally consistent" do
    report = StatementReport.new(SemesterKlass.where(campuse_id: @campuse.id), campuse: @campuse)

    report.rows.each do |row|
      sk = row.semester_klass

      assert_equal sk.current_active_students.count, row.active_count
      assert_equal sk.reserve_students.size, row.reserve_count
      assert_equal row.reserve_count + row.unreserved_count, row.active_count
      assert_equal row.new_students.size, row.new_count
      assert_equal row.expand_students.size, row.expand_count
      assert_equal row.reserve_students.size, row.reserve_count
      assert_equal row.unreserved_students.size, row.unreserved_count

      if row.active_count.positive?
        assert_equal (row.new_count.to_f / row.active_count).round(2), row.new_rate
        assert_equal (row.expand_count.to_f / row.active_count).round(2), row.expand_rate
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
    assert_operator queries, :<=, 10, "报表应只做固定次数的查询，实际发出 #{queries} 次"
  end

  test "summary aggregates counts and average rates" do
    report = StatementReport.new(SemesterKlass.where(campuse_id: @campuse.id), campuse: @campuse)
    summary = report.summary

    assert_equal report.rows.size, summary[:class_count]
    assert_equal report.rows.sum(&:active_count), summary[:active_count]
    assert_kind_of Float, summary[:new_rate]
    assert_kind_of Float, summary[:expand_rate]
    assert_kind_of Float, summary[:reserve_rate]
  end
end
