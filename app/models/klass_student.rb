class KlassStudent < ApplicationRecord
  include AASM

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  belongs_to :semester_klass
  belongs_to :student
  # 转入来源班与入班课次：仅转出转入时写入，供转入班展示「由 X 转入 · 第 N 课起」
  belongs_to :transfer_source_klass, class_name: "SemesterKlass", optional: true
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

  # 撤销退课：恢复最近一段连续退课的考勤，并把报名状态改回在班。
  # 转出不可撤销（需在转入班反向转出回原班），所以只处理 quit 行，保留 transfer 历史。
  # 从考勤入口的「重新加入」调用时，该行已被状态机写回正常，所以只恢复它之后的连续退课，
  # 之前缺的课保留退/转历史；从班级页「撤销」调用时则回滚整段。
  def reinstate!
    transaction do
      ordered = attendances.joins(:course).order("courses.seq").to_a
      last_present = ordered.rindex { |row| !row.status.in?(%w[quit transfer]) }
      streak = ordered[(last_present ? last_present + 1 : 0)..] || []

      streak.each do |row|
        next unless row.status == "quit"

        row.update!(status: "normal")
      end

      # 从考勤入口调用时，关联实例可能早于状态级联加载；reload 后写入，避免脏检查跳过更新
      reload.update!(status: :in)
    end
  end
end
