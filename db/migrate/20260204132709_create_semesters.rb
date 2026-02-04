class CreateSemesters < ActiveRecord::Migration[8.1]
  def change
    create_table :semesters do |t|
      t.string :name, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.bigint :school_id, null: false
    end
  end
end
