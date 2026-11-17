class UserCampuse < ApplicationRecord
  belongs_to :school
  belongs_to :user
  belongs_to :campuse

  ROLES = {
    admin: "超级管理员",
    manager: "管理员"
  }.freeze

  before_validation :fill_school_from_campuse

  def role_label
    ROLES[role&.to_sym] || role.presence || "未设置"
  end

  # 表单提交的多选年级会带上空字符串，统一存成整数数组
  def grade_ids=(value)
    super(Array(value).reject(&:blank?).map(&:to_i).uniq)
  end

  private
    def fill_school_from_campuse
      self.school_id = campuse.school_id if campuse
    end
end
