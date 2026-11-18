class AddUniqueSemesterSeqIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :semesters, [ :school_id, :seq ], unique: true
  end
end
