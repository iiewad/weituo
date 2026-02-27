class ChangeLevelForGrades < ActiveRecord::Migration[8.1]
  def change
    change_column :grades, :level, :integer
  end
end
