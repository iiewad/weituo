class ChangeStudentLayerToString < ActiveRecord::Migration[8.1]
  def up
    change_column :students, :layer, :string
  end

  def down
    change_column :students, :layer, :integer
  end
end
