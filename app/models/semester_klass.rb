class SemesterKlass < ApplicationRecord
  belongs_to :campuse
  belongs_to :subject
  belongs_to :teacher
  belongs_to :semester
  has_many :courses, dependent: :destroy
  belongs_to :grade
  has_many :klass_students, dependent: :destroy
  has_many :students, through: :klass_students
  
  # 确保一个学期内，科目+班型+序号的组合是唯一的
  validates :semester_id, uniqueness: {
    scope: [ :campuse_id, :grade_id, :subject_id, :genre, :seq ],
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
    [ "courses", "grade", "klass_students", "semester", "students", "teacher" ]
  end
  def self.ransackable_attributes(auth_object = nil)
    [ "campuse_id", "created_at", "genre", "grade_id", "id", "semester_id", "seq", "subject_id", "teacher_id", "times", "updated_at" ]
  end

  # 结课判断：如果所有课程都有开始时间，则结课
  def ended?
    !courses.exists?(start_date: nil)
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
        student.join_klass(self, course_seq: course_seq.to_i) if operator == "+"
      elsif line.split(" ").length == 1
        student.join_klass(self, course_seq: 1)
      end
    end
  end

  def students_text
    students.map(&:name).join("\n")
  end
  
  def self.ransackable_associations(auth_object = nil)
    [ "campuse", "courses", "grade", "klass_students", "semester", "students", "subject", "teacher" ]
  end

  def name
    "#{grade.level}#{subject.name[0]}#{GENRE_MAP_REVERSE[genre][0]}#{seq}"
  end
end