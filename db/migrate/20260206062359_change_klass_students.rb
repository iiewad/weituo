class ChangeKlassStudents < ActiveRecord::Migration[8.1]
  def change
    remove_column :klass_students, :stop_date, :date, if_exists: true
    remove_column :klass_students, :quit_date, :date, if_exists: true
    remove_column :klass_students, :join_date, :date, if_exists: true
  end
end
