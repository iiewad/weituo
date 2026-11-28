class AddDaySchoolClassNameToStudents < ActiveRecord::Migration[8.1]
  def change
    add_column :students, :day_school_class_name, :string
  end
end
