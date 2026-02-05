class CreateTeachers < ActiveRecord::Migration[8.1]
  def change
    create_table :teachers do |t|
      t.string :name, null: false
      t.string :phone
      t.bigint :campuse_id, null: false
      t.bigint :subject_id, null: false
    end
  end
end
