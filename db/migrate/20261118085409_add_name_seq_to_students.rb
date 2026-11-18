class AddNameSeqToStudents < ActiveRecord::Migration[8.1]
  def up
    add_column :students, :name_seq, :integer, null: false, default: 1

    execute <<~SQL
      UPDATE students s
      JOIN (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY campuse_id, name ORDER BY id) AS seq
        FROM students
      ) ranked ON ranked.id = s.id
      SET s.name_seq = ranked.seq
    SQL

    add_index :students, [ :campuse_id, :name, :name_seq ], unique: true
  end

  def down
    remove_index :students, column: [ :campuse_id, :name, :name_seq ]
    remove_column :students, :name_seq
  end
end
