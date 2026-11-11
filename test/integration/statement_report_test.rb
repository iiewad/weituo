require "test_helper"

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
  end
end
