class CreateReservations < ActiveRecord::Migration[8.1]
  def change
    create_table :reservations do |t|
      t.references :student, null: false, foreign_key: true
      t.references :semester, null: false, foreign_key: true
      t.references :subject, null: false, foreign_key: true
      t.references :grade, null: false, foreign_key: true
      t.references :teacher, null: false, foreign_key: true
      t.string :genre, null: false
      t.references :source_semester_klass, foreign_key: { to_table: :semester_klasses, on_delete: :nullify }
      t.references :semester_klass, foreign_key: { to_table: :semester_klasses, on_delete: :nullify }
      t.timestamps
    end

    add_index :reservations, [ :student_id, :semester_id, :subject_id ], unique: true,
      name: "index_reservations_on_student_semester_subject"
  end
end
