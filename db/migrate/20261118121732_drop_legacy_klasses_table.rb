class DropLegacyKlassesTable < ActiveRecord::Migration[8.1]
  def up
    drop_table :klasses, if_exists: true
  end

  def down
    create_table :klasses do |t|
      t.bigint :campuse_id, null: false
      t.string :genre, null: false
      t.integer :seq, null: false
      t.bigint :subject_id, null: false
      t.bigint :teacher_id, null: false
    end
  end
end
