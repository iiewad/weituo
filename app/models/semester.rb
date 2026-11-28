class Semester < ApplicationRecord
  belongs_to :campuse

  validates :name, :seq, presence: true
  validates :seq, uniqueness: { scope: :campuse_id }

  # 当前学期由 semesters.current 标记决定（每个校区唯一），不再根据日期推断
  def self.current(campuse_id)
    where(campuse_id: campuse_id, current: true).first
  end

  def self.history(campuse_id)
    current_semester = current(campuse_id)
    return none if current_semester.nil?

    where(campuse_id: campuse_id).where(seq: ...current_semester.seq).order(seq: :desc)
  end

  has_many :semester_klasses, dependent: :destroy
  # 学期删除时其年级科目配置一并删除，否则外键会拦住学期管理页的学期删除
  has_many :grade_subjects, dependent: :destroy
  # 学期删除后预留记录失去目标，一并删除，否则外键会拦住学期管理页的学期删除
  has_many :reservations, dependent: :destroy
  # 学员的入学学期；学期删除时置空，不删学员
  has_many :students, class_name: "Student", foreign_key: :in_semester_id, dependent: :nullify, inverse_of: :in_semester

  after_save :apply_current_flag
  after_destroy :restore_current_flag

  def self.ransackable_attributes(auth_object = nil)
    [ "id", "name", "seq" ]
  end

  # 学期顺序统一以 seq 为准
  def related_next_semester
    campuse.semesters.where("seq > ?", seq).order(seq: :asc).first
  end

  def related_previous_semester
    campuse.semesters.where("seq < ?", seq).order(seq: :desc).first
  end

  def related_history_semesters
    campuse.semesters.where("seq < ?", seq).order(seq: :desc)
  end

  private
    # 每个校区恰好一个当前学期：标记 current 时取消同级其它学期；没有 current 时回落到序号最小的学期
    def apply_current_flag
      if current
        campuse.semesters.where.not(id: id).update_all(current: false)
      elsif !campuse.semesters.where(current: true).exists?
        campuse.semesters.order(:seq).first&.update_column(:current, true)
      end
    end

    def restore_current_flag
      return if campuse.semesters.where(current: true).exists?

      campuse.semesters.order(:seq).first&.update_column(:current, true)
    end
end
