class CreateCampuses < ActiveRecord::Migration[8.1]
  def change
    create_table :campuses do |t|
      t.string :name, null: false
      t.bigint :school_id, null: false
    end
  end
end
