class CreateUserCampuses < ActiveRecord::Migration[8.1]
  def change
    create_table :user_campuses do |t|
      t.references :school, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :campuse, null: false, foreign_key: true

      t.timestamps
    end
  end
end
