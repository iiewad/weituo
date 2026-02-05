class CreateKlasses < ActiveRecord::Migration[8.1]
  def change
    create_table :klasses do |t|
      t.string :genre, null: false
      t.integer :seq, null: false
      t.integer :times, null: false
      t.bigint :semester_id, null: false
      t.bigint :grade_id, null: false
      t.bigint :subject_id, null: false
      t.bigint :campuse_id, null: false
      t.bigint :teacher_id, null: false
    end
  end
end
