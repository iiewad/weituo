class Reservation < ApplicationRecord
  belongs_to :student
  belongs_to :semester
  belongs_to :subject
  belongs_to :grade
  # 预留时可以不指定教师，生成分班时再选
  belongs_to :teacher, optional: true
  belongs_to :source_semester_klass, class_name: "SemesterKlass", optional: true
  belongs_to :semester_klass, class_name: "SemesterKlass", optional: true

  # 尚未生成下学期班级
  scope :pending, -> { where(semester_klass_id: nil) }
  scope :generated, -> { where.not(semester_klass_id: nil) }

  # 预留表排序：目标学期（新的在前）、年级、科目、班型、教师、学员
  scope :ordered_by_target, -> {
    left_joins(:semester, :grade, :subject, :teacher)
      .order("semesters.seq DESC, grades.level, subjects.id, reservations.genre, reservations.teacher_id, students.name, reservations.id")
  }

  validates :genre, inclusion: { in: SemesterKlass::GENRE_MAP.values }
  validates :student_id, uniqueness: { scope: [ :semester_id, :subject_id ], message: "该学员已预留该学期同科目" }

  def self.ransackable_attributes(auth_object = nil)
    [ "semester_id", "grade_id", "subject_id", "genre", "teacher_id" ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "student", "source_semester_klass" ]
  end

  # 源学期：预留来自哪个学期的班级；来源班级被删除后为空
  def source_semester
    source_semester_klass&.semester
  end

  def generated?
    semester_klass_id.present?
  end

  # 生成的班级沿用来源班级的阶段
  def phase
    source_semester_klass&.phase || SemesterKlass::PHASE_PREFIX.keys.first
  end

  # 生成分班时的分组：同一组的预留学员会进入同一个下学期班级
  def group_key
    [ semester_id, grade_id, subject_id, genre, phase, teacher_id ]
  end
end
