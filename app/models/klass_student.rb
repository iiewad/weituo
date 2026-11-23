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

  # 撤销退课 / 转出：恢复最近一段连续退/转的考勤，并把报名状态改回在班。
  # attendance 用于从考勤入口撤销：该行此时已被状态机写回正常，不进 streak，
  # 但仍需清理它记录的转出目标班。
  def reinstate!(attendance: nil)
    transaction do
      release_transfer_target(attendance) if attendance

      ordered = attendances.joins(:course).order("courses.seq").to_a
      last_present = ordered.rindex { |row| !row.status.in?(%w[quit transfer]) }
      streak = ordered[(last_present ? last_present + 1 : 0)..] || []

      streak.each do |row|
        next unless row.status.in?(%w[quit transfer])

        release_transfer_target(row)
        row.update!(status: "normal")
      end

      # 从考勤入口调用时，关联实例可能早于状态级联加载；reload 后写入，避免脏检查跳过更新
      reload.update!(status: :in)
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
