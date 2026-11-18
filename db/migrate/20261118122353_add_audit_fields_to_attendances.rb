class AddAuditFieldsToAttendances < ActiveRecord::Migration[8.1]
  def up
    add_column :attendances, :created_at, :datetime
    add_column :attendances, :updated_at, :datetime
    add_reference :attendances, :marked_by,
      foreign_key: { to_table: :users, on_delete: :nullify },
      index: true

    execute "UPDATE attendances SET created_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE created_at IS NULL"

    change_column_null :attendances, :created_at, false
    change_column_null :attendances, :updated_at, false
  end

  def down
    remove_reference :attendances, :marked_by, foreign_key: true
    remove_column :attendances, :updated_at
    remove_column :attendances, :created_at
  end
end
