class UserCampuse < ApplicationRecord
  belongs_to :school
  belongs_to :user
  belongs_to :campuse
  ROLES = {
    admin: "超级管理员",
    manager: "管理员"
  }
end
