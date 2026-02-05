class CreateKlassStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :klass_students do |t|
      t.bigint :klass_id, null: false
      t.bigint :student_id, null: false
      t.integer :status, default: 1
      t.date :join_date
      t.date :quit_date
      t.date :stop_date
    end
  end
end
