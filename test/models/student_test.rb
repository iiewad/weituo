require "test_helper"

class StudentTest < ActiveSupport::TestCase
  test "ransackable attributes are limited to name and grade" do
    assert_equal [ "name", "grade_id" ], Student.ransackable_attributes
  end

  test "join klass creates enrollment and attendance for started courses" do
    student = students(:student_7_2)
    sk = semester_klasses(:sk_math_1)
    course = sk.courses.find_by!(seq: 1)
    course.start!

    student.join_klass(sk)

    ks = sk.klass_students.find_by!(student_id: student.id)
    assert_equal "normal", course.attendances.find_by!(klass_student_id: ks.id).status
  end

  test "soft delete hides the student from the active scope and restore brings it back" do
    student = students(:student_7_1)

    assert_not student.deleted?
    student.soft_delete!
    assert student.reload.deleted?
    assert_includes Student.deleted, student
    assert_not_includes Student.active, student

    student.restore!
    assert_not student.reload.deleted?
    assert_includes Student.active, student
  end

  test "join klass rejects a different grade" do
    sk = semester_klasses(:sk_math_1)
    student = students(:student_8_1)

    assert_nil student.join_klass(sk)
    assert_nil sk.klass_students.find_by(student_id: student.id)
  end

  test "mark transferred in marks earlier started target courses and preserves real attendance" do
    target = semester_klasses(:sk_math_3)
    source = semester_klasses(:sk_math_1)
    student = students(:student_7_1)
    # 入班课次为第 4 课：目标班第 1-3 课已开课
    target.courses.find_by!(seq: 1).start!
    target.courses.find_by!(seq: 2).start!
    target.courses.find_by!(seq: 3).start!

    student.join_klass(target, course_seq: 4, mark_previous_absent: false, transfer_from: source)
    target_ks = target.klass_students.find_by!(student_id: student.id)
    # 目标班第 2 课已有真实考勤（模拟反向转回原班），应保留不被覆盖
    target.courses.find_by!(seq: 2).attendances.create!(klass_student: target_ks, status: "absent")

    student.mark_transferred_in_attendances(target, before_seq: 4)

    assert_equal "transfer_in", target.courses.find_by!(seq: 1).attendances.find_by!(klass_student_id: target_ks.id).status
    assert_equal "absent", target.courses.find_by!(seq: 2).attendances.find_by!(klass_student_id: target_ks.id).status
    assert_equal "transfer_in", target.courses.find_by!(seq: 3).attendances.find_by!(klass_student_id: target_ks.id).status
    # 入班课次起（未开课）不建转入行
    assert_nil target.courses.find_by!(seq: 4).attendances.find_by(klass_student_id: target_ks.id)
    # 转入信息记录在报名上
    assert_equal source, target_ks.reload.transfer_source_klass
    assert_equal 4, target_ks.transfer_in_seq
  end

  test "join klass requires the student grade to match even for next semester classes" do
    student = students(:student_7_1)
    target = SemesterKlass.create!(
      semester: semesters(:semester_next), campuse: campuses(:campuse_1),
      grade: grades(:grade_8), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      genre: "TG", seq: 3, times: 1
    )

    # 预留分班不再放宽年级：未升级到目标年级不能进班
    assert_nil student.join_klass(target)
    assert_not target.klass_students.exists?(student_id: student.id)

    # 升级到目标年级后才能进班，且不改动其它属性
    student.update!(grade: grades(:grade_8))
    assert student.join_klass(target)
    assert target.klass_students.exists?(student_id: student.id)
    assert_equal grades(:grade_8), student.reload.grade
  end

  test "join klass rejects a second class of the same subject in the same semester" do
    student = students(:student_7_1)
    first = semester_klasses(:sk_math_2)
    second = semester_klasses(:sk_math_3)

    assert student.join_klass(first)
    assert_nil student.join_klass(second)
    assert_not second.klass_students.exists?(student_id: student.id)
  end

  test "join klass allows a different subject in the same semester" do
    student = students(:student_7_1)
    assert student.join_klass(semester_klasses(:sk_math_2))

    english = SemesterKlass.create!(
      semester: semesters(:semester_current), campuse: campuses(:campuse_1),
      grade: grades(:grade_7), subject: subjects(:eng), teacher: teachers(:eng_teacher_1),
      genre: "TG", seq: 1, times: 1
    )
    assert student.join_klass(english)
  end

  test "join klass allows a same-subject class in a different semester" do
    student = students(:student_7_1)
    assert student.join_klass(semester_klasses(:sk_math_1))
    # sk_math_2 属于另一学期的同科目班，不受同学期同科目限制
    assert student.join_klass(semester_klasses(:sk_math_2))
  end

  test "join klass exempt transfer from the same-subject restriction" do
    student = students(:student_7_1)
    source = semester_klasses(:sk_math_2)
    target = semester_klasses(:sk_math_3)
    assert student.join_klass(source)

    # 转班：即便已在同科目其他班，带 transfer_from 仍可进目标班
    assert student.join_klass(target, course_seq: 1, transfer_from: source)
    assert target.klass_students.exists?(student_id: student.id)
  end

  test "update grade moves to the next level and stops at the top" do
    top = students(:student_9_1)
    top.update_grade
    assert_equal grades(:grade_9).id, top.reload.grade_id
  end

  test "same-name students get increasing name sequences and identity detail" do
    campuse = campuses(:campuse_1)
    first = Student.create!(name: "同名", campuse:, grade: grades(:grade_7))
    second = Student.create!(name: "同名", campuse:, grade: grades(:grade_7))
    third = Student.create!(name: "同名", campuse:, grade: grades(:grade_8))

    assert_equal 1, first.name_seq
    assert_equal 2, second.name_seq
    assert_equal 3, third.name_seq
    assert_nil first.identity_suffix
    assert_equal "序号 2", second.identity_suffix
    assert_equal "同名（序号 2）", second.identity_label
    assert_equal "七年级 · 序号 2", second.identity_detail
  end

  test "renaming keeps the name sequence when it is free" do
    campuse = campuses(:campuse_1)
    student = Student.create!(name: "旧名", campuse:, grade: grades(:grade_7))

    student.update!(name: "改名后")

    assert_equal 1, student.name_seq
  end

  test "renaming bumps the sequence only when the target name already uses it" do
    campuse = campuses(:campuse_1)
    first = Student.create!(name: "同名", campuse:, grade: grades(:grade_7))
    second = Student.create!(name: "同名", campuse:, grade: grades(:grade_7))
    renamed = Student.create!(name: "另一人", campuse:, grade: grades(:grade_7))

    renamed.update!(name: "同名")

    assert_equal 1, first.name_seq
    assert_equal 2, second.name_seq
    assert_equal 3, renamed.name_seq
  end

  test "name sequence is scoped by campus and bumps when a rename collides" do
    other_campuse = Campuse.create!(name: "第二校区", school: schools(:school_1))
    first = Student.create!(name: "跨校区同名", campuse: campuses(:campuse_1), grade: grades(:grade_7))
    second = Student.create!(name: "跨校区同名", campuse: other_campuse, grade: grades(:grade_7))

    assert_equal 1, first.name_seq
    assert_equal 1, second.name_seq

    renamed = Student.create!(name: "改名前", campuse: campuses(:campuse_1), grade: grades(:grade_7))
    renamed.update!(name: "跨校区同名")
    assert_equal 2, renamed.name_seq
  end

  test "trailing digits in the name are stored as the name sequence" do
    campuse = campuses(:campuse_1)
    student = Student.create!(name: "重名2", campuse:, grade: grades(:grade_7))

    assert_equal "重名", student.name
    assert_equal 2, student.name_seq
    assert_equal "序号 2", student.identity_suffix
  end

  test "digit sequence falls back to the next free one when taken" do
    campuse = campuses(:campuse_1)
    first = Student.create!(name: "占号", campuse:, grade: grades(:grade_7))
    second = Student.create!(name: "占号2", campuse:, grade: grades(:grade_7))
    third = Student.create!(name: "占号2", campuse:, grade: grades(:grade_7))

    assert_equal [ 1, 2, 3 ], [ first, second, third ].map { |s| s.reload.name_seq }
  end

  test "renaming with trailing digits moves to that sequence" do
    campuse = campuses(:campuse_1)
    first = Student.create!(name: "改号", campuse:, grade: grades(:grade_7))
    second = Student.create!(name: "别人", campuse:, grade: grades(:grade_7))

    second.update!(name: "改号3")

    assert_equal "改号", second.name
    assert_equal 3, second.name_seq
    assert_equal 1, first.name_seq
  end

  test "import stores trailing digits as the name sequence and dedupes by the stripped name" do
    text = "导入重名5,男,2000-01-01,7,1,current,三中"

    created, skipped = Student.add_by_text(campuses(:campuse_1).id, text)
    assert_equal 1, created
    assert_equal 0, skipped
    student = Student.find_by!(name: "导入重名")
    assert_equal 5, student.name_seq

    created, skipped = Student.add_by_text(campuses(:campuse_1).id, text)
    assert_equal 0, created
    assert_equal 1, skipped
    assert_equal 1, Student.where(name: "导入重名").count
  end

  test "assigning referrer id creates and clears the referral" do
    student = students(:student_7_5)
    referrer = students(:student_9_2)

    student.update!(referrer_id: referrer.id)
    assert_equal referrer, student.reload.referrer

    student.update!(referrer_id: "")
    assert_nil student.reload.referrer
  end

  test "referrer must belong to the same campus and cannot be the student" do
    student = students(:student_7_5)

    student.update!(referrer_id: student.id)
    assert_nil student.reload.referrer

    student.update!(referrer_id: 0)
    assert_nil student.reload.referrer
  end

  test "import by text maps genders and reports created and skipped rows" do
    text = [
      "导入甲,男,2000-01-01,7,1,current,三中,,,家长甲,13800000001,父亲",
      "导入乙,女,2000-01-01,7,1,不存在学期,三中",
      "坏日校,男,2000-01-01,7,1,current,不存在",
      "未授权年级,男,2000-01-01,9,1,current,三中",
      "导入甲,男,2000-01-01,7,1,current,三中,,,家长甲,13800000001,父亲"
    ].join("\n")

    created, skipped = Student.add_by_text(
      campuses(:campuse_1).id,
      text,
      grade_ids: [ grades(:grade_7).id ]
    )

    assert_equal 2, created
    assert_equal 3, skipped
    assert_equal "male", Student.find_by!(name: "导入甲").gender
    assert_equal "female", Student.find_by!(name: "导入乙").gender
    assert_equal grades(:grade_7), Student.find_by!(name: "导入甲").grade
    assert_equal day_schools(:one), Student.find_by!(name: "导入甲").day_school
    assert_equal semesters(:semester_current), Student.find_by!(name: "导入甲").in_semester
    assert_nil Student.find_by!(name: "导入乙").in_semester
    assert_nil Student.find_by!(name: "导入甲").day_school_class_name

    guardian = Student.find_by!(name: "导入甲").guardians.sole
    assert_equal "家长甲", guardian.name
    assert_equal "13800000001", guardian.phone
    assert_equal "父亲", guardian.relationship
    assert_empty Student.find_by!(name: "导入乙").guardians
  end

  test "import by text stores the day school class and address with a nameless guardian's occupation" do
    text = [
      "住址学员,男,2000-01-01,7,1,current,三中,初三(2)班,幸福路 1 号,,13900000000,,医生",
      "无监护人学员,女,2000-02-02,7,1,current,三中"
    ].join("\n")

    created, skipped = Student.add_by_text(campuses(:campuse_1).id, text)

    assert_equal 2, created
    assert_equal 0, skipped

    student = Student.find_by!(name: "住址学员")
    assert_equal "幸福路 1 号", student.address
    assert_equal "初三(2)班", student.day_school_class_name
    assert_nil Student.find_by!(name: "无监护人学员").day_school_class_name

    guardian = student.guardians.sole
    assert guardian.name.blank?
    assert_equal "13900000000", guardian.phone
    assert_equal "医生", guardian.occupation
    assert_empty Student.find_by!(name: "无监护人学员").guardians
  end

  test "import by text creates multiple guardians from grouped columns" do
    text = "多监护人,男,2000-01-01,7,1,current,三中,,,张建国,13800000000,父亲,工程师,李梅,13900000001,母亲,医生"

    created, skipped = Student.add_by_text(campuses(:campuse_1).id, text)

    assert_equal 1, created
    assert_equal 0, skipped

    guardians = Student.find_by!(name: "多监护人").guardians.order(:phone).to_a
    assert_equal 2, guardians.size
    assert_equal [ "张建国", "李梅" ], guardians.map(&:name)
    assert_equal [ "父亲", "母亲" ], guardians.map(&:relationship)
    assert_equal [ "工程师", "医生" ], guardians.map(&:occupation)
  end

  test "import dedupes by name and birthday even when other fields change" do
    campuse = campuses(:campuse_1)
    DaySchool.create!(name: "二中", campuse:)

    text = [
      "跨届学员,男,2000-01-01,7,1,current,三中",
      "跨届学员,男,2000/1/1,8,2,current previous,二中"
    ].join("\n")

    created, skipped = Student.add_by_text(campuse.id, text)

    assert_equal 1, created
    assert_equal 1, skipped
    assert_equal 1, Student.where(campuse_id: campuse.id, name: "跨届学员").count
  end

  test "import keeps same-name students with different birthdays apart" do
    campuse = campuses(:campuse_1)
    text = [
      "同名不同人,男,2000-01-01,7,1,current,三中",
      "同名不同人,男,2001-01-01,7,1,current,三中"
    ].join("\n")

    created, skipped = Student.add_by_text(campuse.id, text)

    assert_equal 2, created
    assert_equal 0, skipped
    assert_equal [ 1, 2 ], Student.where(name: "同名不同人").order(:name_seq).pluck(:name_seq)
  end

  test "import falls back to grade when the birthday is blank" do
    campuse = campuses(:campuse_1)
    text = [
      "无生日,男,,7,1,,三中",
      "无生日,男,,7,1,,三中",
      "无生日,男,,8,1,,三中"
    ].join("\n")

    created, skipped = Student.add_by_text(campuse.id, text)

    assert_equal 2, created
    assert_equal 1, skipped
    assert_equal [ grades(:grade_7).id, grades(:grade_8).id ],
      Student.where(name: "无生日").order(:id).pluck(:grade_id)
  end

  test "import rolls back the whole batch when a row fails" do
    campuse = campuses(:campuse_1)
    text = [
      "正常导入,男,2000-01-01,7,1,current,三中",
      "#{"超长" * 200},男,2000-01-02,7,1,current,三中"
    ].join("\n")

    assert_no_difference -> { Student.count } do
      assert_raises(ActiveRecord::ActiveRecordError) do
        Student.add_by_text(campuse.id, text)
      end
    end
  end

  test "add by text imports only rows with a valid grade and day school" do
    text = "新学员,男,2000-01-01,7,1,current,三中\n坏年级,男,2000-01-01,99,1,current,三中\n坏日校,男,2000-01-01,7,1,current,不存在"

    assert_difference -> { Student.count }, 1 do
      Student.add_by_text(campuses(:campuse_1).id, text)
    end
    assert_equal grades(:grade_7).id, Student.find_by!(name: "新学员").grade_id
  end
end
