class SemesterKlass < ApplicationRecord
  belongs_to :campuse
  belongs_to :subject
  belongs_to :teacher
  belongs_to :semester
  has_many :courses, dependent: :destroy
  belongs_to :grade
  has_many :klass_students, dependent: :destroy
  has_many :students, through: :klass_students
  
  # 确保同一个校区内，科目+班型+序号的组合是唯一的
  validates :seq, uniqueness: {
    scope: [ :campuse_id, :subject_id, :genre ],
    message: "班级信息已存在，不可重复"
  }

  GENRE_MAP = {
    "提高班" => "TG",
    "精英班" => "JY",
    "创新班" => "XZ",
    "兴趣班" => "XQ",
    "超常班" => "CC"
  }

  GENRE_MAP_REVERSE = GENRE_MAP.invert

  after_create :create_courses

  def create_courses
    self.times.times do |i|
      courses.find_or_create_by(seq: i + 1, semester_klass: self)
    end
  end

  def self.ransackable_associations(auth_object = nil)
    [ "courses", "grade", "klass_students", "semester", "students" ]
  end
  def self.ransackable_attributes(auth_object = nil)
  [ "created_at", "grade_id", "id", "semester_id", "times", "updated_at" ]
  end

  def add_students_by_text(text)
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

  def students_text
    students.map(&:name).join("\n")
  end

  def self.ransackable_attributes(auth_object = nil)
    [ "campuse_id", "genre", "id", "seq", "subject_id", "teacher_id" ]
  end
  
  def self.ransackable_associations(auth_object = nil)
    [ "campuse", "subject", "teacher", "semester_klasses", "semesters" ]
  end

  def name
    "#{subject.name[0]}#{GENRE_MAP_REVERSE[genre][0]}#{seq}"
  end


end
