class CreateStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :students do |t|
      t.string :name, null: false
      t.string :phone
      t.string :gender
      t.date :birthday
      t.date :in_date
      t.integer :layer
      t.bigint :campuse_id, null: false
      t.bigint :grade_id

      t.timestamps
    end
  end
end
