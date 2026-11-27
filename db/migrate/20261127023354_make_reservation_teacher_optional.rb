class MakeReservationTeacherOptional < ActiveRecord::Migration[8.1]
  def change
    # 预留时可以不指定教师，生成分班时再选
    change_column_null :reservations, :teacher_id, true
  end
end
