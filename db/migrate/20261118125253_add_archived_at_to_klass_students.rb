class AddArchivedAtToKlassStudents < ActiveRecord::Migration[8.1]
  def change
    add_column :klass_students, :archived_at, :datetime
    add_index :klass_students, :archived_at
  end
end
