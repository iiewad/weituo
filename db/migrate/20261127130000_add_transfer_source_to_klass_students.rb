class AddTransferSourceToKlassStudents < ActiveRecord::Migration[8.1]
  def change
    add_column :klass_students, :transfer_source_klass_id, :bigint
    add_column :klass_students, :transfer_in_seq, :integer
    add_index :klass_students, :transfer_source_klass_id
    add_foreign_key :klass_students, :semester_klasses,
      column: :transfer_source_klass_id, on_delete: :nullify
  end
end
