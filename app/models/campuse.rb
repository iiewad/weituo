class Campuse < ApplicationRecord
  belongs_to :school

  # 删除校区时级联删除全部下属资源；声明顺序即删除顺序，须满足外键约束：
  # 班级依赖教师，学员依赖日校，所以先删班级、学员，再删教师、日校
  has_many :semester_klasses, dependent: :destroy
  has_many :students, dependent: :destroy
  has_many :teachers, dependent: :destroy
  has_many :day_schools, dependent: :destroy
  has_many :user_campuses, dependent: :destroy
  has_many :users, through: :user_campuses

  validates :reserve_min_attendances, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
