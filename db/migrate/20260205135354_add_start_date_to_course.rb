class AddStartDateToCourse < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :start_date, :date, default: ""
  end
end
