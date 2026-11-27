class AddSourceSemesterToReservations < ActiveRecord::Migration[8.1]
  def change
    add_reference :reservations, :source_semester, foreign_key: { to_table: :semesters, on_delete: :nullify }

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE reservations
          INNER JOIN semester_klasses ON semester_klasses.id = reservations.source_semester_klass_id
          SET reservations.source_semester_id = semester_klasses.semester_id
        SQL
      end
    end
  end
end
