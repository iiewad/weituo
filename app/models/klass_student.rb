class KlassStudent < ApplicationRecord
  include AASM

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

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
  # 从考勤入口的「重新加入」调用时，该行已被状态机写回正常，所以只恢复它之后的连续退/转，
  # 之前缺的课保留退/转历史；从班级页「撤销」调用时则回滚整段。
  # 转出目标记录在退/转起点行上，可能早于当前行，统一解除，避免重新加入后仍留在目标班。
  def reinstate!
    transaction do
      release_transfer_targets

      ordered = attendances.joins(:course).order("courses.seq").to_a
      last_present = ordered.rindex { |row| !row.status.in?(%w[quit transfer]) }
      streak = ordered[(last_present ? last_present + 1 : 0)..] || []

      streak.each do |row|
        next unless row.status.in?(%w[quit transfer])

        row.update!(status: "normal")
      end

      # 从考勤入口调用时，关联实例可能早于状态级联加载；reload 后写入，避免脏检查跳过更新
      reload.update!(status: :in)
    end
  end

  private
    def release_transfer_targets
      attendances.where.not(transfer_target_klass_id: nil).find_each do |row|
        release_transfer_target(row)
      end
    end

    # 转出时在考勤上记录目标班；撤销时把该班报名移出，历史考勤保留
    def release_transfer_target(attendance)
      target_id = attendance.transfer_target_klass_id
      return if target_id.blank?

      target = KlassStudent.unscoped.find_by(semester_klass_id: target_id, student_id: student_id)
      target.archive! if target && target.archived_at.nil?
      attendance.update_columns(transfer_target_klass_id: nil)
    end
end
