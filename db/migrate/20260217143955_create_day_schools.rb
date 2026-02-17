class CreateDaySchools < ActiveRecord::Migration[8.1]
  def change
    create_table :day_schools do |t|
      t.string :name
      t.bigint :campuse_id, null: false
    end
    add_column :students, :day_school_id, :bigint
  end
end
