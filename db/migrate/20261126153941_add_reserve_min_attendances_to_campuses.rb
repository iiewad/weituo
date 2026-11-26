class AddReserveMinAttendancesToCampuses < ActiveRecord::Migration[8.1]
  def change
    # 预留口径：下学期同科目班至少上 N 次课才计入预留
    add_column :campuses, :reserve_min_attendances, :integer, default: 4, null: false
  end
end
