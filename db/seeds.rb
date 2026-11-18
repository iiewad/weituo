# 重建一套覆盖全部功能的演示数据（会清空现有业务数据）。
# 运行：bin/rails db:seed
# 演示账号：admin / user1 / user2 / user3，密码均为 password；pending 为未授权账号。

abort "db/seeds.rb 会清空业务数据，仅用于本地与测试环境。" if Rails.env.production?

rng = Random.new(20261117)

puts "清空现有数据…"
[
  Attendance, KlassStudent, Course, SemesterKlass,
  Guardian, Student, Teacher, GradeSubject,
  DaySchool, Semester,
  UserCampuse, Session, User,
  Campuse, School,
  Subject, Grade
].each(&:delete_all)

def term_name(date)
  season = case date.month
  when 1..2 then "寒假"
  when 3..7 then "春季"
  else "秋季"
  end
  "#{date.year} #{season}学期"
end

def attendance_status(klass_student_status, course_index, student_index, rng)
  if klass_student_status == "out"
    return course_index < 2 ? "normal" : "quit"
  end
  return course_index < 3 ? "normal" : "transfer" if klass_student_status == "transfer"
  return %w[normal normal normal normal absent personal_leave sick_leave filled][student_index % 8] if course_index.zero?

  roll = rng.rand
  if roll < 0.82 then "normal"
  elsif roll < 0.88 then "absent"
  elsif roll < 0.92 then "personal_leave"
  elsif roll < 0.96 then "sick_leave"
  else "filled"
  end
end

puts "创建学校、校区与学期…"
school = School.create!(name: "维拓教育")
campuses = [
  school.campuses.create!(name: "城东校区"),
  school.campuses.create!(name: "城西校区")
]

current_start = Date.today.beginning_of_month - 2.months
current_end = (current_start + 3.months).end_of_month
previous_end = current_start - 1.day
previous_start = (current_start - 5.months).beginning_of_month
oldest_end = previous_start - 1.day
oldest_start = (previous_start - 5.months).beginning_of_month
future_start = current_end + 1.day
future_end = (future_start + 2.months) - 1.day

semesters = [
  [ oldest_start, oldest_end ],
  [ previous_start, previous_end ],
  [ current_start, current_end ],
  [ future_start, future_end ]
].each_with_index.map do |(start_date, end_date), index|
  school.semesters.create!(name: term_name(start_date), seq: index + 1, start_date:, end_date:)
end
current_semester = semesters[2]

puts "创建年级、科目与教师…"
grades = (7..9).map { |level| Grade.create!(level:, name: "#{level}年级") }
subjects = { "数学" => "MATH", "英语" => "ENG", "物理" => "PHY", "化学" => "CHEM" }.to_h do |name, code|
  [ name, Subject.create!(name:, code:) ]
end
curriculum = {
  grades[0] => %w[数学 英语],
  grades[1] => %w[数学 英语 物理],
  grades[2] => %w[数学 英语 物理 化学]
}
curriculum.each do |grade, subject_names|
  subject_names.each { |name| GradeSubject.create!(school:, grade:, subject: subjects[name]) }
end

day_schools = campuses.to_h do |campuse|
  [ campuse.id, %w[一中 二中 三中].map { |name| campuse.day_schools.create!(name:) } ]
end

teacher_names = %w[张伟 王芳 李娜 刘洋 陈静 杨磊 赵敏 黄强 周涛 吴丹 徐晶 孙浩 马丽 朱军 胡雪 郭鹏]
teachers = {}
campuses.each_with_index do |campuse, campus_index|
  subjects.each_with_index do |(_subject_name, subject), subject_index|
    2.times do |n|
      name = teacher_names[(campus_index * 8 + subject_index * 2 + n) % teacher_names.size]
      teacher = campuse.teachers.create!(
        name:,
        phone: format("137%08d", campus_index * 100 + subject_index * 10 + n + 1),
        subject:
      )
      (teachers[[ campuse.id, subject.id ]] ||= []) << teacher
    end
  end
end

puts "创建账号与校区授权…"
grade_ids = grades.map(&:id)
admin = User.create!(name: "admin", password: "password")
campuses.each do |campuse|
  UserCampuse.create!(user: admin, school:, campuse:, role: "admin", grade_ids:)
end

user1 = User.create!(name: "user1", password: "password")
UserCampuse.create!(user: user1, school:, campuse: campuses[0], role: "manager", grade_ids: grades.first(2).map(&:id))

user2 = User.create!(name: "user2", password: "password")
UserCampuse.create!(user: user2, school:, campuse: campuses[1], role: "manager", grade_ids:)

user3 = User.create!(name: "user3", password: "password")
UserCampuse.create!(user: user3, school:, campuse: campuses[0], role: "manager", grade_ids: [ grades[2].id ])

User.create!(name: "pending", password: "password")

puts "创建学员与监护人…"
surnames = %w[张 王 李 赵 刘 陈 杨 黄 周 吴 徐 孙 马 朱 胡 郭 何 高 林 罗 郑 梁 谢 宋 唐 许 韩 冯 邓 曹]
given_names = %w[子涵 雨轩 一凡 欣怡 浩然 思远 佳琪 明哲 梓萱 俊杰 诗涵 天佑 嘉怡 承泽 若曦 博文 雅宁 奕辰 可欣 睿泽]
students_by = {}

campuses.each_with_index do |campuse, campus_index|
  grades.each do |grade|
    pool = 24.times.map do |index|
      name = "#{surnames[index % surnames.size]}#{given_names[(index + grade.level + campus_index) % given_names.size]}"
      student = campuse.students.create!(
        name:,
        gender: index.even? ? "male" : "female",
        birthday: Date.new(2021 - grade.level, (index % 12) + 1, (index % 27) + 1),
        phone: format("138%08d", campus_index * 10_000 + grade.level * 1_000 + index),
        grade:,
        layer: (index % 5) + 1,
        in_date: semesters.first.start_date - (index % 40).days,
        day_school: day_schools[campuse.id][index % day_schools[campuse.id].size],
        remark: (index % 7).zero? ? "家长要求每节课后反馈学习情况" : nil
      )
      Guardian.create!(
        student:,
        name: "#{name[0]}建国",
        phone: format("139%08d", campus_index * 10_000 + grade.level * 1_000 + index),
        relationship: "父亲"
      )
      if index.even?
        Guardian.create!(
          student:,
          name: "#{name[0]}丽华",
          phone: format("136%08d", campus_index * 10_000 + grade.level * 1_000 + index),
          relationship: "母亲"
        )
      end
      student
    end
    students_by[[ campuse.id, grade.id ]] = pool
  end
end

# 本学期才入学的学员，用于让新增率不为 0
newcomers_by = {}
campuses.each_with_index do |campuse, campus_index|
  grades.each do |grade|
    newcomers_by[[ campuse.id, grade.id ]] = 6.times.map do |index|
      student = campuse.students.create!(
        name: "#{surnames[24 + index]}#{given_names[(index + grade.level) % given_names.size]}",
        gender: index.even? ? "male" : "female",
        birthday: Date.new(2021 - grade.level, (index % 12) + 1, (index % 27) + 1),
        phone: format("135%08d", campus_index * 10_000 + grade.level * 1_000 + index),
        grade:,
        layer: (index % 5) + 1,
        in_date: current_start + (index % 20).days,
        day_school: day_schools[campuse.id][(index + 1) % day_schools[campuse.id].size]
      )
      Guardian.create!(
        student:,
        name: "#{student.name[0]}建国",
        phone: format("134%08d", campus_index * 10_000 + grade.level * 1_000 + index),
        relationship: "父亲"
      )
      student
    end
  end
end

puts "创建推荐关系…"
campuses.each do |campuse|
  grades.each_with_index do |grade, grade_index|
    referrer_grade = grade_index.zero? ? grade : grades[grade_index - 1]
    referrer_pool = students_by[[ campuse.id, referrer_grade.id ]]
    students_by[[ campuse.id, grade.id ]].first(3).each_with_index do |student, index|
      referrer = referrer_pool[(index + 4) % referrer_pool.size]
      next if referrer == student

      StudentReferral.create!(referrer:, referred: student)
    end
  end
end

puts "创建历史、当前与未来学期的班级…"
class_specs = curriculum.flat_map do |grade, subject_names|
  subject_names.flat_map do |subject_name|
    specs = [ { grade:, subject: subjects[subject_name], genre: "TG", seq: 1 } ]
    specs << { grade:, subject: subjects[subject_name], genre: "JY", seq: 2 } if subject_name == "数学"
    specs
  end
end

rosters = {}
classes = []

semesters.each_with_index do |semester, semester_index|
  campuses.each do |campuse|
    class_specs.each_with_index do |spec, spec_index|
      pool = students_by[[ campuse.id, spec[:grade].id ]]
      key = [ campuse.id, spec[:grade].id, spec[:subject].id, spec[:genre] ]
      roster = rosters[key] ||= pool.rotate(spec_index * 3).first(13 + (spec_index % 4))

      if semester_index.positive?
        leavers = roster.sample(1, random: rng)
        additions = (pool - roster).sample(2, random: rng)
        roster = ((roster - leavers) + additions).first(18)
        rosters[key] = roster
      end

      if semester_index >= 2
        newcomers = newcomers_by[[ campuse.id, spec[:grade].id ]]
        roster = (roster + newcomers.sample(2, random: rng)).uniq
        rosters[key] = roster
      end

      # 留一个没有学员的当前学期班级，用于验证空考勤与添加学员流程
      if semester == current_semester && campuse == campuses[1] && spec[:grade] == grades[2] && spec[:subject].name == "化学"
        roster = []
      end

      teacher = teachers[[ campuse.id, spec[:subject].id ]][spec[:genre] == "JY" ? 1 : 0]
      times = case semester_index
      when 3 then 8
      when 2 then 12
      else 6
      end

      sk = SemesterKlass.create!(
        campuse:, semester:, grade: spec[:grade], subject: spec[:subject],
        teacher:, genre: spec[:genre], seq: spec[:seq], times:
      )

      roster.each_with_index do |student, index|
        status = if semester_index >= 1 && index == roster.size - 1
          "out"
        elsif semester_index >= 2 && index == roster.size - 2 && (spec_index % 3).zero?
          "transfer"
        else
          "in"
        end
        KlassStudent.create!(semester_klass: sk, student:, status:)
      end

      classes << [ sk, semester_index ]
    end
  end
end

puts "排课并生成考勤…"
attendance_rows = []

classes.each do |sk, semester_index|
  courses = sk.courses.order(:seq).to_a

  case semester_index
  when 0, 1
    courses.each_with_index do |course, index|
      course.update_column(:start_date, sk.semester.start_date + ((index + 1) * 7).days)
    end
  when 2
    courses.each_with_index do |course, index|
      date = sk.semester.start_date + ((index + 1) * 7).days
      course.update_column(:start_date, date) if date <= Date.today
    end
  end

  klass_students = sk.klass_students.to_a
  courses.select { |course| course.start_date.present? }.each_with_index do |course, course_index|
    klass_students.each_with_index do |klass_student, student_index|
      status = attendance_status(klass_student.status, course_index, student_index, rng)
      attendance_rows << {
        course_id: course.id,
        klass_student_id: klass_student.id,
        status: Attendance.statuses[status]
      }
    end
  end
end

attendance_rows.each_slice(1_000) { |rows| Attendance.insert_all(rows) }

puts <<~SUMMARY
  种子数据已生成：
    学校 #{School.count} 所 / 校区 #{Campuse.count} 个 / 学期 #{Semester.count} 个
    年级 #{Grade.count} 个 / 科目 #{Subject.count} 个 / 教师 #{Teacher.count} 名
    学员 #{Student.count} 名 / 监护人 #{Guardian.count} 名 / 推荐关系 #{StudentReferral.count} 条
    班级 #{SemesterKlass.count} 个 / 课次 #{Course.count} 节 / 考勤 #{Attendance.count} 条
  账号：admin、user1、user2、user3（密码 password）；pending 为未授权账号。
SUMMARY
