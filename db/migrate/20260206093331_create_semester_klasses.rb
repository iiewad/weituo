class CreateSemesterKlasses < ActiveRecord::Migration[8.1]
  def change
    create_table :semester_klasses do |t|
      t.bigint :klass_id, null: false
      t.bigint :semester_id, null: false
      t.bigint :grade_id, null: false
      t.integer :times, null: false
      t.timestamps
    end
    add_index :semester_klasses, %i[klass_id semester_id], unique: true
    remove_column :klasses, :times, :integer, if_exists: true
    remove_column :klasses, :semester_id, :bigint, if_exists: true
    remove_column :klasses, :grade_id, :bigint, if_exists: true

    remove_column :courses, :klass_id, :bigint, if_exists: true
    add_column :courses, :semester_klass_id, :bigint, if_exists: true
    remove_column :klass_students, :klass_id, :bigint, if_exists: true
    add_column :klass_students, :semester_klass_id, :bigint, if_exists: true
  end
end
