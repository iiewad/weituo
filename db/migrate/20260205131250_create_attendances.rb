class CreateAttendances < ActiveRecord::Migration[8.1]
  def change
    create_table :attendances do |t|
      t.bigint :course_id, null: false
      t.bigint :student_id, null: false
      t.integer :status, null: false, default: 1
    end
  end
end
