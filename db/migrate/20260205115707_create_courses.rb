class CreateCourses < ActiveRecord::Migration[8.1]
  def change
    create_table :courses do |t|
      t.integer :seq, null: false
      t.bigint :klass_id, null: false
    end
  end
end
