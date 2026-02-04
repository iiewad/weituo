class GradesAndSubjects < ActiveRecord::Migration[8.1]
  def change
    create_table :grades do |t|
      t.string :name, null: false
      t.string :level, null: false
    end
    create_table :subjects do |t|
      t.string :name, null: false
      t.string :code, null: false
    end
    create_table :grade_subjects do |t|
      t.belongs_to :school, null: false
      t.belongs_to :grade, null: false
      t.belongs_to :subject, null: false
    end
  end
end
