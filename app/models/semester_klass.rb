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

  def inactive_students
    students.where(klass_students: { status: "out" })
  end

  def current_active_students
    students.where(klass_students: { status: "in" })
  end

  # 预留率 = 上学期有就读相同学科的学员人数 / 当前班级人数
  # 新学生：未在历史学期中任何班级的学员
  def new_students
    current_students = current_active_students
    return [] if current_students.empty?
    
    # 历史学期（当前学期之前的所有学期）
    history_semesters = semester.related_history_semesters
    return current_students if history_semesters.blank?
    
    # 历史学期所有班级的学生
    history_klasses = SemesterKlass.where(
      semester_id: history_semesters.pluck(:id),
      campuse_id: campuse_id
    )
    
    history_students = history_klasses.map(&:current_active_students).flatten.uniq
    
    current_students - history_students
  end
  
  # 拓科学生：上学期读过其他学科但未读相同学科的学员
  def expand_students
    current_students = current_active_students
    return [] if current_students.empty?
    
    # 上学期
    last_semester = semester.related_previous_semester
    return [] if last_semester.blank?
    
    # 上学期相同科目的班级
    last_same_subject_sks = last_semester.semester_klasses.where(subject_id: subject_id, campuse_id: campuse_id)
    last_same_subject_students = last_same_subject_sks.map(&:current_active_students).flatten.uniq
    
    # 上学期所有科目的班级（同一校区）
    last_all_sks = last_semester.semester_klasses.where(campuse_id: campuse_id)
    last_all_students = last_all_sks.map(&:current_active_students).flatten.uniq
    
    # 上学期在任何班级就读过，但未在相同学科班级就读过的学生
    (current_students & last_all_students) - last_same_subject_students
  end
  
  # 保留学生：上学期有就读相同学科的学员
  def reserve_students
    current_students = current_active_students
    return [] if current_students.empty?
    
    # 上学期
    last_semester = semester.related_previous_semester
    return [] if last_semester.blank?
    
    # 上学期同科目班级
    last_klasses = last_semester.semester_klasses.where(subject_id: subject_id, campuse_id: campuse_id)
    last_students = last_klasses.map(&:current_active_students).flatten.uniq
    
    current_students & last_students
  end
  
  # 新增率
  def new_rate
    current_students = current_active_students
    return 0.0 if current_students.empty?
    
    (new_students.size.to_f / current_students.size).round(2)
  end

  # 拓科率
  def expand_rate
    current_students = current_active_students
    return 0.0 if current_students.empty?
    
    (expand_students.size.to_f / current_students.size).round(2)
  end

  # 保留率
  def reserve_rate
    current_students = current_active_students
    return 0.0 if current_students.empty?
    
    (reserve_students.size.to_f / current_students.size).round(2)
  end
end