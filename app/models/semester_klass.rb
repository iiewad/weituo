class SemesterKlass < ApplicationRecord
  belongs_to :campuse
  belongs_to :subject
  belongs_to :teacher
  belongs_to :semester
  has_many :courses, dependent: :destroy
  belongs_to :grade
  has_many :klass_students, -> { active }
  has_many :all_klass_students, class_name: "KlassStudent", dependent: :destroy
  has_many :archived_klass_students, -> { archived }, class_name: "KlassStudent"
  has_many :students, through: :klass_students

  # 确保一个学期内，科目+班型+序号的组合是唯一的
  validates :semester_id, uniqueness: {
    scope: [ :campuse_id, :grade_id, :subject_id, :genre, :seq ],
    message: "班级信息已存在，不可重复"
  }
  validates :seq, presence: true, numericality: { only_integer: true }
  validates :times, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :genre, inclusion: { in: %w[TG JY XZ XQ CC] }
  validate :campuse_and_semester_share_school
  validate :subject_matches_teacher
  validate :grade_locked_when_students_exist, on: :update
  validate :times_not_below_started_courses, on: :update

  GENRE_MAP = {
    "提高班" => "TG",
    "精英班" => "JY",
    "创新班" => "XZ",
    "兴趣班" => "XQ",
    "超常班" => "CC"
  }

  GENRE_MAP_REVERSE = GENRE_MAP.invert

  after_create :create_courses
  after_update :sync_courses

  def create_courses
    self.times.times do |i|
      courses.find_or_create_by(seq: i + 1, semester_klass: self)
    end
  end

  # 编辑课次时同步课程：补齐缺少的课次，删除超出课次的未开课课次
  def sync_courses
    return unless saved_change_to_times?

    courses.where("seq > ?", times).where(start_date: nil).destroy_all
    create_courses
  end

  def self.ransackable_attributes(auth_object = nil)
    [ "campuse_id", "created_at", "genre", "grade_id", "id", "semester_id", "seq", "subject_id", "teacher_id", "times", "updated_at" ]
  end

  # 同一学期、校区、年级、科目、班型下自动取下一个序号，跳过含 4 的序号
  def self.next_seq(campuse_id:, semester_id:, grade_id:, subject_id:, genre:)
    candidate = where(
      campuse_id: campuse_id,
      semester_id: semester_id,
      grade_id: grade_id,
      subject_id: subject_id,
      genre: genre
    ).maximum(:seq).to_i + 1

    candidate += 1 while candidate.to_s.include?("4")
    candidate
  end

  # 结课判断：如果所有课程都有开始时间，则结课
  def ended?
    !courses.exists?(start_date: nil)
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

  # 保留学生：下学期仍在同科目班级就读的学员
  def reserve_students
    current_students = current_active_students
    return [] if current_students.empty?

    # 下学期
    next_semester = semester.related_next_semester
    return [] if next_semester.blank?
    # 下学期同科目班级
    next_klasses = next_semester.semester_klasses.where(subject_id: subject_id, campuse_id: campuse_id)
    next_students = next_klasses.map(&:current_active_students).flatten.uniq

    current_students & next_students
  end

  private
    def campuse_and_semester_share_school
      return if campuse.blank? || semester.blank? || campuse.school_id == semester.school_id

      errors.add(:campuse_id, "与学期不属于同一学校")
    end

    def subject_matches_teacher
      return if subject.blank? || teacher.blank? || subject_id == teacher.subject_id

      errors.add(:subject_id, "与教师科目不一致")
    end

    # 班级已有报名记录（含已移出）时不允许改年级，避免在班学员与班级年级不一致
    def grade_locked_when_students_exist
      return unless grade_id_changed? && all_klass_students.exists?

      errors.add(:grade_id, "班级已有学员，不能修改年级")
    end

    # 已开课的课次不能删除，课次只能加不能减到已开课数量以下
    def times_not_below_started_courses
      return unless times_changed? && times.present?

      started = courses.where.not(start_date: nil).count
      errors.add(:times, "已有 #{started} 个课次开课，不能小于该值") if times.to_i < started
    end
end
