class AddColumnsToSemesterKlasses < ActiveRecord::Migration[8.1]
  def change
    add_column :semester_klasses, :campuse_id, :bigint, if_not_exists: true
    add_column :semester_klasses, :genre, :string, if_not_exists: true
    add_column :semester_klasses, :seq, :integer, if_not_exists: true
    add_column :semester_klasses, :subject_id, :bigint, if_not_exists: true
    add_column :semester_klasses, :teacher_id, :bigint, if_not_exists: true
    remove_index :semester_klasses, %i[klass_id semester_id]
    remove_column :semester_klasses, :klass_id
  end
end
