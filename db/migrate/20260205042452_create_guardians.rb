class CreateGuardians < ActiveRecord::Migration[8.1]
  def change
    create_table :guardians do |t|
      t.string :name, null: false
      t.string :phone, null: false
      t.string :relationship
      t.bigint :student_id, null: false
    end
  end
end
