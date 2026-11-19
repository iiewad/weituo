class KlassStudent < ApplicationRecord
  include AASM

  default_scope { where(archived_at: nil) }
  scope :archived, -> { unscope(where: :archived_at).where.not(archived_at: nil) }

  belongs_to :semester_klass
  belongs_to :student
  has_many :attendances, dependent: :destroy

  enum :status, [ :out, :in, :transfer ]

  aasm column: :status, enum: true do
    state :in, initial: true
    state :out
    state :transfer

    event :mark_out do
      transitions from: [ :in, :transfer ], to: :out
    end

    event :mark_transfer do
      transitions from: [ :in, :out ], to: :transfer
    end
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def restore!
    update!(archived_at: nil, status: :in)
  end

  # 撤销退课 / 转出：恢复当前离开期间的考勤，并把报名状态改回在班
  def reinstate!
    transaction do
      ordered = attendances.joins(:course).order("courses.seq").to_a
      last_present = ordered.rindex { |attendance| !attendance.status.in?(%w[quit transfer]) }
      streak = ordered[(last_present ? last_present + 1 : 0)..] || []

      streak.each do |attendance|
        next unless attendance.status.in?(%w[quit transfer])

        release_transfer_target(attendance)
        attendance.update!(status: "normal")
      end

      update!(status: :in)
    end
  end

  def another_semester_klasses(semester_id)
    SemesterKlass
      .joins(:klass_students)
      .where(
        semester_id: semester_id,
      campuse_id: semester_klass.campuse_id,
    )
  end

  private
    # 转出时在考勤 mark_at 里记录目标班；撤销时把该班报名移出，历史考勤保留
    def release_transfer_target(attendance)
      target_id = attendance.mark_at&.dig("transfer_target_klass_id")
      return if target_id.blank?

      target = KlassStudent.unscoped.find_by(semester_klass_id: target_id, student_id: student_id)
      target.archive! if target && target.archived_at.nil?
    end
end
