class AddManualTransferOutToAttendances < ActiveRecord::Migration[8.1]
  def change
    add_column :attendances, :manual_transfer_out, :boolean, default: false, null: false
  end
end
