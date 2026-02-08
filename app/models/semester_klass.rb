class SemesterKlass < ApplicationRecord
  belongs_to :klass
  belongs_to :semester
  has_many :courses, dependent: :destroy
  belongs_to :grade
  has_many :klass_students, dependent: :destroy
  has_many :students, through: :klass_students
  # 一个学期不允许有两个klass
  validates :semester_id, uniqueness: { scope: :klass_id, message: "该班级已在该学期中存在" }

  after_create :create_courses

  def create_courses
    self.times.times do |i|
      courses.find_or_create_by(seq: i + 1, semester_klass: self)
    end
  end

  def self.ransackable_associations(auth_object = nil)
    [ "courses", "grade", "klass", "klass_students", "semester", "students" ]
  end
  def self.ransackable_attributes(auth_object = nil)
  [ "created_at", "grade_id", "id", "klass_id", "semester_id", "times", "updated_at" ]
  end

  def add_students_by_text(text)
    campuse = klass.campuse
    text.split("\n").each do |line|
      line.strip!
      next if line.blank?
      student = campuse.students.where(grade_id: grade_id).find_by(name: line.split(" ")[0])
      next if student.blank?
      if line.split(" ").length == 2
        operator_str = line.split(" ")[1]
        course_seq = operator_str[0]
        operator = operator_str[1]
        if operator == "+"
          klass_students.find_or_create_by(student_id: student.id)
          # 课程之前的考勤标记为 absent
          course = courses.find_by(seq: course_seq)
          next if course.blank?
          courses.where("seq < ?", course_seq).each do |course|
            attendance = course.attendances.find_or_create_by(student_id: student.id)
            attendance.update!(status: "absent")
          end
          # 课程之后的考勤标记为 normal
          courses.where("seq >= ? AND start_date IS NOT NULL", course_seq).each do |course|
            course.attendances.find_or_create_by(student_id: student.id)
          end
        end
      elsif line.split(" ").length == 1
        klass_students.find_or_create_by(student_id: student.id)
        course = courses.find_by(seq: 1)
        next if course.blank?
        courses.where("seq >= ? AND start_date IS NOT NULL", 1).each do |course|
          course.attendances.find_or_create_by(student_id: student.id)
        end
      end
    end
  end

  def name
    "#{grade.level}#{klass.name}"
  end

  def students_text
    students.map(&:name).join("\n")
  end
end
