class AddSeqToSemesters < ActiveRecord::Migration[8.1]
  def change
    add_column :semesters, :seq, :integer
  end
end
