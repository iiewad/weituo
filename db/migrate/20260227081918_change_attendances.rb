class ChangeAttendances < ActiveRecord::Migration[8.1]
  def change
    remove_column :attendances, :student_id, :bigint
    add_column :attendances, :klass_student_id, :bigint
  end
end
