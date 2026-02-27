class AddMarkAtToAttendances < ActiveRecord::Migration[8.1]
  def change
    add_column :attendances, :mark_at, :json
  end
end
