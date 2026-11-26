class AddArchivedAtToTeachers < ActiveRecord::Migration[8.1]
  def change
    add_column :teachers, :archived_at, :datetime
  end
end
